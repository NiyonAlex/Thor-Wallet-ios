//
//  ThorchainService.swift
//  VoltixApp
//
//  Created by Enrique Souza Soares on 06/03/2024.
//

import Foundation

class ThorchainService {
    static let shared = ThorchainService()
    
    private init() {}
    
    func fetchBalances(_ address: String) async throws -> [CosmosBalance] {
        let cachedBalances = loadBalancesFromCache(forAddress: address)
        if cachedBalances.count > 0 {
            return cachedBalances
        }
        guard let url = URL(string: Endpoint.fetchAccountBalanceThorchainNineRealms(address: address)) else        {
            return [CosmosBalance]()
        }
        let (data, _) = try await URLSession.shared.data(for: get9RRequest(url: url))
        
        let balanceResponse = try JSONDecoder().decode(CosmosBalanceResponse.self, from: data)
        self.cacheBalances(balanceResponse.balances, forAddress: address)
        return balanceResponse.balances
    }
    
    func fetchAccountNumber(_ address: String) async throws -> THORChainAccountValue? {
        guard let url = URL(string: Endpoint.fetchAccountNumberThorchainNineRealms(address)) else {
            return nil
        }
        let (data, _) = try await URLSession.shared.data(for: get9RRequest(url: url))
        let accountResponse = try JSONDecoder().decode(THORChainAccountNumberResponse.self, from: data)
        return accountResponse.result.value
    }
    func get9RRequest(url: URL) -> URLRequest{
        var req = URLRequest(url:url)
        req.addValue("voltix", forHTTPHeaderField: "X-Client-ID")
        return req
    }
    func fetchSwapQuotes(address: String, fromAsset: String, toAsset: String, amount: String, interval: String) async throws -> ThorchainSwapQuote {
        let url = Endpoint.fetchSwaoQuoteThorchainNineRealms(address: address, fromAsset: fromAsset, toAsset: toAsset, amount: amount, interval: interval)
        let (data, _) = try await URLSession.shared.data(for: get9RRequest(url: url))
        do {
            let response = try JSONDecoder().decode(ThorchainSwapQuote.self, from: data)
            return response
        } catch {
            struct CustomError: Codable, Error, LocalizedError {
                let error: String
                var errorDescription: String? { return error.capitalized }
            }
            let error = try JSONDecoder().decode(CustomError.self, from: data)
            throw error
        }
    }

    private func cacheBalances(_ balances: [CosmosBalance], forAddress address: String) {
        let addressKey = "balancesCache_\(address)"
        let cacheEntry = BalanceCacheEntry(balances: balances, timestamp: Date())
        
        if let encodedData = try? JSONEncoder().encode(cacheEntry) {
            UserDefaults.standard.set(encodedData, forKey: addressKey)
        }
    }
    
    private func loadBalancesFromCache(forAddress address: String) -> [CosmosBalance] {
        let addressKey = "balancesCache_\(address)"
        
        guard let savedData = UserDefaults.standard.object(forKey: addressKey) as? Data,
              let cacheEntry = try? JSONDecoder().decode(BalanceCacheEntry.self, from: savedData),
              -cacheEntry.timestamp.timeIntervalSinceNow < 60
        else { // Checks if the cache is older than 1 minute
            return [CosmosBalance]()
        }
        
        return cacheEntry.balances
    }
}
