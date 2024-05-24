//
//  TransactionMemoMigrate.swift
//  VultisigApp
//
//  Created by Enrique Souza Soares on 15/05/24.
//

import SwiftUI
import Foundation
import Combine

class TransactionMemoMigrate: TransactionMemoAddressable, ObservableObject {
    @Published var blockHeight: Int = 0
    
    var addressFields: [String: String] {
        get { [:] }
        set { }
    }
    
    required init() {}
    
    init(blockHeight: Int) {
        self.blockHeight = blockHeight
    }
    
    var description: String {
        return toString()
    }
    
    func toString() -> String {
        return "MIGRATE:\(self.blockHeight)"
    }
    
    func toDictionary() -> ThreadSafeDictionary<String, String> {
        let dict = ThreadSafeDictionary<String, String>()
        dict.set("blockHeight", "\(self.blockHeight)")
        dict.set("memo", self.toString())
        return dict
    }
    
    func getView() -> AnyView {
        AnyView(VStack {
            StyledIntegerField(placeholder: "Block Height", value: Binding(
                get: { self.blockHeight },
                set: { self.blockHeight = $0 }
            ), format: .number)
        })
    }
}
