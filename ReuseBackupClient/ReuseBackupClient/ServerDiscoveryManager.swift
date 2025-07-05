import Foundation
import Network
import APISharedModels

@MainActor
class ServerDiscoveryManager: ObservableObject {
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isSearching = false
    @Published var manualServerAddress = ""
    
    private var browser: NWBrowser?
    private let httpClient = HTTPClient()
    
    func startDiscovery() {
        isSearching = true
        discoveredServers.removeAll()
        
        // Bonjourサービス検索を開始
        startBonjourDiscovery()
        
        // ローカルホストも追加
        addLocalHostServer()
        
        // 5秒後に検索終了
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            stopDiscovery()
        }
    }
    
    func stopDiscovery() {
        isSearching = false
        browser?.cancel()
        browser = nil
    }
    
    func addManualServer() {
        guard !manualServerAddress.isEmpty else { return }
        
        let endpoint: String
        if manualServerAddress.hasPrefix("http://") || manualServerAddress.hasPrefix("https://") {
            endpoint = manualServerAddress
        } else {
            endpoint = "http://\(manualServerAddress)"
        }
        
        let server = DiscoveredServer(
            name: "手動追加サーバー",
            endpoint: endpoint,
            type: .manual
        )
        
        if !discoveredServers.contains(where: { $0.endpoint == server.endpoint }) {
            discoveredServers.append(server)
        }
        
        manualServerAddress = ""
    }
    
    private func startBonjourDiscovery() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_reuse-backup._tcp", domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("Bonjour browser ready")
                case .failed(let error):
                    print("Bonjour browser failed: \(error)")
                case .cancelled:
                    print("Bonjour browser cancelled")
                default:
                    break
                }
            }
        }
        
        browser?.browseResultsChangedHandler = { results, changes in
            DispatchQueue.main.async {
                for result in results {
                    if case .service(let name, let type, let domain, _) = result.endpoint {
                        // Bonjourサービスから実際のIPアドレスとポートを解決
                        self.resolveService(name: name, type: type, domain: domain)
                    }
                }
            }
        }
        
        browser?.start(queue: .main)
    }
    
    private func resolveService(name: String, type: String, domain: String) {
        // Bonjourサービスの名前解決（簡略化）
        // 実際の実装では、NWConnectionを使用してサービスの詳細を解決します
        // ここでは仮のエンドポイントを作成
        let endpoint = "http://\(name).local:8080"
        
        let server = DiscoveredServer(
            name: name,
            endpoint: endpoint,
            type: .bonjour
        )
        
        if !discoveredServers.contains(where: { $0.endpoint == server.endpoint }) {
            discoveredServers.append(server)
        }
    }
    
    private func addLocalHostServer() {
        let server = DiscoveredServer(
            name: "ローカルサーバー",
            endpoint: "http://localhost:8080",
            type: .localhost
        )
        
        discoveredServers.append(server)
    }
}

struct DiscoveredServer {
    let name: String
    let endpoint: String
    let type: ServerType
    
    enum ServerType {
        case bonjour
        case localhost
        case manual
    }
}

@MainActor
class ServerStatusChecker: ObservableObject {
    @Published var isOnline = false
    @Published var isChecking = false
    @Published var serverStatus: Components.Schemas.ServerStatus?
    
    private let httpClient = HTTPClient()
    
    func checkStatus(endpoint: String) async {
        guard let url = URL(string: endpoint) else {
            isOnline = false
            return
        }
        
        isChecking = true
        
        do {
            let status = try await httpClient.checkServerStatus(baseURL: url)
            serverStatus = status
            isOnline = true
        } catch {
            serverStatus = nil
            isOnline = false
            print("サーバーステータス確認エラー (\(endpoint)): \(error)")
        }
        
        isChecking = false
    }
}