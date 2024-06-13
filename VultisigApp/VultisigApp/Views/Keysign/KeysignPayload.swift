//
//  KeysignPayload.swift
//  VultisigApp
//

import Foundation
import BigInt
import WalletCoreCommon

struct KeysignMessage: Codable, Hashable {
    let sessionID: String
    let serviceName: String
    let payload: KeysignPayload
    let encryptionKeyHex: String
    let useVultisigRelay: Bool
}

enum BlockChainSpecific: Codable, Hashable {
    case UTXO(byteFee: BigInt, sendMaxAmount: Bool) // byteFee
    case Ethereum(maxFeePerGasWei: BigInt, priorityFeeWei: BigInt, nonce: Int64, gasLimit: BigInt) // maxFeePerGasWei, priorityFeeWei, nonce , gasLimit
    case THORChain(accountNumber: UInt64, sequence: UInt64, fee: UInt64)
    case MayaChain(accountNumber: UInt64, sequence: UInt64)
    case Cosmos(accountNumber: UInt64, sequence: UInt64, gas: UInt64)
    case Solana(recentBlockHash: String, priorityFee: BigInt) // priority fee is in microlamports
    case Sui(referenceGasPrice: BigInt, coins: [[String:String]])
    case Polkadot(recentBlockHash: String, nonce: UInt64, currentBlockNumber: BigInt, specVersion: UInt32, transactionVersion: UInt32, genesisHash: String)
    
    var gas: BigInt {
        switch self {
        case .UTXO(let byteFee, _):
            return byteFee
        case .Ethereum(let baseFee, let priorityFeeWei, _, _):
            return baseFee + priorityFeeWei
        case .THORChain(_, _, let fee):
            return fee.description.toBigInt()
        case .MayaChain:
            return MayaChainHelper.MayaChainGas.description.toBigInt() //Maya uses 10e10
        case .Cosmos:
            return 7500
        case .Solana:
            return SolanaHelper.defaultFeeInLamports
        case .Sui(let referenceGasPrice, _):
            return referenceGasPrice
        case .Polkadot:
            return PolkadotHelper.defaultFeeInPlancks
        }
    }
}

struct KeysignPayload: Codable, Hashable {
    
    let coin: Coin
    // only toAddress is required , from Address is our own address
    let toAddress: String
    let toAmount: BigInt
    let chainSpecific: BlockChainSpecific
    
    // for UTXO chains , often it need to sign multiple UTXOs at the same time
    // here when keysign , the main device will only pass the utxo info to the keysign device
    // it is up to the signing device to get the presign keyhash , and sign it with the main device
    let utxos: [UtxoInfo]
    let memo: String? // optional memo
    let swapPayload: SwapPayload?
    let approvePayload: ERC20ApprovePayload?
    let vaultPubKeyECDSA: String
    let vaultLocalPartyID: String
    
    init(coin: Coin, toAddress: String, toAmount: BigInt, chainSpecific: BlockChainSpecific, utxos: [UtxoInfo], memo: String?, swapPayload: SwapPayload?, approvePayload: ERC20ApprovePayload? = nil, vaultPubKeyECDSA: String, vaultLocalPartyID: String) {
        self.coin = coin
        self.toAddress = toAddress
        self.toAmount = toAmount
        self.chainSpecific = chainSpecific
        self.utxos = utxos
        self.memo = memo
        self.swapPayload = swapPayload
        self.approvePayload = approvePayload
        self.vaultPubKeyECDSA = vaultPubKeyECDSA
        self.vaultLocalPartyID = vaultLocalPartyID
    }
    
    var toAmountString: String {
        let decimalAmount = Decimal(string: toAmount.description) ?? Decimal.zero
        let power = Decimal(sign: .plus, exponent: -coin.decimals, significand: 1)
        return "\(decimalAmount * power) \(coin.ticker)"
    }
    
    func getKeysignMessages(vault: Vault) -> Result<[String], Error> {
        if let swapPayload {
            switch swapPayload {
            case .thorchain(let payload):
                let swaps = THORChainSwaps(vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode)
                return swaps.getPreSignedImageHash(swapPayload: payload, keysignPayload: self)
            case .oneInch(let payload):
                let swaps = OneInchSwaps(vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode)
                return swaps.getPreSignedImageHash(payload: payload, keysignPayload: self)
            case .mayachain:
                break // No op - Regular transaction with memo
            }
        }
        
        if let approvePayload {
            let swaps = THORChainSwaps(vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode)
            return swaps.getPreSignedApproveImageHash(approvePayload: approvePayload, keysignPayload: self)
        }
        
        switch coin.chain {
        case .bitcoin, .bitcoinCash, .litecoin, .dogecoin, .dash:
            guard let coinType = CoinType.from(string: coin.chain.name.replacingOccurrences(of: "-", with: "")) else {
                print("Coin type not found on Wallet Core")
                return .failure("Coin type not found on Wallet Core" as! Error)
            }
            let utxoHelper = UTXOChainsHelper(coin: coinType, vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode)
            return utxoHelper.getPreSignedImageHash(keysignPayload: self)
        case .ethereum, .arbitrum, .base, .optimism, .polygon, .avalanche, .bscChain, .blast, .cronosChain, .zksync:
            if coin.isNativeToken {
                let helper = EVMHelper.getHelper(coin: coin)
                return helper.getPreSignedImageHash(keysignPayload: self)
            } else {
                let helper = ERC20Helper.getHelper(coin: coin)
                return helper.getPreSignedImageHash(keysignPayload: self)
            }
        case .thorChain:
            return THORChainHelper.getPreSignedImageHash(keysignPayload: self)
        case .mayaChain:
            return MayaChainHelper.getPreSignedImageHash(keysignPayload: self)
        case .solana:
            return SolanaHelper.getPreSignedImageHash(keysignPayload: self)
        case .sui:
            return SuiHelper.getPreSignedImageHash(keysignPayload: self)
        case .gaiaChain:
            return ATOMHelper().getPreSignedImageHash(keysignPayload: self)
        case .kujira:
            return KujiraHelper().getPreSignedImageHash(keysignPayload: self)
        case .polkadot:
            return PolkadotHelper.getPreSignedImageHash(keysignPayload: self)
        }
    }
    
    static let example = KeysignPayload(coin: Coin.example, toAddress: "toAddress", toAmount: 100, chainSpecific: BlockChainSpecific.UTXO(byteFee: 100, sendMaxAmount: false), utxos: [], memo: "Memo", swapPayload: nil, vaultPubKeyECDSA: "12345", vaultLocalPartyID: "iPhone-100")
}
