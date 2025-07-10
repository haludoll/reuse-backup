import Photos
import SwiftUI

struct MediaSelectionView: View {
    @ObservedObject var viewModel: MediaUploadViewModel
    @State private var selectedAssets: Set<MediaAsset> = []
    @State private var showingDatePicker = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()

    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 2),
    ]

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.photoLibraryAuthorizationStatus == .denied {
                    accessDeniedView
                } else if viewModel.photoLibraryAuthorizationStatus == .notDetermined {
                    requestAccessView
                } else {
                    mediaGridView
                }
            }
            .navigationTitle("写真・動画選択")
            .navigationBarItems(
                leading: Button("日付で絞り込み") {
                    showingDatePicker = true
                },
                trailing: addSelectedButton
            )
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
            .task {
                if viewModel.photoLibraryAuthorizationStatus == .authorized ||
                    viewModel.photoLibraryAuthorizationStatus == .limited
                {
                    await viewModel.fetchRecentMedia()
                }
            }
            .onChange(of: viewModel.photoLibraryAuthorizationStatus) { status in
                Task {
                    if status == .authorized || status == .limited {
                        await viewModel.fetchRecentMedia()
                    }
                }
            }
        }
    }

    private var accessDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("フォトライブラリへのアクセスが拒否されています")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("設定アプリでこのアプリの写真アクセス権限を許可してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("設定を開く") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var requestAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("写真・動画アクセス許可")
                .font(.headline)

            Text("バックアップする写真や動画を選択するため、フォトライブラリへのアクセスを許可してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("アクセスを許可") {
                Task {
                    await viewModel.requestPhotoLibraryAccess()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var mediaGridView: some View {
        VStack {
            if viewModel.isLoadingPhotoLibrary {
                ProgressView("写真・動画を読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.photoLibraryAssets.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("写真・動画が見つかりません")
                        .font(.headline)

                    Button("再読み込み") {
                        Task {
                            await viewModel.fetchRecentMedia()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(viewModel.photoLibraryAssets) { asset in
                            MediaThumbnailView(
                                asset: asset,
                                isSelected: selectedAssets.contains(asset),
                                viewModel: viewModel
                            ) {
                                toggleSelection(asset)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }

                if !selectedAssets.isEmpty {
                    selectedCountView
                }
            }
        }
    }

    private var selectedCountView: some View {
        HStack {
            Text("\(selectedAssets.count)個選択中")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("すべて解除") {
                selectedAssets.removeAll()
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var addSelectedButton: some View {
        Button("追加 (\(selectedAssets.count))") {
            viewModel.addMediaAssets(Array(selectedAssets))
            selectedAssets.removeAll()
        }
        .disabled(selectedAssets.isEmpty)
    }

    private var datePickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                DatePicker("終了日", selection: $endDate, displayedComponents: .date)

                Spacer()
            }
            .padding()
            .navigationTitle("期間を選択")
            .navigationBarItems(
                leading: Button("キャンセル") {
                    showingDatePicker = false
                },
                trailing: Button("適用") {
                    Task {
                        await viewModel.fetchMediaInDateRange(from: startDate, to: endDate)
                        showingDatePicker = false
                    }
                }
            )
        }
    }

    private func toggleSelection(_ asset: MediaAsset) {
        if selectedAssets.contains(asset) {
            selectedAssets.remove(asset)
        } else {
            selectedAssets.insert(asset)
        }
    }
}

struct MediaThumbnailView: View {
    let asset: MediaAsset
    let isSelected: Bool
    let viewModel: MediaUploadViewModel
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }

            // 動画の場合は再生時間を表示
            if asset.mediaType == .video, let duration = asset.duration {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
            }

            // 選択状態の表示
            if isSelected {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .background(Color.white)
                            .clipShape(Circle())
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
        .onTapGesture {
            onTap()
        }
        .task {
            thumbnail = await viewModel.getThumbnail(for: asset)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MediaSelectionView(viewModel: MediaUploadViewModel())
}
