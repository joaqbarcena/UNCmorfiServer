import Foundation

struct ReservationLogin : Codable {
    //The image path of captcha also needs session info, so instead sending cookies...
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

enum ReservationStatus : String, Codable {
    case reserved
    case unavailable
    case soldout
    case invalid
    case redoLogin
    
    //this is to complain kitura 's test
    case empty = ""
}

struct ReservationStatusWrapper : Codable {
    let reservationStatus:ReservationStatus?
}

// MARK: Reservation actions

enum ReservationAction {
    case getLogin
    case doLogin
    case getReservation
    case doReservation
    //case doCancel ?
}

/**
 <NSHTTPCookie
 version:0
 name:TOBA_SESSID
 value:qgajrl7v86l3jij00jj1dia4l2
 expiresDate:'(null)'
 created:'2019-08-22 05:45:09 +0000'
 sessionOnly:TRUE
 domain:comedor.unc.edu.ar
 partition:none
 path:/
 isSecure:FALSE
 path:"/" isSecure:FALSE>, <NSHTTPCookie
 version:0
 name:serverid
 value:server_3|XV4r6|XV4r6
 expiresDate:'(null)'
 created:'2019-08-22 05:45:09 +0000'
 sessionOnly:TRUE
 domain:.unc.edu.ar
 partition:none
 path:/
 isSecure:FALSE
 path:"/" isSecure:FALSE>]
*/
