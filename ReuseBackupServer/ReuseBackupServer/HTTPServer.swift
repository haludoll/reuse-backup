import FlyingFox
import Foundation
import OSLog
import Observation

/// ReuseBackupServer用のHTTPサーバー実装
@MainActor
@Observable
class HTTPServer {
    
    // MARK: - Properties
    
    var isRunning = false
    var serverStatus: ServerStatus = .stopped
    
    private var server: FlyingFox.HTTPServer?
    private let port: UInt16 = 8080
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "HTTPServer")
    private var startTime: Date?
    
    // MARK: - Server Status
    
    enum ServerStatus {
        case stopped
        case starting
        case running
        case stopping
        case error(String)
        
        var description: String {
            switch self {
            case .stopped: return "stopped"
            case .starting: return "starting"
            case .running: return "running"
            case .stopping: return "stopping"
            case .error: return "error"
            }
        }
    }
    
    // MARK: - Data Models
    
    struct MessageRequest: Codable {
        let message: String
        let timestamp: String
    }
    
    struct MessageResponse: Codable {
        let status: String
        let received: Bool
        let serverTimestamp: String
    }
    
    struct ErrorResponse: Codable {
        let status: String
        let error: String
        let received: Bool
    }
    
    struct ServerStatusResponse: Codable {
        let status: String
        let uptime: Int
        let version: String
        let serverTime: String
    }
    
    // MARK: - Initialization
    
    init() {
        logger.info("HTTPServer initialized for port \(self.port)")
    }
    
    // MARK: - Server Control
    
    func startServer() async {
        guard !isRunning else {
            logger.warning("Server is already running")
            return
        }
        
        serverStatus = .starting
        logger.info("Starting HTTP server on port \(self.port)")
        
        do {
            let server = FlyingFox.HTTPServer(port: port)
            
            // APIエンドポイントの登録
            await server.appendRoute("POST /api/message", to: handleMessage)
            await server.appendRoute("GET /api/status", to: handleStatus)
            
            self.server = server
            
            // サーバー開始
            try await server.start()
            
            startTime = Date()
            isRunning = true
            serverStatus = .running
            
            logger.info("HTTP server started successfully on port \(self.port)")
            
        } catch {
            let errorMessage = "Failed to start server: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            serverStatus = .error(errorMessage)
            isRunning = false
        }
    }
    
    func stopServer() async {
        guard isRunning, let server = server else {
            logger.warning("Server is not running")
            return
        }
        
        serverStatus = .stopping
        logger.info("Stopping HTTP server")
        
        server.stop()
        
        self.server = nil
        isRunning = false
        serverStatus = .stopped
        startTime = nil
        
        logger.info("HTTP server stopped")
    }
    
    // MARK: - API Handlers
    
    private func handleMessage(_ request: FlyingFox.HTTPRequest) async throws -> FlyingFox.HTTPResponse {
        logger.info("Received POST request to /api/message")
        
        // リクエストボディの解析
        guard let bodyData = request.body,
              let messageRequest = try? JSONDecoder().decode(MessageRequest.self, from: bodyData) else {
            logger.warning("Invalid JSON in message request")
            
            let errorResponse = ErrorResponse(
                status: "error",
                error: "Invalid JSON format",
                received: false
            )
            
            let responseData = try JSONEncoder().encode(errorResponse)
            return HTTPResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: responseData
            )
        }
        
        // メッセージをログに出力
        logger.info("Message received: '\(messageRequest.message)' at \(messageRequest.timestamp)")
        
        // 成功レスポンス
        let response = MessageResponse(
            status: "success",
            received: true,
            serverTimestamp: ISO8601DateFormatter().string(from: Date())
        )
        
        let responseData = try JSONEncoder().encode(response)
        return HTTPResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: responseData
        )
    }
    
    private func handleStatus(_ request: FlyingFox.HTTPRequest) async throws -> FlyingFox.HTTPResponse {
        logger.info("Received GET request to /api/status")
        
        let uptime = startTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
        
        let statusResponse = ServerStatusResponse(
            status: serverStatus.description,
            uptime: uptime,
            version: "1.0.0",
            serverTime: ISO8601DateFormatter().string(from: Date())
        )
        
        let responseData = try JSONEncoder().encode(statusResponse)
        return HTTPResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: responseData
        )
    }
}