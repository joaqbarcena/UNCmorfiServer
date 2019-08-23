//
// Copyright © 2018 George Alegre. All rights reserved.
//

import Foundation

import SwiftSoup

class UNCComedor {

    // MARK: Singleton

    static let api = UNCComedor()
    private init() {}

    // MARK: URLSession
    //Universal session to connect with Rest-services
    private let session = URLSession.shared
    
    //Sesssion that doesnt persist cookies, so they are saved at real end-client
    private let restSession:URLSession = {
        let defaultRestConfig = URLSessionConfiguration.default.copy() as! URLSessionConfiguration
        defaultRestConfig.httpCookieAcceptPolicy = .never
        defaultRestConfig.httpCookieStorage = nil
        defaultRestConfig.httpShouldSetCookies = true
        return URLSession(configuration: defaultRestConfig)
    }()


    // MARK: API endpoints

    private static let baseDataURL = "http://comedor.unc.edu.ar/gv-ds.php"
    private static let baseMenuURL = URL(string: "https://www.unc.edu.ar/vida-estudiantil/men%C3%BA-de-la-semana")!
    private static let baseServingsURL = URL(string: "http://comedor.unc.edu.ar/gv-ds.php?json=true&accion=1&sede=0475")!
    private static let baseImageURL = URL(string: "https://asiruws.unc.edu.ar/foto/")!
    private static let baseReservationURL = "http://comedor.unc.edu.ar/reserva"

    
    // MARK: Errors

    enum APIError: Error {
        /// General error for non 200 HTTP code responses
        case badResponse

        /// When the response cannot be decoded
        case dataDecodingError

        case menuUnparseable
        case userUnparseable
        case servingDateUnparseable
        case servingCountUnparseable
        
        //Unparsable reservation token/path
        case pathUnparseable
        case tokenUnparseable
        case captchaUnparseable
        
        //Captcha/Session inconsistences
        case captchaTextEmpty
        case cookiesEmpty
        case cookiesInvalid
        
        //
        case unimplementedFunction
    }

    // MARK: Helpers

    /**
     Use as first error handling method of any type of URLSession task.
     - Parameters:
     - error: an optional error found in the task completion handler.
     - res: the `URLResponse` found in the task completion handler.
     - Returns: if an error is found, a custom error is returned, else `nil`.
     */
    private static func handleAPIResponse(error: Error?, res: URLResponse?) -> Error? {
        guard error == nil else {
            // TODO handle client error
            //            handleClientError(error)
            return error!
        }

        guard let httpResponse = res as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
                print("response = \(res!)")
                return APIError.badResponse
        }
        
        return nil
    }
    
    
    /**
     Boundary generator
     */
    private static func boundary() -> String {
        return "----WebKitFormBoundary\(String((0..<16).map{ _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!}))"
    }
    /**
     Parser to get application submit path, token and alert message
     This is done by regex, but i would like replace it with soup parser
     - Parameters:
     - page : the html page
     - getAlertMessage? : the last stage has an alert message, and this search
        and retrieve that message
    */
    private static func parseReservationPage(page:String, getAlertMessage:Bool=false) -> Result<(path:String, token:String, alertMessage:String?)> {
            
        //Search/scrap submit path
        guard let pathRange = page.range(of: "/aplicacion\\.php.*onsubmit", options: .regularExpression)
            else {
                return .failure(APIError.pathUnparseable)
            }
        let path = String(page[pathRange].dropLast("' onsubmit".count))
            
        //Search/scrap token
        guard let tokenRange = page.range(of: "id='cstoken'.*/>", options: .regularExpression)
            else {
                return .failure(APIError.tokenUnparseable)
            }
        let token = String(page[tokenRange][page[tokenRange].range(of: "value='.*'", options: .regularExpression)!]
            .dropFirst("value='".count)
            .dropLast("'".count))
        
        var alertMessage:String? = nil
        if getAlertMessage {
            if let alertRange = page.range(of: "<script language='JavaScript'>alert\\(.*;</script></div>", options: .regularExpression){
                let alert = page[alertRange]
                if let idxL = alert.range(of: "alert('"),
                    let idxU = alert.range(of: "');") {
                    alertMessage = String(alert[idxL.upperBound..<idxU.lowerBound])
                }
                // else { return .failure(APIError.alertUnparseable) } ???
            }
        }
        //<td class="ei-cuadro-fila 4">CONSUMIDO</td>
        return .success((path, token, alertMessage))
    }
    
    /**
     Request builder for differents stages
     - Parameters:
     -  action : ReservationAction = (getLogin, doLogin, doProcess)
     -  withPath : String = Path where it sends the form data
     -  withToken : String = Token sended inside the form data (always)
     - Returns: The request ready to use with dataTask
     */
    private static func buildRequest(_ action:ReservationAction, _ reservationLogin:ReservationLogin, withBoundary boundary:String="") -> URLRequest {
        return buildRequest(action,
                            withPath: reservationLogin.path,
                            withToken: reservationLogin.token,
                            withBoundary:boundary,
                            withCode: reservationLogin.code,
                            withCaptcha: reservationLogin.captchaText ?? "",
                            withCookies: reservationLogin.cookies ?? [])
    }
    
    private static func buildRequest(_ action:ReservationAction, withPath path:String = "/",
                      withToken token:String = "",
                      withBoundary boundary:String="",
                      withCode code:String="",
                      withCaptcha captcha:String="",
                      withCookies cookies:[CodableCookie]=[]) -> URLRequest {
        
        var infoRequest:(httpMethod: String, httpBody: String)
        var headers = [
            "cache-control": "no-cache"
        ]
        switch action {
        case .getLogin:
            infoRequest = ("GET","")
        case .doLogin:
            infoRequest = ("POST","--\(boundary)\nContent-Disposition: form-data; name=\"cstoken\"\n\n\(token)\n--\(boundary)\nContent-Disposition: form-data; name=\"form_2689_datos\"\n\n\("ingresar")\n--\(boundary)\nContent-Disposition: form-data; name=\"form_2689_datos_implicito\"\n\n\n--\(boundary)\nContent-Disposition: form-data; name=\"ef_form_2689_datosusuario\"\n\n\(code)\n--\(boundary)\nContent-Disposition: form-data; name=\"ef_form_2689_datoscontrol\"\n\n\(captcha)\n--\(boundary)--")
        case .doReservation:
            infoRequest = ("POST","--\(boundary)\nContent-Disposition: form-data; name=\"cstoken\"\n\n\(token)\n--\(boundary)\nContent-Disposition: form-data; name=\"ci_2695\"\n\n\("procesar")\n--\(boundary)\nContent-Disposition: form-data; name=\"ci_2695__param\"\n\n\("undefined")\n--\(boundary)--")
        case .getReservation:
            infoRequest = ("POST","--\(boundary)\nContent-Disposition: form-data; name=\"cstoken\"\n\n\(token)\n--\(boundary)\nContent-Disposition: form-data; name=\"ci_2695\"\n\n\("consu_rese")\n--\(boundary)\nContent-Disposition: form-data; name=\"ci_2695__param\"\n\n\("undefined")\n--\(boundary)--")
        }
        
        var request = URLRequest(url: URL(string: UNCComedor.baseReservationURL + path)!)
        if infoRequest.httpMethod == "POST" {
            //TODO read meta header in response
            request.httpBody = infoRequest.httpBody.data(using: .isoLatin1)
            headers["Content-Type"] = "multipart/form-data; boundary=" + boundary
        }
        //mapea las codableCookies a cookies que no sean nil
        let cookies = cookies.compactMap({ $0.toCookie() })
        if !cookies.isEmpty {
            headers.merge(HTTPCookie.requestHeaderFields(with: cookies)){ (_,new) in new }
        }
        request.httpMethod = infoRequest.httpMethod
        request.allHTTPHeaderFields = headers
        
        return request
    }

    // MARK: - Public API methods
    
    func getReservationLogin(of code: String, callback: @escaping (_ result: Result<ReservationLogin>) -> Void) {
        //Check empty-ness, maybe it's unnecesary
        guard !code.isEmpty else {
            callback(.failure(APIError.badResponse)) //TODO: Change this
            return
        }
        
        let task = restSession.dataTask(with: UNCComedor.buildRequest(.getLogin)){ data, res, error in
            //Exit early
            let httpError = UNCComedor.handleAPIResponse(error: error, res: res)
            guard httpError == nil else {
                callback(.failure(httpError!))
                return
            }
            
            guard let data = data,
                let dataString = String(data: data, encoding: .isoLatin1) else {
                    callback(.failure(APIError.dataDecodingError))
                    return
            }
            
            guard let res = res as? HTTPURLResponse else {
                    callback(.failure(APIError.badResponse))
                    return
            }
            
            var cookies:[CodableCookie] = []
            if let headers = res.allHeaderFields as? [String:String] {
                let httpCookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: res.url!)
                cookies = httpCookies.map({
                    CodableCookie.fromCookie(cookie: $0)//🍪
                })
            }
            
            guard !cookies.isEmpty else {
                    callback(.failure(APIError.cookiesEmpty))
                    return
            }
            
            switch(UNCComedor.parseReservationPage(page: dataString)){
            //Parsing error
            case .failure(let parserError):
                callback(.failure(parserError))
                
            //getLogin results succesfully
            case .success(let (path,token,_)):
                guard let captchaRange = dataString.range(of: "/aplicacion\\.php.*?ts=mostrar_captchas_efs.*?>", options: .regularExpression) else {
                    callback(.failure(APIError.captchaUnparseable))
                    return
                }
                let captchaPath = String(dataString[captchaRange].dropLast(4))
                let task = self.restSession.dataTask(with: UNCComedor.buildRequest(.getLogin, withPath:captchaPath, withCookies:cookies)) {
                    data, res, error in
                    
                    //Exit Early
                    let httpError = UNCComedor.handleAPIResponse(error: error, res: res)
                    guard httpError == nil else {
                        callback(.failure(httpError!))
                        return
                    }
                    guard let data = data else {
                        callback(.failure(APIError.captchaUnparseable)) //TODO: maybe this should never fire
                        return
                    }
                    
                    callback(.success(ReservationLogin(path:path, token:token, captchaText:nil, captchaImage:data, cookies:cookies, code:code)))
                }
                task.resume()
                
            }
        }
        task.resume()
    }
    
    //TODO: pasarlo a private luego para dejarlo en doProcess ya que luego lksdf
    public func doReservationLogin(with reservationLogin:ReservationLogin, callback: @escaping(_ result:Result<ReservationLogin>) -> Void){
        
        //Exit early
        guard reservationLogin.captchaText != nil else {
            callback(.failure(APIError.captchaTextEmpty))
            return
        }
        guard let cookies = reservationLogin.cookies else {
            callback(.failure(APIError.cookiesEmpty))
            return
        }
        guard !cookies.filter({$0.name == "TOBA_SESSID"}).isEmpty else {
            callback(.failure(APIError.cookiesInvalid))
            return
        }
        
        //Generate a random boundary
        let boundary = UNCComedor.boundary()

        //Makes sure than will not reuse another session cookies
        let task = restSession.dataTask(with: UNCComedor.buildRequest(.doLogin, reservationLogin, withBoundary: boundary)){
            data, res, error in
            
            //Exit early
            let httpError = UNCComedor.handleAPIResponse(error: error, res: res)
            guard httpError == nil else {
                callback(.failure(httpError!))
                return
            }
            
            guard let data = data,
                let dataString = String(data: data, encoding: .isoLatin1) else {
                    callback(.failure(APIError.dataDecodingError))
                    return
            }
            
            switch(UNCComedor.parseReservationPage(page: dataString)){
            //Parsing error, analizar que tipo de error expiro la session ?
            case .failure(let parserError):
                callback(.failure(parserError))
                
            //doLogin results (almost) succesfully
            case .success(let (path,token,_)):
                callback(.success(ReservationLogin(path: path, token: token, captchaText: nil, captchaImage: nil, cookies: reservationLogin.cookies, code: reservationLogin.code)))
                return
            }
        }
        task.resume()
    }
    
    func doReservation(withAction action:ReservationAction, reservationLogin:ReservationLogin, callback: @escaping (_ result:Result<ReservationStatus>) -> Void){
        
        switch action {
        case .doReservation:
            doReservationLogin(with: reservationLogin){
                result in
                switch result {
                case let .success(reservationLogin):
                    let task = self.restSession.dataTask(with:
                    UNCComedor.buildRequest(.doReservation, reservationLogin, withBoundary: UNCComedor.boundary())){
                        data, res, error in
                        
                        //Exit early, Here maybe the server is down so cookies are no longer valid ...
                        let httpError = UNCComedor.handleAPIResponse(error: error, res: res)
                        guard httpError == nil else {
                            callback(.failure(httpError!))
                            return
                        }
                        
                        guard let data = data,
                            let dataString = String(data: data, encoding: .isoLatin1) else {
                                callback(.failure(APIError.dataDecodingError))
                                return
                        }
                        //parse and get the alertmessage if it's present
                        switch(UNCComedor.parseReservationPage(page: dataString, getAlertMessage: true)){
                        //Parsing error
                        case .failure(let parserError):
                            callback(.failure(parserError))
                            //callback(.success(.redoLogin))
                            
                        //doProcess results (almost) succesfully
                        case .success(let (_,_,alert?)):
                            print(alert)
                            if alert.contains("SE REALIZO LA RESERVA CON") {
                                callback(.success(.reserved))
                            } else if alert.contains("NO HAY MAS RESERVAS DISPONIBLES") {
                                callback(.success(.soldout))
                            } else {
                                callback(.success(.unavailable))
                            }
                            
                        case .success(_,_,nil):
                            print(dataString)
                            callback(.success(.invalid))
                        }
                    }
                    task.resume()
                case .failure(_):
                    //This should driver a .failure, to the client
                    callback(.success(.redoLogin)) //Session expires, captcha could change or empty cookie
                }
            }
        //case .getReservation
        default :
            callback(.failure(APIError.unimplementedFunction))
        }
    }
    

    func getMenu(callback: @escaping (_ result: Result<Menu>) -> Void) {
        let task = session.dataTask(with: UNCComedor.baseMenuURL) { data, res, error in
            // Check for errors and exit early.
            let customError = UNCComedor.handleAPIResponse(error: error, res: res)
            guard customError == nil else {
                callback(.failure(customError!))
                return
            }

            guard let data = data,
                let dataString = String(data: data, encoding: .utf8) else {
                    callback(.failure(APIError.dataDecodingError))
                    return
            }

            // Try to parse HTML and find the elements we care about.
            let elements: Elements
            let monthYear: String
            do {
                let doc = try SwiftSoup.parse(dataString)
                elements = try doc.select("div[class='field-item even']")
                monthYear = try elements.select("div[class='tabla_title']").text().components(separatedBy: "-")[1]
            } catch {
                callback(.failure(APIError.menuUnparseable))
                return
            }

            // Should handle parsing lightly, don't completely know server's behaviour.
            // Prefer to not show anything or parse wrongly than to crash.
            var menu: [Date: [String]] = [:]

            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy dd"
            formatter.locale = Locale(identifier: "es_AR")

            // For each day, parse the menu.
            do {
                for (day, list) in zip(try elements.select("p strong"), try elements.select("ul")) {
                    let dayNumber = try day.text()
                        .components(separatedBy:CharacterSet.decimalDigits.inverted)
                        .joined(separator: "")

                    let listItems: [Element] = try list.select("li").array()

                    let foodList = listItems
                        .compactMap { try? $0.text() }
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                    let date = formatter.date(from: "\(monthYear) \(dayNumber)")!
                    menu[date] = foodList
                }
            } catch {
                callback(.failure(APIError.menuUnparseable))
                return
            }

            // For some reason, Kitura encodes a [Date: [String]] dictionary wrong.
            // Using strings as keys instead in the meantime.
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]
            var uglyMenu: [String: [String]] = [:]
            for (key, value) in menu {
                uglyMenu[dateFormatter.string(from: key)] = value
            }

            callback(.success(Menu(menu: uglyMenu)))
        }

        task.resume()
    }

    func getUsers(from codes: [String], callback: @escaping (_ result: Result<[User]>) -> Void) {
        // Exit early.
        guard !codes.isEmpty else {
            callback(.success([]))
            return
        }

        /// API only returns one user at a time. Use a dispatch group to execute many requests in
        /// parallel and wait for all to finish.
        let queue = DispatchQueue(label: "getUsers")
        let group = DispatchGroup()

        func getUser(from code: String, callback: @escaping (_ result: Result<User>) -> Void) {
            // Prepare the request and its parameters.
            var request = URLRequest(url: URL(string: UNCComedor.baseDataURL)!)
            request.httpMethod = "POST"
            request.httpBody = "accion=4&codigo=\(code)".data(using: .utf8)

            // Send the request and setup the callback.
            let task  = session.dataTask(with: request) { data, res, error in
                // Check for errors and exit early.
                let customError = UNCComedor.handleAPIResponse(error: error, res: res)
                guard customError == nil else {
                    callback(.failure(customError!))
                    return
                }

                guard let data = data,
                    let dataString = String(data: data, encoding: .utf8) else {
                    callback(.failure(APIError.dataDecodingError))
                    return
                }


                // Parse the data.
                let preffix = "rows: [{c: ["
                let suffix = "]}]}});"

                guard
                    let preffixIndex = dataString.range(of: preffix)?.upperBound,
                    let suffixIndex = dataString.range(of: suffix)?.lowerBound
                else {
                    callback(.failure(APIError.userUnparseable))
                    return
                }
                let components = dataString[preffixIndex..<suffixIndex].components(separatedBy: "},{")

                var _16 = components[16]
                _16 = String(_16[_16.index(_16.startIndex, offsetBy: 4)..._16.index(_16.startIndex, offsetBy: _16.count - 2)])

                var _17 = components[17]
                _17 = String(_17[_17.index(_17.startIndex, offsetBy: 4)..._17.index(_17.startIndex, offsetBy: _17.count - 2)])

                var _5 = components[5]
                _5 = String(_5[_5.index(_5.startIndex, offsetBy: 3)..._5.index(_5.startIndex, offsetBy: _5.count - 1)])

                var _24 = components[24]
                _24 = String(_24[_24.index(_24.startIndex, offsetBy: 4)..._24.index(_24.startIndex, offsetBy: _24.count - 2)])

                var _8 = components[8]
                _8 = String(_8[_8.index(_8.startIndex, offsetBy: 4)..._8.index(_8.endIndex, offsetBy: -2)])

                var _4 = components[4]
                _4 = String(_4[_4.index(_4.startIndex, offsetBy: 12)..._4.index(_4.endIndex, offsetBy: -2)])
                _4 = _4.components(separatedBy: ", ").joined(separator: "-") + "T00:00:00Z"

                let name = "\(_16) \(_17)"
                let balance = Int(_5)!
                let image = _24
                let type = _8
                let imageURL = UNCComedor.baseImageURL.appendingPathComponent(_24)

                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                dateFormatter.formatOptions = [.withInternetDateTime]
                let expirationDate = dateFormatter.date(from: _4)!
                let expirationDateString = dateFormatter.string(from: expirationDate)

                let user = User(name: name,
                                code: code,
                                balance: balance,
                                imageCode: image,
                                expirationDate: expirationDateString,
                                type: type,
                                imageURL: imageURL)

                callback(.success(user))
            }

            task.resume()

        }

        // Shared storage for each task
        var users: [String: User] = [:]

        // Run all tasks concurrently.
        for code in codes {
            group.enter()

            getUser(from: code) { result in
                defer { group.leave() }

                switch result {
                case let .success(user):
                    users[code] = user
                case let .failure(error):
                    print(error)
                }
            }
        }

        // Wait for all tasks to be finished.
        group.notify(queue: queue) {
            callback(.success(Array(users.values)))
        }
    }

    func getServings(callback: @escaping (_ result: Result<Servings>) -> Void) {
        let task = session.dataTask(with: UNCComedor.baseServingsURL) { data, res, error in
            // Check for errors and exit early.
            let customError = UNCComedor.handleAPIResponse(error: error, res: res)
            guard customError == nil else {
                callback(.failure(customError!))
                return
            }

            guard let data = data,
                let dataString = String(data: data, encoding: .utf8) else {
                callback(.failure(APIError.dataDecodingError))
                return
            }


            /* Server response is weird Javascript function application with data as function's parameter.
             * Data is not a JSON string but a Javascript object, not to be confused with one another.
             */

            // Attempt to parse string into something useful.
            guard
                let start = dataString.range(of: "(")?.upperBound,
                let end = dataString.range(of: ")")?.lowerBound else {
                    callback(.failure(APIError.servingCountUnparseable))
                    return
            }
            var jsonString = String(dataString[start..<end])

            jsonString = jsonString
                // Add quotes to keys.
                .replacingOccurrences(of: "(\\w*[A-Za-z]\\w*)\\s*:",
                                      with: "\"$1\":",
                                      options: .regularExpression,
                                      range: jsonString.startIndex..<jsonString.endIndex)
                // Replace single quotes with double quotes.
                .replacingOccurrences(of: "'", with: "\"")

            // Parse fixed string.
            guard let jsonData = jsonString.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                callback(.failure(APIError.servingCountUnparseable))
                return
            }

            // Transform complicated JSON structure into simple [Date: Int] dictionary.
            guard let table = json?["table"] as? [String: [[String: Any]]],
                let rows = table["rows"] else {
                callback(.failure(APIError.servingCountUnparseable))
                return
            }

            let result = rows.reduce([Date: Int]()) { (result, row) -> [Date: Int] in
                // 'result' parameter is constant, can't be changed.
                var result = result

                guard let row = row["c"] as? [[String: Any]] else {
                    return result
                }

                // The server only gave us a time in timezone GMT-3 (e.g. 12:09:00)
                // We need to add the current date and timezone data. (e.g. 2017-09-10 15:09:00 +0000)
                // Start off by getting the current date.
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'"

                let todaysDate = dateFormatter.string(from: Date())

                // Join today's date, the time from the row and the timezone into one string in ISO format.
                guard let time = row[0]["v"] as? String else {
                    return result
                }
                let dateString = "\(todaysDate)\(time)-0300"

                // Add time and timezone support to the parser.
                let timeFormat = "HH:mm:ssZ"
                dateFormatter.dateFormat = dateFormatter.dateFormat + timeFormat

                // Get a Date object from the resulting string.
                guard let date = dateFormatter.date(from: dateString) else {
                    return result
                }

                // Get food count from row.
                guard let count = row[1]["v"] as? Int else {
                    return result
                }

                // Add data to the dictionary.
                result[date] = count

                return result
            }

            // TODO this is a workaround of an error with Kitura not encoding Date keys properly.
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]
            var servings: [String: Int] = [:]
            for (key, value) in result {
                servings[dateFormatter.string(from: key)] = value
            }
            callback(.success(Servings(servings: servings)))
        }

        task.resume()
    }
    
    
    // MARK: Deprecated methods
    
    @available(*,deprecated)
    func getReservation(of code: String, callback: @escaping (_ result: Result<ReservationStatus>) -> Void) {
        /**
         The reservation consists performing 3 steps
         - Get Login page then parse "cstoken" and submit-action path of the form (/aplicacion.php?...)
         while the path is constant, it contains query params calle ai & ah, that idk what they are,
         but `ai` its like a hash and ah has a couple of values like `migestion||3614`
         - Perform a POST (with login data) at the submit path with some boundaries, they should be random
         or constants because the boundaries goes into header but idk if the server do some check of
         the length of boundaries, then parse same cstoken and submit path
         - At last instance, do another POST like the previus step but the data request a "procesar" command
         so that makes the reservation, then parse an alert dialog with status of your request
         **/
        
        //Check empty-ness, maybe it's unnecesary
        guard !code.isEmpty else {
            callback(.success(ReservationStatus.invalid))
            return
        }
        
        //Boundary + Random 16 chars generator
        let boundary = UNCComedor.boundary()
        
        //Starts succesive requests to do a reservation
        //MARK: getLogin
        //Stage 1, get Login page to obtain path and token
        let task = session.dataTask(with: UNCComedor.buildRequest(.getLogin)){ data, res, error in
            //Exit early
            let httpError = UNCComedor.handleAPIResponse(error: error, res: res)
            guard httpError == nil else {
                callback(.failure(httpError!))
                return
            }
            
            guard let data = data,
                let dataString = String(data: data, encoding: .isoLatin1) else {
                    callback(.failure(APIError.dataDecodingError))
                    return
            }
            
            switch(UNCComedor.parseReservationPage(page: dataString)){
            //Parsing error
            case .failure(let parserError):
                callback(.failure(parserError))
                
            //getLogin results succesfully
            case .success(let (path,token,_)):
                // TODO: Now Firtstly we have to complete the parsing this maybe possible with and ocr ?
                //MARK: doLogin
                //Stage 2 do Login with path, token and provided user code
                let task = self.session.dataTask(with:
                UNCComedor.buildRequest(.doLogin, withPath: path, withToken: token, withBoundary: boundary, withCode: code)){
                    data, res, error in
                                                
                    //Exit early
                    let httpError = UNCComedor.handleAPIResponse(error: error, res: res)
                    guard httpError == nil else {
                        callback(.failure(httpError!))
                        return
                    }
                    
                    guard let data = data,
                        let dataString = String(data: data, encoding: .isoLatin1) else {
                            callback(.failure(APIError.dataDecodingError))
                            return
                    }
                    
                    switch(UNCComedor.parseReservationPage(page: dataString)){
                    //Parsing error
                    case .failure(let parserError):
                        callback(.failure(parserError))
                        
                    //doLogin results (almost) succesfully
                    case .success(let (path,token,_)):
                        
                        //MARK: doProcess
                        //Stage 3 do Process with path, token
                        let task = self.session.dataTask(with:
                            UNCComedor.buildRequest(.doReservation, withPath: path, withToken: token, withBoundary: boundary, withCode: code)){
                                data, res, error in
                                                        
                                //Exit early
                                let httpError = UNCComedor.handleAPIResponse(error: error, res: res)
                                guard httpError == nil else {
                                    callback(.failure(httpError!))
                                    return
                                }
                                
                                guard let data = data,
                                    let dataString = String(data: data, encoding: .isoLatin1) else {
                                        callback(.failure(APIError.dataDecodingError))
                                        return
                                }
                                //parse and get the alertmessage if it's present
                                switch(UNCComedor.parseReservationPage(page: dataString, getAlertMessage: true)){
                                //Parsing error
                                case .failure(let parserError):
                                    callback(.failure(parserError))
                                    
                                //doProcess results (almost) succesfully
                                case .success(let (_,_,alert?)):
                                    print(alert)
                                    if alert.contains("SE REALIZO LA RESERVA CON") {
                                        callback(.success(.reserved))
                                    } else if alert.contains("NO HAY MAS RESERVAS DISPONIBLES") {
                                        callback(.success(.soldout))
                                    } else {
                                        callback(.success(.unavailable))
                                    }
                                    
                                case .success(_,_,nil):
                                    callback(.success(.invalid))
                                }
                        }
                        task.resume()
                    }
                }
                task.resume()
            }
        }
        task.resume()
    }
    
}
