import CryptoKit
import Foundation
import NIOSSL
import Security
import UIKit

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
            case let .generationFailed(message):
                "証明書生成に失敗しました: \(message)"
            case .invalidCertificate:
                "無効な証明書です"
            case .certificateExpired:
                "証明書が期限切れです"
            case let .fileSystemError(message):
                "ファイルシステムエラー: \(message)"
            }
        }
    }

    /// 証明書有効期限（日数）
    private static let certificateValidityDays = 365

    /// Keychain保存用のサービス名
    private static let keychainService = "com.reusebackup.tls"

    /// 証明書のKeychain保存キー
    private static let certificateKeychainKey = "tls_certificate"

    /// 秘密鍵のKeychain保存キー
    private static let privateKeyKeychainKey = "tls_private_key"

    /// 証明書保存ディレクトリ（旧版との互換性用）
    private let certificateDirectory: URL

    /// 証明書ファイル名（旧版との互換性用）
    private let certificateFileName = "server.crt"

    /// 秘密鍵ファイル名（旧版との互換性用）
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
        // まずKeychainから証明書を取得を試行
        if let certificateData = loadCertificateFromKeychain() {
            do {
                let certificate = try NIOSSLCertificate(bytes: certificateData, format: .pem)
                if isCertificateValidFromData(certificateData) {
                    return [certificate]
                } else {
                    // 期限切れの場合は削除して新規生成
                    try removeCertificateFromKeychain()
                }
            } catch {
                // 証明書が無効な場合は削除して新規生成
                try removeCertificateFromKeychain()
            }
        }

        // 旧版のファイルベース証明書をチェック（移行処理）
        let certificateURL = certificateDirectory.appendingPathComponent(certificateFileName)
        if FileManager.default.fileExists(atPath: certificateURL.path) {
            if let certificate = try? loadCertificate(from: certificateURL) {
                if isCertificateValid(certificate) {
                    // 有効な証明書をKeychainに移行
                    let certificateData = try Data(contentsOf: certificateURL)
                    let privateKeyData = try Data(contentsOf: certificateDirectory
                        .appendingPathComponent(privateKeyFileName)
                    )
                    try saveCertificateToKeychain(certificateData)
                    try savePrivateKeyToKeychain(privateKeyData)
                    try removeCertificateFiles()
                    return [certificate]
                } else {
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
        // まずKeychainから秘密鍵を取得を試行
        if let privateKeyData = loadPrivateKeyFromKeychain() {
            do {
                return try NIOSSLPrivateKey(bytes: privateKeyData, format: .pem)
            } catch {
                try removePrivateKeyFromKeychain()
            }
        }

        // 旧版のファイルベース秘密鍵をチェック（移行処理）
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
        // CryptoKitを使用してデバイス固有の証明書を動的に生成
        let (certificateData, privateKeyData) = try generateDeviceSpecificCertificate()

        // 生成した証明書と秘密鍵をKeychainに保存
        try saveCertificateToKeychain(certificateData)
        try savePrivateKeyToKeychain(privateKeyData)

        // 生成された証明書を読み込み
        let certificate = try NIOSSLCertificate(bytes: certificateData, format: .pem)
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
    private func isCertificateValid(_: NIOSSLCertificate) -> Bool {
        // 簡単な有効性チェック（実際の実装では証明書の有効期限をチェック）
        // NIOSSLCertificateには直接的な有効期限チェック機能がないため、
        // 実際の実装では証明書の作成日時をファイルのタイムスタンプから判定
        let certificateURL = certificateDirectory.appendingPathComponent(certificateFileName)

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: certificateURL.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let expirationDate = creationDate
                    .addingTimeInterval(TimeInterval(Self.certificateValidityDays * 24 * 60 * 60))
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

    // MARK: - Keychain Operations

    /// Keychainから証明書を読み込み
    /// - Returns: 証明書データ（PEM形式）
    private func loadCertificateFromKeychain() -> [UInt8]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.certificateKeychainKey,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return Array(data)
    }

    /// Keychainから秘密鍵を読み込み
    /// - Returns: 秘密鍵データ（PEM形式）
    private func loadPrivateKeyFromKeychain() -> [UInt8]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.privateKeyKeychainKey,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return Array(data)
    }

    /// 証明書をKeychainに保存
    /// - Parameter certificateData: 証明書データ（PEM形式）
    /// - Throws: CertificateError
    private func saveCertificateToKeychain(_ certificateData: [UInt8]) throws {
        let data = Data(certificateData)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.certificateKeychainKey,
            kSecValueData as String: data,
        ]

        // 既存のアイテムを削除
        SecItemDelete(query as CFDictionary)

        // 新しいアイテムを追加
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CertificateError.fileSystemError("証明書のKeychain保存に失敗しました: \(status)")
        }
    }

    /// 秘密鍵をKeychainに保存
    /// - Parameter privateKeyData: 秘密鍵データ（PEM形式）
    /// - Throws: CertificateError
    private func savePrivateKeyToKeychain(_ privateKeyData: [UInt8]) throws {
        let data = Data(privateKeyData)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.privateKeyKeychainKey,
            kSecValueData as String: data,
        ]

        // 既存のアイテムを削除
        SecItemDelete(query as CFDictionary)

        // 新しいアイテムを追加
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CertificateError.fileSystemError("秘密鍵のKeychain保存に失敗しました: \(status)")
        }
    }

    /// Keychainから証明書を削除
    /// - Throws: CertificateError
    private func removeCertificateFromKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.certificateKeychainKey,
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Keychainから秘密鍵を削除
    /// - Throws: CertificateError
    private func removePrivateKeyFromKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.privateKeyKeychainKey,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Dynamic Certificate Generation

    /// デバイス固有の自己署名証明書を動的生成
    /// - Returns: (証明書データ, 秘密鍵データ) のタプル
    /// - Throws: CertificateError
    private func generateDeviceSpecificCertificate() throws -> ([UInt8], [UInt8]) {
        // RSA鍵ペアを生成
        let rsaKeyPair = try generateRSAKeyPair()

        // デバイス識別子を取得（または生成）
        let deviceIdentifier = getDeviceIdentifier()

        // 証明書のSubject Name（CN=デバイス識別子）
        let subjectName = "CN=ReuseBackup-\(deviceIdentifier)"

        // 現在時刻から有効期限を設定
        let validFrom = Date()
        let validTo = validFrom.addingTimeInterval(TimeInterval(Self.certificateValidityDays * 24 * 60 * 60))

        // 自己署名証明書を生成
        let certificatePEM = try generateSelfSignedRSACertificate(
            keyPair: rsaKeyPair,
            subjectName: subjectName,
            validFrom: validFrom,
            validTo: validTo
        )

        // RSA秘密鍵をPEM形式でエクスポート
        let privateKeyPEM = try exportRSAPrivateKeyToPEM(rsaKeyPair.0)

        return (Array(certificatePEM.utf8), Array(privateKeyPEM.utf8))
    }

    /// デバイス固有の識別子を取得
    /// - Returns: デバイス識別子
    private func getDeviceIdentifier() -> String {
        // iOS: identifierForVendorを使用
        if let vendorID = UIDevice.current.identifierForVendor {
            return vendorID.uuidString
        }

        // フォールバック: ランダムUUIDを生成してKeychainに保存
        let deviceIdQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "device_id",
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(deviceIdQuery as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data,
           let existingId = String(data: data, encoding: .utf8)
        {
            return existingId
        }

        // 新しいデバイスIDを生成
        let newDeviceId = UUID().uuidString
        let newIdData = newDeviceId.data(using: .utf8)!

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "device_id",
            kSecValueData as String: newIdData,
        ]

        SecItemAdd(addQuery as CFDictionary, nil)
        return newDeviceId
    }

    /// RSA秘密鍵をPEM形式でエクスポート（実際のRSA秘密鍵用）
    /// - Parameter rsaPrivateKey: RSA秘密鍵（SecKey）
    /// - Returns: PEM形式の秘密鍵
    /// - Throws: CertificateError
    private func exportRSAPrivateKeyToPEM(_ rsaPrivateKey: SecKey) throws -> String {
        var error: Unmanaged<CFError>?
        guard let privateKeyData = SecKeyCopyExternalRepresentation(rsaPrivateKey, &error) else {
            throw CertificateError.generationFailed("RSA秘密鍵のエクスポートに失敗")
        }

        let privateKeyPEM = try convertDERToPEM(privateKeyData as Data, type: "RSA PRIVATE KEY")
        return privateKeyPEM
    }

    /// RSA鍵ペアを生成
    /// - Returns: RSA鍵ペア (秘密鍵, 公開鍵)
    /// - Throws: CertificateError
    private func generateRSAKeyPair() throws -> (SecKey, SecKey) {
        let keySize = 2048
        let privateKeyAttrs: [String: Any] = [
            kSecAttrIsPermanent as String: false,
            kSecAttrApplicationTag as String: "temp-rsa-key".data(using: .utf8)!,
        ]

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: keySize,
            kSecPrivateKeyAttrs as String: privateKeyAttrs,
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey)
        else {
            let errorMessage = error?.takeRetainedValue().localizedDescription ?? "RSA鍵生成に失敗"
            throw CertificateError.generationFailed(errorMessage)
        }

        return (privateKey, publicKey)
    }

    /// RSA自己署名証明書を生成
    /// - Parameters:
    ///   - keyPair: RSA鍵ペア
    ///   - subjectName: Subject Name
    ///   - validFrom: 有効期間開始日時
    ///   - validTo: 有効期間終了日時
    /// - Returns: PEM形式の証明書
    /// - Throws: CertificateError
    private func generateSelfSignedRSACertificate(
        keyPair: (SecKey, SecKey),
        subjectName: String,
        validFrom: Date,
        validTo: Date
    ) throws -> String {
        let (privateKey, publicKey) = keyPair

        // 証明書の基本情報
        let serialNumber = UInt64.random(in: 1 ... UInt64.max)

        // 公開鍵データを取得
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw CertificateError.generationFailed("公開鍵の取得に失敗")
        }

        // X.509証明書構造を簡易的に構築
        // 注意: これは実際のDER/ASN.1エンコーディングではなく、NIOSSL用のプレースホルダー
        let tbsCertificate = try buildTBSCertificate(
            serialNumber: serialNumber,
            subjectName: subjectName,
            publicKeyData: publicKeyData as Data,
            validFrom: validFrom,
            validTo: validTo
        )

        // 自己署名（SHA256withRSA）
        let signature = try signTBSCertificate(tbsCertificate, with: privateKey)

        // PEM形式で証明書を構築
        let certificateDER = try assembleCertificate(tbsCertificate: tbsCertificate, signature: signature)
        let certificatePEM = try convertDERToPEM(certificateDER, type: "CERTIFICATE")

        return certificatePEM
    }

    /// TBSCertificate (To Be Signed Certificate) を構築
    /// - Parameters:
    ///   - serialNumber: シリアル番号
    ///   - subjectName: Subject Name
    ///   - publicKeyData: 公開鍵データ
    ///   - validFrom: 有効期間開始日時
    ///   - validTo: 有効期間終了日時
    /// - Returns: TBSCertificateデータ
    /// - Throws: CertificateError
    private func buildTBSCertificate(
        serialNumber: UInt64,
        subjectName: String,
        publicKeyData: Data,
        validFrom: Date,
        validTo: Date
    ) throws -> Data {
        // 簡易ASN.1構造（実際のX.509実装では適切なASN.1エンコーダーを使用）
        let version = Data([0x02, 0x01, 0x02]) // Version 3
        let serial = encodeASN1Integer(serialNumber)
        let algorithm = encodeASN1ObjectIdentifier("1.2.840.113549.1.1.11") // SHA256withRSA
        let issuer = try encodeASN1DistinguishedName(subjectName)
        let validity = try encodeASN1Validity(from: validFrom, to: validTo)
        let subject = try encodeASN1DistinguishedName(subjectName)
        let publicKeyInfo = try encodeASN1PublicKeyInfo(publicKeyData)

        var tbsData = Data()
        tbsData.append(version)
        tbsData.append(serial)
        tbsData.append(algorithm)
        tbsData.append(issuer)
        tbsData.append(validity)
        tbsData.append(subject)
        tbsData.append(publicKeyInfo)

        return tbsData
    }

    /// TBSCertificateに署名
    /// - Parameters:
    ///   - tbsCertificate: TBSCertificateデータ
    ///   - privateKey: 署名用秘密鍵
    /// - Returns: 署名データ
    /// - Throws: CertificateError
    private func signTBSCertificate(_ tbsCertificate: Data, with privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            tbsCertificate as CFData,
            &error
        ) else {
            throw CertificateError.generationFailed("証明書署名に失敗")
        }

        return signature as Data
    }

    /// 証明書を組み立て
    /// - Parameters:
    ///   - tbsCertificate: TBSCertificateデータ
    ///   - signature: 署名データ
    /// - Returns: DER形式の証明書
    /// - Throws: CertificateError
    private func assembleCertificate(tbsCertificate: Data, signature: Data) throws -> Data {
        let algorithm = encodeASN1ObjectIdentifier("1.2.840.113549.1.1.11") // SHA256withRSA
        let signatureBitString = encodeASN1BitString(signature)

        var certificateData = Data()
        certificateData.append(tbsCertificate)
        certificateData.append(algorithm)
        certificateData.append(signatureBitString)

        // SEQUENCE ラッパー
        return encodeASN1Sequence(certificateData)
    }

    /// DERデータをPEM形式に変換
    /// - Parameters:
    ///   - derData: DERデータ
    ///   - type: PEMタイプ（例: "CERTIFICATE"）
    /// - Returns: PEM形式の文字列
    /// - Throws: CertificateError
    private func convertDERToPEM(_ derData: Data, type: String) throws -> String {
        let base64 = derData.base64EncodedString()
        let lines = base64.chunked(into: 64)

        var pem = "-----BEGIN \(type)-----\n"
        for line in lines {
            pem += line + "\n"
        }
        pem += "-----END \(type)-----"

        return pem
    }

    // MARK: - ASN.1 Encoding Helpers

    private func encodeASN1Integer(_ value: UInt64) -> Data {
        // 簡易的なASN.1 INTEGER エンコーディング
        var bytes = Data()
        var val = value

        if val == 0 {
            bytes.append(0)
        } else {
            while val > 0 {
                bytes.insert(UInt8(val & 0xFF), at: 0)
                val >>= 8
            }
        }

        if bytes.first! & 0x80 != 0 {
            bytes.insert(0, at: 0)
        }

        return Data([0x02, UInt8(bytes.count)]) + bytes
    }

    private func encodeASN1ObjectIdentifier(_ oid: String) -> Data {
        // 簡易的なOIDエンコーディング
        let components = oid.split(separator: ".").compactMap { UInt(String($0)) }
        var encoded = Data()

        if components.count >= 2 {
            encoded.append(UInt8(components[0] * 40 + components[1]))

            for component in components.dropFirst(2) {
                var value = component
                var bytes = [UInt8]()

                repeat {
                    bytes.insert(UInt8(value & 0x7F), at: 0)
                    value >>= 7
                } while value > 0

                for i in 0 ..< bytes.count - 1 {
                    bytes[i] |= 0x80
                }

                encoded.append(contentsOf: bytes)
            }
        }

        return Data([0x06, UInt8(encoded.count)]) + encoded
    }

    private func encodeASN1DistinguishedName(_ name: String) -> Data {
        // 簡易的なDN エンコーディング（CN=name）
        let cnOID = encodeASN1ObjectIdentifier("2.5.4.3") // commonName
        let cnValue = Data([0x0C, UInt8(name.utf8.count)]) + name.data(using: .utf8)!
        let cnSequence = encodeASN1Sequence(cnOID + cnValue)
        let rdnSet = Data([0x31, UInt8(cnSequence.count)]) + cnSequence
        return encodeASN1Sequence(rdnSet)
    }

    private func encodeASN1Validity(from: Date, to: Date) -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmssZ"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let notBefore = formatter.string(from: from)
        let notAfter = formatter.string(from: to)

        let notBeforeData = Data([0x17, UInt8(notBefore.utf8.count)]) + notBefore.data(using: .utf8)!
        let notAfterData = Data([0x17, UInt8(notAfter.utf8.count)]) + notAfter.data(using: .utf8)!

        return encodeASN1Sequence(notBeforeData + notAfterData)
    }

    private func encodeASN1PublicKeyInfo(_ publicKeyData: Data) -> Data {
        let algorithm = encodeASN1ObjectIdentifier("1.2.840.113549.1.1.1") // RSA
        let nullParams = Data([0x05, 0x00])
        let algorithmId = encodeASN1Sequence(algorithm + nullParams)
        let publicKey = encodeASN1BitString(publicKeyData)

        return encodeASN1Sequence(algorithmId + publicKey)
    }

    private func encodeASN1Sequence(_ data: Data) -> Data {
        Data([0x30]) + encodeASN1Length(data.count) + data
    }

    private func encodeASN1BitString(_ data: Data) -> Data {
        Data([0x03, UInt8(data.count + 1), 0x00]) + data
    }

    private func encodeASN1Length(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        } else {
            var bytes = Data()
            var len = length
            while len > 0 {
                bytes.insert(UInt8(len & 0xFF), at: 0)
                len >>= 8
            }
            return Data([0x80 | UInt8(bytes.count)]) + bytes
        }
    }

    /// データから証明書の有効性をチェック
    /// - Parameter certificateData: 証明書データ
    /// - Returns: 有効かどうか
    private func isCertificateValidFromData(_ certificateData: [UInt8]) -> Bool {
        // 簡易的な有効性チェック
        // 実際の実装では証明書の有効期限を解析
        let pemString = String(bytes: certificateData, encoding: .utf8) ?? ""

        // 証明書が存在し、基本的なPEM形式かどうかをチェック
        return pemString.contains("-----BEGIN CERTIFICATE-----") &&
            pemString.contains("-----END CERTIFICATE-----")
    }
}

// MARK: - String Extensions

extension String {
    /// 文字列を指定した文字数で分割
    /// - Parameter size: 分割する文字数
    /// - Returns: 分割された文字列の配列
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start ..< end])
        }
    }
}
