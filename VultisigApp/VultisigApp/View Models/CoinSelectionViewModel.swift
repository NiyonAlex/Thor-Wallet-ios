//
//  TokenSelectionViewModel.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-03-11.
//

import Foundation
import OSLog
import WalletCore

@MainActor
class CoinSelectionViewModel: ObservableObject {
    
    @Published var groupedAssets: [String: [Coin]] = [:]
    @Published var selection = Set<Coin>()
    
    let actionResolver = CoinActionResolver()
    let balanceService = BalanceService.shared
    let priceService = CryptoPriceService.shared
    
    private let logger = Logger(subsystem: "assets-list", category: "view")
    
    func allCoins(vault: Vault) -> [Coin] {
        return vault.coins.filter { $0.isNativeToken }
    }
    
    func loadData(coin: Coin) async {
        await balanceService.updateBalance(for: coin)
    }
    
    func setData(for vault: Vault) {
        groupAssets()
        checkSelected(for: vault)
    }
    
    private func checkSelected(for vault: Vault) {
        selection = Set(vault.coins)
    }
    
    private func groupAssets() {
        groupedAssets = [:]
        groupedAssets = Dictionary(grouping: TokensStore.TokenSelectionAssets.sorted(by: { first, second in
            if first.isNativeToken {
                return true
            }
            return false
        })) { $0.chain.name }
    }
    
    func handleSelection(isSelected: Bool, asset: Coin) {
        if isSelected {
            if !selection.contains(where: { $0.chain == asset.chain && $0.ticker == asset.ticker }) {
                selection.insert(asset)
            }
        } else {
            if let remove = selection.first(where: { $0.chain == asset.chain && $0.ticker == asset.ticker }) {
                selection.remove(remove)
            }
        }
    }
    
    private func removeCoins(coins: [Coin], vault: Vault) async throws {
        for coin in coins {
            if let idx = vault.coins.firstIndex(where: { $0.ticker == coin.ticker && $0.chain == coin.chain }) {
                vault.coins.remove(at: idx)
            }
            
            try await Storage.shared.delete(coin)
        }
    }
    func saveAssets(for vault: Vault) async {
        do {
            let removedCoins = vault.coins.filter { coin in
                !selection.contains(where: { $0.ticker == coin.ticker && $0.chain == coin.chain})
            }
            let nativeCoins = removedCoins.filter { $0.isNativeToken }
            let allTokens = vault.coins.filter { coin in
                nativeCoins.contains(where: { $0.chain == coin.chain }) && !coin.isNativeToken
            }
            
            try await removeCoins(coins: removedCoins, vault: vault)
            try await removeCoins(coins: nativeCoins, vault: vault)
            try await removeCoins(coins: allTokens, vault: vault)
            
            // remove all native tokens and also the tokens so they are not added again
            let filteredSelection = selection.filter{ selection in
                !nativeCoins.contains(where: { selection.ticker == $0.ticker && selection.chain == $0.chain}) &&
                !allTokens.contains(where: { selection.ticker == $0.ticker && selection.chain == $0.chain})
            }
            
            var newCoins: [Coin] = []
            for asset in filteredSelection {
                if !vault.coins.contains(where: { $0.ticker == asset.ticker && $0.chain == asset.chain}) {
                    newCoins.append(asset)
                    print("asset ticker \(asset.ticker)")
                }
            }
            
            try await addToChain(assets: newCoins, to: vault)
            
        } catch {
            print("fail to save asset,\(error)")
        }
    }
    private func getNewCoin(asset: Coin, vault: Vault) -> Coin? {
        switch asset.chain {
        case .thorChain:
            let runeCoinResult = THORChainHelper.getRUNECoin(hexPubKey: vault.pubKeyECDSA, hexChainCode: vault.hexChainCode)
            switch runeCoinResult {
            case .success(let coin):
                coin.priceProviderId = asset.priceProviderId
                return coin
            case .failure(let error):
                logger.info("fail to get thorchain address,error:\(error.localizedDescription)")
            }
        case .mayaChain:
            let cacaoCoinResult = MayaChainHelper.getMayaCoin(hexPubKey: vault.pubKeyECDSA,
                                                              hexChainCode: vault.hexChainCode,
                                                              coinTicker: asset.ticker)
            switch cacaoCoinResult {
            case .success(let coin):
                coin.priceProviderId = asset.priceProviderId
                return coin
            case .failure(let error):
                logger.info("fail to get thorchain address,error:\(error.localizedDescription)")
            }
        case .ethereum, .arbitrum, .base, .optimism, .polygon, .bscChain, .avalanche, .blast, .cronosChain, .zksync:
            let evmHelper = EVMHelper.getHelper(coin: asset)
            
            let coinResult = evmHelper.getCoin(hexPubKey: vault.pubKeyECDSA, hexChainCode: vault.hexChainCode)
            switch coinResult {
            case .success(let coin):
                let newCoin = Coin.getInstance(chain: asset.chain,
                                   ticker: asset.ticker,
                                   logo: asset.logo,
                                   address: coin.address,
                                   priceRate: 0.0,
                                   decimals: asset.decimals, // Assuming 18 for Ethereum-based tokens
                                   hexPublicKey: coin.hexPublicKey,
                                   priceProviderId: asset.priceProviderId ,
                                   contractAddress: asset.contractAddress , // Assuming asset has a contractAddress field
                                   rawBalance: "0",
                                   isNativeToken: asset.isNativeToken
                )
                return newCoin
                
            case .failure(let error):
                logger.info("fail to get ethereum address, error: \(error.localizedDescription)")
            }
            
        case .bitcoin, .bitcoinCash, .litecoin, .dogecoin, .dash:
            guard let coinType = CoinType.from(string: asset.chain.name.replacingOccurrences(of: "-", with: "")) else {
                print("Coin type not found on Wallet Core")
                return nil
            }
            let coinResult = UTXOChainsHelper(coin: coinType, vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode).getCoin()
            switch coinResult {
            case .success(let btc):
                btc.priceProviderId = asset.priceProviderId
                return btc
            case .failure(let err):
                logger.info("fail to get bitcoin address,error:\(err.localizedDescription)")
            }
        case .solana:
            let coinResult = SolanaHelper.getSolana(hexPubKey: vault.pubKeyEdDSA, hexChainCode: vault.hexChainCode)
            switch coinResult {
            case .success(let sol):
                sol.priceProviderId = asset.priceProviderId
                return sol
            case .failure(let err):
                logger.info("fail to get solana address,error:\(err.localizedDescription)")
            }
        case .sui:
            let coinResult = SuiHelper.getSui(hexPubKey: vault.pubKeyEdDSA, hexChainCode: vault.hexChainCode)
            switch coinResult {
            case .success(let sui):
                sui.priceProviderId = asset.priceProviderId
                return sui
            case .failure(let err):
                logger.info("fail to get sui address,error:\(err.localizedDescription)")
            }
        case .polkadot:
            let coinResult = PolkadotHelper.getPolkadot(hexPubKey: vault.pubKeyEdDSA, hexChainCode: vault.hexChainCode)
            switch coinResult {
            case .success(let dot):
                dot.priceProviderId = asset.priceProviderId
                return dot
            case .failure(let err):
                logger.info("fail to get polkadot address,error:\(err.localizedDescription)")
            }
        case .gaiaChain:
            let coinResult = ATOMHelper().getATOMCoin(hexPubKey: vault.pubKeyECDSA, hexChainCode: vault.hexChainCode)
            switch coinResult {
            case .success(let atom):
                atom.priceProviderId = asset.priceProviderId
                return atom
            case .failure(let err):
                logger.info("fail to get solana address,error:\(err.localizedDescription)")
            }
        case .kujira:
            let coinResult = KujiraHelper().getCoin(hexPubKey: vault.pubKeyECDSA, hexChainCode: vault.hexChainCode)
            switch coinResult {
            case .success(let kuji):
                kuji.priceProviderId = asset.priceProviderId
                return kuji
            case .failure(let err):
                logger.info("fail to get solana address,error:\(err.localizedDescription)")
            }
        case .dydx:
            let coinResult = DydxHelper().getDydxCoin(hexPubKey: vault.pubKeyECDSA, hexChainCode: vault.hexChainCode)
            switch coinResult {
            case .success(let dydx):
                dydx.priceProviderId = asset.priceProviderId
                return dydx
            case .failure(let err):
                logger.info("fail to get solana address,error:\(err.localizedDescription)")
            }
        }
        return nil
    }
    
    private func addToChain(assets: [Coin], to vault: Vault) async throws {
        if let coin = assets.first, coin.chainType == .EVM, !coin.isNativeToken {
            let addresses = assets.map { $0.contractAddress }
            let coingekoIDs = try await priceService.fetchCoingeckoId(chain: coin.chain, addresses: addresses)
            
            let tokensWithCoingeckoIDs = zip(assets, coingekoIDs).filter { $0.1 != nil }
            let tokensWithoutCoingeckoIDs = zip(assets, coingekoIDs).filter { $0.1 == nil }.map { $0.0 }
            
            for (token, priceProviderId) in tokensWithCoingeckoIDs {
                if let priceProviderId = priceProviderId {
                    _ = try await addToChain(asset: token, to: vault, priceProviderId: priceProviderId)
                }
            }
            
            for token in tokensWithoutCoingeckoIDs {
                _ = try await addToChain(asset: token, to: vault, priceProviderId: nil)
            }
            
        } else {
            for asset in assets {
                if let newCoin = try await addToChain(asset: asset, to: vault, priceProviderId: nil) {
                    print("Add discovered tokens for \(asset.ticker) on the chain \(asset.chain.name)")
                    try await addDiscoveredTokens(nativeToken: newCoin, to: vault)
                }
            }
        }
    }
    
    
    private func addToChain(asset: Coin, to vault: Vault, priceProviderId: String?) async throws -> Coin? {
        guard let newCoin = getNewCoin(asset: asset, vault: vault) else {
            return nil
        }
        if let priceProviderId {
            newCoin.priceProviderId = priceProviderId
        }
        
        // Save the new coin first
        try await Storage.shared.save(newCoin)
        
        // Check if the new coin already exists in the vault's coins before appending it
        if !vault.coins.contains(where: { $0.id == newCoin.id }) {
            vault.coins.append(newCoin)
        }
        
        return newCoin
    }
    
    
    private func addDiscoveredTokens(nativeToken: Coin, to vault: Vault) async throws  {
        do {
            let service = try EvmServiceFactory.getService(forCoin: nativeToken)
            let tokens = await service.getTokens(nativeToken: nativeToken, address: nativeToken.address)
            let addresses = tokens.map { $0.contractAddress }
            let coingekoIDs = try await priceService.fetchCoingeckoId(chain: nativeToken.chain, addresses: addresses)
            
            guard coingekoIDs.count == tokens.count else {
                return
            }
            
            for (index, token) in tokens.enumerated() {
                if let priceProviderId = coingekoIDs[index] {
                    _ = try await addToChain(asset: token, to: vault, priceProviderId: priceProviderId)
                }
            }
        } catch {
            print("Error fetching service: \(error)")
        }
    }
}
