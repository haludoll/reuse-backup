import Foundation
import NIOSSL

/// TLS証明書管理クラス
/// 自己署名証明書の生成、管理、検証を行う
public final class TLSCertificateManager: Sendable {
    
    /// 証明書生成エラー
    public enum CertificateError: Error, CustomStringConvertible {
        case generationFailed(String)
        case invalidCertificate
        case certificateExpired
        case fileSystemError(String)
        
        public var description: String {
            switch self {
            case .generationFailed(let message):
                return "証明書生成に失敗しました: \(message)"
            case .invalidCertificate:
                return "無効な証明書です"
            case .certificateExpired:
                return "証明書が期限切れです"
            case .fileSystemError(let message):
                return "ファイルシステムエラー: \(message)"
            }
        }
    }
    
    /// 証明書有効期限（日数）
    private static let certificateValidityDays = 365
    
    /// 証明書保存ディレクトリ
    private let certificateDirectory: URL
    
    /// 証明書ファイル名
    private let certificateFileName = "server.crt"
    
    /// 秘密鍵ファイル名
    private let privateKeyFileName = "server.key"
    
    public init(certificateDirectory: URL? = nil) {
        // デフォルトの証明書保存ディレクトリを設定
        if let directory = certificateDirectory {
            self.certificateDirectory = directory
        } else {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.certificateDirectory = documentsPath.appendingPathComponent("TLS", isDirectory: true)
        }
    }
    
    /// TLS設定を取得
    /// 既存の証明書があれば使用し、なければ新規生成
    /// - Returns: TLSConfiguration
    /// - Throws: CertificateError
    public func getTLSConfiguration() throws -> TLSConfiguration {
        let certificateChain = try getCertificateChain()
        let privateKey = try getPrivateKey()
        
        return TLSConfiguration.makeServerConfiguration(
            certificateChain: certificateChain,
            privateKey: privateKey
        )
    }
    
    /// 証明書チェーンを取得
    /// - Returns: 証明書チェーン
    /// - Throws: CertificateError
    private func getCertificateChain() throws -> [NIOSSLCertificate] {
        let certificateURL = certificateDirectory.appendingPathComponent(certificateFileName)
        
        // 既存の証明書をチェック
        if FileManager.default.fileExists(atPath: certificateURL.path) {
            if let certificate = try? loadCertificate(from: certificateURL) {
                // 証明書の有効期限をチェック
                if isCertificateValid(certificate) {
                    return [certificate]
                } else {
                    // 期限切れの場合は新規生成
                    try removeCertificateFiles()
                }
            }
        }
        
        // 新規証明書を生成
        return try generateSelfSignedCertificate()
    }
    
    /// 秘密鍵を取得
    /// - Returns: 秘密鍵
    /// - Throws: CertificateError
    private func getPrivateKey() throws -> NIOSSLPrivateKey {
        let privateKeyURL = certificateDirectory.appendingPathComponent(privateKeyFileName)
        
        if FileManager.default.fileExists(atPath: privateKeyURL.path) {
            return try loadPrivateKey(from: privateKeyURL)
        }
        
        throw CertificateError.generationFailed("秘密鍵が見つかりません")
    }
    
    /// 自己署名証明書を生成
    /// - Returns: 証明書チェーン
    /// - Throws: CertificateError
    private func generateSelfSignedCertificate() throws -> [NIOSSLCertificate] {
        // 証明書ディレクトリを作成
        try createCertificateDirectory()
        
        // OpenSSLコマンドを使用して自己署名証明書を生成
        let certificateURL = certificateDirectory.appendingPathComponent(certificateFileName)
        let privateKeyURL = certificateDirectory.appendingPathComponent(privateKeyFileName)
        
        // 秘密鍵生成
        let keyGenResult = try executeCommand([
            "openssl", "genrsa", "-out", privateKeyURL.path, "2048"
        ])
        
        guard keyGenResult.success else {
            throw CertificateError.generationFailed("秘密鍵生成に失敗しました: \(keyGenResult.error)")
        }
        
        // 証明書生成
        let certGenResult = try executeCommand([
            "openssl", "req", "-new", "-x509", "-key", privateKeyURL.path,
            "-out", certificateURL.path, "-days", "\(Self.certificateValidityDays)",
            "-subj", "/C=JP/ST=Tokyo/L=Tokyo/O=ReuseBackup/CN=localhost"
        ])
        
        guard certGenResult.success else {
            throw CertificateError.generationFailed("証明書生成に失敗しました: \(certGenResult.error)")
        }
        
        // 生成された証明書を読み込み
        let certificate = try loadCertificate(from: certificateURL)
        return [certificate]
    }
    
    /// 証明書ファイルから証明書を読み込み
    /// - Parameter url: 証明書ファイルのURL
    /// - Returns: NIOSSLCertificate
    /// - Throws: CertificateError
    private func loadCertificate(from url: URL) throws -> NIOSSLCertificate {
        do {
            let certificateData = try Data(contentsOf: url)
            return try NIOSSLCertificate(bytes: Array(certificateData), format: .pem)
        } catch {
            throw CertificateError.generationFailed("証明書の読み込みに失敗しました: \(error)")
        }
    }
    
    /// 秘密鍵ファイルから秘密鍵を読み込み
    /// - Parameter url: 秘密鍵ファイルのURL
    /// - Returns: NIOSSLPrivateKey
    /// - Throws: CertificateError
    private func loadPrivateKey(from url: URL) throws -> NIOSSLPrivateKey {
        do {
            let keyData = try Data(contentsOf: url)
            return try NIOSSLPrivateKey(bytes: Array(keyData), format: .pem)
        } catch {
            throw CertificateError.generationFailed("秘密鍵の読み込みに失敗しました: \(error)")
        }
    }
    
    /// 証明書の有効性をチェック
    /// - Parameter certificate: チェック対象の証明書
    /// - Returns: 有効かどうか
    private func isCertificateValid(_ certificate: NIOSSLCertificate) -> Bool {
        // 簡単な有効性チェック（実際の実装では証明書の有効期限をチェック）
        // NIOSSLCertificateには直接的な有効期限チェック機能がないため、
        // 実際の実装では証明書の作成日時をファイルのタイムスタンプから判定
        let certificateURL = certificateDirectory.appendingPathComponent(certificateFileName)
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: certificateURL.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let expirationDate = creationDate.addingTimeInterval(TimeInterval(Self.certificateValidityDays * 24 * 60 * 60))
                return Date() < expirationDate
            }
        } catch {
            return false
        }
        
        return false
    }
    
    /// 証明書ディレクトリを作成
    /// - Throws: CertificateError
    private func createCertificateDirectory() throws {
        do {
            try FileManager.default.createDirectory(at: certificateDirectory, withIntermediateDirectories: true)
        } catch {
            throw CertificateError.fileSystemError("証明書ディレクトリの作成に失敗しました: \(error)")
        }
    }
    
    /// 証明書ファイルを削除
    /// - Throws: CertificateError
    private func removeCertificateFiles() throws {
        let certificateURL = certificateDirectory.appendingPathComponent(certificateFileName)
        let privateKeyURL = certificateDirectory.appendingPathComponent(privateKeyFileName)
        
        try? FileManager.default.removeItem(at: certificateURL)
        try? FileManager.default.removeItem(at: privateKeyURL)
    }
    
    /// コマンドを実行
    /// - Parameter arguments: コマンド引数
    /// - Returns: 実行結果
    /// - Throws: CertificateError
    private func executeCommand(_ arguments: [String]) throws -> (success: Bool, error: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: data, encoding: .utf8) ?? ""
            
            return (process.terminationStatus == 0, errorOutput)
        } catch {
            throw CertificateError.generationFailed("コマンド実行に失敗しました: \(error)")
        }
    }
}