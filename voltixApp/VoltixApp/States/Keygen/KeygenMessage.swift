//
//  KeygenMessage.swift
//  VoltixApp
//

struct keygenMessage: Codable {
    let sessionID: String
    let hexChainCode: String
    let serviceName: String
    let encryptionKeyHex: String
    let useVoltixRouter: Bool
}
