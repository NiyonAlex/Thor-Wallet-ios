//
//  KeysignPayload.swift
//  VoltixApp
//

import Foundation
import BigInt
import WalletCore

struct KeysignMessage: Codable, Hashable {
    let sessionID: String
    let serviceName: String
    let payload: KeysignPayload
    let encryptionKeyHex: String
    let useVoltixRelay: Bool
}

enum BlockChainSpecific: Codable, Hashable {
    case UTXO(byteFee: BigInt) // byteFee
    case Ethereum(maxFeePerGasWei: BigInt, priorityFeeWei: BigInt, nonce: Int64, gasLimit: BigInt) // maxFeePerGasWei, priorityFeeWei, nonce , gasLimit
    case ERC20(maxFeePerGasWei: BigInt, priorityFeeWei: BigInt, nonce: Int64, gasLimit: BigInt, contractAddr: String)
    case THORChain(accountNumber: UInt64, sequence: UInt64)
    case Cosmos(accountNumber: UInt64, sequence: UInt64, gas: UInt64)
    case Solana(recentBlockHash: String, priorityFee: BigInt) // priority fee is in microlamports

    var gas: BigInt {
        switch self {
        case .UTXO(let byteFee):
            return byteFee
        case .Ethereum(let maxFeePerGas, _, _, _):
            return maxFeePerGas
        case .ERC20(let maxFeePerGas, _, _, _, _):
            return maxFeePerGas
        case .THORChain:
            return 2_000_000
        case .Cosmos:
            return 7500
        case .Solana:
            return SolanaHelper.defaultFeeInLamports
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
    let swapPayload: THORChainSwapPayload?
    
    var toAmountString: String {
        let decimalAmount = Decimal(string: toAmount.description) ?? Decimal.zero
        let power = Decimal(sign: .plus, exponent: -(Int(coin.decimals) ?? 0), significand: 1)
        return "\(decimalAmount * power) \(coin.ticker)"
    }
    
    func getKeysignMessages(vault: Vault) -> Result<[String], Error> {
        if swapPayload != nil {
            let swaps = THORChainSwaps(vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode)
            return swaps.getPreSignedImageHash(keysignPayload: self)
        }
        switch coin.chain {
        case .bitcoin, .bitcoinCash, .litecoin, .dogecoin, .dash:
            guard let coinType = CoinType.from(string: coin.chain.name.replacingOccurrences(of: "-", with: "")) else {
                print("Coin type not found on Wallet Core")
                return .failure("Coin type not found on Wallet Core" as! Error)
            }
            let utxoHelper = UTXOChainsHelper(coin: coinType, vaultHexPublicKey: vault.pubKeyECDSA, vaultHexChainCode: vault.hexChainCode)
            return utxoHelper.getPreSignedImageHash(keysignPayload: self)
        case .ethereum, .arbitrum, .base, .optimism, .polygon, .avalanche, .bscChain, .blast, .cronosChain, .merlin:
            if coin.isNativeToken {
                let helper = EVMHelper.getHelper(coin: coin)?.getPreSignedImageHash(keysignPayload: self)
                guard let preSignedImageHash = helper else {
                    return .failure("Error to get getPreSignedImageHash on EVM" as! Error)
                }
                return preSignedImageHash
                
            }else{
                let helper = ERC20Helper.getHelper(coin: coin)?.getPreSignedImageHash(keysignPayload: self)
                guard let preSignedImageHash = helper else {
                    return .failure("Error to get getPreSignedImageHash on EVM" as! Error)
                }
                return preSignedImageHash
                
            }
        case .thorChain:
            return THORChainHelper.getPreSignedImageHash(keysignPayload: self)
        case .mayaChain:
            return MayaChainHelper.getPreSignedImageHash(keysignPayload: self)
        case .solana:
            return SolanaHelper.getPreSignedImageHash(keysignPayload: self)
        case .gaiaChain:
            return ATOMHelper().getPreSignedImageHash(keysignPayload: self)
        case .kujira:
            return KujiraHelper().getPreSignedImageHash(keysignPayload: self)
        }
    }
    
    static let example = KeysignPayload(coin: Coin.example, toAddress: "toAddress", toAmount: 100, chainSpecific: BlockChainSpecific.UTXO(byteFee: 100), utxos: [], memo: "Memo", swapPayload: nil)
}
