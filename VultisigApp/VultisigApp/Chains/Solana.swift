//
//  Solana.swift
//  VultisigApp
//

import Foundation
import Tss
import WalletCore
import BigInt

enum SolanaHelper {

    static let defaultFeeInLamports: BigInt = 1000000 //0.001

    static func getSolana(hexPubKey: String, hexChainCode: String) -> Result<Coin, Error> {
        return getAddressFromPublicKey(hexPubKey: hexPubKey, hexChainCode: hexChainCode).flatMap { addr -> Result<Coin, Error> in
            TokensStore.createNewCoinInstance(ticker: "SOL", address: addr, hexPublicKey: hexPubKey, coinType: .solana)
        }
    }
    
    static func getAddressFromPublicKey(hexPubKey: String, hexChainCode: String) -> Result<String, Error> {
        // Solana is using EdDSA , so it doesn't need to use HD derive
        guard let pubKeyData = Data(hexString: hexPubKey) else {
            return .failure(HelperError.runtimeError("public key: \(hexPubKey) is invalid"))
        }
        guard let publicKey = PublicKey(data: pubKeyData, type: .ed25519) else {
            return .failure(HelperError.runtimeError("public key: \(hexPubKey) is invalid"))
        }
        return .success(CoinType.solana.deriveAddressFromPublicKey(publicKey: publicKey))
    }
    
    static func getPreSignedInputData(keysignPayload: KeysignPayload) -> Result<Data, Error> {
        guard keysignPayload.coin.chain.ticker == "SOL" else {
            return .failure(HelperError.runtimeError("coin is not SOL"))
        }
        guard case .Solana(let recentBlockHash, let priorityFee) = keysignPayload.chainSpecific else {
            return .failure(HelperError.runtimeError("fail to get to address"))
        }
        guard let toAddress = AnyAddress(string: keysignPayload.toAddress, coin: .solana) else {
            return .failure(HelperError.runtimeError("fail to get to address"))
        }
        
        let input = SolanaSigningInput.with {
            $0.transferTransaction = SolanaTransfer.with {
                $0.recipient = toAddress.description
                $0.value = UInt64(keysignPayload.toAmount)
                if let memo = keysignPayload.memo {
                    $0.memo = memo
                }
            }
            $0.recentBlockhash = recentBlockHash
            $0.sender = keysignPayload.coin.address
            $0.priorityFeePrice = SolanaPriorityFeePrice.with{
                $0.price = UInt64(priorityFee)
            }
        }
        
        do {
            let inputData = try input.serializedData()
            return .success(inputData)
        } catch {
            return .failure(HelperError.runtimeError("fail to get PreSign input data"))
        }
    }
    
    static func getPreSignedImageHash(keysignPayload: KeysignPayload) -> Result<[String], Error> {
        let result = getPreSignedInputData(keysignPayload: keysignPayload)
        switch result {
        case .success(let inputData):
            do {
                
                let hashes = TransactionCompiler.preImageHashes(coinType: .solana, txInputData: inputData)
                let preSigningOutput = try SolanaPreSigningOutput(serializedData: hashes)
                print("hash:\(preSigningOutput.data.hexString)")
                return .success([preSigningOutput.data.hexString])
            } catch {
                return .failure(HelperError.runtimeError("fail to get preSignedImageHash,error:\(error.localizedDescription)"))
            }
        case .failure(let err):
            return .failure(err)
        }
    }
    
    static func getSignedTransaction(vaultHexPubKey: String,
                                     vaultHexChainCode: String,
                                     keysignPayload: KeysignPayload,
                                     signatures: [String: TssKeysignResponse]) -> Result<SignedTransactionResult, Error>
    {
        guard let pubkeyData = Data(hexString: vaultHexPubKey) else {
            return .failure(HelperError.runtimeError("public key \(vaultHexPubKey) is invalid"))
        }
        guard let publicKey = PublicKey(data: pubkeyData, type: .ed25519) else {
            return .failure(HelperError.runtimeError("public key \(vaultHexPubKey) is invalid"))
        }
        
        let result = getPreSignedInputData(keysignPayload: keysignPayload)
        switch result {
        case .success(let inputData):
            do {
                let hashes = TransactionCompiler.preImageHashes(coinType: .solana, txInputData: inputData)
                let preSigningOutput = try SolanaPreSigningOutput(serializedData: hashes)
                let allSignatures = DataVector()
                let publicKeys = DataVector()
                let signatureProvider = SignatureProvider(signatures: signatures)
                let signature = signatureProvider.getSignature(preHash: preSigningOutput.data)
                guard publicKey.verify(signature: signature, message: preSigningOutput.data) else {
                    return .failure(HelperError.runtimeError("fail to verify signature"))
                }
                
                allSignatures.add(data: signature)
                publicKeys.add(data: pubkeyData)
                let compileWithSignature = TransactionCompiler.compileWithSignatures(coinType: .solana,
                                                                                     txInputData: inputData,
                                                                                     signatures: allSignatures,
                                                                                     publicKeys: publicKeys)
                let output = try SolanaSigningOutput(serializedData: compileWithSignature)
                let result = SignedTransactionResult(rawTransaction: output.encoded, 
                                                     transactionHash: getHashFromRawTransaction(tx:output.encoded))
                return .success(result)
            } catch {
                return .failure(HelperError.runtimeError("fail to get signed solana transaction,error:\(error.localizedDescription)"))
            }
        case .failure(let err):
            return .failure(err)
        }
    }
    static func getHashFromRawTransaction(tx: String) -> String {
        let sig =  Data(tx.prefix(64).utf8)
        return sig.base64EncodedString()
    }
}
