import Foundation
import os.log
import UIKit

/// Bonjourサービス発見機能を提供するサービス
final class BonjourService: NSObject, ObservableObject {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "BonjourService")
    private var netService: NetService?
    private let serviceType = "_reuse-backup._tcp"
    private let serviceName: String
    private let port: Int32

    @Published private(set) var isAdvertising = false
    @Published private(set) var lastError: Error?

    // MARK: - Initialization

    init(port: Int32) {
        self.port = port
        // デバイス名を使用してサービス名を生成
        let deviceName = UIDevice.current.name
        serviceName = "ReuseBackupServer-\(deviceName)"

        super.init()

        logger.info("BonjourService initialized with service name: \(serviceName), port: \(port)")
    }

    // MARK: - Public Methods

    /// Bonjourサービスの発信を開始
    func startAdvertising() {
        guard !isAdvertising else {
            logger.warning("Bonjour service is already advertising")
            return
        }

        logger.info("Starting Bonjour service advertising")

        // TXTレコードを作成
        let txtRecord = createTXTRecord()

        // NetServiceを作成
        netService = NetService(domain: "", type: serviceType, name: serviceName, port: port)
        netService?.delegate = self

        // TXTレコードを設定
        if let txtData = NetService.data(fromTXTRecord: txtRecord) {
            netService?.setTXTRecord(txtData)
        }

        // サービスを発信
        netService?.publish()

        logger.info("Bonjour service publish initiated")
    }

    /// Bonjourサービスの発信を停止
    func stopAdvertising() {
        guard isAdvertising else {
            logger.warning("Bonjour service is not advertising")
            return
        }

        logger.info("Stopping Bonjour service advertising")

        netService?.stop()
        netService = nil

        DispatchQueue.main.async {
            self.isAdvertising = false
        }

        logger.info("Bonjour service stopped")
    }

    /// TXTレコードを更新
    func updateTXTRecord(status: String = "running", capacity: String = "available") {
        guard let netService = netService, isAdvertising else {
            logger.warning("Cannot update TXT record: service not advertising")
            return
        }

        let txtRecord = createTXTRecord(status: status, capacity: capacity)

        if let txtData = NetService.data(fromTXTRecord: txtRecord) {
            netService.setTXTRecord(txtData)
            logger.info("TXT record updated with status: \(status), capacity: \(capacity)")
        } else {
            logger.error("Failed to create TXT record data")
        }
    }

    // MARK: - Private Methods

    private func createTXTRecord(status: String = "running", capacity: String = "available") -> [String: Data] {
        var txtRecord: [String: Data] = [:]

        // バージョン情報
        if let versionData = "1.0.0".data(using: .utf8) {
            txtRecord["version"] = versionData
        }

        // サーバー状態
        if let statusData = status.data(using: .utf8) {
            txtRecord["status"] = statusData
        }

        // 容量状態
        if let capacityData = capacity.data(using: .utf8) {
            txtRecord["capacity"] = capacityData
        }

        // デバイス情報
        let deviceModel = UIDevice.current.model
        if let modelData = deviceModel.data(using: .utf8) {
            txtRecord["device"] = modelData
        }

        return txtRecord
    }
}

// MARK: - NetServiceDelegate

extension BonjourService: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        logger.info("Bonjour service successfully published: \(sender.name)")

        DispatchQueue.main.async {
            self.isAdvertising = true
            self.lastError = nil
        }
    }

    func netService(_: NetService, didNotPublish errorDict: [String: NSNumber]) {
        let errorCode = errorDict[NetService.errorCode] ?? NSNumber(value: -1)
        let errorDomain = errorDict[NetService.errorDomain] ?? NSNumber(value: -1)

        logger.error("Failed to publish Bonjour service. Code: \(errorCode), Domain: \(errorDomain)")

        let error = NSError(
            domain: "BonjourServiceError",
            code: errorCode.intValue,
            userInfo: [NSLocalizedDescriptionKey: "Failed to publish Bonjour service"]
        )

        DispatchQueue.main.async {
            self.isAdvertising = false
            self.lastError = error
        }
    }

    func netServiceDidStop(_ sender: NetService) {
        logger.info("Bonjour service stopped: \(sender.name)")

        DispatchQueue.main.async {
            self.isAdvertising = false
            self.lastError = nil
        }
    }

    func netService(_: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let errorCode = errorDict[NetService.errorCode] ?? NSNumber(value: -1)
        logger.warning("Bonjour service resolution failed. Code: \(errorCode)")
    }
}
