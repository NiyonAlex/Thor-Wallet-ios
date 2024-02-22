import Cache
import CryptoKit
import Foundation
import Network
import OSLog
import Swifter

public final class Mediator {
    private let logger = Logger(subsystem: "Mediator", category: "communication")
    let port: UInt16 = 8080
    let server = HttpServer()
    let cache = MemoryStorage<String, Any>(config: MemoryConfig())
    var clients = [String: WebSocketSession]()
    var sessions = [String: String]()
    private let service: NetService
    
    // Singleton
    public static let shared = Mediator()
    private init() {
        self.service = NetService(domain: "local.", type: "_http._tcp", name: "VoltixApp", port: Int32(self.port))
        self.setupRoute()
    }
    
    private func setupRoute() {
        // POST with a sessionID
        self.server.POST["/:sessionID"] = self.postSession
        // DELETE all messages related to the sessionID
        self.server.DELETE["/:sessionID"] = self.deleteSession
        // GET all participants that are linked to a specific session
        self.server.GET["/:sessionID"] = self.getSession
        // POST a message to a specific session
        self.server.POST["/message/:sessionID"] = self.sendMessage
        // GET all messages for a specific session and participant
        self.server.GET["/message/:sessionID/:participantKey"] = self.getMessages
        // DELETE a message , client indicate it already received it
        self.server.DELETE["/message/:sessionID/:participantKey/:hash"] = self.deleteMessage
        // POST/GET , to notifiy all parties to start keygen/keysign
        self.server["/start/:sessionID"] = self.startKeygenOrKeysign
        self.server["/websocket/ws"] = websocket(text: self.OnWebSocketText,
                                              connected: self.OnClientConnected,
                                              disconnected: self.OnClientDisconnected)
    }

    private func OnWebSocketText(session: WebSocketSession, content: String) {
        let decoder = JSONDecoder()
        guard let contentData = content.data(using: .utf8) else {
            self.logger.error("content: \(content) can't be decoded correctly")
            return
        }
        do {
            let socketMsg = try decoder.decode(WebsocketMessage.self, from: contentData)
            switch socketMsg.header {
            case .HelloMessage:
                self.processHelloMessage(session: session, payload: socketMsg.body)
            case .DropSession:
                self.processJoinAndDropSession(session: session, payload: socketMsg.body, content: content)
            case .EndSession:
                self.processEndSession(session: session, payload: socketMsg.body)
            case .JoinSession:
                self.processJoinAndDropSession(session: session, payload: socketMsg.body, content: content)
            case .StartSession:
                self.processStartSession(session: session, payload: socketMsg.body)
            case .StartTSS:
                self.processStartTSS(session: session, payload: socketMsg.body, content: content)
            case .TSSRouting:
                self.processTSSRouting(session: session, payload: socketMsg.body, content: content)
            }
        } catch {
            self.logger.error("fail to process message,error:\(error.localizedDescription)")
        }
    }

    private func OnClientConnected(session: WebSocketSession) {
        
    }
    
    private func OnClientDisconnected(session: WebSocketSession) {
        var keysToDelete = [String]()
        for item in self.clients {
            if item.value == session {
                keysToDelete.append(item.key)
            }
        }
        for item in keysToDelete {
            self.clients.removeValue(forKey: item)
        }
    }
    
    private func processTSSRouting(session: WebSocketSession, payload: String, content: String) {
        guard let payloadData = payload.data(using: .utf8) else {
            self.logger.error("TSS Routing message payload can't be decoded,\(payload)")
            return
        }
        do {
            let decoder = JSONDecoder()
            let tssRoutingMsg = try decoder.decode(TSSRoutingMessage.self, from: payloadData)
            
            guard let clientSession = clients[tssRoutingMsg.to] else {
                self.logger.error("client:\(tssRoutingMsg.to) is offline")
                return
            }
            // foward the message to client
            clientSession.writeText(content)
            
        } catch {
            self.logger.error("fail to decode start tss message,error:\(error)")
        }
    }

    private func processStartTSS(session: WebSocketSession, payload: String, content: String) {
        guard let payloadData = payload.data(using: .utf8) else {
            self.logger.error("start tss message payload can't be decoded,\(payload)")
            return
        }
        do {
            let decoder = JSONDecoder()
            let startTssMsg = try decoder.decode(StartTSSMessage.self, from: payloadData)
            for item in startTssMsg.committee {
                guard let clientSession = clients[item] else {
                    continue
                }
                // foward the message to client
                clientSession.writeText(content)
            }
        } catch {
            self.logger.error("fail to decode start tss message,error:\(error)")
        }
    }

    private func processEndSession(session: WebSocketSession, payload: String) {
        let sessionMsg = self.getSessionMsg(payload: payload)
        guard let sessionMsg else {
            self.logger.error("fail to get session msg")
            return
        }
        self.sessions.removeValue(forKey: sessionMsg.sessionID)
    }

    // for both joining a session and drop a session , just forward the message to session owner
    private func processJoinAndDropSession(session: WebSocketSession, payload: String, content: String) {
        let sessionMsg = self.getSessionMsg(payload: payload)
        guard let sessionMsg else {
            self.logger.error("fail to get session msg")
            return
        }
        guard let owner = sessions[sessionMsg.sessionID] else {
            self.logger.debug("session:\(sessionMsg.sessionID) is not started")
            return
        }
        guard let socketSession = clients[owner] else {
            self.logger.debug("session owner: \(owner) is not online")
            return
        }
            
        // foward the payload the owner
        socketSession.writeText(content)
    }

    private func getSessionMsg(payload: String) -> SessionMessage? {
        guard let payloadData = payload.data(using: .utf8) else {
            self.logger.error("session message payload can't be decoded,\(payload)")
            return nil
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(SessionMessage.self, from: payloadData)
        } catch {
            self.logger.error("fail to decode session message,error:\(error)")
        }
        return nil
    }

    // start a session, so other client can join
    private func processStartSession(session: WebSocketSession, payload: String) {
        let sessionMsg = self.getSessionMsg(payload: payload)
        if let sessionMsg {
            self.sessions[sessionMsg.sessionID] = sessionMsg.clientKey
        }
    }

    private func processHelloMessage(session: WebSocketSession, payload: String) {
        logger.info("process hello message")
        guard let payloadData = payload.data(using: .utf8) else {
            self.logger.error("hello message payload can't be decoded,\(payload)")
            return
        }
        do {
            let decoder = JSONDecoder()
            let helloMsg = try decoder.decode(HelloMessage.self, from: payloadData)
            self.clients[helloMsg.clientKey] = session
            logger.info("successfully process hello message")
        } catch {
            self.logger.error("fail to process hello message,error:\(error)")
        }
    }
    
    // start the server
    public func start() {
        do {
            try self.server.start(self.port)
            self.service.publish()
        } catch {
            self.logger.error("fail to start http server on port: \(self.port), error:\(error)")
            return
        }
        self.logger.info("server started successfully")
    }
    
    // stop mediator server
    public func stop() {
        self.server.stop()
        // clean up all
        self.cache.removeAll()
    }
    
    private func startKeygenOrKeysign(req: HttpRequest) -> HttpResponse {
        guard let sessionID = req.params[":sessionID"] else {
            return HttpResponse.badRequest(.text("sessionID is empty"))
        }
        let cleanSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "session-\(cleanSessionID)-start"
        self.logger.debug("request session id is: \(cleanSessionID)")
        do {
            switch req.method {
            case "POST":
                do {
                    let decoder = JSONDecoder()
                    let p = try decoder.decode([String].self, from: Data(req.body))
                    self.cache.setObject(Session(SessionID: cleanSessionID, Participants: p), forKey: key)
                } catch {
                    self.logger.error("fail to start keygen/keysign,error:\(error.localizedDescription)")
                    return HttpResponse.badRequest(.none)
                }
                
                return HttpResponse.ok(.text(""))
            case "GET":
                if !self.cache.objectExists(forKey: key) {
                    // self.logger.debug("session didn't start, can't find key:\(key)")
                    return HttpResponse.notFound
                }
                let cachedSession = try self.cache.object(forKey: key) as? Session
                if let cachedSession {
                    return HttpResponse.ok(.json(cachedSession.Participants))
                }
                return HttpResponse.notAcceptable
            default:
                return HttpResponse.notFound
            }
        } catch {
            self.logger.error("fail to process request to start keygen/keysign,error:\(error.localizedDescription)")
            return HttpResponse.internalServerError
        }
    }
    
    private func sendMessage(req: HttpRequest) -> HttpResponse {
        guard let sessionID = req.params[":sessionID"] else {
            return HttpResponse.badRequest(.text("sessionID is empty"))
        }
        let messageID = req.headers["message_id"] // message_id indicate the keysign message id
        let cleanSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(Message.self, from: Data(req.body))
            for recipient in message.to {
                var key = "\(cleanSessionID)-\(recipient)-\(message.hash)"
                if let messageID {
                    key = "\(cleanSessionID)-\(recipient)-\(messageID)-\(message.hash)"
                }
                self.logger.info("received message \(message.hash) from \(message.from) to \(recipient)")
                self.cache.setObject(message, forKey: key)
            }
        } catch {
            self.logger.error("fail to decode message payload,error:\(error)")
            return HttpResponse.badRequest(.text("fail to decode payload"))
        }
        return HttpResponse.accepted
    }
    
    private func getMessages(req: HttpRequest) -> HttpResponse {
        guard let sessionID = req.params[":sessionID"] else {
            return HttpResponse.badRequest(.text("sessionID is empty"))
        }
        guard let participantID = req.params[":participantKey"] else {
            return HttpResponse.badRequest(.text("participantKey is empty"))
        }
        let cleanSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanParticipantKey = participantID.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageID = req.headers["message_id"]
        // make sure the keyprefix endwith `-` so it doesn't clash with the participant key
        var keyPrefix = "\(cleanSessionID)-\(cleanParticipantKey)-"
        if let messageID {
            keyPrefix = "\(cleanSessionID)-\(cleanParticipantKey)-\(messageID)-"
        }
        let encoder = JSONEncoder()
        do {
            // get all the messages
            let messages = try self.cache.allKeys.filter {
                $0.hasPrefix(keyPrefix)
            }.compactMap { cacheKey in
                try self.cache.object(forKey: cacheKey) as? Message
            }
            let result = try encoder.encode(messages)
            return HttpResponse.ok(.data(result, contentType: "application/json"))
        } catch {
            self.logger.error("fail to encode object to json,error:\(error)")
            return HttpResponse.internalServerError
        }
    }

    private func postSession(req: HttpRequest) -> HttpResponse {
        guard let sessionID = req.params[":sessionID"] else {
            self.logger.error("request session id is empty")
            return HttpResponse.badRequest(.text("sessionID is empty"))
        }
        let cleanSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "session-\(cleanSessionID)"
        self.logger.debug("request session id is: \(cleanSessionID)")
        do {
            let decoder = JSONDecoder()
            let p = try decoder.decode([String].self, from: Data(req.body))
            if self.cache.objectExists(forKey: key) {
                if let cachedValue = try self.cache.object(forKey: key) as? Session {
                    for newParticipant in p {
                        if !cachedValue.Participants.contains(where: { $0 == newParticipant }) {
                            cachedValue.Participants.append(newParticipant)
                        }
                    }
                    self.cache.setObject(cachedValue, forKey: key)
                }
            } else {
                let session = Session(SessionID: cleanSessionID, Participants: p)
                self.cache.setObject(session, forKey: key)
            }
            
        } catch {
            self.logger.error("fail to decode json body,error:\(error)")
            return HttpResponse.badRequest(.text("invalid json payload"))
        }
        return HttpResponse.created
    }
    
    private func deleteSession(req: HttpRequest) -> HttpResponse {
        guard let sessionID = req.params[":sessionID"] else {
            return HttpResponse.badRequest(.text("sessionID is empty"))
        }
        let cleanSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "session-\(cleanSessionID)"
        self.cache.removeObject(forKey: key)
        let keyStart = "\(key)-start"
        self.cache.removeObject(forKey: keyStart)
        return HttpResponse.ok(.text(""))
    }
    
    private func getSession(req: HttpRequest) -> HttpResponse {
        guard let sessionID = req.params[":sessionID"] else {
            return HttpResponse.badRequest(.text("sessionID is empty"))
        }
        
        let cleanSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "session-\(cleanSessionID)"
        do {
            if let cachedValue = try self.cache.object(forKey: key) as? Session {
                self.logger.debug("session obj : \(cachedValue.SessionID), participants: \(cachedValue.Participants)")
                return HttpResponse.ok(.json(cachedValue.Participants))
            }
        } catch Cache.StorageError.notFound {
            return HttpResponse.notFound
        } catch {
            self.logger.error("fail to get session,error:\(error.localizedDescription)")
        }
        return HttpResponse.notFound
    }

    private func deleteMessage(req: HttpRequest) -> HttpResponse {
        guard let sessionID = req.params[":sessionID"] else {
            return HttpResponse.badRequest(.text("sessionID is empty"))
        }
        let cleanSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let participantID = req.params[":participantKey"] else {
            return HttpResponse.badRequest(.text("participantKey is empty"))
        }
        let cleanParticipantKey = participantID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let msgHash = req.params[":hash"] else {
            return HttpResponse.badRequest(.text("hash is empty"))
        }
        let messageID = req.headers["message_id"]
        var key = "\(cleanSessionID)-\(cleanParticipantKey)-\(msgHash)"
        if let messageID {
            key = "\(cleanSessionID)-\(cleanParticipantKey)-\(messageID)-\(msgHash)"
        }
        self.logger.info("message with key:\(key) deleted")
        self.cache.removeObject(forKey: key)
        return HttpResponse.ok(.text(""))
    }

    deinit {
        self.cache.removeAll() // clean up cache
    }
}
