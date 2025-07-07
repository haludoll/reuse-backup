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

            // NWParametersを設定
            let parameters = NWParameters.tcp

            // Bonjourサービスを設定
            let service = NWListener.Service(
                name: serviceName,
                type: "_reuse-backup._tcp",
                txtRecord: txtRecord
            )
            parameters.includePeerToPeer = true

            // NWListenerを作成
            nwListener = try NWListener(using: parameters, on: port)

            // Bonjourサービスを発信
            nwListener?.service = service

            // 状態変更ハンドラーを設定
            nwListener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.handleStateUpdate(state)
                }
            }

            // 新しい接続ハンドラーを設定
            nwListener?.newConnectionHandler = { [weak self] (connection: NWConnection) in
                guard let self else { return }
                self.logger.info("New connection received from Bonjour")
                // 実際のHTTPサーバーは別で処理されるため、ここでは何もしない
                connection.cancel()
            }

            // リスナーを開始
            nwListener?.start(queue: DispatchQueue.global(qos: .userInitiated))

            logger.info("Bonjour service publish initiated")

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

        return txtRecord
    }

    private func handleStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("Bonjour service is ready")
            isAdvertising = true
            lastError = nil

        case let .waiting(error):
            logger.warning("Bonjour service is waiting: \(error)")
            isAdvertising = false
            lastError = error

        case let .failed(error):
            logger.error("Bonjour service failed: \(error)")
            isAdvertising = false
            lastError = error

        case .cancelled:
            logger.info("Bonjour service cancelled")
            isAdvertising = false
            lastError = nil

        default:
            logger.info("Bonjour service state changed")
        }
    }
}
