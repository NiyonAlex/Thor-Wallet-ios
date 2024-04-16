//
//  THORChainSwapPayload.swift
//  VoltixApp
//

import Foundation
import WalletCore

extension THORChainSwapChain: Codable {}

extension THORChainSwapAsset: Codable {
    enum CodingKeys: String, CodingKey {
        case chain
        case symbol
        case tokenID
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.chain = try container.decode(THORChainSwapChain.self, forKey: .chain)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.tokenID = try container.decode(String.self, forKey: .tokenID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.chain, forKey: .chain)
        try container.encode(self.symbol, forKey: .symbol)
        try container.encode(self.tokenID, forKey: .tokenID)
    }
}

struct THORChainSwapPayload: Codable, Hashable {
    let fromAddress: String
    let fromAsset: THORChainSwapAsset
    let toAsset: THORChainSwapAsset
    let toAddress: String
    let vaultAddress: String
    let routerAddress: String?
    let fromAmount: String
    let toAmountLimit: String
    let streamingInterval: String
    let streamingQuantity: String

    init(fromAddress: String,
         fromAsset: THORChainSwapAsset,
         toAsset: THORChainSwapAsset,
         toAddress: String,
         vaultAddress: String,
         routerAddress: String?,
         fromAmount: String,
         toAmountLimit: String,
         streamingInterval: String,
         streamingQuantity: String)
    {
        self.fromAddress = fromAddress
        self.fromAsset = fromAsset
        self.toAsset = toAsset
        self.toAddress = toAddress
        self.vaultAddress = vaultAddress
        self.routerAddress = routerAddress
        self.fromAmount = fromAmount
        self.toAmountLimit = toAmountLimit
        self.streamingInterval = streamingInterval
        self.streamingQuantity = streamingQuantity
    }
}
