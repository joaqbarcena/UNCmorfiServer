import Foundation

// MARK: ReservationLogin Model

struct ReservationLogin : Codable {
    let path:String
    let token:String
    let captchaText:String?
    let captchaImage:Data?
    let cookies:[CodableCookie]?
    let code:String
}

struct CodableCookie : Codable {
    let name:String
    let value:String
    //let sessionOnly:Bool
    let domain:String
    //let created:String //This is date so must parse
    func toCookie() -> HTTPCookie? {
        return HTTPCookie(properties:[
                HTTPCookiePropertyKey.name : self.name,
                HTTPCookiePropertyKey.value : self.value,
                HTTPCookiePropertyKey.domain : self.domain,
                //Harcodeo cosmico, without this httpCookie is nil
                HTTPCookiePropertyKey.path : "/",
                HTTPCookiePropertyKey.secure : "FALSE",
                HTTPCookiePropertyKey.expires : "(null)"
            ])
    }
    
    public static func fromCookie(cookie:HTTPCookie) -> CodableCookie {
        return CodableCookie(name: cookie.name, value:cookie.value, domain:cookie.domain)
    }
}

// MARK: Reservation Status Model

struct ReservationStatus : Codable {
    let reservationResult:ReservationResult?
    let path:String?  //Found that "doLogin" re-sending nextPath is unnecesary
    let token:String? //Also token changes
}

enum ReservationResult : String, Codable {
    case reserved
    case unavailable
    case soldout
    case invalid
    case redoLogin
    
    //this is to complain kitura 's test
    case empty = ""
}

// MARK: Reservation actions

enum ReservationAction {
    case getLogin
    case doLogin
    case getReservation
    case doReservation
    //case doCancel ?
}
