import Foundation
import Network
import OSLog

/// ReuseBackupServer用のHTTPサーバー実装
@MainActor
class HTTPServer: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isRunning = false
    @Published var serverStatus: ServerStatus = .stopped
    
    private var listener: NWListener?
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
            let parameters = NWParameters.tcp
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.startTime = Date()
                        self?.isRunning = true
                        self?.serverStatus = .running
                        self?.logger.info("HTTP server started successfully on port \(self?.port ?? 0)")
                    case .failed(let error):
                        let errorMessage = "Server failed: \(error.localizedDescription)"
                        self?.logger.error("\(errorMessage)")
                        self?.serverStatus = .error(errorMessage)
                        self?.isRunning = false
                    case .cancelled:
                        self?.isRunning = false
                        self?.serverStatus = .stopped
                        self?.startTime = nil
                        self?.logger.info("HTTP server stopped")
                    default:
                        break
                    }
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                Task {
                    await self?.handleConnection(connection)
                }
            }
            
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
            
        } catch {
            let errorMessage = "Failed to start server: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            serverStatus = .error(errorMessage)
            isRunning = false
        }
    }
    
    func stopServer() async {
        guard isRunning, let listener = listener else {
            logger.warning("Server is not running")
            return
        }
        
        serverStatus = .stopping
        logger.info("Stopping HTTP server")
        
        listener.cancel()
        self.listener = nil
    }
    
    // MARK: - Connection Handling
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        // 基本的なHTTPレスポンスを送信
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: 84\r
        \r
        {"status":"success","message":"ReuseBackup Server is running","port":\(port)}
        """.data(using: .utf8)!
        
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}