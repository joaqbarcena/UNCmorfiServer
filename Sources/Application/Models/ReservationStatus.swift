import Foundation

enum ReservationStatus : String, Codable {
    case reserved //= "reserved"
    case unavailable //= "unavailable"
    case soldout //= "soldout"
    case invalid //= "invalid"
    case empty = "" //this is to complain kitura 's test
}

struct ReservationStatusWrapper : Codable {
    let reservationStatus:ReservationStatus?
}
