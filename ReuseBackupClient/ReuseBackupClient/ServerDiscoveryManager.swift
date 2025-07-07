import Foundation
import Network
import APISharedModels

@MainActor
class ServerDiscoveryManager: ObservableObject {
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isSearching = false
    @Published var manualServerAddress = ""
    @Published var errorMessage: String?
    @Published var showingAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
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
        print("🛑 Stopping Bonjour discovery (5-second timeout reached)")
        isSearching = false
        browser?.cancel()
        browser = nil
    }
    
    func addManualServer() {
        let trimmedAddress = manualServerAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            showAlert("入力エラー", "サーバーアドレスを入力してください。")
            return
        }
        
        // 基本的な形式チェック
        if !trimmedAddress.contains(":") {
            showAlert("入力エラー", "ポート番号を含めてください。例: 192.168.1.100:8080")
            return
        }
        
        let endpoint: String
        if trimmedAddress.hasPrefix("http://") || trimmedAddress.hasPrefix("https://") {
            endpoint = trimmedAddress
        } else {
            endpoint = "http://\(trimmedAddress)"
        }
        
        // URL形式の検証
        guard URL(string: endpoint) != nil else {
            showAlert("入力エラー", "有効なアドレス形式で入力してください。例: 192.168.1.100:8080")
            return
        }
        
        let server = DiscoveredServer(
            name: "手動追加サーバー",
            endpoint: endpoint,
            type: .manual
        )
        
        if !discoveredServers.contains(where: { $0.endpoint == server.endpoint }) {
            discoveredServers.append(server)
            showAlert("追加完了", "サーバーを追加しました: \(endpoint)")
        } else {
            showAlert("重複エラー", "このサーバーは既に追加されています。")
        }
        
        manualServerAddress = ""
    }
    
    private func showAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    private func startBonjourDiscovery() {
        print("🔍 Starting Bonjour discovery for _reuse-backup._tcp services")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_reuse-backup._tcp", domain: nil), using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("✅ Bonjour browser ready - starting discovery")
                case .failed(let error):
                    print("❌ Bonjour browser failed: \(error)")
                    switch error {
                    if error is NWError {
                        let nwError = error as! NWError
                        switch nwError {
                        case .dns(let dnsError):
                            print("DNS Error: \(dnsError)")
                        default:
                            print("Network Error: \(nwError)")
                        }
                    } else {
                        print("Other Error: \(error)")
                    }
                    }
                    self?.errorMessage = "Bonjour検索エラー: \(error.localizedDescription)"
                case .cancelled:
                    print("🔄 Bonjour browser cancelled - This is expected when stopDiscovery() is called")
                case .waiting(let error):
                    print("⏳ Bonjour browser waiting: \(error)")
                default:
                    print("📊 Bonjour browser state: \(state)")
                }
            }
        }

        browser?.browseResultsChangedHandler = { (results, changes) in
            DispatchQueue.main.async {
                print("📱 Bonjour results changed. Found \(results.count) services")
                for change in changes {
                    switch change {
                    case .added(let result):
                        print("➕ Service added: \(result.endpoint)")
                    case .removed(let result):
                        print("➖ Service removed: \(result.endpoint)")
                    case .changed(let old, let new):
                        print("🔄 Service changed: \(old.endpoint) -> \(new.endpoint)")
                    @unknown default:
                        print("❓ Unknown change type")
                    }
                }
                
                for result in results {
                    if case .service(let name, let type, let domain, _) = result.endpoint {
                        print("🌐 Resolving service: \(name).\(type)\(domain)")
                        // Bonjourサービスから実際のIPアドレスとポートを解決
                        self.resolveService(name: name, type: type, domain: domain)
                    }
                }
            }
        }
        
        browser?.start(queue: .main)
    }
    
    private func resolveService(name: String, type: String, domain: String) {
        let serviceName = "\(name).\(type)\(domain)"
        let serviceEndpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        let connection = NWConnection(to: serviceEndpoint, using: parameters)
        
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    // 接続が確立できた場合、エンドポイント情報を取得
                    if let endpoint = connection.currentPath?.remoteEndpoint {
                        self?.handleResolvedEndpoint(
                            serviceName: name,
                            endpoint: endpoint,
                            connection: connection
                        )
                    }
                    connection.cancel()
                    
                case .failed(let error):
                    print("サービス解決失敗 (\(serviceName)): \(error)")
                    connection.cancel()
                    
                case .cancelled:
                    break
                    
                default:
                    break
                }
            }
        }
        
        connection.start(queue: .main)
        
        // 5秒でタイムアウト
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if connection.state != .cancelled {
                connection.cancel()
            }
        }
    }
    
    private func handleResolvedEndpoint(serviceName: String, endpoint: NWEndpoint, connection: NWConnection) {
        var serverHost = ""
        var serverPort = 8080
        
        switch endpoint {
        case .hostPort(let host, let port):
            switch host {
            case .ipv4(let address):
                serverHost = address.debugDescription
            case .ipv6(let address):
                serverHost = "[\(address.debugDescription)]"
            case .name(let hostname, _):
                serverHost = hostname
            @unknown default:
                serverHost = "unknown"
            }
            serverPort = Int(port.rawValue)
            
        case .service(_, _, _, _):
            // サービス形式の場合は.localドメインを使用
            serverHost = "\(serviceName).local"
            
        case .unix(path: _):
            // Unixソケットはサポートしない
            serverHost = "\(serviceName).local"
            
        case .url(_):
            // URLエンドポイントはサポートしない
            serverHost = "\(serviceName).local"
            
        case .opaque(_):
            // Opaqueエンドポイントはサポートしない
            serverHost = "\(serviceName).local"
            
        @unknown default:
            serverHost = "\(serviceName).local"
        }
        
        let serverEndpoint = "http://\(serverHost):\(serverPort)"
        
        let server = DiscoveredServer(
            name: serviceName,
            endpoint: serverEndpoint,
            type: .bonjour
        )
        
        if !discoveredServers.contains(where: { $0.endpoint == server.endpoint }) {
            discoveredServers.append(server)
            print("Bonjourサービス解決成功: \(serverEndpoint)")
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
