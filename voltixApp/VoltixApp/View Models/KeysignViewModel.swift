//
//  KeysignViewModel.swift
//  VoltixApp
//
//  Created by Johnny Luo on 15/3/2024.
//

import Foundation
import OSLog
import Tss
import WalletCore

enum KeysignStatus {
    case CreatingInstance
    case KeysignECDSA
    case KeysignEdDSA
    case KeysignFinished
    case KeysignFailed
}

@MainActor
class KeysignViewModel: ObservableObject {
    private let logger = Logger(subsystem: "keysign", category: "tss")
    @Published var status: KeysignStatus = .CreatingInstance
    @Published var keysignError: String = ""
    @Published var signatures = [String: TssKeysignResponse]()
    @Published var txid: String = ""
    
    private var tssService: TssServiceImpl? = nil
    private var tssMessenger: TssMessengerImpl? = nil
    private var stateAccess: LocalStateAccessorImpl? = nil
    private var messagePuller: MessagePuller? = nil
    
    var keysignCommittee: [String]
    var mediatorURL: String
    var sessionID: String
    var keysignType: KeyType
    var messsageToSign: [String]
    var vault: Vault
    var keysignPayload: KeysignPayload?
    var encryptionKeyHex: String
    
    init() {
        self.keysignCommittee = []
        self.mediatorURL = ""
        self.sessionID = ""
        self.vault = Vault(name: "tempory")
        self.keysignType = .ECDSA
        self.messsageToSign = []
        self.keysignPayload = nil
        self.encryptionKeyHex = ""
    }
    
    func setData(keysignCommittee: [String],
                 mediatorURL: String,
                 sessionID: String,
                 keysignType: KeyType,
                 messagesToSign: [String],
                 vault: Vault,
                 keysignPayload: KeysignPayload?,
                 encryptionKeyHex: String
    ) {
        self.keysignCommittee = keysignCommittee
        self.mediatorURL = mediatorURL
        self.sessionID = sessionID
        self.keysignType = keysignType
        self.messsageToSign = messagesToSign
        self.vault = vault
        self.keysignPayload = keysignPayload
        self.encryptionKeyHex = encryptionKeyHex
        self.messagePuller = MessagePuller(encryptionKeyHex: encryptionKeyHex,pubKey: vault.pubKeyECDSA)
    }
    func getTransactionExplorerURL(txid: String) -> String{
        guard let keysignPayload else {
            return ""
        }
        return Endpoint.getExplorerURL(chainTicker: keysignPayload.coin.chain.ticker, txid: txid)
    }
    func startKeysign() async {
        defer {
            self.messagePuller?.stop()
        }
        for msg in self.messsageToSign {
            logger.info("signing message:\(msg)")
            let msgHash = Utils.getMessageBodyHash(msg: msg)
            var pubkey = ""
            switch self.keysignType {
            case .ECDSA:
                pubkey = vault.pubKeyECDSA
            case .EdDSA:
                pubkey = vault.pubKeyEdDSA
            }
            self.tssMessenger = TssMessengerImpl(mediatorUrl: self.mediatorURL,
                                                 sessionID: self.sessionID,
                                                 messageID: msgHash,
                                                 encryptionKeyHex: encryptionKeyHex,
                                                 vaultPubKey: pubkey,
                                                 isKeygen: false)
            self.stateAccess = LocalStateAccessorImpl(vault: self.vault)
            var err: NSError?
            // keysign doesn't need to recreate preparams
            self.tssService = TssNewService(self.tssMessenger, self.stateAccess, false, &err)
            if let err {
                self.logger.error("Failed to create TSS instance, error: \(err.localizedDescription)")
                self.keysignError = err.localizedDescription
                self.status = .KeysignFailed
                return
            }
            guard let service = self.tssService else {
                self.logger.error("tss service instance is nil")
                self.status = .KeysignFailed
                return
            }
            
            self.messagePuller?.pollMessages(mediatorURL: self.mediatorURL,
                                             sessionID: self.sessionID,
                                             localPartyKey: self.vault.localPartyID,
                                             tssService: service,
                                             messageID: msgHash)
            
            let keysignReq = TssKeysignRequest()
            keysignReq.localPartyKey = self.vault.localPartyID
            keysignReq.keysignCommitteeKeys = self.keysignCommittee.joined(separator: ",")
            if let keysignPayload {
                let coinType = keysignPayload.coin.getCoinType()
                if let coinType {
                    keysignReq.derivePath = coinType.derivationPath()
                } else {
                    self.logger.error("don't support this coin type")
                    self.status = .KeysignFailed
                }
            }
            // sign messages one by one , since the msg is in hex format , so we need convert it to base64
            // and then pass it to TSS for keysign
            if let msgToSign = Data(hexString: msg)?.base64EncodedString() {
                keysignReq.messageToSign = msgToSign
            }
            
            do {
                switch self.keysignType {
                case .ECDSA:
                    keysignReq.pubKey = self.vault.pubKeyECDSA
                    self.status = .KeysignECDSA
                case .EdDSA:
                    keysignReq.pubKey = self.vault.pubKeyEdDSA
                    self.status = .KeysignEdDSA
                }
                if let service = self.tssService {
                    let resp = try await tssKeysign(service: service, req: keysignReq, keysignType: keysignType)
                    self.signatures[msg] = resp
                }
                self.messagePuller?.stop()
                try await Task.sleep(for: .seconds(1)) // backoff for 1 seconds , so other party can finish appropriately
            } catch {
                self.logger.error("fail to do keysign,error:\(error.localizedDescription)")
                self.keysignError = error.localizedDescription
                self.status = .KeysignFailed
                return
            }
            
        }
        await self.broadcastTransaction()
        self.status = .KeysignFinished
        
    }
    func stopMessagePuller(){
        self.messagePuller?.stop()
    }
    func tssKeysign(service: TssServiceImpl, req: TssKeysignRequest, keysignType: KeyType) async throws -> TssKeysignResponse {
        let t = Task.detached(priority: .high) {
            switch keysignType {
            case .ECDSA:
                return try service.keysignECDSA(req)
            case .EdDSA:
                return try service.keysignEdDSA(req)
            }
        }
        return try await t.value
    }
    
    func getSignedTransaction(keysignPayload: KeysignPayload) -> Result<SignedTransactionResult, Error> {
        if keysignPayload.swapPayload != nil {
            let swaps = THORChainSwaps(vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode)
            let result = swaps.getSignedTransaction(keysignPayload: keysignPayload, signatures: signatures)
            return result
        }
        
        switch keysignPayload.coin.chain.chainType {
        case .UTXO:
            guard let coinType = keysignPayload.coin.getCoinType() else {
                return .failure(HelperError.runtimeError("Coin type not found on Wallet Core"))
            }
            
            let utxoHelper = UTXOChainsHelper(coin: coinType, vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode)
            let result = utxoHelper.getSignedTransaction(keysignPayload: keysignPayload, signatures: signatures)
            return result
            
        case .EVM:
            if keysignPayload.coin.isNativeToken {
                guard let helper = EVMHelper.getHelper(coin: keysignPayload.coin) else {
                    return .failure(HelperError.runtimeError("Coin type not found on EVM helper"))
                }
                
                return helper.getSignedTransaction(vaultHexPubKey: self.vault.pubKeyECDSA, vaultHexChainCode: self.vault.hexChainCode, keysignPayload: keysignPayload, signatures: self.signatures)
            } else {
                guard let helper = ERC20Helper.getHelper(coin: keysignPayload.coin) else {
                    return .failure(HelperError.runtimeError("Coin type not found on EVM ERC20 helper"))
                }
                
                return helper.getSignedTransaction(vaultHexPubKey: self.vault.pubKeyECDSA, vaultHexChainCode: self.vault.hexChainCode, keysignPayload: keysignPayload, signatures: self.signatures)
            }
            
        case .THORChain:
            if keysignPayload.coin.chain == .thorChain {
                let result = THORChainHelper.getSignedTransaction(vaultHexPubKey: self.vault.pubKeyECDSA, vaultHexChainCode: self.vault.hexChainCode, keysignPayload: keysignPayload, signatures: self.signatures)
                return result
            } else if keysignPayload.coin.chain == .mayaChain {
                let result = MayaChainHelper.getSignedTransaction(vaultHexPubKey: self.vault.pubKeyECDSA, vaultHexChainCode: self.vault.hexChainCode, keysignPayload: keysignPayload, signatures: self.signatures)
                return result
            }
            
        case .Solana:
            let result = SolanaHelper.getSignedTransaction(vaultHexPubKey: self.vault.pubKeyEdDSA, vaultHexChainCode: self.vault.hexChainCode, keysignPayload: keysignPayload, signatures: self.signatures)
            return result
            
        case .Cosmos:
            if keysignPayload.coin.chain == .gaiaChain {
                let result = ATOMHelper().getSignedTransaction(vaultHexPubKey: self.vault.pubKeyECDSA, vaultHexChainCode: self.vault.hexChainCode, keysignPayload: keysignPayload, signatures: self.signatures)
                return result
            } else if keysignPayload.coin.chain == .kujira {
                let result = KujiraHelper().getSignedTransaction(vaultHexPubKey: self.vault.pubKeyECDSA, vaultHexChainCode: self.vault.hexChainCode, keysignPayload: keysignPayload, signatures: self.signatures)
                return result
            }
        }
        
        return .failure(HelperError.runtimeError("Unexpected error"))
    }
    
    func broadcastTransaction() async {
        guard let keysignPayload else { return }
        let result = getSignedTransaction(keysignPayload: keysignPayload)
        switch result {
        case .success(let tx):
            do {
                switch keysignPayload.coin.chain {
                case .thorChain:
                    let broadcastResult = await ThorchainService.shared.broadcastTransaction(jsonString: tx.rawTransaction)
                    switch broadcastResult {
                    case .success(let txHash):
                        self.txid = txHash
                        print("Transaction successful, hash: \(txHash)")
                    case .failure(let error):
                        throw error
                    }
                case .mayaChain:
                    let broadcastResult = await MayachainService.shared.broadcastTransaction(jsonString: tx.rawTransaction)
                    switch broadcastResult {
                    case .success(let txHash):
                        self.txid = txHash
                        print("Transaction successful, hash: \(txHash)")
                    case .failure(let error):
                        throw error
                    }
                case .ethereum, .avalanche,.arbitrum, .bscChain, .base, .optimism, .polygon, .blast, .cronosChain, .merlin:
                    let service = try EvmServiceFactory.getService(forChain: keysignPayload.coin)
                    self.txid = try await service.broadcastTransaction(hex: tx.rawTransaction)
                case .bitcoin, .bitcoinCash, .litecoin, .dogecoin, .dash:
                    let chainName = keysignPayload.coin.chain.name.lowercased()
                    UTXOTransactionsService.broadcastTransaction(chain: chainName, signedTransaction: tx.rawTransaction) { result in
                        switch result {
                        case .success(let transactionHash):
                            self.txid = transactionHash
                        case .failure(let error):
                            self.handleBroadcastError(err: error,tx:tx)
                        }
                    }
                case .gaiaChain:
                    let broadcastResult = await GaiaService.shared.broadcastTransaction(jsonString: tx.rawTransaction)
                    switch broadcastResult {
                    case .success(let hash):
                        self.txid = hash
                    case .failure(let err):
                        throw err
                    }
                case .kujira:
                    let broadcastResult = await KujiraService.shared.broadcastTransaction(jsonString: tx.rawTransaction)
                    switch broadcastResult {
                    case .success(let hash):
                        self.txid = hash
                    case .failure(let err):
                        throw err
                    }
                case .solana:
                    self.txid = await SolanaService.shared.sendSolanaTransaction(encodedTransaction: tx.rawTransaction) ?? ""
                }
            } catch {
                handleBroadcastError(err: error,tx: tx)
            }
        case .failure(let error):
            handleHelperError(err: error)
        }
        
    }
    func handleBroadcastError(err: Error,tx: SignedTransactionResult){
        var errMessage: String = ""
        switch err{
        case HelperError.runtimeError(let errDetail):
            errMessage = "Failed to broadcast transaction,\(errDetail)"
        case RpcEvmServiceError.rpcError(let code, let message):
            print("code:\(code), message:\(message)")
            if message == "already known" || message == "replacement transaction underpriced" {
                print("the transaction already broadcast,code:\(code)")
                self.txid = tx.transactionHash
                return
            }
        default:
            errMessage = "Failed to broadcast transaction,error:\(err.localizedDescription)"
        }
        print(errMessage)
        DispatchQueue.main.async {
            self.keysignError = errMessage
            self.status = .KeysignFailed
        }
    }
    func handleHelperError(err: Error) {
        var errMessage: String
        switch err {
        case HelperError.runtimeError(let errDetail):
            errMessage = "Failed to get signed transaction,error:\(errDetail)"
            
        default:
            errMessage = "Failed to get signed transaction,error:\(err.localizedDescription)"
        }
        // since it failed to get transaction or failed to broadcast , go to failed page
        DispatchQueue.main.async {
            self.status = .KeysignFailed
            self.keysignError = errMessage
        }
        
    }
}
