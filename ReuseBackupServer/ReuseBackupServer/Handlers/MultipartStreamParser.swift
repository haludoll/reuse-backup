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
    
    /// データをチャンクに分割して処理
    private func processDataInChunks(data: Data, tempDirectory: URL) async throws -> [MultipartChunk] {
        var chunks: [MultipartChunk] = []
        var currentIndex = 0
        var chunkCounter = 0
        
        logger.info("Starting chunk processing for \(data.count) bytes")
        
        // boundaryでデータを分割
        while currentIndex < data.count {
            let progress = Double(currentIndex) / Double(data.count) * 100
            logger.info("Processing chunk \(chunkCounter), progress: \(String(format: "%.1f", progress))%")
            
            // 次のboundaryを検索
            guard let boundaryRange = findNextBoundary(in: data, startingAt: currentIndex) else {
                logger.info("No more boundaries found at index \(currentIndex)")
                break
            }
            
            // チャンクデータを抽出
            let chunkStart = currentIndex == 0 ? boundaryRange.upperBound : currentIndex
            let chunkEnd = boundaryRange.lowerBound
            
            if chunkStart < chunkEnd {
                let chunkData = data.subdata(in: chunkStart..<chunkEnd)
                
                // チャンクを一時ファイルに保存（メモリ節約）
                let chunkURL = tempDirectory.appendingPathComponent("chunk_\(chunkCounter).tmp")
                try await saveChunkToFile(chunkData, to: chunkURL)
                
                let chunk = MultipartChunk(
                    id: chunkCounter,
                    fileURL: chunkURL,
                    size: chunkData.count
                )
                chunks.append(chunk)
                chunkCounter += 1
            }
            
            currentIndex = boundaryRange.upperBound
        }
        
        return chunks
    }
    
    /// 次のboundaryの位置を検索
    private func findNextBoundary(in data: Data, startingAt start: Int) -> Range<Int>? {
        let searchRange = start..<data.count
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
    
    /// 大きなデータを分割してboundaryを検索
    private func findBoundaryInChunks(data: Data, searchRange: Range<Int>, chunkSize: Int) -> Range<Int>? {
        let start = searchRange.lowerBound
        let end = searchRange.upperBound
        
        var currentStart = start
        let boundarySize = boundaryData.count
        
        while currentStart < end {
            let chunkEnd = min(currentStart + chunkSize + boundarySize, end)
            let chunkRange = currentStart..<chunkEnd
            
            logger.debug("Searching chunk \(currentStart)..<\(chunkEnd)")
            
            // このチャンク内で境界を検索
            if let range = data.range(of: boundaryData, in: chunkRange) {
                return range
            }
            
            if let range = data.range(of: finalBoundaryData, in: chunkRange) {
                return range
            }
            
            currentStart += chunkSize
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
    private func parseChunk(_ chunk: MultipartChunk, tempDirectory: URL) async throws -> (name: String, value: MultipartStreamValue)? {
        // チャンクファイルを読み込み（メモリ効率的に）
        let data = try Data(contentsOf: chunk.fileURL)
        
        // ヘッダーとボディを分離
        let headerBodySeparator = "\r\n\r\n".data(using: .utf8)!
        guard let separatorRange = data.range(of: headerBodySeparator) else {
            return nil
        }
        
        let headerData = data.subdata(in: 0..<separatorRange.lowerBound)
        let bodyData = data.subdata(in: separatorRange.upperBound..<data.count)
        
        // ヘッダーを解析
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw MultipartStreamError.invalidHeader
        }
        
        let headers = parseHeaders(headerString)
        
        // Content-Dispositionからnameとfilenameを抽出
        guard let contentDisposition = headers["content-disposition"],
              let name = extractParameterValue(from: contentDisposition, parameter: "name") else {
            throw MultipartStreamError.missingName
        }
        
        let filename = extractParameterValue(from: contentDisposition, parameter: "filename")
        let contentType = headers["content-type"]
        
        // ファイルデータの場合は一時ファイルとして保存
        let value: MultipartStreamValue
        if let filename = filename, !filename.isEmpty {
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
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
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
        if let tempFileURL = tempFileURL {
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
            return "Invalid multipart header"
        case .missingName:
            return "Missing name parameter in Content-Disposition"
        case .invalidBoundary:
            return "Invalid boundary in multipart data"
        case .fileWriteError:
            return "Failed to write temporary file"
        case .memoryLimitExceeded:
            return "Memory limit exceeded during parsing"
        }
    }
}