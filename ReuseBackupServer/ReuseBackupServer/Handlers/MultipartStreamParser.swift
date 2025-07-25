import Foundation
import OSLog

/// ストリーミング対応マルチパートフォームデータ解析クラス
/// メモリ効率を重視し、大容量ファイルを段階的に処理する
final class MultipartStreamParser {
    private let boundary: String
    private let boundaryData: Data
    private let finalBoundaryData: Data
    private let chunkSize: Int
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "MultipartStreamParser")

    /// チャンクサイズ（8MB）
    static let defaultChunkSize = 8 * 1024 * 1024

    init(boundary: String, chunkSize: Int = defaultChunkSize) {
        self.boundary = boundary
        self.boundaryData = "--\(boundary)".data(using: .utf8)!
        self.finalBoundaryData = "--\(boundary)--".data(using: .utf8)!
        self.chunkSize = chunkSize
    }

    /// ストリーミング解析：大容量データを段階的に処理
    func parseStream(data: Data) async throws -> [String: MultipartStreamValue] {
        logger.info("Starting streaming multipart parse for \(data.count) bytes")

        // 一時ディレクトリを作成
        let tempDir = try createTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // データをチャンクに分割してストリーミング処理
        let chunks = try await processDataInChunks(data: data, tempDirectory: tempDir)

        // 解析結果を返す
        var result: [String: MultipartStreamValue] = [:]
        for chunk in chunks {
            if let parsed = try await parseChunk(chunk, tempDirectory: tempDir) {
                result[parsed.name] = parsed.value
            }
        }

        logger.info("Completed streaming parse with \(result.count) fields")
        return result
    }

    // MARK: - Private Methods

    /// 一時ディレクトリを作成
    private func createTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("multipart_stream_\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// データをチャンクに分割して処理（効率化版）
    private func processDataInChunks(data: Data, tempDirectory: URL) async throws -> [MultipartChunk] {
        logger.info("Starting optimized chunk processing for \(data.count) bytes")

        // マルチパートデータを効率的に解析
        return try await processMultipartDataEfficiently(data: data, tempDirectory: tempDirectory)
    }

    /// 効率的なマルチパート解析（単純化版）
    private func processMultipartDataEfficiently(data: Data, tempDirectory: URL) async throws -> [MultipartChunk] {
        logger.info("Processing multipart data with boundary search")

        var chunks: [MultipartChunk] = []
        var currentPosition = 0
        var chunkId = 0

        // 最初の境界を探す
        guard let firstBoundaryRange = findNextBoundary(in: data, startingAt: currentPosition) else {
            logger.error("No initial boundary found in multipart data")
            throw MultipartStreamError.invalidBoundary
        }

        currentPosition = firstBoundaryRange.upperBound

        // 各パートを処理
        while currentPosition < data.count {
            // 次の境界を探す
            let nextBoundaryRange = findNextBoundary(in: data, startingAt: currentPosition)

            let partEndPosition: Int = if let nextRange = nextBoundaryRange {
                // 境界の前の改行を除く
                nextRange.lowerBound - 2 // \r\nを除く
            } else {
                // 最後のパートの場合
                data.count
            }

            // パートのデータを抽出
            if partEndPosition > currentPosition {
                let partData = data.subdata(in: currentPosition ..< partEndPosition)

                // チャンクファイルとして保存
                let chunkFile = tempDirectory.appendingPathComponent("chunk_\(chunkId)")
                try partData.write(to: chunkFile)

                chunks.append(MultipartChunk(
                    id: chunkId,
                    fileURL: chunkFile,
                    size: partData.count
                ))

                logger.debug("Created chunk \(chunkId) with size \(partData.count)")
                chunkId += 1
            }

            // 終了境界の場合は終了
            if let nextRange = nextBoundaryRange {
                let boundaryData = data.subdata(in: nextRange)
                if boundaryData.starts(with: finalBoundaryData) {
                    logger.info("Found final boundary, ending parse")
                    break
                }
                currentPosition = nextRange.upperBound
            } else {
                break
            }
        }

        logger.info("Created \(chunks.count) chunks from multipart data")
        return chunks
    }

    /// データを単一ファイルとして処理（境界検索を回避）
    private func processAsSignleFile(data: Data, tempDirectory: URL) async throws -> [MultipartChunk] {
        logger.info("Processing as single file to avoid boundary search")

        let fileURL = tempDirectory.appendingPathComponent("file_\(UUID().uuidString)")

        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    try data.write(to: fileURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        let chunk = MultipartChunk(
            id: 0,
            fileURL: fileURL,
            size: data.count
        )

        logger.info("Created single file chunk: \(fileURL.path) (\(data.count) bytes)")
        return [chunk]
    }

    /// 次のboundaryの位置を検索
    private func findNextBoundary(in data: Data, startingAt start: Int) -> Range<Int>? {
        let searchRange = start ..< data.count
        let searchSize = searchRange.count

        logger.debug("Searching for boundary in range \(start)..<\(data.count) (size: \(searchSize) bytes)")

        // 大きなデータの場合は段階的に検索
        let maxSearchSize = 10 * 1024 * 1024 // 10MB単位で検索
        if searchSize > maxSearchSize {
            logger.warning("Large search range detected (\(searchSize) bytes), using chunked search")
            return findBoundaryInChunks(data: data, searchRange: searchRange, chunkSize: maxSearchSize)
        }

        // 通常のboundaryを検索
        if let range = data.range(of: boundaryData, in: searchRange) {
            logger.debug("Found boundary at range \(range)")
            return range
        }

        // 終了boundaryを検索
        if let range = data.range(of: finalBoundaryData, in: searchRange) {
            return range
        }

        return nil
    }

    /// 大容量データのチャンク分割境界検索
    private func findBoundaryInChunks(data: Data, searchRange: Range<Int>, chunkSize: Int) -> Range<Int>? {
        logger.debug("Starting chunked boundary search in range \(searchRange)")

        let totalSize = searchRange.count
        var currentOffset = searchRange.lowerBound

        while currentOffset < searchRange.upperBound {
            let chunkEnd = min(currentOffset + chunkSize, searchRange.upperBound)
            let chunkRange = currentOffset ..< chunkEnd

            logger.debug("Searching chunk \(currentOffset)..<\(chunkEnd)")

            // 通常の境界を検索
            if let range = data.range(of: boundaryData, in: chunkRange) {
                logger.debug("Found boundary in chunk at \(range)")
                return range
            }

            // 終了境界を検索
            if let range = data.range(of: finalBoundaryData, in: chunkRange) {
                logger.debug("Found final boundary in chunk at \(range)")
                return range
            }

            // 次のチャンクに移動（オーバーラップを考慮）
            currentOffset += chunkSize - boundaryData.count
        }

        logger.debug("No boundary found in chunked search")
        return nil
    }

    /// 効率的な境界検索（シーケンシャルスキャン）
    private func findBoundarySequentially(
        in data: Data,
        startingAt start: Int,
        boundary: Data,
        finalBoundary: Data
    ) -> Range<Int>? {
        let maxSearchSize = min(1024 * 1024, data.count - start) // 最大1MBまで検索
        let searchEnd = min(start + maxSearchSize, data.count)
        let searchRange = start ..< searchEnd

        logger.debug("Sequential search in range \(start)..<\(searchEnd)")

        // 通常の境界を検索
        if let range = data.range(of: boundary, in: searchRange) {
            return range
        }

        // 終了境界を検索
        if let range = data.range(of: finalBoundary, in: searchRange) {
            return range
        }

        // 見つからない場合は、より大きな範囲で検索
        if searchEnd < data.count {
            let extendedEnd = min(start + 10 * 1024 * 1024, data.count) // 最大10MBまで拡張
            let extendedRange = start ..< extendedEnd

            logger.debug("Extended search in range \(start)..<\(extendedEnd)")

            if let range = data.range(of: boundary, in: extendedRange) {
                return range
            }

            if let range = data.range(of: finalBoundary, in: extendedRange) {
                return range
            }
        }

        return nil
    }

    /// チャンクデータを一時ファイルに保存
    private func saveChunkToFile(_ data: Data, to url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try data.write(to: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// チャンクを解析
    private func parseChunk(
        _ chunk: MultipartChunk,
        tempDirectory: URL
    ) async throws -> (name: String, value: MultipartStreamValue)? {
        // チャンクファイルを読み込み（メモリ効率的に）
        let data = try Data(contentsOf: chunk.fileURL)

        // ヘッダーとボディを分離
        let headerBodySeparator = "\r\n\r\n".data(using: .utf8)!
        guard let separatorRange = data.range(of: headerBodySeparator) else {
            return nil
        }

        let headerData = data.subdata(in: 0 ..< separatorRange.lowerBound)
        let bodyData = data.subdata(in: separatorRange.upperBound ..< data.count)

        // ヘッダーを解析
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw MultipartStreamError.invalidHeader
        }

        let headers = parseHeaders(headerString)

        // Content-Dispositionからnameとfilenameを抽出
        guard let contentDisposition = headers["content-disposition"],
              let name = extractParameterValue(from: contentDisposition, parameter: "name")
        else {
            throw MultipartStreamError.missingName
        }

        let filename = extractParameterValue(from: contentDisposition, parameter: "filename")
        let contentType = headers["content-type"]

        // ファイルデータの場合は一時ファイルとして保存
        let value: MultipartStreamValue
        if let filename, !filename.isEmpty {
            // 大きなファイルの場合は一時ファイルとして処理
            let tempFileURL = tempDirectory.appendingPathComponent("file_\(UUID().uuidString)")
            try bodyData.write(to: tempFileURL)

            value = MultipartStreamValue(
                data: bodyData,
                filename: filename,
                contentType: contentType,
                tempFileURL: tempFileURL
            )
        } else {
            // 小さなテキストデータの場合はメモリに保持
            value = MultipartStreamValue(
                data: bodyData,
                filename: nil,
                contentType: contentType,
                tempFileURL: nil
            )
        }

        return (name: name, value: value)
    }

    /// ヘッダー文字列を解析
    private func parseHeaders(_ headerString: String) -> [String: String] {
        var headers: [String: String] = [:]

        let lines = headerString.components(separatedBy: "\r\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }

            let parts = trimmedLine.components(separatedBy: ":")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        return headers
    }

    /// ヘッダー値からパラメータ値を抽出
    private func extractParameterValue(from headerValue: String, parameter: String) -> String? {
        let components = headerValue.components(separatedBy: ";")

        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            let lowerParameter = parameter.lowercased()

            if trimmed.lowercased().hasPrefix("\(lowerParameter)=") {
                var value = String(trimmed.dropFirst("\(lowerParameter)=".count))

                // クォートを除去
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                    (value.hasPrefix("'") && value.hasSuffix("'"))
                {
                    value = String(value.dropFirst().dropLast())
                }

                return value
            }
        }

        return nil
    }
}

// MARK: - Supporting Types

/// ストリーミング処理用のマルチパート値
struct MultipartStreamValue {
    let data: Data
    let filename: String?
    let contentType: String?
    let tempFileURL: URL?

    /// 文字列としてデータを取得
    var string: String? {
        String(data: data, encoding: .utf8)
    }

    /// ファイルサイズを取得
    var fileSize: Int {
        if let tempFileURL {
            return (try? FileManager.default.attributesOfItem(atPath: tempFileURL.path)[.size] as? Int) ?? data.count
        }
        return data.count
    }
}

/// マルチパートチャンク情報
private struct MultipartChunk {
    let id: Int
    let fileURL: URL
    let size: Int
}

/// ストリーミング解析エラー
enum MultipartStreamError: Error, LocalizedError {
    case invalidHeader
    case missingName
    case invalidBoundary
    case fileWriteError
    case memoryLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidHeader:
            "Invalid multipart header"
        case .missingName:
            "Missing name parameter in Content-Disposition"
        case .invalidBoundary:
            "Invalid boundary in multipart data"
        case .fileWriteError:
            "Failed to write temporary file"
        case .memoryLimitExceeded:
            "Memory limit exceeded during parsing"
        }
    }
}
