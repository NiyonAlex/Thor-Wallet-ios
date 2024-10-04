//
//  FeatureFlagService.swift
//  VultisigApp
//
//  Created by Johnny Luo on 4/10/2024.
//

import Foundation

final class FeatureFlagService {
    static let ENCRYPT_GCM = "encrypt-gcm"
    
    func isFeatureEnabled(feature: String) async -> Bool {
        do{
            let features = try await getFeatureFlagFromServer()
            if let result = features[feature] as? Bool {
                return result
            } else {
                print("Feature flag for \(feature) is not a boolean value")
            }
            
        } catch {
            print("fail to get features \(error)")
        }
        return false
    }
    
    private func getFeatureFlagFromServer() async throws -> [String: Any]{
#if DEBUG
        let url =  URL(string:"https://api.vultisig.com/feature/debug.json")!
#else
        let url = URL(string:"https://api.vultisig.com/feature/release.json")!
#endif
        let (jsonData, _) = try await URLSession.shared.data(from: url)
        // Decode JSON data into a dictionary
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let jsonDict = jsonObject as? [String: Any] else {
            throw NSError(domain: "FeatureFlagService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }
        return jsonDict
    }
}
