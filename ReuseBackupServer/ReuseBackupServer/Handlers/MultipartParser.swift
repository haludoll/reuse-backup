import Foundation

/// マルチパートフォームデータ解析クラス
struct MultipartParser {
    private let boundary: String
    private let boundaryData: Data
    private let finalBoundaryData: Data
    
    init(boundary: String) {
        self.boundary = boundary
        self.boundaryData = "--\(boundary)".data(using: .utf8)!
        self.finalBoundaryData = "--\(boundary)--".data(using: .utf8)!
    }
    
    /// マルチパートデータを解析して辞書形式で返す
    func parse(data: Data) throws -> [String: MultipartValue] {
        var result: [String: MultipartValue] = [:]
        
        // データをboundaryで分割
        let parts = splitByBoundary(data: data)
        
        for partData in parts {
            if let part = try parsePartData(partData) {
                result[part.name] = part.value
            }
        }
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// データをboundaryで分割
    private func splitByBoundary(data: Data) -> [Data] {
        var parts: [Data] = []
        var currentIndex = 0
        
        while currentIndex < data.count {
            // boundary の開始位置を検索
            guard let boundaryRange = data.range(of: boundaryData, in: currentIndex..<data.count) else {
                break
            }
            
            // 次のboundaryまたは終了boundaryを検索
            let searchStart = boundaryRange.upperBound
            var nextBoundaryRange: Range<Int>?
            
            // 通常のboundaryを検索
            if let range = data.range(of: boundaryData, in: searchStart..<data.count) {
                nextBoundaryRange = range
            }
            
            // 終了boundaryも検索
            if let finalRange = data.range(of: finalBoundaryData, in: searchStart..<data.count) {
                if nextBoundaryRange == nil || finalRange.lowerBound < nextBoundaryRange!.lowerBound {
                    nextBoundaryRange = finalRange
                }
            }
            
            if let nextRange = nextBoundaryRange {
                // CRLFを考慮してpartデータを抽出
                let partStart = boundaryRange.upperBound
                let partEnd = nextRange.lowerBound
                
                if partStart < partEnd {
                    var partData = data.subdata(in: partStart..<partEnd)
                    
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
                    }
                }
                
                currentIndex = nextRange.upperBound
            } else {
                break
            }
        }
        
        return parts
    }
    
    /// 個別のpartデータを解析
    private func parsePartData(_ data: Data) throws -> (name: String, value: MultipartValue)? {
        // ヘッダーとボディを分離（空行で分割）
        let headerBodySeparator = "\r\n\r\n".data(using: .utf8)!
        guard let separatorRange = data.range(of: headerBodySeparator) else {
            // ヘッダーのみでボディがない場合はスキップ
            return nil
        }
        
        let headerData = data.subdata(in: 0..<separatorRange.lowerBound)
        let bodyData = data.subdata(in: separatorRange.upperBound..<data.count)
        
        // ヘッダーを解析
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw MultipartParseError.invalidHeader
        }
        
        let headers = parseHeaders(headerString)
        
        // Content-Dispositionからnameとfilenameを抽出
        guard let contentDisposition = headers["content-disposition"],
              let name = extractParameterValue(from: contentDisposition, parameter: "name") else {
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
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
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
    /// 指定されたデータパターンを検索して範囲を返す
    func range(of data: Data, in range: Range<Int>) -> Range<Int>? {
        let searchData = subdata(in: range)
        
        // 検索対象のデータが検索範囲より大きい場合は見つからない
        guard searchData.count >= data.count else {
            return nil
        }
        
        for i in 0..<searchData.count - data.count + 1 {
            let candidateRange = i..<i + data.count
            let candidate = searchData.subdata(in: candidateRange)
            
            if candidate == data {
                return (range.lowerBound + i)..<(range.lowerBound + i + data.count)
            }
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
            return "Invalid multipart header"
        case .missingName:
            return "Missing name parameter in Content-Disposition"
        case .invalidBoundary:
            return "Invalid boundary in multipart data"
        }
    }
}