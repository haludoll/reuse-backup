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
    private var netServiceResolvers: [NetService] = []
    private var netServiceTXTResolvers: [NetServiceTXTResolver] = []
    
    func startDiscovery() {
        isSearching = true
        discoveredServers.removeAll()
        
        // Bonjourサービス検索を開始
        startBonjourDiscovery()
        
        // ローカルホストも追加
        addLocalHostServer()
        
        // 15秒後に検索終了（NetServiceの解決時間を確保）
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            stopDiscovery()
        }
    }
    
    func stopDiscovery() {
        isSearching = false
        browser?.cancel()
        browser = nil
        
        // NetServiceResolverもクリーンアップ
        for netService in netServiceResolvers {
            netService.stop()
        }
        netServiceResolvers.removeAll()
        netServiceTXTResolvers.removeAll()
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
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // TXTレコード取得のためのボンジュールブラウザ記述子を作成
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_reuse-backup._tcp", domain: nil)
        browser = NWBrowser(for: descriptor, using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    break
                case .failed(let error):
                    self?.errorMessage = "Bonjour検索エラー: \(error.localizedDescription)"
                case .cancelled:
                    break
                case .waiting(_):
                    break
                default:
                    break
                }
            }
        }
        browser?.browseResultsChangedHandler = { results, changes in
            DispatchQueue.main.async {
                // サービス解決処理
                for result in results {
                    if case .service(let name, let type, let domain, _) = result.endpoint {
                        // NWBrowser.Resultのメタデータから情報を取得
                        let metadata = result.metadata
                        
                        var txtRecord: NWTXTRecord? = nil
                        switch metadata {
                        case .bonjour(let bonjourMetadata):
                            txtRecord = bonjourMetadata
                        case .none:
                            // メタデータが取得できない場合はサービス解決を実行
                            self.resolveServiceForTXTRecord(name: name, type: type, domain: domain)
                            continue
                        @unknown default:
                            break
                        }
                        
                        self.addDiscoveredServer(name: name, type: type, domain: domain, txtRecord: txtRecord)
                    }
                }
            }
        }
        
        browser?.start(queue: .main)
    }
    
    private func addDiscoveredServer(name: String, type: String, domain: String, txtRecord: NWTXTRecord?) {
        // TXTレコードからHTTPポート情報を取得
        var httpPort = 8080 // デフォルト値
        
        // デバッグ: TXTレコードの内容をログ出力
        if let txtRecord = txtRecord {
            print("🔍 [DEBUG] TXTレコード取得成功: \(txtRecord.count)個のエントリ")
            for (key, value) in txtRecord {
                print("🔍 [DEBUG] TXTエントリ: \(key) = \(value)")
                if key == "port" {
                    switch value {
                    case .data(let data):
                        if let portString = String(data: data, encoding: .utf8), let port = Int(portString) {
                            httpPort = port
                            print("🔍 [DEBUG] ポート解析成功: \(httpPort)")
                        }
                    case .string(let portString):
                        if let port = Int(portString) {
                            httpPort = port
                            print("🔍 [DEBUG] ポート解析成功: \(httpPort)")
                        }
                    case .none,
                         .empty:
                        break
                    @unknown default:
                        fatalError()
                    }
                }
            }
        } else {
            print("🔍 [DEBUG] TXTレコードなし - デフォルトポート8080を使用")
        }
        
        // Bonjourサービス名からホスト名を構築
        let serverHost = "\(name).local"
        let serverEndpoint = "http://\(serverHost):\(httpPort)"
        
        // デバッグ: 接続情報をログ出力
        print("🔍 [DEBUG] 接続先: \(serverEndpoint)")
        print("🔍 [DEBUG] サービス名: \(name), ポート: \(httpPort)")
        
        let server = DiscoveredServer(
            name: name,
            endpoint: serverEndpoint,
            type: .bonjour
        )
        
        if !discoveredServers.contains(where: { $0.endpoint == server.endpoint }) {
            discoveredServers.append(server)
        }
    }
    
    private func resolveServiceForTXTRecord(name: String, type: String, domain: String) {
        // NetServiceを使ってTXTレコードを解決
        // domainが空の場合はローカルドメインを明示的に指定
        let resolvedDomain = domain.isEmpty ? "local." : domain
        let netService = NetService(domain: resolvedDomain, type: type, name: name)
        netServiceResolvers.append(netService)
        
        // NetServiceDelegateを設定して解決結果を処理
        let resolver = NetServiceTXTResolver(
            serviceName: name,
            serviceType: type,
            serviceDomain: domain,
            onResolved: { [weak self] txtRecord in
                DispatchQueue.main.async {
                    self?.addDiscoveredServer(name: name, type: type, domain: domain, txtRecord: txtRecord)
                    self?.cleanupNetServiceResolver(netService)
                }
            },
            onFailed: { [weak self] error in
                DispatchQueue.main.async {
                    self?.addDiscoveredServer(name: name, type: type, domain: domain, txtRecord: nil)
                    self?.cleanupNetServiceResolver(netService)
                }
            }
        )
        
        // resolverインスタンスを保持（delegate参照を維持するため）
        netServiceTXTResolvers.append(resolver)
        
        // 解決を開始
        netService.delegate = resolver
        netService.resolve(withTimeout: 5.0)
        
        // 7秒でタイムアウト（Discovery全体のタイムアウトより前に実行）
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            if self.netServiceResolvers.contains(where: { $0 === netService }) {
                self.addDiscoveredServer(name: name, type: type, domain: domain, txtRecord: nil)
                self.cleanupNetServiceResolver(netService)
            }
        }
    }
    
    private func cleanupNetServiceResolver(_ netService: NetService) {
        netService.stop()
        netServiceResolvers.removeAll { $0 === netService }
        
        // 対応するresolverも削除
        if let serviceName = netService.name.isEmpty ? nil : netService.name {
            netServiceTXTResolvers.removeAll { $0.serviceName == serviceName }
        }
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
                    
                case .failed(_):
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

class NetServiceTXTResolver: NSObject, NetServiceDelegate {
    let serviceName: String  // publicアクセスに変更
    private let serviceType: String
    private let serviceDomain: String
    private let onResolved: (NWTXTRecord?) -> Void
    private let onFailed: (Error) -> Void
    
    init(serviceName: String, serviceType: String, serviceDomain: String, 
         onResolved: @escaping (NWTXTRecord?) -> Void, 
         onFailed: @escaping (Error) -> Void) {
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.serviceDomain = serviceDomain
        self.onResolved = onResolved
        self.onFailed = onFailed
        super.init()
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        // TXTレコードデータを取得
        if let txtData = sender.txtRecordData() {
            // NSDataからNWTXTRecordに変換
            let txtRecord = convertToNWTXTRecord(from: txtData)
            onResolved(txtRecord)
        } else {
            onResolved(nil)
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        let error = NSError(domain: "NetServiceError", code: -1, userInfo: errorDict as [String: Any])
        onFailed(error)
    }
    
    func netServiceWillResolve(_ sender: NetService) {
        // NetService解決開始
    }
    
    func netServiceDidStop(_ sender: NetService) {
        // NetService停止
    }
    
    private func convertToNWTXTRecord(from data: Data) -> NWTXTRecord? {
        // NetService.dictionary(fromTXTRecord:)を使ってTXTレコードを解析
        let txtDict = NetService.dictionary(fromTXTRecord: data)
        
        var nwTxtRecord = NWTXTRecord()
        for (key, value) in txtDict {
            if let keyString = key as String?, let dataValue = value as Data? {
                if let stringValue = String(data: dataValue, encoding: .utf8) {
                    nwTxtRecord[keyString] = stringValue
                } else {
                    // バイナリデータの場合は可能な範囲で文字列化して設定
                    let binaryString = dataValue.map { String(format: "%02x", $0) }.joined()
                    nwTxtRecord[keyString] = binaryString
                }
            }
        }
        
        return nwTxtRecord.isEmpty ? nil : nwTxtRecord
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
        }
        
        isChecking = false
    }
}
