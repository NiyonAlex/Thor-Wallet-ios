import Foundation
import CodeScanner
import OSLog
import SwiftUI
import UniformTypeIdentifiers
import WalletCore
import BigInt

class SendTransaction: ObservableObject, Hashable {
    @Published var toAddress: String = .empty
    @Published var amount: String = .empty
    @Published var amountInFiat: String = .empty
    @Published var memo: String = .empty
    @Published var gas: String = .empty
    @Published var sendMaxAmount: Bool = false
    @Published var memoFunctionDictionary: ThreadSafeDictionary<String, String> = ThreadSafeDictionary()

    @Published var coin: Coin = Coin(
        chain: Chain.bitcoin,
        ticker: "BTC",
        logo: "",
        address: "",
        priceRate: 0.0,
        chainType: ChainType.UTXO,
        decimals: "8",
        hexPublicKey: "",
        feeUnit: "",
        priceProviderId: "",
        contractAddress: "",
        rawBalance: "0",
        isNativeToken: true,
        feeDefault: "20"
    )
    
    var fromAddress: String {
        coin.address
    }
    
    var isAmountExceeded: Bool {
        
        let totalBalance = BigInt(coin.rawBalance) ?? BigInt.zero
        
        var gasInt = BigInt.zero
        if coin.isNativeToken {
            gasInt = BigInt(gas) ?? BigInt.zero
            if coin.chainType == .EVM {
                if let gasLimitBigInt = BigInt(coin.feeDefault) {
                    gasInt = gasInt * gasLimitBigInt
                }
            }
        }
        
        let totalTransactionCost = amountInRaw + gasInt
        
        return totalTransactionCost > totalBalance
        
    }
    
    func hasEnoughNativeTokensToPayTheFees() async -> Bool {
        guard !coin.isNativeToken else { return true }
        
        var gasPriceBigInt = BigInt(gas) ?? BigInt.zero
        if let gasLimitBigInt = BigInt(coin.feeDefault) {
            if coin.chainType == .EVM {
                gasPriceBigInt *= gasLimitBigInt
            }
            if let vault = ApplicationState.shared.currentVault {
                if let nativeToken = vault.coins.first(where: { $0.isNativeToken && $0.chain.name == coin.chain.name }) {
                    
                    do
                    {
                        let (_, _, _) = try await BalanceService.shared.balance(for: nativeToken)
                        
                        let nativeTokenBalance = BigInt(nativeToken.rawBalance) ?? BigInt.zero
                        
                        if gasPriceBigInt > nativeTokenBalance {
                            print("Insufficient \(nativeToken.ticker) balance for fees: needed \(gasPriceBigInt), available \(nativeTokenBalance)")
                            return false
                        }
                    } catch {
                        print("Error to get the balance for a Native Coin")
                        return false
                    }
                    return true
                } else {
                    print("No native token found for chain \(coin.chain.name)")
                    return false
                }
            }
            print("Failed to access current vault")
        } else {
            print("Failed to convert \(coin.feeDefault) to BigInt")
        }
        return false
    }
    
    
    func getNativeTokenBalance() async -> String {
        guard !coin.isNativeToken else { return .zero }
        
        if let vault = ApplicationState.shared.currentVault {
            if let nativeToken = vault.coins.first(where: { $0.isNativeToken && $0.chain.name == coin.chain.name }) {
                do
                {
                    let (_, _, _) = try await BalanceService.shared.balance(for: nativeToken)
                    let nativeTokenRawBalance = Decimal(string: nativeToken.rawBalance) ?? .zero
                    
                    guard let nativeDecimals = Int(nativeToken.decimals) else {
                        return .zero
                    }
                    
                    let nativeTokenBalance = nativeTokenRawBalance / pow(10, nativeDecimals)
                    
                    let nativeTokenBalanceDecimal = nativeTokenBalance.description.formatToDecimal(digits: 8)
                    
                    return "\(nativeTokenBalanceDecimal) \(nativeToken.ticker)"
                } catch {
                    print("Error to get the balance for a Native Coin")
                    return .zero
                }
            } else {
                print("No native token found for chain \(coin.chain.name)")
                return .zero
            }
        }
        print("Failed to access current vault")
        return .zero
    }
    
    var amountInRaw: BigInt {
        if let decimals = Double(coin.decimals) {
            return BigInt(amountDecimal * pow(10, decimals))
        }
        return BigInt.zero
    }
    
    var amountDecimal: Double {
        let amountString = amount.replacingOccurrences(of: ",", with: ".")
        return Double(amountString) ?? 0
    }
    
    var amountInCoinDecimal: BigInt {
        let amountDouble = amountDecimal
        let decimals = Int(coin.decimals) ?? 8
        return BigInt(amountDouble * pow(10,Double(decimals)))
    }
    
    var gasDecimal: Decimal {
        let gasString = gas.replacingOccurrences(of: ",", with: ".")
        return Decimal(string:gasString) ?? 0
    }
    
    var gasInReadable: String {
        guard var decimals = Int(coin.decimals) else {
            return .empty
        }
        if coin.chain.chainType == .EVM {
            // convert to Gwei , show as Gwei for EVM chain only
            guard let weiPerGWeiDecimal = Decimal(string: EVMHelper.weiPerGWei.description) else {
                return .empty
            }
            return "\(gasDecimal / weiPerGWeiDecimal) \(coin.feeUnit)"
        }
        
        // If not a native token we need to get the decimals from the native token
        if !coin.isNativeToken {
            if let vault = ApplicationState.shared.currentVault {
                if let nativeToken = vault.coins.first(where: { $0.isNativeToken && $0.chain.name == coin.chain.name }) {
                    decimals = Int(nativeToken.decimals) ?? .zero
                }
            }
        }
        
        return "\((gasDecimal / pow(10,decimals)).formatToDecimal(digits: decimals).description) \(coin.feeUnit)"
    }
    
    init() {
        self.toAddress = .empty
        self.amount = .empty
        self.amountInFiat = .empty
        self.memo = .empty
        self.gas = .empty
        self.sendMaxAmount = false
    }
    
    init(coin: Coin) {
        self.reset(coin: coin)
    }
    
    init(toAddress: String, amount: String, memo: String, gas: String) {
        self.toAddress = toAddress
        self.amount = amount
        self.memo = memo
        self.gas = gas
        self.sendMaxAmount = false
    }
    
    init(toAddress: String, amount: String, memo: String, gas: String, coin: Coin) {
        self.toAddress = toAddress
        self.amount = amount
        self.memo = memo
        self.gas = gas
        self.coin = coin
        self.sendMaxAmount = false
    }
    
    static func == (lhs: SendTransaction, rhs: SendTransaction) -> Bool {
        lhs.fromAddress == rhs.fromAddress &&
        lhs.toAddress == rhs.toAddress &&
        lhs.amount == rhs.amount &&
        lhs.memo == rhs.memo &&
        lhs.gas == rhs.gas &&
        lhs.sendMaxAmount == rhs.sendMaxAmount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(fromAddress)
        hasher.combine(toAddress)
        hasher.combine(amount)
        hasher.combine(memo)
        hasher.combine(gas)
        hasher.combine(sendMaxAmount)
    }
    
    func reset(coin: Coin) {
        self.toAddress = .empty
        self.amount = .empty
        self.amountInFiat = .empty
        self.memo = .empty
        self.gas = .empty
        self.coin = coin
        self.sendMaxAmount = false
    }
    
    func parseCryptoURI(_ uri: String) {
        guard let url = URLComponents(string: uri) else {
            print("Invalid URI")
            return
        }
        
        // Use the path for the address if the host is nil, which can be the case for some URIs.
        toAddress = url.host ?? url.path
        
        url.queryItems?.forEach { item in
            switch item.name {
            case "amount":
                amount = item.value ?? ""
            case "label", "message":
                // For simplicity, appending label and message to memo, separated by spaces
                if let value = item.value, !value.isEmpty {
                    memo += (memo.isEmpty ? "" : " ") + value
                }
            default:
                print("Unknown query item: \(item.name)")
            }
        }
    }
    
    func toString() -> String {
        let properties = [
            "toAddress: \(toAddress)",
            "amount: \(amount)",
            "amountInFiat: \(amountInFiat)",
            "memo: \(memo)",
            "gas: \(gas)",
            "coin: \(coin.toString())",
            "fromAddress: \(fromAddress)",
            "amountDecimal: \(amountDecimal)",
            "amountInCoinDecimal: \(amountInCoinDecimal)",
            "gasDecimal: \(gasDecimal)"
        ]
        return properties.joined(separator: ",\n")
    }
}
