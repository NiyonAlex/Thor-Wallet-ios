import Foundation

class TokensStore {
    static var TokenSelectionAssets = [
        Coin(chain: Chain.bitcoin, ticker: "BTC", logo: "btc", address: "", priceRate: 0.0, chainType: ChainType.UTXO, decimals: "8", hexPublicKey: "", feeUnit: "Sats/vbyte", priceProviderId: "bitcoin", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "20"),

        Coin(chain: Chain.bitcoinCash, ticker: "BCH", logo: "bch", address: "", priceRate: 0.0, chainType: ChainType.UTXO, decimals: "8", hexPublicKey: "", feeUnit: "Sats/vbyte", priceProviderId: "bitcoin-cash", contractAddress: "", rawBalance: "0", isNativeToken: false, feeDefault: "20"),

        Coin(chain: Chain.litecoin, ticker: "LTC", logo: "ltc", address: "", priceRate: 0.0, chainType: ChainType.UTXO, decimals: "8", hexPublicKey: "", feeUnit: "Lits/vbyte", priceProviderId: "litecoin", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "1000"),

        Coin(chain: Chain.dogecoin, ticker: "DOGE", logo: "doge", address: "", priceRate: 0.0, chainType: ChainType.UTXO, decimals: "8", hexPublicKey: "", feeUnit: "Doges/vbyte", priceProviderId: "dogecoin", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "1000000"),

        Coin(chain: Chain.thorChain, ticker: "RUNE", logo: "rune", address: "", priceRate: 0.0, chainType: ChainType.THORChain, decimals: "8", hexPublicKey: "", feeUnit: "Rune", priceProviderId: "thorchain", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "0.02"),

        Coin(chain: Chain.ethereum, ticker: "ETH", logo: "eth", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "18", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "ethereum", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "21000"),

        Coin(chain: Chain.ethereum, ticker: "USDC", logo: "usdc", address: "", priceRate: 1.0, chainType: ChainType.EVM, decimals: "6", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "usd-coin", contractAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", rawBalance: "0", isNativeToken: false, feeDefault: "120000"),

        Coin(chain: Chain.ethereum, ticker: "USDT", logo: "usdt", address: "", priceRate: 1.0, chainType: ChainType.EVM, decimals: "6", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "tether", contractAddress: "0xdac17f958d2ee523a2206206994597c13d831ec7", rawBalance: "0", isNativeToken: false, feeDefault: "120000"),

        Coin(chain: Chain.ethereum, ticker: "UNI", logo: "uni", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "18", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "uniswap", contractAddress: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", rawBalance: "0", isNativeToken: false, feeDefault: "120000"),

        Coin(chain: Chain.ethereum, ticker: "MATIC", logo: "matic", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "18", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "polygon", contractAddress: "0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0", rawBalance: "0", isNativeToken: false, feeDefault: "120000"),

        Coin(chain: Chain.ethereum, ticker: "WBTC", logo: "wbtc", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "8", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "wrapped-bitcoin", contractAddress: "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599", rawBalance: "0", isNativeToken: false, feeDefault: "120000"),

        Coin(chain: Chain.ethereum, ticker: "LINK", logo: "link", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "18", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "chainlink", contractAddress: "0x514910771af9ca656af840dff83e8264ecf986ca", rawBalance: "0", isNativeToken: false, feeDefault: "120000"),

        Coin(chain: Chain.ethereum, ticker: "FLIP", logo: "flip", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "18", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "chainflip", contractAddress: "0x826180541412d574cf1336d22c0c0a287822678a", rawBalance: "0", isNativeToken: false, feeDefault: "120000"),

        Coin(chain: Chain.solana, ticker: "SOL", logo: "solana", address: "", priceRate: 0.0, chainType: ChainType.Solana, decimals: "9", hexPublicKey: "", feeUnit: "Lamports", priceProviderId: "solana", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "7000"),

        Coin(chain: Chain.avalanche, ticker: "AVAX", logo: "avax", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "18", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "avalanche-2", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "21000"),

        Coin(chain: Chain.avalanche, ticker: "USDC", logo: "usdc", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "6", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "usd-coin", contractAddress: "0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e", rawBalance: "0", isNativeToken: false, feeDefault: "21000"),

        Coin(chain: Chain.bscChain, ticker: "BNB", logo: "bsc", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "18", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "binancecoin", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "21000"),
        
        Coin(chain: Chain.bscChain, ticker: "USDT", logo: "usdt", address: "", priceRate: 0.0, chainType: ChainType.EVM, decimals: "18", hexPublicKey: "", feeUnit: "Gwei", priceProviderId: "tether", contractAddress: "0x55d398326f99059fF775485246999027B3197955", rawBalance: "0", isNativeToken: false, feeDefault: "120000"),

        Coin(chain: Chain.gaiaChain, ticker: "ATOM", logo: "atom", address: "", priceRate: 0.0, chainType: ChainType.Cosmos, decimals: "6", hexPublicKey: "", feeUnit: "uatom", priceProviderId: "cosmos", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "200000"),
        
        Coin(chain: Chain.ton, ticker: "TON", logo: "ton", address: "", priceRate: 0.0, chainType: ChainType.Ton, decimals: "9", hexPublicKey: "", feeUnit: "nanoton", priceProviderId: "ton", contractAddress: "", rawBalance: "0", isNativeToken: true, feeDefault: "50000000"), // 0.05 TON
    ]
    
    static func getCoin(_ ticker: String) -> Coin? {
        return TokenSelectionAssets.first(where: { $0.ticker == ticker}) ?? nil
    }
    
    static func createNewCoinInstance(ticker: String, address: String, hexPublicKey: String) -> Result<Coin, Error> {
        guard let templateCoin = getCoin(ticker) else {
            return .failure(HelperError.runtimeError("doesn't support coin \(ticker)"))
        }
        let clonedCoin = templateCoin.clone()
        clonedCoin.address = address
        clonedCoin.hexPublicKey = hexPublicKey
        return .success(clonedCoin)
    }
}
