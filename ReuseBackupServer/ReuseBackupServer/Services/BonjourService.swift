import dnssd
import Foundation
import Network
import os.log
import UIKit

/// Network frameworkを使用したモダンなBonjourサービス発見機能を提供するサービス
@available(iOS 13.0, *)
final class BonjourService: ObservableObject {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "BonjourService")
    private var nwListener: NWListener?
    private let serviceName: String
    private let port: NWEndpoint.Port

    @Published private(set) var isAdvertising = false
    @Published private(set) var lastError: Error?

    /// ユーザーフレンドリーなエラーメッセージ
    var userFriendlyErrorMessage: String? {
        guard let error = lastError else { return nil }

        switch error {
        case NWError.dns(DNSServiceErrorType(kDNSServiceErr_NoAuth)):
            return "ローカルネットワークへのアクセス許可が必要です。設定 > プライバシーとセキュリティ > ローカルネットワーク でこのアプリを有効にしてください。"
        default:
            return "ネットワークエラーが発生しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Initialization

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(8080)

        // デバイス名を使用してサービス名を生成
        let deviceName = UIDevice.current.name
        serviceName = "ReuseBackupServer-\(deviceName)"

        let logServiceName = serviceName
        logger.info("BonjourService initialized with service name: \(logServiceName), port: \(port)")
    }

    // MARK: - Public Methods

    /// Bonjourサービスの発信を開始
    func startAdvertising() {
        guard !isAdvertising else {
            logger.warning("Bonjour service is already advertising")
            return
        }

        logger.info("Starting Bonjour service advertising")

        do {
            // TXTレコードを作成
            let txtRecord = createTXTRecord()
            logger.info("TXTレコード内容確認: \(String(describing: txtRecord))")

            // NWParametersを設定
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            // Bonjourサービスを設定
            let service = NWListener.Service(
                name: serviceName,
                type: "_reuse-backup._tcp",
                domain: nil,
                txtRecord: txtRecord
            )
            logger.info("NWListener.Service作成: name=\(self.serviceName), type=_reuse-backup._tcp")

            // 自動ポート割り当てを使用してNWListenerを作成
            let bonjourPort = NWEndpoint.Port(rawValue: 0) ?? NWEndpoint.Port(8080)
            nwListener = try NWListener(using: parameters, on: bonjourPort)
            logger.info("NWListener作成完了: port=\(String(describing: bonjourPort))")

            // Bonjourサービスを発信
            nwListener?.service = service
            logger.info("NWListener.serviceにサービス設定完了")

            // 状態変更ハンドラーを設定
            nwListener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.handleStateUpdate(state)
                }
            }

            // 新しい接続は即座にキャンセル（HTTPサーバーが別で処理）
            nwListener?.newConnectionHandler = { connection in
                // 接続を即座に拒否（HTTPサーバーが別で処理）
                connection.cancel()
            }

            // リスナーを開始
            nwListener?.start(queue: DispatchQueue.global(qos: .userInitiated))
            logger.info("NWListener開始完了")

        } catch {
            logger.error("Failed to start Bonjour service: \(error)")
            DispatchQueue.main.async {
                self.lastError = error
            }
        }
    }

    /// Bonjourサービスの発信を停止
    func stopAdvertising() {
        guard let listener = nwListener else {
            logger.warning("Bonjour service is not running")
            return
        }

        logger.info("Stopping Bonjour service advertising")

        listener.cancel()
        nwListener = nil

        DispatchQueue.main.async {
            self.isAdvertising = false
        }

        logger.info("Bonjour service stopped")
    }

    /// TXTレコードを更新
    func updateTXTRecord(status: String = "running", capacity: String = "available") {
        guard let listener = nwListener, isAdvertising else {
            logger.warning("Cannot update TXT record: service not advertising")
            return
        }

        let txtRecord = createTXTRecord(status: status, capacity: capacity)

        // 新しいサービス情報でリスナーを更新
        let service = NWListener.Service(
            name: serviceName,
            type: "_reuse-backup._tcp",
            domain: nil,
            txtRecord: txtRecord
        )

        listener.service = service
        logger.info("TXT record updated with status: \(status), capacity: \(capacity)")
    }

    // MARK: - Private Methods

    private func createTXTRecord(status: String = "running", capacity: String = "available") -> NWTXTRecord {
        var txtRecord = NWTXTRecord()

        // バージョン情報
        txtRecord["version"] = "1.0.0"

        // サーバー状態
        txtRecord["status"] = status

        // 容量状態
        txtRecord["capacity"] = capacity

        // デバイス情報
        txtRecord["device"] = UIDevice.current.model

        // ポート情報（クライアントが接続するため）
        let portString = String(port.rawValue)
        txtRecord["port"] = portString

        logger.info("TXTレコード作成: version=1.0.0, status=\(status), capacity=\(capacity), device=\(UIDevice.current.model), port=\(portString)")

        return txtRecord
    }

    private func handleStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("Bonjour service is ready")
            if let actualPort = nwListener?.port {
                logger.info("Bonjourサービス開始成功: 実際のポート=\(String(describing: actualPort))")
            }
            if let service = nwListener?.service {
                logger.info("発信中のサービス: \(String(describing: service))")
            }
            isAdvertising = true
            lastError = nil

        case let .waiting(error):
            switch error {
            case NWError.dns(DNSServiceErrorType(kDNSServiceErr_NoAuth)):
                logger.warning("Bonjour service waiting: Local network permission required. Please check app permissions in Settings.")
            default:
                logger.warning("Bonjour service is waiting: \(error)")
            }
            isAdvertising = false
            lastError = error

        case let .failed(error):
            switch error {
            case NWError.dns(DNSServiceErrorType(kDNSServiceErr_NoAuth)):
                logger.error("Bonjour service failed: No authorization for local network access. User needs to grant permission in Settings.")
            default:
                logger.error("Bonjour service failed: \(error)")
            }
            isAdvertising = false
            lastError = error

        case .cancelled:
            logger.info("Bonjour service cancelled")
            isAdvertising = false
            lastError = nil

        default:
            logger.info("Bonjour service state changed to: \(String(describing: state))")
        }
    }
}
