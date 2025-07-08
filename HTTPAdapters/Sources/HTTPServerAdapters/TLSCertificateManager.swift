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
            certificateChain: certificateChain.map { .certificate($0) },
            privateKey: .privateKey(privateKey)
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
        
        // iOS環境では事前に生成した証明書を使用
        let certificateURL = certificateDirectory.appendingPathComponent(certificateFileName)
        let privateKeyURL = certificateDirectory.appendingPathComponent(privateKeyFileName)
        
        // 事前に生成した証明書データを作成
        let certificateData = generateEmbeddedCertificate()
        let privateKeyData = generateEmbeddedPrivateKey()
        
        // ファイルに保存
        do {
            try certificateData.write(to: certificateURL)
            try privateKeyData.write(to: privateKeyURL)
        } catch {
            throw CertificateError.fileSystemError("証明書ファイルの書き込みに失敗しました: \(error)")
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
    
    /// 埋め込み証明書データを生成
    /// - Returns: 証明書データ（PEM形式）
    private func generateEmbeddedCertificate() -> Data {
        // 自己署名証明書（localhost用、1年間有効）
        let certificateString = """
-----BEGIN CERTIFICATE-----
MIIDKjCCAhICCQDqKOVabNHkVjANBgkqhkiG9w0BAQsFADBXMQswCQYDVQQGEwJK
UDEOMAwGA1UECAwFVG9reW8xDjAMBgNVBAcMBVRva3lvMRQwEgYDVQQKDAtSZXVz
ZUJhY2t1cDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI1MDcwODE2NDE1N1oXDTI2
MDcwODE2NDE1N1owVzELMAkGA1UEBhMCSlAxDjAMBgNVBAgMBVRva3lvMQ4wDAYD
VQQHDAVUb2t5bzEUMBIGA1UECgwLUmV1c2VCYWNrdXAxEjAQBgNVBAMMCWxvY2Fs
aG9zdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK64ege+KyiecZnd
zrz0XM7zNbJ6U8lGfJndGSInPZX3T6G6JyCxE9dK/wScjECipFocrRHFSr3qcKF+
OXJAG3MYOjM81vbqXFrxVCZQR90xuqnyzSHzRk8132ZLt1dM1r970b8LbYSqbxKD
WtIz1I+NfEXxOIDw65AbV8ALpsGdpIgKc5Y1AvvORT5psZk7HPiKXobO/xyU5Dus
l+x/u01GDJI71ejO0ChspnjYg7tDPnflFY+qHnL1xDvFDD0NV3Hl5gkdOJHm/PQx
KyxxJHaqgwpGlQDPCo01O7JHyW1SHoHN5Uuoh/8y+vTe4E12kcc4cKrRS1BiW+o2
B8bEnvsCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAcPnCPj+0WmRAehoil7eIq6IP
tFI+axIS8MaYcLyk8M5qh+rhEoXEYnq7Hw6JG0mSf+YBg1/6R0bkXX/LxIvu76my
MSPEYiM8crkF7Qk+oXb0vWj7bp2BqtcwUsYuEgdaB1QaYGKShQDGAPE9Y337XpJU
N/8xIk9zTKle2ZNI9XzUSOzZYrzvRodaALDE951n02uy93ZfH1Vk1iqTMTH8GsMF
EqnKQ1e9hy8gYahnZpbjPH/ybiyVuPqQc33xINFM+FA0pTmMwfWGwCEHfHw+FD7A
4mIswRBh3Q2MMhjUeeugIrDFZ5m98e2qqbMgEFaPNQ4Q+ooe2qH8yMHSI7Lewg==
-----END CERTIFICATE-----
"""
        return certificateString.data(using: .utf8) ?? Data()
    }
    
    /// 埋め込み秘密鍵データを生成
    /// - Returns: 秘密鍵データ（PEM形式）
    private func generateEmbeddedPrivateKey() -> Data {
        // 対応する秘密鍵
        let privateKeyString = """
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEArrh6B74rKJ5xmd3OvPRczvM1snpTyUZ8md0ZIic9lfdPobon
ILET10r/BJyMQKKkWhytEcVKvepwoX45ckAbcxg6MzzW9upcWvFUJlBH3TG6qfLN
IfNGTzXfZku3V0zWv3vRvwtthKpvEoNa0jPUj418RfE4gPDrkBtXwAumwZ2kiApz
ljUC+85FPmmxmTsc+Ipehs7/HJTkO6yX7H+7TUYMkjvV6M7QKGymeNiDu0M+d+UV
j6oecvXEO8UMPQ1XceXmCR04keb89DErLHEkdqqDCkaVAM8KjTU7skfJbVIegc3l
S6iH/zL69N7gTXaRxzhwqtFLUGJb6jYHxsSe+wIDAQABAoIBAQCshL0BvjWRUvmq
y0gibUrikWVZCM6IdE/+AUGa5pI57Mu1TkDqV87Wi1fJbuZRwAZ2b9A4Ns25Pq7d
1uvUMxani6mUBCPiBMESjy3e8vAyqbK9sl/4gOTQu8oNkP/EdLuqsREHCbqm/z7T
Ud4wpjrhT/wAd9GqB7khPs5jc13B2EpI+mNYsksXpGO5OwT9Nh0sVjiD/JaKXMA3
Bd/y0DerrtocksrOY5HsasUbf0lFikgpdo/drzNrvdkQs8SucjJUcDmz/qCuA5wE
sKH6QZuhYeLPQNe/bhKNpg1JZrnbS7FHVUlY/RBV/QKZ/9DdRblTbZHeKliatz65
RLpjBx8pAoGBAOeMvvac+M/5grOZBLz4EWjrzPa2KITuZNMsYUOirTHdLDieaPBP
wat4cPipJikYdGVnZy4ILCv2TYIT159wC3o5w77WIiOP8RaF0g5no23KUAQnS6xx
K+PyGzcs0PbEjaNcklt/hpB7bnGv4vjp8V+IZg7oUvfKjb1lwdzsBCmPAoGBAMEr
hj3+L4NWOpOEzzPOh83rqWmH+Skc/FbINiocNV938pe3Rt72fOF3XYadG+8dep7t
ZA/raOF98iRzpp8+WkJPRy9mL8Ug5U3qkbUm/pA2aumZvj0KnaXjkfQZFYnjOlRb
M+aAnS9HbLmyCOt4loBqloeUpFlJV9b00thP/cXVAoGAZI89iADYFgp4duMnqaHa
fcSaeTLXGhQmeYe2nhcSPKufPt+dF3Cr3XorJfLf/cz/D+L+boFiHZ2UP7+6TyXr
9iMMHd8FaIhk3bE0bskXsuDAK22dccCcnRxSMX4nKmRmVuInNdGGcU0JxBns6sk+
6IxmNmczUSYItI5yyS0/CYUCgYEAreGw8ELLoCzRg5LsNRU3F7yHfhBAz6pg1vlY
EGXeAXbmb30yFWfJl+cr0A3CZGajx0WnadEdUsVdX0Sfev7UnpXgXSFd5NOstYtt
56QXR9dEO80B+s6AhCAqdJDT25AoJGEIgffKBhIEI8/HybZ9u1C2+YpquliT8lHl
LYQrypUCgYEApNBakRDCW9i1phquKk/bYZ0/ZSzy4gBuWeJnDSQEiqw84AAPudQk
g6Y0U/MzqW8IE5c8jWSfOZAyI9tphr+bR38efG/NuJkWQ2iMCoWg44eHixlCUCom
gSxW4vGrQv50xa+LBgcwwhLtC2z5F9Or4pI98AMLMn63hV9T2SXs99c=
-----END RSA PRIVATE KEY-----
"""
        return privateKeyString.data(using: .utf8) ?? Data()
    }
}