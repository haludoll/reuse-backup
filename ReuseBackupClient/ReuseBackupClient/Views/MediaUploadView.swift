import SwiftUI

struct MediaUploadView: View {
    @StateObject private var viewModel = MediaUploadViewModel()
    @StateObject private var serverDiscovery = ServerDiscoveryManager()
    @State private var showingMediaSelection = false
    @State private var showingServerSelection = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                serverSelectionSection
                uploadQueueSection
                uploadControlsSection
                statisticsSection

                Spacer()
            }
            .padding()
            .navigationTitle("メディアアップロード")
            .navigationBarItems(
                trailing: Button("写真・動画を選択") {
                    showingMediaSelection = true
                }
                .disabled(viewModel.selectedServerURL == nil)
            )
            .sheet(isPresented: $showingMediaSelection) {
                MediaSelectionView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingServerSelection) {
                ServerSelectionSheet(
                    serverDiscovery: serverDiscovery,
                    onServerSelected: { url in
                        viewModel.setServerURL(url)
                        showingServerSelection = false
                    }
                )
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private var serverSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("サーバー選択")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    if let serverURL = viewModel.selectedServerURL {
                        Text(serverURL.absoluteString)
                            .font(.body)
                            .foregroundColor(.primary)
                        Text("接続中のサーバー")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("サーバーが選択されていません")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("選択") {
                    showingServerSelection = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private var uploadQueueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("アップロード待ち")
                    .font(.headline)

                Spacer()

                if !viewModel.uploadItems.isEmpty {
                    Button("すべて削除") {
                        viewModel.clearAllItems()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            if viewModel.uploadItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("アップロード対象がありません")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("右上の「写真・動画を選択」ボタンから追加してください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.uploadItems) { item in
                            UploadItemRow(
                                item: item,
                                viewModel: viewModel,
                                onRemove: {
                                    viewModel.removeUploadItem(item)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    private var uploadControlsSection: some View {
        VStack(spacing: 12) {
            if viewModel.isUploading {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.statistics.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle())

                    HStack {
                        Text("アップロード中...")
                            .font(.body)

                        Spacer()

                        Text("\(viewModel.statistics.completedCount)/\(viewModel.statistics.totalCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button("停止") {
                    viewModel.stopUpload()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            } else {
                HStack(spacing: 12) {
                    Button("アップロード開始") {
                        Task {
                            await viewModel.startUpload()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStartUpload)

                    if viewModel.statistics.failedCount > 0 {
                        Button("失敗分を再試行") {
                            Task {
                                await viewModel.retryFailedItems()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("統計情報")
                .font(.headline)

            VStack(spacing: 4) {
                StatisticRow(label: "総数", value: "\(viewModel.statistics.totalCount)個")
                StatisticRow(label: "完了", value: "\(viewModel.statistics.completedCount)個")

                if viewModel.statistics.failedCount > 0 {
                    StatisticRow(
                        label: "失敗",
                        value: "\(viewModel.statistics.failedCount)個",
                        valueColor: .red
                    )
                }

                StatisticRow(
                    label: "進捗",
                    value: String(format: "%.1f%%", viewModel.statistics.progressPercentage * 100)
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct UploadItemRow: View {
    let item: MediaUploadItem
    let viewModel: MediaUploadViewModel
    let onRemove: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)

                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }

                // メディアタイプのアイコン
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: item.asset.mediaType == .video ? "video.fill" : "photo.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(2)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(4)
            }

            // ファイル情報
            VStack(alignment: .leading, spacing: 4) {
                Text(item.asset.filename)
                    .font(.body)
                    .lineLimit(1)

                Text(item.asset.mediaType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // ステータス表示
                statusView
            }

            Spacer()

            // 削除ボタン
            if !item.status.isUploading {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .task {
            thumbnail = await viewModel.getThumbnail(for: item.asset)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .waiting:
            Text("待機中")
                .font(.caption)
                .foregroundColor(.blue)
        case let .uploading(progress):
            HStack(spacing: 4) {
                ProgressView(value: progress)
                    .scaleEffect(0.8)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("完了")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case let .failed(error):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text("失敗")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

struct StatisticRow: View {
    let label: String
    let value: String
    let valueColor: Color

    init(label: String, value: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundColor(valueColor)
        }
    }
}

struct ServerSelectionSheet: View {
    @ObservedObject var serverDiscovery: ServerDiscoveryManager
    let onServerSelected: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if serverDiscovery.discoveredServers.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("サーバーを検索中...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(serverDiscovery.discoveredServers, id: \.name) { server in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.name)
                                .font(.headline)
                            Text(server.address)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: "http://\(server.address):\(server.port)") {
                                onServerSelected(url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("サーバー選択")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                }
            )
        }
        .onAppear {
            serverDiscovery.startDiscovery()
        }
        .onDisappear {
            serverDiscovery.stopDiscovery()
        }
    }
}

#Preview {
    MediaUploadView()
}
