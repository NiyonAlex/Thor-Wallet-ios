import Foundation
import BigInt

// This was moved since it will work for other chains
// Infura support many chains, so we will need to change the infura URL per network
enum Web3ServiceError: Error {
	case badURL
	case rpcError(code: Int, message: String)
	case invalidResponse
	case unknown(Error)
	
	var localizedDescription: String {
		switch self {
			case .badURL:
				return "Invalid URL."
			case let .rpcError(code, message):
				return "RPC Error \(code): \(message)"
			case .invalidResponse:
				return "Invalid response from the server."
			case let .unknown(error):
				return "Unknown error: \(error.localizedDescription)"
		}
	}
}

class Web3Service: ObservableObject {
	@Published var nonce: BigInt?
	@Published var gasPrice: BigInt?
	
	private let session = URLSession.shared
	
	//TODO: It can't be fixed since each chain has a different URL
	private let infuraEndpoint = Endpoint.web3ServiceInfura
	
	init() {
		guard URL(string: infuraEndpoint) != nil else {
			fatalError("Invalid Infura endpoint URL")
		}
	}
	
	// Call this method to update nonce and gas price
	// TODO: move this method to view model
	func updateNonceAndGasPrice(forAddress address: String) async throws {
		do {
			let fetchedNonce = try await fetchNonce(address: address)
			let fetchedGasPrice = try await fetchGasPrice()
			
			DispatchQueue.main.async {
				self.nonce = fetchedNonce
				self.gasPrice = fetchedGasPrice
			}
		} catch {
				// Handle errors appropriately
			throw error
		}
	}
	
	func estimateGasForEthTransaction(senderAddress: String, recipientAddress: String, value: BigInt, memo: String?) async throws -> BigInt {
		let memoDataHex = memo?.data(using: .utf8)?.map { byte in String(format: "%02x", byte) }.joined() ?? ""
		
		let transactionObject: [String: Any] = [
			"from": senderAddress,
			"to": recipientAddress,
			"value": "0x" + String(value, radix: 16), // Convert value to hex string
			"data": "0x" + memoDataHex // Include the memo in the data field, if present
		]
		
		let payload: [String: Any] = [
			"jsonrpc": "2.0",
			"method": "eth_estimateGas",
			"params": [transactionObject],
			"id": 1
		]
		
		return try await sendRPCRequest(payload: payload, method: "eth_estimateGas")
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
		
		let payload: [String: Any] = [
			"jsonrpc": "2.0",
			"method": "eth_estimateGas",
			"params": [transactionObject],
			"id": 1
		]
		
		return try await sendRPCRequest(payload: payload, method: "eth_estimateGas")
	}
	
	private func fetchNonce(address: String) async throws -> BigInt {
		let payload: [String: Any] = [
			"jsonrpc": "2.0",
			"method": "eth_getTransactionCount",
			"params": [address, "latest"],
			"id": 1
		]
		
		return try await sendRPCRequest(payload: payload, method: "eth_getTransactionCount")
	}
	
	private func fetchGasPrice() async throws -> BigInt {
		let payload: [String: Any] = [
			"jsonrpc": "2.0",
			"method": "eth_gasPrice",
			"params": [],
			"id": 1
		]
		
		return try await sendRPCRequest(payload: payload, method: "eth_gasPrice")
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
		
		print("Method ID: \(methodId)")
		print("Recipient Address: \(paddedAddress)")
		print("Value Hex: \(paddedValue)")
		print("Value: \(value)")
		print("Constructed Data: \(data)")
		return data
	}
	
	func broadcastTransaction(signedTransactionData: String) async throws -> String {
		let payload: [String: Any] = [
			"jsonrpc": "2.0",
			"method": "eth_sendRawTransaction",
			"params": [signedTransactionData],
			"id": 1
		]
		
		// Correctly handle the request and response for sending a raw transaction
		guard let url = URL(string: infuraEndpoint) else {
			throw Web3ServiceError.badURL
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
		
		do {
			let (data, _) = try await session.data(for: request)
			// Attempt to deserialize the JSON response
			guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
				  let result = response["result"] as? String else {
				throw Web3ServiceError.invalidResponse
			}
			
			return result // Return the transaction hash string directly
		} catch {
			// Handle and throw more specific errors as needed
			throw Web3ServiceError.unknown(error)
		}
	}
	
	private func sendRPCRequest(payload: [String: Any], method: String) async throws -> BigInt {
		guard let url = URL(string: infuraEndpoint) else {
			throw Web3ServiceError.badURL
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
		
		do {
			let (data, _) = try await session.data(for: request)
				// Attempt to deserialize the JSON response
			guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
				throw Web3ServiceError.invalidResponse
			}
			
				// Log the whole response
			print("RPC Response for method \(method): \(response)")
			
			if let errorDetails = response["error"] as? [String: Any] {
					// If there's an error in the response, log and throw an error
				if let code = errorDetails["code"] as? Int, let message = errorDetails["message"] as? String {
					print("RPC Error - Code: \(code), Message: \(message)")
					throw Web3ServiceError.rpcError(code: code, message: message)
				} else {
					throw Web3ServiceError.invalidResponse
				}
			} else if let result = response["result"] as? String, let bigIntResult = BigInt(result.stripHexPrefix(), radix: 16) {
					// Successful response
				return bigIntResult
			} else {
					// The response is not in the expected format
				throw Web3ServiceError.invalidResponse
			}
		} catch {
				// Log the error before rethrowing
			print("Error sending RPC request: \(error)")
			throw Web3ServiceError.unknown(error)
		}
	}
}
