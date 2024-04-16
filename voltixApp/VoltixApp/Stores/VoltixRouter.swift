//
//  VoltixRouter.swift
//  VoltixApp
//
//  Created by Johnny Luo on 14/4/2024.
//

import Foundation

class VoltixRouter {
    static var IsRouterEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "use_voltix_router")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "use_voltix_router")
        }
    }
    static var VoltixApiKey: String{
        get{
            return UserDefaults.standard.string(forKey: "voltix_apikey") ?? ""
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "voltix_apikey")
        }
    }
}
