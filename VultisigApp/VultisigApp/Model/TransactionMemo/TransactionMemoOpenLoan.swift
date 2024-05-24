//
//  TransactionMemoOpenLoan.swift
//  VultisigApp
//
//  Created by Enrique Souza Soares on 15/05/24.
//

import SwiftUI
import Foundation
import Combine

class TransactionMemoOpenLoan: TransactionMemoAddressable, ObservableObject {
    @Published var asset: String = ""
    @Published var destinationAddress: String = ""
    @Published var minOut: Double = 0.0
    @Published var affiliate: String = ""
    @Published var fee: Double = 0.0
    
    var addressFields: [String: String] {
        get { ["destinationAddress": destinationAddress, "affiliate": affiliate] }
        set {
            if let value = newValue["destinationAddress"] { destinationAddress = value }
            if let value = newValue["affiliate"] { affiliate = value }
        }
    }
    
    required init() {}
    
    init(asset: String, destinationAddress: String, minOut: Double, affiliate: String = "", fee: Double = 0.0) {
        self.asset = asset
        self.destinationAddress = destinationAddress
        self.minOut = minOut
        self.affiliate = affiliate
        self.fee = fee
    }
    
    var description: String {
        return toString()
    }
    
    func toString() -> String {
        var memo = "LOAN+:\(self.asset):\(self.destinationAddress)"
        
        if self.minOut != 0.0 {
            memo += ":\(self.minOut)"
        } else {
            memo += ":"
        }
        
        if !self.affiliate.isEmpty {
            memo += ":\(self.affiliate)"
        }
        
        if self.fee != 0.0 {
            if self.affiliate.isEmpty {
                memo += "::\(self.fee)"
            } else {
                memo += ":\(self.fee)"
            }
        }
        
        return memo
    }
    
    func toDictionary() -> ThreadSafeDictionary<String, String> {
        let dict = ThreadSafeDictionary<String, String>()
        dict.set("asset", "\(self.asset)")
        dict.set("destinationAddress", "\(self.destinationAddress)")
        dict.set("minOut", "\(self.minOut)")
        dict.set("affiliate", "\(self.affiliate)")
        dict.set("fee", "\(self.fee)")
        dict.set("memo", self.toString())
        return dict
    }
    
    func getView() -> AnyView {
        AnyView(VStack {
            StyledTextField(placeholder: "Asset", text: Binding(
                get: { self.asset },
                set: { self.asset = $0 }
            ))
            TransactionMemoAddressTextField(memo: self, addressKey: "destinationAddress")
            StyledFloatingPointField(placeholder: "Min Out", value: Binding(
                get: { self.minOut },
                set: { self.minOut = $0 }
            ), format: .number)
            TransactionMemoAddressTextField(memo: self, addressKey: "affiliate")
            StyledFloatingPointField(placeholder: "Fee", value: Binding(
                get: { self.fee },
                set: { self.fee = $0 }
            ), format: .number)
        })
    }
}
