import Foundation
import OSLog

/// マルチパートフォームデータ解析クラス
struct MultipartParser {
    private let boundary: String
    private let boundaryData: Data
    private let finalBoundaryData: Data
    private let logger = Logger(subsystem: "com.haludoll.ReuseBackupServer", category: "MultipartParser")

    init(boundary: String) {
        self.boundary = boundary
        self.boundaryData = "--\(boundary)".data(using: .utf8)!
        self.finalBoundaryData = "--\(boundary)--".data(using: .utf8)!
    }

    /// マルチパートデータを解析して辞書形式で返す
    func parse(data: Data) throws -> [String: MultipartValue] {
        logger.info("Starting multipart parse for \(data.count) bytes")
        var result: [String: MultipartValue] = [:]

        // データをboundaryで分割
        let parts = splitByBoundary(data: data)
        logger.info("Found \(parts.count) parts in multipart data")

        for (index, partData) in parts.enumerated() {
            logger.debug("Processing part \(index + 1)/\(parts.count) with size \(partData.count)")
            if let part = try parsePartData(partData) {
                result[part.name] = part.value
                logger.debug("Added field '\(part.name)' to result")
            }
        }

        logger.info("Completed multipart parse with \(result.count) fields")
        return result
    }

    // MARK: - Private Methods

    /// データをboundaryで分割
    private func splitByBoundary(data: Data) -> [Data] {
        var parts: [Data] = []
        var currentIndex = 0
        let dataCount = data.count

        logger.debug("Starting boundary split for \(dataCount) bytes")
        logger.debug("Boundary pattern: \(String(data: boundaryData, encoding: .utf8) ?? "N/A")")
        logger.debug("Final boundary pattern: \(String(data: finalBoundaryData, encoding: .utf8) ?? "N/A")")
        var lastProgressLog = 0

        // 最初の境界を探す（通常、データの先頭近くにある）
        guard let firstBoundaryRange = data.range(of: boundaryData, in: 0 ..< min(1000, dataCount)) else {
            logger.error("No initial boundary found at start of data")
            return []
        }

        logger.debug("Found initial boundary at: \(firstBoundaryRange)")
        currentIndex = firstBoundaryRange.upperBound

        while currentIndex < dataCount {
            // 進捗ログ（10%ごとに出力）
            let progress = Int(Double(currentIndex) / Double(dataCount) * 100)
            if progress >= lastProgressLog + 10 {
                logger.info("Boundary search progress: \(progress)%")
                lastProgressLog = progress
            }

            // 次のboundary の開始位置を検索
            let nextBoundaryRange = data.range(of: boundaryData, in: currentIndex ..< dataCount)
            let nextFinalBoundaryRange = data.range(of: finalBoundaryData, in: currentIndex ..< dataCount)

            // 最も近い境界を選択
            var selectedRange: Range<Int>?
            if let nextRange = nextBoundaryRange, let finalRange = nextFinalBoundaryRange {
                selectedRange = nextRange.lowerBound < finalRange.lowerBound ? nextRange : finalRange
            } else if let nextRange = nextBoundaryRange {
                selectedRange = nextRange
            } else if let finalRange = nextFinalBoundaryRange {
                selectedRange = finalRange
            }

            if let selectedRange {
                // CRLFを考慮してpartデータを抽出
                let partEnd = selectedRange.lowerBound

                if currentIndex < partEnd {
                    var partData = data.subdata(in: currentIndex ..< partEnd)

                    // 先頭のCRLFを除去
                    if partData.starts(with: "\r\n".data(using: .utf8)!) {
                        partData = partData.dropFirst(2)
                    }

                    // 末尾のCRLFを除去
                    if partData.hasSuffix("\r\n".data(using: .utf8)!) {
                        partData = partData.dropLast(2)
                    }

                    if !partData.isEmpty {
                        parts.append(Data(partData))
                        logger.debug("Found part #\(parts.count) with size \(partData.count)")

                        // パートの先頭をデバッグ出力（最初の200文字まで）
                        if let preview = String(data: Data(partData.prefix(200)), encoding: .utf8) {
                            logger
                                .debug(
                                    "Part #\(parts.count) preview: \(preview.replacingOccurrences(of: "\r\n", with: "\\r\\n"))"
                                )
                        }
                    }
                }

                // 終了boundary（--boundary--）の場合は処理を終了
                let boundaryData = data.subdata(in: selectedRange)
                if boundaryData.starts(with: finalBoundaryData) {
                    logger.info("Found final boundary, stopping parse")
                    break
                }

                currentIndex = selectedRange.upperBound
            } else {
                // 最後のパートを処理
                if currentIndex < dataCount {
                    var partData = data.subdata(in: currentIndex ..< dataCount)

                    // 先頭のCRLFを除去
                    if partData.starts(with: "\r\n".data(using: .utf8)!) {
                        partData = partData.dropFirst(2)
                    }

                    // 末尾のCRLFを除去
                    if partData.hasSuffix("\r\n".data(using: .utf8)!) {
                        partData = partData.dropLast(2)
                    }

                    if !partData.isEmpty {
                        parts.append(Data(partData))
                        logger.debug("Found final part #\(parts.count) with size \(partData.count)")
                    }
                }
                break
            }
        }

        logger.info("Completed boundary split with \(parts.count) parts")
        return parts
    }

    /// 個別のpartデータを解析
    private func parsePartData(_ data: Data) throws -> (name: String, value: MultipartValue)? {
        // ヘッダーとボディを分離（空行で分割）
        let headerBodySeparator = "\r\n\r\n".data(using: .utf8)!
        guard let separatorRange = data.range(of: headerBodySeparator) else {
            // ヘッダーのみでボディがない場合はスキップ
            logger.debug("No header-body separator found in part, skipping")
            return nil
        }

        let headerData = data.subdata(in: 0 ..< separatorRange.lowerBound)
        let bodyData = data.subdata(in: separatorRange.upperBound ..< data.count)

        // ヘッダーを解析
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            logger.error("Failed to decode header as UTF-8")
            throw MultipartParseError.invalidHeader
        }

        logger.debug("Parsing part with header: \(headerString.replacingOccurrences(of: "\r\n", with: "\\r\\n"))")

        let headers = parseHeaders(headerString)

        // Content-Dispositionからnameとfilenameを抽出
        guard let contentDisposition = headers["content-disposition"],
              let name = extractParameterValue(from: contentDisposition, parameter: "name")
        else {
            throw MultipartParseError.missingName
        }

        let filename = extractParameterValue(from: contentDisposition, parameter: "filename")
        let contentType = headers["content-type"]

        let value = MultipartValue(
            data: bodyData,
            filename: filename,
            contentType: contentType
        )

        return (name: name, value: value)
    }

    /// ヘッダー文字列を解析してキー・値のペアにする
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

// MARK: - Extensions

extension Data {
    /// 指定されたデータパターンを検索して範囲を返す（最適化版）
    func range(of data: Data, in range: Range<Int>) -> Range<Int>? {
        // 検索対象のデータが検索範囲より大きい場合は見つからない
        guard range.count >= data.count else {
            return nil
        }

        // Foundation標準のrangeメソッドを使用（内部でより効率的な検索アルゴリズムを使用）
        if let foundRange = self.range(of: data, options: [], in: range) {
            return foundRange.lowerBound ..< foundRange.upperBound
        }

        return nil
    }

    /// 指定されたデータで始まるかチェック
    func starts(with data: Data) -> Bool {
        guard count >= data.count else { return false }
        return prefix(data.count) == data
    }

    /// 指定されたデータで終わるかチェック
    func hasSuffix(_ data: Data) -> Bool {
        guard count >= data.count else { return false }
        return suffix(data.count) == data
    }
}

// MARK: - Error Types

enum MultipartParseError: Error, LocalizedError {
    case invalidHeader
    case missingName
    case invalidBoundary

    var errorDescription: String? {
        switch self {
        case .invalidHeader:
            "Invalid multipart header"
        case .missingName:
            "Missing name parameter in Content-Disposition"
        case .invalidBoundary:
            "Invalid boundary in multipart data"
        }
    }
}
