//
//  ChainCellViewModel.swift
//  VoltixApp
//
//  Created by Amol Kumar on 2024-04-11.
//

import Foundation

@MainActor
class ChainCellViewModel: ObservableObject {
    @Published var balanceInFiat: String? = nil
    @Published var quantity: String? = nil
    
    func loadData(for group: GroupedChain) async {
        if group.coins.count==1, let coin = group.coins.first {
            await loadQuantity(for: coin)
        }
        
        await loadBalance(for: group)
    }
    
    func loadQuantity(for coin: Coin) async {
        do {
            let balanceService = BalanceService.shared
            let coinQuantity = try await balanceService.balance(for: coin)
            quantity = coinQuantity.coinBalance
        }
        catch {
            print("ChainCellViewModel > loadQuantity: \(error.localizedDescription)")
        }
    }
    
    func getGroupCount(_ group: GroupedChain) -> String {
        guard group.coins.count>1 else {
            return "1 " + NSLocalizedString("asset", comment: "")
        }
        
        return "\(group.coins.count) \(NSLocalizedString("assets", comment: ""))"
    }
    
    func loadBalance(for group: GroupedChain) async {
        balanceInFiat = nil
        var total: Decimal = 0.0
        
        for coin in group.coins {
            let balance = await getCoinBalance(for: coin)
            total += balance
        }
        
        balanceInFiat = total.formatToFiat()
    }
    
    private func getCoinBalance(for coin: Coin) async -> Decimal {
        do {
            let balanceService = BalanceService.shared
            let balance = try await balanceService.balance(for: coin)
            return balance.balanceInFiatDecimal
        }
        catch {
            print("ChainCellViewModel > getCoinBalance: \(coin.ticker) \(error.localizedDescription)")
        }
        return 0
    }
}
