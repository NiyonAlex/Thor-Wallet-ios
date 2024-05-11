//
//  ServiceDelegate.swift
//  VultisigApp
//
//  Created by Johnny Luo on 18/3/2024.
//
import OSLog
import SwiftUI

final class ServiceDelegate: NSObject, NetServiceDelegate, ObservableObject {
    private let logger = Logger(subsystem: "service-delegate", category: "communication")
    @Published var serverURL: String?

    public func netServiceDidResolveAddress(_ sender: NetService) {
        logger.info("Service found: \(sender.name), \(sender.hostName ?? ""), port \(sender.port) in domain \(sender.domain)")
        serverURL = "http://\(sender.hostName ?? ""):\(sender.port)"
    }
    
    public func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        logger.error("Failed to resolve service: \(sender.name) with error: \(errorDict)")
    }
}
