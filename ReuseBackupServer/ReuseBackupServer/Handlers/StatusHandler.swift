import APISharedModels
import FlyingFox
import Foundation
import SystemConfiguration

/// ステータスエンドポイント（/api/status）のハンドラー
final class StatusHandler: HTTPHandler {
    private let port: UInt16
    private let startTime: Date

    init(port: UInt16, startTime: Date) {
        self.port = port
        self.startTime = startTime
    }

    func handleRequest(_: HTTPRequest) async throws -> HTTPResponse {
        do {
            let uptime = Date().timeIntervalSince(startTime)
            let healthCheck = performHealthCheck()

            if healthCheck.isHealthy {
                let statusResponse = Components.Schemas.ServerStatus(
                    status: .running,
                    uptime: Int(uptime),
                    version: "1.0.0",
                    serverTime: Date()
                )

                let jsonData = try JSONEncoder().encode(statusResponse)
                return HTTPResponse(
                    statusCode: .ok,
                    headers: [.contentType: "application/json"],
                    body: jsonData
                )
            } else {
                // サーバーに問題がある場合
                let statusResponse = Components.Schemas.ServerStatus(
                    status: .running, // OpenAPIスキーマでは"running"のみ対応
                    uptime: Int(uptime),
                    version: "1.0.0",
                    serverTime: Date()
                )

                let jsonData = try JSONEncoder().encode(statusResponse)
                return HTTPResponse(
                    statusCode: .ok, // ステータス情報は返せるので200
                    headers: [.contentType: "application/json"],
                    body: jsonData
                )
            }
        } catch {
            // 予期しないエラー
            let errorResponse = Components.Schemas.ErrorResponse(
                status: .error,
                error: "Unable to retrieve server status",
                received: false
            )

            let jsonData = try JSONEncoder().encode(errorResponse)
            return HTTPResponse(
                statusCode: .internalServerError,
                headers: [.contentType: "application/json"],
                body: jsonData
            )
        }
    }

    private func performHealthCheck() -> (isHealthy: Bool, issues: [String]) {
        var issues: [String] = []

        // メモリ使用量チェック
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let memoryResult = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if memoryResult == KERN_SUCCESS {
            let memoryUsage = Double(memoryInfo.resident_size) / (1024 * 1024 * 1024) // GB
            if memoryUsage > 2.0 { // 2GB以上使用時は警告
                issues.append("High memory usage: \(String(format: "%.2f", memoryUsage))GB")
            }
        }

        // ディスク容量チェック
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableCapacity = resourceValues.volumeAvailableCapacity {
                let availableGB = Double(availableCapacity) / (1024 * 1024 * 1024)
                if availableGB < 1.0 { // 1GB未満の場合は警告
                    issues.append("Low disk space: \(String(format: "%.2f", availableGB))GB remaining")
                }
            }
        } catch {
            issues.append("Unable to check disk space")
        }

        // ネットワーク接続状態チェック（簡易）
        let reachability = SCNetworkReachabilityCreateWithName(nil, "localhost")
        var flags = SCNetworkReachabilityFlags()
        if let reachability = reachability,
           SCNetworkReachabilityGetFlags(reachability, &flags)
        {
            if !flags.contains(.reachable) {
                issues.append("Network connectivity issue detected")
            }
        } else {
            issues.append("Unable to check network connectivity")
        }

        return (isHealthy: issues.isEmpty, issues: issues)
    }
}
