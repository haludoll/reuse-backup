import Foundation
import OSLog
import UniformTypeIdentifiers

/// メディアファイルのストレージ管理サービス
final class MediaStorageService {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "MediaStorageService")
    private let fileManager = FileManager.default
    private let mediaDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        // Documents/Media ディレクトリを作成
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        mediaDirectory = documentsPath.appendingPathComponent("Media", isDirectory: true)
        
        do {
            try createMediaDirectoryStructure()
            logger.info("MediaStorageService initialized with directory: \(self.mediaDirectory.path)")
        } catch {
            fatalError("Failed to initialize MediaStorageService: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// メディアファイルを保存
    /// - Parameters:
    ///   - data: ファイルデータ
    ///   - filename: 元のファイル名
    ///   - mediaType: メディアタイプ（photo/video）
    ///   - timestamp: ファイル作成時刻
    ///   - mimeType: MIMEタイプ（オプション）
    /// - Returns: 保存されたメディア情報
    func saveMedia(
        data: Data,
        filename: String,
        mediaType: MediaType,
        timestamp: Date,
        mimeType: String? = nil
    ) async throws -> SavedMediaInfo {
        
        logger.info("Starting to save media file: \(filename) (\(data.count) bytes)")
        
        // 一意のメディアIDを生成
        let mediaId = generateMediaId(for: filename, timestamp: timestamp)
        
        // ファイル拡張子を取得
        let fileExtension = URL(fileURLWithPath: filename).pathExtension
        
        // 保存先パスを決定
        let subdirectory = getSubdirectory(for: mediaType, timestamp: timestamp)
        let targetDirectory = mediaDirectory.appendingPathComponent(subdirectory, isDirectory: true)
        
        // ディレクトリを作成
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        
        // 重複しないファイル名を生成
        let savedFilename = generateUniqueFilename(
            baseFilename: filename,
            mediaId: mediaId,
            directory: targetDirectory
        )
        
        let targetURL = targetDirectory.appendingPathComponent(savedFilename)
        
        // ファイルを保存
        try data.write(to: targetURL)
        
        // ファイル属性を設定（作成日時など）
        try setFileAttributes(url: targetURL, timestamp: timestamp)
        
        // メタデータを保存
        let metadataInfo = MediaMetadata(
            mediaId: mediaId,
            originalFilename: filename,
            savedFilename: savedFilename,
            mediaType: mediaType,
            fileSize: data.count,
            mimeType: mimeType ?? inferMimeType(from: fileExtension),
            originalTimestamp: timestamp,
            savedTimestamp: Date(),
            relativePath: subdirectory + "/" + savedFilename
        )
        
        try await saveMetadata(metadataInfo)
        
        logger.info("Media file saved successfully: \(savedFilename) in \(subdirectory)")
        
        return SavedMediaInfo(
            mediaId: mediaId,
            filename: savedFilename,
            mediaType: mediaType,
            fileSize: data.count
        )
    }
    
    /// 保存されたメディアファイルの一覧を取得
    func listSavedMedia() async throws -> [MediaMetadata] {
        let metadataDirectory = mediaDirectory.appendingPathComponent("metadata", isDirectory: true)
        
        guard fileManager.fileExists(atPath: metadataDirectory.path) else {
            return []
        }
        
        let metadataFiles = try fileManager.contentsOfDirectory(at: metadataDirectory, includingPropertiesForKeys: nil)
        
        var mediaList: [MediaMetadata] = []
        
        for metadataFile in metadataFiles where metadataFile.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: metadataFile)
                let metadata = try JSONDecoder().decode(MediaMetadata.self, from: data)
                mediaList.append(metadata)
            } catch {
                logger.warning("Failed to load metadata from \(metadataFile.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        return mediaList.sorted { $0.originalTimestamp > $1.originalTimestamp }
    }
    
    /// メディアファイルを削除
    func deleteMedia(mediaId: String) async throws {
        // メタデータを読み込んで削除対象ファイルを特定
        if let metadata = try await loadMetadata(mediaId: mediaId) {
            let mediaFilePath = mediaDirectory.appendingPathComponent(metadata.relativePath)
            
            // メディアファイルを削除
            if fileManager.fileExists(atPath: mediaFilePath.path) {
                try fileManager.removeItem(at: mediaFilePath)
                logger.info("Deleted media file: \(metadata.relativePath)")
            }
            
            // メタデータファイルを削除
            let metadataPath = getMetadataPath(for: mediaId)
            if fileManager.fileExists(atPath: metadataPath.path) {
                try fileManager.removeItem(at: metadataPath)
                logger.info("Deleted metadata: \(mediaId).json")
            }
        } else {
            throw MediaStorageError.mediaNotFound(mediaId)
        }
    }
    
    // MARK: - Private Methods
    
    /// メディアディレクトリ構造を作成
    private func createMediaDirectoryStructure() throws {
        let subdirectories = ["photos", "videos", "metadata"]
        
        for subdirectory in subdirectories {
            let path = mediaDirectory.appendingPathComponent(subdirectory, isDirectory: true)
            try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }
    
    /// 一意のメディアIDを生成
    private func generateMediaId(for filename: String, timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestampString = formatter.string(from: timestamp)
        
        let fileBaseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let randomSuffix = String(UUID().uuidString.prefix(8))
        
        return "\(timestampString)_\(fileBaseName)_\(randomSuffix)"
    }
    
    /// メディアタイプと日付に基づいてサブディレクトリを決定
    private func getSubdirectory(for mediaType: MediaType, timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM"
        let yearMonth = formatter.string(from: timestamp)
        
        switch mediaType {
        case .photo:
            return "photos/\(yearMonth)"
        case .video:
            return "videos/\(yearMonth)"
        }
    }
    
    /// 重複しないファイル名を生成
    private func generateUniqueFilename(baseFilename: String, mediaId: String, directory: URL) -> String {
        let fileURL = URL(fileURLWithPath: baseFilename)
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension
        
        // メディアIDを含むファイル名
        let candidateFilename = "\(mediaId)_\(baseName).\(ext)"
        let candidatePath = directory.appendingPathComponent(candidateFilename)
        
        if !fileManager.fileExists(atPath: candidatePath.path) {
            return candidateFilename
        }
        
        // 重複する場合は連番を追加
        var counter = 1
        while true {
            let numberedFilename = "\(mediaId)_\(baseName)_\(counter).\(ext)"
            let numberedPath = directory.appendingPathComponent(numberedFilename)
            
            if !fileManager.fileExists(atPath: numberedPath.path) {
                return numberedFilename
            }
            
            counter += 1
            if counter > 1000 {
                fatalError("Too many duplicate files")
            }
        }
    }
    
    /// ファイル属性を設定
    private func setFileAttributes(url: URL, timestamp: Date) throws {
        let attributes: [FileAttributeKey: Any] = [
            .creationDate: timestamp,
            .modificationDate: timestamp
        ]
        
        try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
    }
    
    /// ファイル拡張子からMIMEタイプを推測
    private func inferMimeType(from fileExtension: String) -> String {
        let ext = fileExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "mov":
            return "video/quicktime"
        case "mp4":
            return "video/mp4"
        case "m4v":
            return "video/x-m4v"
        default:
            return "application/octet-stream"
        }
    }
    
    /// メタデータを保存
    private func saveMetadata(_ metadata: MediaMetadata) async throws {
        let metadataPath = getMetadataPath(for: metadata.mediaId)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(metadata)
        try data.write(to: metadataPath)
    }
    
    /// メタデータを読み込み
    private func loadMetadata(mediaId: String) async throws -> MediaMetadata? {
        let metadataPath = getMetadataPath(for: mediaId)
        
        guard fileManager.fileExists(atPath: metadataPath.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: metadataPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(MediaMetadata.self, from: data)
    }
    
    /// メタデータファイルのパスを取得
    private func getMetadataPath(for mediaId: String) -> URL {
        return mediaDirectory
            .appendingPathComponent("metadata", isDirectory: true)
            .appendingPathComponent("\(mediaId).json")
    }
}

// MARK: - Supporting Types

/// メディアメタデータ
struct MediaMetadata: Codable {
    let mediaId: String
    let originalFilename: String
    let savedFilename: String
    let mediaType: MediaType
    let fileSize: Int
    let mimeType: String
    let originalTimestamp: Date
    let savedTimestamp: Date
    let relativePath: String
}

extension MediaType: Codable {
    enum CodingKeys: String, CodingKey {
        case photo = "photo"
        case video = "video"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "photo":
            self = .photo
        case "video":
            self = .video
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid MediaType: \(rawValue)"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .photo:
            try container.encode("photo")
        case .video:
            try container.encode("video")
        }
    }
}

/// メディアストレージエラー
enum MediaStorageError: Error, LocalizedError {
    case directoryCreationFailed
    case mediaNotFound(String)
    case metadataCorrupted(String)
    case diskSpaceInsufficient
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "Failed to create media storage directories"
        case .mediaNotFound(let mediaId):
            return "Media not found: \(mediaId)"
        case .metadataCorrupted(let mediaId):
            return "Metadata corrupted for media: \(mediaId)"
        case .diskSpaceInsufficient:
            return "Insufficient disk space for media storage"
        }
    }
}