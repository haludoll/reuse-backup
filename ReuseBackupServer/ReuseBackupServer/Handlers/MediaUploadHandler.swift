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
              contentType.lowercased().hasPrefix("multipart/form-data")
        else {
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
            // 大容量ファイルの場合は従来のパーサーを使用（より安定）
            let multipartData: [String: MultipartStreamValue]

            if body.count > 50 * 1024 * 1024 { // 50MB以上の場合は従来のパーサーを使用
                logger.info("Large file detected (\(body.count) bytes), using traditional parser")
                let traditionalData = try parseMultipartFormData(body: body, contentType: contentType)

                // MultipartValueをMultipartStreamValueに変換
                multipartData = traditionalData.mapValues { value in
                    MultipartStreamValue(
                        data: value.data,
                        filename: value.filename,
                        contentType: value.contentType,
                        tempFileURL: nil
                    )
                }
            } else {
                // 小さなファイルの場合はストリーミングパーサーを使用
                multipartData = try await parseMultipartFormDataStreaming(body: body, contentType: contentType)
            }

            // デバッグ: 受信したフィールドをログ出力
            logger.info("Received multipart fields: \(multipartData.keys)")
            for (key, value) in multipartData {
                if key == "file" {
                    let dataSize = value.data.count
                    logger.info("Field '\(key)': <binary data size: \(dataSize)>")
                } else {
                    let rawValue = value.string ?? "<nil>"
                    let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    logger.info("Field '\(key)': '\(rawValue)' (trimmed: '\(trimmedValue)')")
                }
            }

            // 必須フィールドをバリデーション
            guard let fileValue = multipartData["file"],
                  let filename = multipartData["filename"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let mediaTypeString = multipartData["mediaType"]?.string?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
                  let timestampString = multipartData["timestamp"]?.string?
                  .trimmingCharacters(in: .whitespacesAndNewlines)
            else {
                let missingFields = ["file", "filename", "mediaType", "timestamp"].filter { key in
                    multipartData[key] == nil
                }
                logger.error("Missing required fields: \(missingFields)")

                return createErrorResponse(
                    message: "Missing required fields: \(missingFields.joined(separator: ", "))",
                    status: .badRequest
                )
            }

            // メディアタイプをバリデーション
            logger.info("Validating mediaType: '\(mediaTypeString)'")
            let mediaType: MediaType
            switch mediaTypeString.lowercased() {
            case "photo":
                mediaType = .photo
            case "video":
                mediaType = .video
            default:
                logger.error("Invalid mediaType: '\(mediaTypeString)'")
                return createErrorResponse(
                    message: "Invalid mediaType. Must be 'photo' or 'video'",
                    status: .badRequest
                )
            }
            logger.info("MediaType validated successfully: \(String(describing: mediaType))")

            // タイムスタンプをパース
            logger.info("Parsing timestamp: '\(timestampString)'")
            let dateFormatter = ISO8601DateFormatter()
            guard let timestamp = dateFormatter.date(from: timestampString) else {
                logger.error("Failed to parse timestamp: '\(timestampString)'")
                return createErrorResponse(
                    message: "Invalid timestamp format. Must be ISO 8601",
                    status: .badRequest
                )
            }
            logger.info("Timestamp parsed successfully: \(timestamp)")

            // ファイル形式をバリデーション
            let fileExtension = URL(fileURLWithPath: filename).pathExtension.lowercased()
            logger.info("Validating file extension: '\(fileExtension)' for mediaType: \(String(describing: mediaType))")
            guard isValidFileType(extension: fileExtension, for: mediaType) else {
                logger
                    .error("Unsupported file type: '\(fileExtension)' for mediaType: \(String(describing: mediaType))")
                return createErrorResponse(
                    message: "Unsupported file type for \(mediaTypeString): .\(fileExtension)",
                    status: .badRequest
                )
            }
            logger.info("File type validation successful")

            // ストレージ容量をチェック
            if let insufficientStorageResponse = try checkStorageCapacity(for: fileValue.fileSize) {
                return insufficientStorageResponse
            }

            // ファイルを保存（ストリーミング処理）
            let savedMedia: SavedMediaInfo
            if let tempFileURL = fileValue.tempFileURL {
                logger.info("Using streaming save with temp file: \(tempFileURL.path)")

                // 一時ファイルの存在確認
                let tempFileExists = fileManager.fileExists(atPath: tempFileURL.path)
                logger.info("Temp file exists: \(tempFileExists)")

                if !tempFileExists {
                    logger.error("Temp file not found, falling back to data-based save")
                    // 一時ファイルが見つからない場合はデータベースの保存にフォールバック
                    savedMedia = try await mediaStorage.saveMedia(
                        data: fileValue.data,
                        filename: filename,
                        mediaType: mediaType,
                        timestamp: timestamp,
                        mimeType: multipartData["mimeType"]?.string
                    )
                } else {
                    // 大きなファイルの場合はストリーミング保存
                    savedMedia = try await mediaStorage.saveMediaStreaming(
                        sourceURL: tempFileURL,
                        filename: filename,
                        mediaType: mediaType,
                        timestamp: timestamp,
                        mimeType: multipartData["mimeType"]?.string
                    )
                }
            } else {
                logger.info("Using data-based save (no temp file)")
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
            logger.error("Error details: \(error)")

            // より具体的なエラーメッセージを提供
            let errorMessage: String
            let statusCode: HTTPResponse.Status

            if let mediaError = error as? MediaUploadError {
                errorMessage = mediaError.localizedDescription
                statusCode = .badRequest
            } else {
                errorMessage = "Failed to process upload: \(error.localizedDescription)"
                statusCode = .internalServerError
            }

            return createErrorResponse(
                message: errorMessage,
                status: statusCode
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
    private func parseMultipartFormDataStreaming(
        body: Data,
        contentType: String
    ) async throws -> [String: MultipartStreamValue] {
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
            ["jpg", "jpeg", "png", "heic", "gif", "webp"].contains(fileExtension)
        case .video:
            ["mov", "mp4", "m4v"].contains(fileExtension)
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
        case let .invalidContentType(details):
            "Invalid Content-Type: \(details)"
        case .invalidMultipartData:
            "Invalid multipart form data"
        case let .missingRequiredField(field):
            "Missing required field: \(field)"
        case .invalidFileType:
            "Invalid or unsupported file type"
        case .storageFull:
            "Insufficient storage space"
        case let .saveFailed(error):
            "Failed to save file: \(error.localizedDescription)"
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
