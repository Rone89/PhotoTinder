import SwiftUI
import Photos
import PhotosUI

struct TrashView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @State private var showConfirmDeleteAlert = false
    @State private var showDeleteSuccessAlert = false
    @State private var lastDeletedCount = 0
    @State private var selectedItem: PhotoItem?
    @State private var isEditMode = false
    @State private var selectedIds: Set<String> = []

    let columns = [GridItem(.adaptive(minimum: 90), spacing: 2)]

    private var trashItems: [PhotoItem] { viewModel.allDeletedPhotos }

    private var deleteTargetCount: Int {
        if isEditMode && !selectedIds.isEmpty { return selectedIds.count }
        return trashItems.count
    }

    var body: some View {
        Group {
            if trashItems.isEmpty {
                emptyTrashView
            } else {
                trashGrid
            }
        }
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isEditMode {
                    if !selectedIds.isEmpty {
                        Button {
                            viewModel.restoreSelectedFromTrash(selectedIds)
                            selectedIds.removeAll()
                            isEditMode = false
                        } label: {
                            Label("移出", systemImage: "arrow.uturn.left.circle")
                                .font(.subheadline).foregroundColor(.blue)
                        }
                        Button(role: .destructive) {
                            showConfirmDeleteAlert = true
                        } label: {
                            Label("删除", systemImage: "trash.fill")
                                .font(.subheadline)
                        }
                    }
                    Button("取消") {
                        isEditMode = false
                        selectedIds.removeAll()
                    }
                } else if !trashItems.isEmpty {
                    Button {
                        viewModel.restoreAllFromTrash()
                    } label: {
                        Label("全部恢复", systemImage: "arrow.uturn.left")
                            .font(.subheadline)
                    }

                    Button {
                        isEditMode = true
                    } label: {
                        Label("选择", systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }

                    Button(role: .destructive) {
                        showConfirmDeleteAlert = true
                    } label: {
                        Label("全部删除", systemImage: "trash.fill")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationDestination(item: $selectedItem) { item in
            TrashDetailView(
                item: item,
                onRestore: {
                    viewModel.restoreFromTrash(item)
                    selectedItem = nil
                },
                onDelete: {
                    deleteSingle(item)
                    selectedItem = nil
                }
            )
        }
        .alert("确认删除", isPresented: $showConfirmDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { performDelete() }
        } message: {
            Text("确定要永久删除 \(deleteTargetCount) 张照片吗？此操作不可撤销。")
        }
        .alert("完成", isPresented: $showDeleteSuccessAlert) {
            Button("好的") {}
        } message: {
            Text("已删除 \(lastDeletedCount) 张照片")
        }
    }

    // MARK: - 空状态

    private var emptyTrashView: some View {
        ContentUnavailableView {
            Label("回收站为空", systemImage: "archivebox")
        } description: {
            Text("在审查时标记为删除的照片会出现在这里")
        }
    }

    // MARK: - 照片网格

    private var trashGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(trashItems) { item in
                    MiniThumbnail(asset: item.asset)
                        .overlay(alignment: .topLeading) {
                            if isEditMode { checkBadge(item) }
                        }
                        // Live Photo 小标记
                        .overlay(alignment: .topTrailing) {
                            if !isEditMode && item.asset.mediaSubtypes.contains(.photoLive) {
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(.black.opacity(0.4)))
                                    .padding(4)
                            }
                        }
                        .overlay {
                            if isEditMode && selectedIds.contains(item.id) {
                                Color.blue.opacity(0.3)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .onTapGesture {
                            if isEditMode {
                                toggleSelection(item)
                            } else {
                                selectedItem = item
                            }
                        }
                        .contextMenu {
                            if !isEditMode {
                                Button { viewModel.restoreFromTrash(item) } label: {
                                    Label("移出回收站", systemImage: "arrow.uturn.left")
                                }
                                Button(role: .destructive) { deleteSingle(item) } label: {
                                    Label("永久删除", systemImage: "trash.fill")
                                }
                            }
                        }
                }
            }
            .padding()
            .frame(maxWidth: 600) // iPhone Air 适配

            statsBar
                .padding(.horizontal)
                .padding(.vertical, 16)
                .frame(maxWidth: 600)
        }
    }

    // MARK: - 底部统计

    private var statsBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(trashItems.count)")
                        .font(.title2.bold())
                        .foregroundColor(.red)
                    Text("待删除")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    showConfirmDeleteAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("全部永久删除")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.gradient, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.restoreAllFromTrash()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("全部恢复")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(.systemBackground).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.06), radius: 8))
    }

    private func checkBadge(_ item: PhotoItem) -> some View {
        let sel = selectedIds.contains(item.id)
        return Image(systemName: sel ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(sel ? Color.blue : Color.white)
            .shadow(color: .black.opacity(0.15), radius: 1)
            .padding(4)
    }

    private func toggleSelection(_ item: PhotoItem) {
        if selectedIds.contains(item.id) { selectedIds.remove(item.id) }
        else { selectedIds.insert(item.id) }
    }

    private func deleteSingle(_ item: PhotoItem) {
        Task {
            await viewModel.deleteItemsFromTrash([item])
            lastDeletedCount = 1
            showDeleteSuccessAlert = true
        }
    }

    private func performDelete() {
        if isEditMode && !selectedIds.isEmpty {
            let items = trashItems.filter { selectedIds.contains($0.id) }
            Task {
                await viewModel.deleteItemsFromTrash(items)
                lastDeletedCount = items.count
                showDeleteSuccessAlert = true
            }
            selectedIds.removeAll()
            isEditMode = false
        } else {
            let count = trashItems.count
            Task {
                await viewModel.deleteAllFromTrash()
                lastDeletedCount = count
                showDeleteSuccessAlert = true
            }
        }
    }
}

// MARK: - 回收站详情页（支持 Live Photo 长按播放，无缩放）

struct TrashDetailView: View {
    let item: PhotoItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var image: UIImage?
    @State private var loadFailed = false
    @State private var livePhotoView: PHLivePhotoView?
    @State private var isLivePhoto = false
    @State private var isPlayingLive = false

    private let sizes: [CGSize] = [
        CGSize(width: 1500, height: 2000),
        PHImageManagerMaximumSize,
        CGSize(width: 600, height: 800)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 照片区域
                ZStack {
                    if isLivePhoto, let livePhotoView {
                        LivePhotoViewRepresentable(livePhotoView: livePhotoView, isPlaying: $isPlayingLive)
                    } else if let ui = image {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                    } else if loadFailed {
                        errorContent
                    } else {
                        ProgressView().controlSize(.large).tint(.white)
                    }

                    // LIVE 标记
                    if isLivePhoto {
                        VStack {
                            HStack {
                                liveBadge
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(12)
                    }
                }
                .frame(maxHeight: .infinity)
                // 长按播放 Live Photo
                .onLongPressGesture(minimumDuration: 0.1) {
                    if isLivePhoto { isPlayingLive = true }
                } onPressingChanged: { pressing in
                    if !pressing && isPlayingLive { isPlayingLive = false }
                }

                // 照片信息面板
                if image != nil || isLivePhoto {
                    PhotoInfoPanel(asset: item.asset)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: 600) // iPhone Air 适配
        }
        .navigationTitle("照片详情")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { onRestore() } label: {
                        Label("移出回收站", systemImage: "arrow.uturn.left")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("永久删除", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
        }
        .task(id: item.id) {
            image = nil
            loadFailed = false
            isLivePhoto = item.asset.mediaSubtypes.contains(.photoLive)

            if isLivePhoto {
                loadLivePhoto()
            } else {
                let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
                if let result { image = result }
                else { loadFailed = true }
            }
        }
    }

    // MARK: - LIVE 标记

    private var liveBadge: some View {
        Text("LIVE")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(1.2)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.black.opacity(0.5))
                    .blur(radius: 1)
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
            )
    }

    // MARK: - 加载 Live Photo

    private func loadLivePhoto() {
        let targetSize = CGSize(width: 1024, height: 1024)
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestLivePhoto(
            for: item.asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { livePhoto, _ in
            guard let livePhoto else { return }
            DispatchQueue.main.async {
                let view = PHLivePhotoView()
                view.contentMode = .scaleAspectFit
                view.livePhoto = livePhoto
                view.isMuted = true
                self.livePhotoView = view
            }
        }
    }

    private var errorContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.5))
            Text("无法加载此照片")
                .foregroundColor(.white.opacity(0.5))
        }
    }
}
