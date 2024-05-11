import Foundation

class CosmosService {
    func fetchBalances(address: String) async throws -> [CosmosBalance] {
        let cachedBalances = loadBalancesFromCache(forAddress: address)
        if cachedBalances.count > 0 {
            return cachedBalances
        }
        guard let url = balanceURL(forAddress: address) else {
            return [CosmosBalance]()
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let balanceResponse = try JSONDecoder().decode(CosmosBalanceResponse.self, from: data)
        cacheBalances(balanceResponse.balances, forAddress: address)
        return balanceResponse.balances
    }
    
    func fetchAccountNumber(_ address: String) async throws -> CosmosAccountValue? {
        guard let url = accountNumberURL(forAddress: address) else {
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let accountResponse = try JSONDecoder().decode(CosmosAccountsResponse.self, from: data)
        return accountResponse.account
    }
    
    func broadcastTransaction(jsonString: String) async -> Result<String, Error> {
        guard let url = transactionURL(), let jsonData = jsonString.data(using: .utf8) else {
            return .failure(HelperError.runtimeError("Failed to convert input json to data"))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard let httpResponse = resp as? HTTPURLResponse else {
                return .failure(HelperError.runtimeError("Invalid HTTP response"))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(HelperError.runtimeError("Status code: \(httpResponse.statusCode), \(String(data: data, encoding: .utf8) ?? "Unknown error")"))
            }
            let response = try JSONDecoder().decode(CosmosTransactionBroadcastResponse.self, from: data)
            if let code = response.txResponse?.code, code == 0 || code == 19 {
                if let txHash = response.txResponse?.txhash {
                    return .success(txHash)
                }
            }
            return .failure(HelperError.runtimeError(String(data: data, encoding: .utf8) ?? "Unknown error"))
            
        } catch {
            return .failure(error)
        }
    }
    
    // Methods to be overridden
    func balanceURL(forAddress address: String) -> URL? {
        fatalError("Must override in subclass")
    }
    
    func accountNumberURL(forAddress address: String) -> URL? {
        fatalError("Must override in subclass")
    }
    
    func transactionURL() -> URL? {
        fatalError("Must override in subclass")
    }
    
    // Cache-related methods
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
        else {
            return [CosmosBalance]()
        }
        
        return cacheEntry.balances
    }
}
