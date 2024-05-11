import Foundation
import BigInt

enum RpcEvmServiceError: Error {
    case rpcError(code: Int, message: String)
    
    var localizedDescription: String {
        switch self {
        case let .rpcError(code, message):
            return "RPC Error \(code): \(message)"
        }
    }
}

class RpcEvmService: RpcService {
    
    func getBalance(coin: Coin) async throws ->(rawBalance: String,priceRate: Double){
        // Start fetching all information concurrently
        let cryptoPrice = await CryptoPriceService.shared.getPrice(priceProviderId: coin.priceProviderId)
        var rawBalance = ""
        do{
            if coin.isNativeToken {
                rawBalance = String(try await fetchBalance(address: coin.address))
            } else {
                rawBalance = String(try await fetchERC20TokenBalance(contractAddress: coin.contractAddress, walletAddress: coin.address))
            }
        } catch {
            print("getBalance:: \(error.localizedDescription)")
            throw error
        }
        return (rawBalance,cryptoPrice)
    }
    
    func getGasInfo(fromAddress: String) async throws -> (gasPrice: BigInt, priorityFee: BigInt, nonce: Int64) {
        async let gasPrice = fetchGasPrice()
        async let nonce = fetchNonce(address: fromAddress)
        async let priorityFee = fetchMaxPriorityFeePerGas()
        return (try await gasPrice, try await priorityFee, Int64(try await nonce))
    }
    
    func broadcastTransaction(hex: String) async throws -> String {
        let hexWithPrefix = hex.hasPrefix("0x") ? hex : "0x\(hex)"
        return try await strRpcCall(method: "eth_sendRawTransaction", params: [hexWithPrefix])
    }

    
    func estimateGasForEthTransaction(senderAddress: String, recipientAddress: String, value: BigInt, memo: String?) async throws -> BigInt {
        // Convert the memo to hex (if present). Assume memo is a String.
        let memoDataHex = memo?.data(using: .utf8)?.map { byte in String(format: "%02x", byte) }.joined() ?? ""
        
        let transactionObject: [String: Any] = [
            "from": senderAddress,
            "to": recipientAddress,
            "value": "0x" + String(value, radix: 16), // Convert value to hex string
            "data": "0x" + memoDataHex // Include the memo in the data field, if present
        ]
        
        return try await intRpcCall(method: "eth_estimateGas", params: [transactionObject])
    }
    
    func estimateGasForERC20Transfer(senderAddress: String, contractAddress: String, recipientAddress: String, value: BigInt) async throws -> BigInt {
        let data = constructERC20TransferData(recipientAddress: recipientAddress, value: value)
        
        let nonce = try await fetchNonce(address: senderAddress)
        let gasPrice = try await fetchGasPrice()
        
        let transactionObject: [String: Any] = [
            "from": senderAddress,
            "to": contractAddress,
            "value": "0x0",
            "data": data,
            "nonce": "0x\(String(nonce, radix: 16))",
            "gasPrice": "0x\(String(gasPrice, radix: 16))"
        ]
        
        return try await intRpcCall(method: "eth_estimateGas", params: [transactionObject])
    }
    
    func fetchERC20TokenBalance(contractAddress: String, walletAddress: String) async throws -> BigInt {
        // Function signature hash of `balanceOf(address)` is `0x70a08231`
        // The wallet address is stripped of '0x', left-padded with zeros to 64 characters
        let paddedWalletAddress = String(walletAddress.dropFirst(2)).paddingLeft(toLength: 64, withPad: "0")
        let data = "0x70a08231" + paddedWalletAddress
        
        let params: [Any] = [
            ["to": contractAddress, "data": data],
            "latest"
        ]
        
        return try await intRpcCall(method: "eth_call", params: params)
    }

    func fetchAllowance(contractAddress: String, owner: String, spender: String) async throws -> BigInt {
        let paddedOwner = String(owner.dropFirst(2)).paddingLeft(toLength: 64, withPad: "0")
        let paddedSpender = String(spender.dropFirst(2)).paddingLeft(toLength: 64, withPad: "0")
        
        let data = "0xdd62ed3e" + paddedOwner + paddedSpender
        let params: [Any] = [["to": contractAddress, "data": data], "latest"]

        return try await intRpcCall(method: "eth_call", params: params)
    }

    private func fetchBalance(address: String) async throws -> BigInt {
        return try await intRpcCall(method: "eth_getBalance", params: [address, "latest"])
    }
    
    func fetchMaxPriorityFeePerGas() async throws -> BigInt {
        return try await intRpcCall(method: "eth_maxPriorityFeePerGas", params: []) //WEI
    }

    private func fetchNonce(address: String) async throws -> BigInt {
        return try await intRpcCall(method: "eth_getTransactionCount", params: [address, "latest"])
    }
    
    private func fetchGasPrice() async throws -> BigInt {
        return try await intRpcCall(method: "eth_gasPrice", params: [])
    }
    
    private func constructERC20TransferData(recipientAddress: String, value: BigInt) -> String {
        let methodId = "a9059cbb"
        
        // Ensure the recipient address is correctly stripped of the '0x' prefix and then padded
        let strippedRecipientAddress = recipientAddress.stripHexPrefix()
        let paddedAddress = strippedRecipientAddress.paddingLeft(toLength: 64, withPad: "0")
        
        // Convert the BigInt value to a hexadecimal string without leading '0x', then pad
        let valueHex = String(value, radix: 16)
        let paddedValue = valueHex.paddingLeft(toLength: 64, withPad: "0")
        
        // Construct the data string with '0x' prefix
        let data = "0x" + methodId + paddedAddress + paddedValue
        
        return data
    }
    
}
