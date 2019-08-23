//
// Copyright © 2018 George Alegre. All rights reserved.
//

import Foundation

import Kitura
import KituraContracts

/// Router handling main API requests.
class APIRouter {

    private init() {}

    // MARK: - Endpoints

    static func setEndpoints(router: Router) {
        router.get("/users", handler: getUsers)
        router.get("/menu", handler: getMenu)
        router.get("/servings", handler: getServings)
        
        //MARK: Reservation actions
        router.get("/reservation/login", handler: getReservationLogin)
        router.post("/reservation/login", handler: doReservationLogin) //this will be deprecated
        router.post("/reservation/reserve", handler: doReservation)
        router.post("/reservation/status", handler: getReservation)
    }

    // MARK: - Handlers

    private struct GetUsersQuery: QueryParams {
        let codes: [String]
    }

    private static func getUsers(queryParams: GetUsersQuery, callback: @escaping ([User]?, RequestError?) -> Void) {
        UNCComedor.api.getUsers(from: queryParams.codes) { result in
            switch result {
            case let .success(users):
                callback(users, nil)
            case let .failure(error):
                print(error)
                callback(nil, nil)
            }

        }
    }

    private static func getMenu(callback: @escaping (Menu?, RequestError?) -> Void) {
        UNCComedor.api.getMenu { result in
            switch result {
            case let .success(menu):
                callback(menu, nil)
            case .failure(_):
                callback(nil, nil)
            }
        }
    }

    private static func getServings(callback: @escaping (Servings?, RequestError?) -> Void) {
        UNCComedor.api.getServings { result in
            switch result {
            case let .success(servings):
                callback(servings, nil)
            case .failure(_):
                callback(nil, nil)
            }

        }
    }
    
    //MARK: Reservation Feature
    
    private struct ReservationLoginParams : QueryParams {
        let code:String
    }
    private static func getReservationLogin(queryParams:ReservationLoginParams, callback: @escaping (ReservationLogin?,RequestError?) -> Void) {
        UNCComedor.api.getReservationLogin(of: queryParams.code) {
            result in
            switch result {
            case let .success(reservation):
                callback(reservation,nil)
            case .failure(_):
                callback(nil,nil)
            }
        }
    }
    
    private static func doReservationLogin(reservationLogin:ReservationLogin, callback: @escaping (ReservationLogin?,RequestError?) -> Void) {
        UNCComedor.api.doReservationLogin(with: reservationLogin) {
            result in
            switch result {
            case let .success(reservation):
                callback(reservation,nil)
            case .failure(_):
                callback(nil,nil)
            }
        }
    }
    
    private static func doReservation(reservationLogin:ReservationLogin, callback: @escaping (ReservationStatusWrapper?,RequestError?) -> Void){
        UNCComedor.api.doReservation(withAction:.doReservation, reservationLogin:reservationLogin) {
            result in
            switch result {
            case let .success(reservationStatus):
                callback(ReservationStatusWrapper(reservationStatus: reservationStatus),nil)
            case .failure(_):
                callback(nil,nil)
            }
        }
    }
    
    private static func getReservation(reservationLogin:ReservationLogin, callback: @escaping (ReservationStatusWrapper?,RequestError?) -> Void){
        UNCComedor.api.doReservation(withAction:.getReservation, reservationLogin:reservationLogin) {
            result in
            switch result {
            case let .success(reservationStatus):
                callback(ReservationStatusWrapper(reservationStatus: reservationStatus),nil)
            case .failure(_):
                callback(nil,nil)
            }
        }
    }
    
}
