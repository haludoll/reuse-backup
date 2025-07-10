import Foundation
import Photos
import UIKit

/// フォトライブラリアクセス権限のエラー
enum PhotoLibraryError: LocalizedError {
    case accessDenied
    case limited
    case fetchFailed
    case exportFailed(String)
    case unsupportedMediaType

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "フォトライブラリへのアクセスが拒否されました"
        case .limited:
            "フォトライブラリへのアクセスが制限されています"
        case .fetchFailed:
            "写真・動画の取得に失敗しました"
        case let .exportFailed(details):
            "メディアのエクスポートに失敗しました: \(details)"
        case .unsupportedMediaType:
            "サポートされていないメディアタイプです"
        }
    }
}

/// フォトライブラリ管理クラス
@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var mediaAssets: [MediaAsset] = []
    @Published var isLoading = false

    private let imageManager = PHCachingImageManager()

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// フォトライブラリへのアクセス権限を要求
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status

        switch status {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    /// 最新の写真・動画を取得
    func fetchRecentMedia(limit: Int = 100) async throws {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotoLibraryError.accessDenied
        }

        isLoading = true
        defer { isLoading = false }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)

        var assets: [MediaAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image || asset.mediaType == .video {
                assets.append(MediaAsset(asset: asset))
            }
        }

        mediaAssets = assets
    }

    /// 指定した期間の写真・動画を取得
    func fetchMediaInDateRange(from startDate: Date, to endDate: Date) async throws {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotoLibraryError.accessDenied
        }

        isLoading = true
        defer { isLoading = false }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)

        var assets: [MediaAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image || asset.mediaType == .video {
                assets.append(MediaAsset(asset: asset))
            }
        }

        mediaAssets = assets
    }

    /// サムネイル画像を取得
    func requestThumbnail(for asset: MediaAsset, size: CGSize = CGSize(width: 150, height: 150)) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// メディアデータをエクスポート
    func exportMediaData(for asset: MediaAsset) async throws -> MediaUploadData {
        switch asset.mediaType {
        case .photo:
            try await exportPhotoData(for: asset)
        case .video:
            try await exportVideoData(for: asset)
        }
    }

    /// 写真データをエクスポート
    private func exportPhotoData(for asset: MediaAsset) async throws -> MediaUploadData {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImageDataAndOrientation(for: asset.asset, options: options) { data, dataUTI, _, _ in
                guard let data else {
                    continuation.resume(throwing: PhotoLibraryError.exportFailed("Failed to get image data"))
                    return
                }

                guard let uti = dataUTI else {
                    continuation.resume(throwing: PhotoLibraryError.exportFailed("Failed to get image UTI"))
                    return
                }

                let mimeType = self.mimeType(for: uti)
                let filename = asset.filename.isEmpty ? "photo_\(asset.asset.localIdentifier)" : asset.filename

                let uploadData = MediaUploadData(
                    data: data,
                    filename: filename,
                    mimeType: mimeType,
                    mediaType: .photo,
                    fileSize: data.count,
                    timestamp: asset.creationDate
                )

                continuation.resume(returning: uploadData)
            }
        }
    }

    /// 動画データをエクスポート
    private func exportVideoData(for asset: MediaAsset) async throws -> MediaUploadData {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: asset.asset, options: options) { avAsset, _, _ in
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: PhotoLibraryError.exportFailed("Failed to get video URL"))
                    return
                }

                do {
                    let data = try Data(contentsOf: urlAsset.url)
                    let filename = asset.filename.isEmpty ? "video_\(asset.asset.localIdentifier).mov" : asset.filename

                    let uploadData = MediaUploadData(
                        data: data,
                        filename: filename,
                        mimeType: "video/quicktime",
                        mediaType: .video,
                        fileSize: data.count,
                        timestamp: asset.creationDate
                    )

                    continuation.resume(returning: uploadData)
                } catch {
                    continuation.resume(throwing: PhotoLibraryError.exportFailed(error.localizedDescription))
                }
            }
        }
    }

    /// UTIからMIMEタイプを取得
    private func mimeType(for uti: String) -> String {
        switch uti {
        case "public.jpeg":
            "image/jpeg"
        case "public.png":
            "image/png"
        case "public.heic":
            "image/heic"
        case "com.compuserve.gif":
            "image/gif"
        case "org.webmproject.webp":
            "image/webp"
        case "com.apple.quicktime-movie":
            "video/quicktime"
        case "public.mpeg-4":
            "video/mp4"
        default:
            "application/octet-stream"
        }
    }
}
