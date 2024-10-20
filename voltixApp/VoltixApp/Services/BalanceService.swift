//
//  BalanceService.swift
//  VoltixApp
//
//  Created by Artur Guseinov on 04.04.2024.
//

import Foundation

class BalanceService {
    static let shared = BalanceService()

    private let utxo = BlockchairService.shared
    private let thor = ThorchainService.shared
    private let sol = SolanaService.shared
    private let gaia = GaiaService.shared
    private let ton = TonService.shared
    
    func balance(for coin: Coin) async throws -> (coinBalance: String, balanceFiat: String, balanceInFiatDecimal: Decimal) {
        
        switch coin.chain {
        case .bitcoin, .bitcoinCash, .litecoin, .dogecoin:
            let blockChairData = try await utxo.fetchBlockchairData(coin: coin)
            coin.rawBalance = blockChairData?.address?.balance?.description ?? "0"
            coin.priceRate = await CryptoPriceService.shared.getPrice(priceProviderId: coin.priceProviderId)
            let balanceFiat = coin.balanceInFiat
            let coinBalance = coin.balanceString
            let balanceInFiatDecimal = coin.balanceInFiatDecimal
            return (coinBalance, balanceFiat, balanceInFiatDecimal)
            
        case .thorChain:
            let thorBalances = try await thor.fetchBalances(coin.address)
            coin.rawBalance = thorBalances.runeBalance() ?? "0.0"
            coin.priceRate = await CryptoPriceService.shared.getPrice(priceProviderId: coin.priceProviderId)
            let balanceFiat = thorBalances.runeBalanceInFiat(price: coin.priceRate) ?? "$ 0,00"
            let coinBalance = thorBalances.formattedRuneBalance() ?? "0.0"
            let balanceInFiatDecimal = coin.balanceInFiatDecimal
            return (coinBalance, balanceFiat, balanceInFiatDecimal)
            
        case .solana:
            let (rawBalance,priceRate) = try await sol.getSolanaBalance(coin: coin)
            coin.rawBalance = rawBalance
            coin.priceRate = priceRate
            let balanceFiat = coin.balanceInFiat
            let coinBalance = coin.balanceString
            let balanceInFiatDecimal = coin.balanceInFiatDecimal
            return (coinBalance, balanceFiat, balanceInFiatDecimal)
            
        case .ethereum, .avalanche, .bscChain:
            let service = try EvmServiceFactory.getService(forChain: coin)
            let (rawBalance,priceRate) = try await service.getBalance(coin: coin)
            coin.rawBalance = rawBalance
            coin.priceRate = priceRate
            let balanceFiat = coin.balanceInFiat
            let coinBalance = coin.balanceString
            let balanceInFiatDecimal = coin.balanceInFiatDecimal
            return (coinBalance, balanceFiat, balanceInFiatDecimal)
            
        case .gaiaChain:
            let atomBalance =  try await gaia.fetchBalances(address: coin.address)
            var balanceFiat: String = .empty
            balanceFiat = atomBalance.atomBalanceInFiat(price: coin.priceRate) ?? "$ 0,00"
            coin.rawBalance = atomBalance.atomBalance() ?? "0.0"
            let coinBalance = atomBalance.formattedAtomBalance() ?? "0.0"
            let balanceInFiatDecimal = coin.balanceInFiatDecimal
            return (coinBalance, balanceFiat, balanceInFiatDecimal)
        case .ton:
            let (rawBalance,priceRate) = try await ton.getBalance(coin: coin)
            coin.rawBalance = rawBalance
            coin.priceRate = priceRate
            let balanceFiat = coin.balanceInFiat
            let coinBalance = coin.balanceString
            let balanceInFiatDecimal = coin.balanceInFiatDecimal
            return (coinBalance, balanceFiat, balanceInFiatDecimal)
        }
    }
}
