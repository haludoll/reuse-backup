import APISharedModels
import Foundation
import HTTPServerAdapters
import HTTPTypes
import OSLog
import UniformTypeIdentifiers

/// 写真・動画アップロードエンドポイント（/api/media/upload）のハンドラー
final class MediaUploadHandler: HTTPHandlerAdapter {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "MediaUploadHandler")
    private let mediaStorage: MediaStorageService
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    init(mediaStorage: MediaStorageService? = nil) {
        self.mediaStorage = mediaStorage ?? MediaStorageService()
    }
    
    // MARK: - HTTPHandlerAdapter Implementation
    
    func handleRequest(_ request: HTTPRequestInfo) async throws -> HTTPResponseInfo {
        logger.info("Received media upload request")
        
        // Content-Typeがmultipart/form-dataかチェック
        guard let contentType = request.headerFields[.contentType],
              contentType.lowercased().hasPrefix("multipart/form-data") else {
            return createErrorResponse(
                message: "Content-Type must be multipart/form-data",
                status: .badRequest
            )
        }
        
        // リクエストボディが存在するかチェック
        guard let body = request.body, !body.isEmpty else {
            return createErrorResponse(
                message: "Request body is required",
                status: .badRequest
            )
        }
        
        do {
            // ストリーミングマルチパートデータを解析
            let multipartData = try await parseMultipartFormDataStreaming(body: body, contentType: contentType)
            
            // 必須フィールドをバリデーション
            guard let fileValue = multipartData["file"],
                  let filename = multipartData["filename"]?.string,
                  let mediaTypeString = multipartData["mediaType"]?.string,
                  let timestampString = multipartData["timestamp"]?.string else {
                return createErrorResponse(
                    message: "Missing required fields: file, filename, mediaType, timestamp",
                    status: .badRequest
                )
            }
            
            // メディアタイプをバリデーション
            let mediaType: MediaType
            switch mediaTypeString.lowercased() {
            case "photo":
                mediaType = .photo
            case "video":
                mediaType = .video
            default:
                return createErrorResponse(
                    message: "Invalid mediaType. Must be 'photo' or 'video'",
                    status: .badRequest
                )
            }
            
            // タイムスタンプをパース
            let dateFormatter = ISO8601DateFormatter()
            guard let timestamp = dateFormatter.date(from: timestampString) else {
                return createErrorResponse(
                    message: "Invalid timestamp format. Must be ISO 8601",
                    status: .badRequest
                )
            }
            
            // ファイル形式をバリデーション
            let fileExtension = URL(fileURLWithPath: filename).pathExtension.lowercased()
            guard isValidFileType(extension: fileExtension, for: mediaType) else {
                return createErrorResponse(
                    message: "Unsupported file type for \(mediaTypeString): .\(fileExtension)",
                    status: .badRequest
                )
            }
            
            // ストレージ容量をチェック
            if let insufficientStorageResponse = try checkStorageCapacity(for: fileValue.fileSize) {
                return insufficientStorageResponse
            }
            
            // ファイルを保存（ストリーミング処理）
            let savedMedia: SavedMediaInfo
            if let tempFileURL = fileValue.tempFileURL {
                // 大きなファイルの場合はストリーミング保存
                savedMedia = try await mediaStorage.saveMediaStreaming(
                    sourceURL: tempFileURL,
                    filename: filename,
                    mediaType: mediaType,
                    timestamp: timestamp,
                    mimeType: multipartData["mimeType"]?.string
                )
            } else {
                // 小さなファイルの場合は従来の方法
                savedMedia = try await mediaStorage.saveMedia(
                    data: fileValue.data,
                    filename: filename,
                    mediaType: mediaType,
                    timestamp: timestamp,
                    mimeType: multipartData["mimeType"]?.string
                )
            }
            
            // 成功レスポンスを作成
            return createSuccessResponse(savedMedia: savedMedia)
            
        } catch {
            logger.error("Media upload failed: \(error.localizedDescription)")
            return createErrorResponse(
                message: "Failed to process upload: \(error.localizedDescription)",
                status: .internalServerError
            )
        }
    }
    
    // MARK: - Private Methods
    
    /// マルチパートフォームデータを解析（従来版）
    private func parseMultipartFormData(body: Data, contentType: String) throws -> [String: MultipartValue] {
        // Content-Typeからboundaryを抽出
        guard let boundary = extractBoundary(from: contentType) else {
            throw MediaUploadError.invalidContentType("Missing boundary in Content-Type")
        }
        
        let parser = MultipartParser(boundary: boundary)
        return try parser.parse(data: body)
    }
    
    /// ストリーミングマルチパートフォームデータを解析（メモリ効率版）
    private func parseMultipartFormDataStreaming(body: Data, contentType: String) async throws -> [String: MultipartStreamValue] {
        // Content-Typeからboundaryを抽出
        guard let boundary = extractBoundary(from: contentType) else {
            throw MediaUploadError.invalidContentType("Missing boundary in Content-Type")
        }
        
        let streamParser = MultipartStreamParser(boundary: boundary)
        return try await streamParser.parseStream(data: body)
    }
    
    /// Content-Typeからboundaryを抽出
    private func extractBoundary(from contentType: String) -> String? {
        let components = contentType.components(separatedBy: ";")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("boundary=") {
                return String(trimmed.dropFirst("boundary=".count))
            }
        }
        return nil
    }
    
    /// ファイル形式が有効かチェック
    private func isValidFileType(extension fileExtension: String, for mediaType: MediaType) -> Bool {
        switch mediaType {
        case .photo:
            return ["jpg", "jpeg", "png", "heic", "gif", "webp"].contains(fileExtension)
        case .video:
            return ["mov", "mp4", "m4v"].contains(fileExtension)
        }
    }
    
    /// ストレージ容量をチェック
    private func checkStorageCapacity(for fileSize: Int) throws -> HTTPResponseInfo? {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        
        guard let availableCapacity = resourceValues.volumeAvailableCapacity else {
            return nil
        }
        
        // 安全マージンとして要求ファイルサイズの2倍の容量が必要
        let requiredCapacity = Int64(fileSize * 2)
        
        if availableCapacity < requiredCapacity {
            return createErrorResponse(
                message: "Insufficient storage space",
                status: .internalServerError
            )
        }
        
        return nil
    }
    
    /// 成功レスポンスを作成
    private func createSuccessResponse(savedMedia: SavedMediaInfo) -> HTTPResponseInfo {
        let response = Components.Schemas.MediaUploadResponse(
            status: .success,
            mediaId: savedMedia.mediaId,
            filename: savedMedia.filename,
            mediaType: savedMedia.mediaType == .photo ? .photo : .video,
            fileSize: Int64(savedMedia.fileSize),
            serverTimestamp: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(response)
            
            var headers = HTTPFields()
            headers[.contentType] = "application/json"
            
            return HTTPResponseInfo(
                status: .ok,
                headerFields: headers,
                body: jsonData
            )
        } catch {
            logger.error("Failed to encode success response: \(error.localizedDescription)")
            return createErrorResponse(
                message: "Failed to create response",
                status: .internalServerError
            )
        }
    }
    
    /// エラーレスポンスを作成
    private func createErrorResponse(message: String, status: HTTPResponse.Status) -> HTTPResponseInfo {
        let response = Components.Schemas.MediaUploadResponse(
            status: .error,
            serverTimestamp: Date(),
            error: message
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(response)
            
            var headers = HTTPFields()
            headers[.contentType] = "application/json"
            
            return HTTPResponseInfo(
                status: status,
                headerFields: headers,
                body: jsonData
            )
        } catch {
            // JSONエンコードも失敗した場合はプレーンテキストで返す
            var headers = HTTPFields()
            headers[.contentType] = "text/plain"
            
            return HTTPResponseInfo(
                status: .internalServerError,
                headerFields: headers,
                body: "Internal server error".data(using: .utf8)
            )
        }
    }
}

// MARK: - Supporting Types

/// メディアタイプ
enum MediaType {
    case photo
    case video
}

/// 保存されたメディア情報
struct SavedMediaInfo {
    let mediaId: String
    let filename: String
    let mediaType: MediaType
    let fileSize: Int
}

/// メディアアップロードエラー
enum MediaUploadError: Error, LocalizedError {
    case invalidContentType(String)
    case invalidMultipartData
    case missingRequiredField(String)
    case invalidFileType
    case storageFull
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidContentType(let details):
            return "Invalid Content-Type: \(details)"
        case .invalidMultipartData:
            return "Invalid multipart form data"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFileType:
            return "Invalid or unsupported file type"
        case .storageFull:
            return "Insufficient storage space"
        case .saveFailed(let error):
            return "Failed to save file: \(error.localizedDescription)"
        }
    }
}

/// マルチパートフォームデータの値
struct MultipartValue {
    let data: Data
    let filename: String?
    let contentType: String?
    
    var string: String? {
        String(data: data, encoding: .utf8)
    }
}