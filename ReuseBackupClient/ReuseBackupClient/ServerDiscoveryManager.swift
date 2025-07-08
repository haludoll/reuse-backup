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
            endpoint = "https://\(trimmedAddress)"
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
                case .ready,
                     .cancelled,
                     .waiting:
                    break
                case .failed(let error):
                    self?.errorMessage = "Bonjour検索エラー: \(error.localizedDescription)"
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
                        
                        self.addDiscoveredServer(name: name, type: type, domain: domain, txtRecord: txtRecord, ipAddress: nil)
                    }
                }
            }
        }
        
        browser?.start(queue: .main)
    }
    
    private func addDiscoveredServer(name: String, type: String, domain: String, txtRecord: NWTXTRecord?, ipAddress: String? = nil) {
        // TXTレコードからHTTPSポート情報を取得
        var httpsPort = 8443 // デフォルト値
        
        // TXTレコードからポート情報を取得
        if let txtRecord = txtRecord {
            for (key, value) in txtRecord {
                if key == "port" {
                    switch value {
                    case .data(let data):
                        if let portString = String(data: data, encoding: .utf8), let port = Int(portString) {
                            httpsPort = port
                        }
                    case .string(let portString):
                        if let port = Int(portString) {
                            httpsPort = port
                        }
                    case .none,
                         .empty:
                        break
                    @unknown default:
                        fatalError()
                    }
                }
            }
        }
        
        // IPアドレスが取得できている場合は、フォールバック用として追加
        if let ipAddress = ipAddress {
            let ipEndpoint = "https://\(ipAddress):\(httpsPort)"
            
            let ipServer = DiscoveredServer(
                name: name,
                endpoint: ipEndpoint,
                type: .bonjour
            )
            
            if !discoveredServers.contains(where: { $0.endpoint == ipServer.endpoint }) {
                discoveredServers.append(ipServer)
            }
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
            onResolved: { [weak self] txtRecord, ipAddress in
                DispatchQueue.main.async {
                    self?.addDiscoveredServer(name: name, type: type, domain: domain, txtRecord: txtRecord, ipAddress: ipAddress)
                    self?.cleanupNetServiceResolver(netService)
                }
            },
            onFailed: { [weak self] error in
                DispatchQueue.main.async {
                    self?.addDiscoveredServer(name: name, type: type, domain: domain, txtRecord: nil, ipAddress: nil)
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
                self.addDiscoveredServer(name: name, type: type, domain: domain, txtRecord: nil, ipAddress: nil)
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
    
    private func addLocalHostServer() {
        let server = DiscoveredServer(
            name: "ローカルサーバー",
            endpoint: "https://localhost:8443",
            type: .localhost
        )
        
        discoveredServers.append(server)
    }
}

class NetServiceTXTResolver: NSObject, NetServiceDelegate {
    let serviceName: String  // publicアクセスに変更
    private let serviceType: String
    private let serviceDomain: String
    private let onResolved: (NWTXTRecord?, String?) -> Void
    private let onFailed: (Error) -> Void
    
    init(serviceName: String, serviceType: String, serviceDomain: String, 
         onResolved: @escaping (NWTXTRecord?, String?) -> Void, 
         onFailed: @escaping (Error) -> Void) {
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.serviceDomain = serviceDomain
        self.onResolved = onResolved
        self.onFailed = onFailed
        super.init()
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        
        // 最初のIPアドレスを取得
        var ipAddress: String? = nil
        if let addresses = sender.addresses, !addresses.isEmpty {
            let addressData = addresses[0]
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addressData.withUnsafeBytes { $0.bindMemory(to: sockaddr.self).baseAddress },
                socklen_t(addressData.count),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            
            if result == 0 {
                ipAddress = String(cString: hostname)
            }
        }
        
        // TXTレコードデータを取得
        if let txtData = sender.txtRecordData() {
            // NSDataからNWTXTRecordに変換
            let txtRecord = convertToNWTXTRecord(from: txtData)
            onResolved(txtRecord, ipAddress)
        } else {
            onResolved(nil, ipAddress)
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
