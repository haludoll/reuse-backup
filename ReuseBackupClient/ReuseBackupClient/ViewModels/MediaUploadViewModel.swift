import Foundation
import Photos
import SwiftUI

@MainActor
class MediaUploadViewModel: ObservableObject {
    @Published var uploadItems: [MediaUploadItem] = []
    @Published var statistics = UploadStatistics()
    @Published var isUploading = false
    @Published var errorMessage: String?
    @Published var selectedServerURL: URL?

    private let photoLibraryManager = PhotoLibraryManager()
    private let httpClient = HTTPClient()

    var canStartUpload: Bool {
        !uploadItems.isEmpty && selectedServerURL != nil && !isUploading
    }

    /// 選択されたメディアアセットを追加
    func addMediaAssets(_ assets: [MediaAsset]) {
        let newItems = assets.map { MediaUploadItem(asset: $0) }
        uploadItems.append(contentsOf: newItems)
        updateStatistics()
    }

    /// アップロードアイテムを削除
    func removeUploadItem(_ item: MediaUploadItem) {
        uploadItems.removeAll { $0.id == item.id }
        updateStatistics()
    }

    /// すべてのアップロードアイテムを削除
    func clearAllItems() {
        uploadItems.removeAll()
        updateStatistics()
    }

    /// アップロード統計を更新
    private func updateStatistics() {
        statistics.totalCount = uploadItems.count
        statistics.completedCount = uploadItems.filter(\.status.isCompleted).count
        statistics.failedCount = uploadItems.filter(\.status.isFailed).count

        // ファイルサイズの計算（概算）
        statistics.totalBytes = Int64(uploadItems.count * 5_000_000) // 平均5MBと仮定
        statistics.uploadedBytes = Int64(statistics.completedCount * 5_000_000)
    }

    /// アップロードを開始
    func startUpload() async {
        guard canStartUpload else { return }

        isUploading = true
        errorMessage = nil

        // 待機中のアイテムを取得
        let pendingItems = uploadItems.filter { $0.status == .waiting }

        for item in pendingItems {
            if !isUploading { break } // キャンセルされた場合

            await uploadSingleItem(item)
            updateStatistics()
        }

        isUploading = false
    }

    /// 単一アイテムのアップロード
    private func uploadSingleItem(_ item: MediaUploadItem) async {
        guard let serverURL = selectedServerURL else { return }

        // アイテムのインデックスを取得
        guard let index = uploadItems.firstIndex(where: { $0.id == item.id }) else { return }

        do {
            // アップロード開始状態に更新
            uploadItems[index].status = .uploading(progress: 0.0)

            // メディアデータをエクスポート
            let mediaData = try await photoLibraryManager.exportMediaData(for: item.asset)

            // アップロード実行
            let response = try await httpClient.uploadMedia(
                baseURL: serverURL,
                mediaData: mediaData
            ) { progress in
                Task { @MainActor in
                    if let currentIndex = self.uploadItems.firstIndex(where: { $0.id == item.id }) {
                        self.uploadItems[currentIndex].status = .uploading(progress: progress)
                    }
                }
            }

            // 成功時の処理
            uploadItems[index].status = .completed
            uploadItems[index].serverMediaId = response.mediaId

        } catch {
            // エラー時の処理
            uploadItems[index].status = .failed(error: error.localizedDescription)
            errorMessage = "アップロードエラー: \(error.localizedDescription)"
        }
    }

    /// アップロードを停止
    func stopUpload() {
        isUploading = false
    }

    /// 失敗したアイテムを再試行
    func retryFailedItems() async {
        let failedItems = uploadItems.filter(\.status.isFailed)

        for item in failedItems {
            if let index = uploadItems.firstIndex(where: { $0.id == item.id }) {
                uploadItems[index].status = .waiting
            }
        }

        if !failedItems.isEmpty {
            await startUpload()
        }
    }

    /// サーバーURLを設定
    func setServerURL(_ url: URL) {
        selectedServerURL = url
    }

    /// フォトライブラリアクセス権限を要求
    func requestPhotoLibraryAccess() async -> Bool {
        await photoLibraryManager.requestAuthorization()
    }

    /// 最新メディアを取得
    func fetchRecentMedia(limit: Int = 50) async {
        do {
            try await photoLibraryManager.fetchRecentMedia(limit: limit)
        } catch {
            errorMessage = "メディア取得エラー: \(error.localizedDescription)"
        }
    }

    /// 指定期間のメディアを取得
    func fetchMediaInDateRange(from startDate: Date, to endDate: Date) async {
        do {
            try await photoLibraryManager.fetchMediaInDateRange(from: startDate, to: endDate)
        } catch {
            errorMessage = "メディア取得エラー: \(error.localizedDescription)"
        }
    }

    /// サムネイル画像を取得
    func getThumbnail(for asset: MediaAsset) async -> UIImage? {
        await photoLibraryManager.requestThumbnail(for: asset)
    }

    /// フォトライブラリのメディアアセットを取得
    var photoLibraryAssets: [MediaAsset] {
        photoLibraryManager.mediaAssets
    }

    /// フォトライブラリの読み込み状態
    var isLoadingPhotoLibrary: Bool {
        photoLibraryManager.isLoading
    }

    /// フォトライブラリのアクセス権限状態
    var photoLibraryAuthorizationStatus: PHAuthorizationStatus {
        photoLibraryManager.authorizationStatus
    }
}
