import Foundation
import Photos
import UIKit

/// 写真・動画のメディアタイプを表す列挙型
enum MediaType: String, CaseIterable {
    case photo
    case video

    var displayName: String {
        switch self {
        case .photo:
            "写真"
        case .video:
            "動画"
        }
    }
}

/// アップロード対象のメディアアセット情報
struct MediaAsset: Identifiable, Hashable {
    let id = UUID()
    let asset: PHAsset
    let mediaType: MediaType

    var filename: String {
        asset.value(forKey: "filename") as? String ?? "unknown"
    }

    var creationDate: Date {
        asset.creationDate ?? Date()
    }

    var duration: TimeInterval? {
        guard mediaType == .video else { return nil }
        return asset.duration
    }

    var isSelected: Bool = false

    init(asset: PHAsset) {
        self.asset = asset
        switch asset.mediaType {
        case .image:
            self.mediaType = .photo
        case .video:
            self.mediaType = .video
        default:
            self.mediaType = .photo
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(asset.localIdentifier)
    }

    static func == (lhs: MediaAsset, rhs: MediaAsset) -> Bool {
        lhs.asset.localIdentifier == rhs.asset.localIdentifier
    }
}

/// アップロード進捗を表す状態
enum UploadStatus: Equatable {
    case waiting
    case uploading(progress: Double)
    case completed
    case failed(error: String)

    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }

    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    var isUploading: Bool {
        if case .uploading = self {
            return true
        }
        return false
    }
}

/// アップロード対象のメディアアイテム
struct MediaUploadItem: Identifiable {
    let id = UUID()
    let asset: MediaAsset
    var status: UploadStatus = .waiting
    var serverMediaId: String?

    init(asset: MediaAsset) {
        self.asset = asset
    }
}

/// アップロード用のメディアデータ
struct MediaUploadData {
    let data: Data
    let filename: String
    let mimeType: String
    let mediaType: MediaType
    let fileSize: Int
    let timestamp: Date
}

/// アップロード統計情報
struct UploadStatistics {
    var totalCount: Int = 0
    var completedCount: Int = 0
    var failedCount: Int = 0
    var totalBytes: Int64 = 0
    var uploadedBytes: Int64 = 0

    var progressPercentage: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(completedCount) / Double(totalCount)
    }

    var isCompleted: Bool {
        completedCount == totalCount
    }

    var remainingCount: Int {
        totalCount - completedCount - failedCount
    }
}
