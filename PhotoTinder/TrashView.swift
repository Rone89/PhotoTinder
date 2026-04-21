import Photos
import PhotosUI
import SwiftUI

struct TrashView: View {
    @Environment(PhotoViewModel.self) private var viewModel

    @State private var showConfirmDeleteAlert = false
    @State private var showDeleteSuccessAlert = false
    @State private var lastDeletedCount = 0
    @State private var selectedItem: PhotoItem?
    @State private var isEditMode = false
    @State private var selectedIds: Set<String> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var trashItems: [PhotoItem] {
        viewModel.allDeletedPhotos
    }

    private var deleteTargetCount: Int {
        if isEditMode && !selectedIds.isEmpty {
            return selectedIds.count
        }
        return trashItems.count
    }

    private var actionTitle: String {
        if isEditMode && !selectedIds.isEmpty {
            return "已选择 \(selectedIds.count) 张"
        }
        return "待处理 \(trashItems.count) 张"
    }

    var body: some View {
        ZStack {
            AmbientBackdrop()

            Group {
                if trashItems.isEmpty {
                    ContentUnavailableView {
                        Label("回收站为空", systemImage: "archivebox")
                    } description: {
                        Text("在审查时标记为删除的照片会出现在这里。")
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            overviewPanel
                            trashGrid
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 150)
                    }
                }
            }
        }
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !trashItems.isEmpty {
                    if isEditMode {
                        Button("取消") {
                            isEditMode = false
                            selectedIds.removeAll()
                        }
                    } else {
                        Button("选择") {
                            isEditMode = true
                        }

                        Menu {
                            Button {
                                viewModel.restoreAllFromTrash()
                            } label: {
                                Label("全部恢复", systemImage: "arrow.uturn.left")
                            }

                            Button(role: .destructive) {
                                showConfirmDeleteAlert = true
                            } label: {
                                Label("全部删除", systemImage: "trash.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
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
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom) {
            if !trashItems.isEmpty {
                actionDock
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
        }
        .alert("确认删除", isPresented: $showConfirmDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                performDelete()
            }
        } message: {
            Text("确定要永久删除 \(deleteTargetCount) 张照片吗？此操作不可撤销。")
        }
        .alert("完成", isPresented: $showDeleteSuccessAlert) {
            Button("好的") {}
        } message: {
            Text("已删除 \(lastDeletedCount) 张照片")
        }
    }

    private var overviewPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("清理总览", systemImage: "tray.full.fill")
                .font(.headline.weight(.semibold))

            Text(actionTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()

            VStack(spacing: 10) {
                StatusRow(title: "操作方式", value: isEditMode ? "多选模式" : "点按进入详情", systemImage: "cursorarrow.click")
                StatusRow(title: "恢复入口", value: "原生底部玻璃按钮", systemImage: "arrow.uturn.backward.circle")
                StatusRow(title: "永久删除", value: "系统确认弹窗", systemImage: "exclamationmark.shield")
            }
        }
        .dashboardPanel()
    }

    private var trashGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(trashItems) { item in
                trashCell(for: item)
            }
        }
    }

    private func trashCell(for item: PhotoItem) -> some View {
        MiniThumbnail(asset: item.asset)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 0.8)
            }
            .overlay(alignment: .topLeading) {
                if isEditMode {
                    checkBadge(for: item)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !isEditMode {
                    if item.asset.mediaSubtypes.contains(.photoLive) {
                        MediaBadge(title: "LIVE", symbol: "livephoto")
                            .padding(8)
                    } else if item.asset.mediaSubtypes.contains(.photoHDR) {
                        MediaBadge(title: "HDR", symbol: nil)
                            .padding(8)
                    }
                }
            }
            .overlay {
                if isEditMode && selectedIds.contains(item.id) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(PhotoTinderPalette.accent.opacity(0.22))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .onTapGesture {
                if isEditMode {
                    toggleSelection(item)
                } else {
                    selectedItem = item
                }
            }
            .contextMenu {
                if !isEditMode {
                    Button {
                        viewModel.restoreFromTrash(item)
                    } label: {
                        Label("移出回收站", systemImage: "arrow.uturn.left")
                    }

                    Button(role: .destructive) {
                        deleteSingle(item)
                    } label: {
                        Label("永久删除", systemImage: "trash.fill")
                    }
                }
            }
    }

    private var actionDock: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                if isEditMode {
                    Button {
                        viewModel.restoreSelectedFromTrash(selectedIds)
                        selectedIds.removeAll()
                        isEditMode = false
                    } label: {
                        Label("移出选中", systemImage: "arrow.uturn.left")
                            .liquidActionLabel(tint: PhotoTinderPalette.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIds.isEmpty)

                    Button(role: .destructive) {
                        showConfirmDeleteAlert = true
                    } label: {
                        Label("删除选中", systemImage: "trash.fill")
                            .liquidActionLabel(tint: PhotoTinderPalette.rose, prominent: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIds.isEmpty)
                } else {
                    Button {
                        viewModel.restoreAllFromTrash()
                    } label: {
                        Label("全部恢复", systemImage: "arrow.counterclockwise")
                            .liquidActionLabel(tint: PhotoTinderPalette.accent)
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        showConfirmDeleteAlert = true
                    } label: {
                        Label("永久删除", systemImage: "trash.fill")
                            .liquidActionLabel(tint: PhotoTinderPalette.rose, prominent: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func checkBadge(for item: PhotoItem) -> some View {
        let selected = selectedIds.contains(item.id)
        return Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(selected ? PhotoTinderPalette.accent : .white)
            .padding(8)
            .glassEffect()
            .padding(6)
    }

    private func toggleSelection(_ item: PhotoItem) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
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

struct TrashDetailView: View {
    let item: PhotoItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var image: UIImage?
    @State private var loadFailed = false
    @State private var livePhotoView: PHLivePhotoView?
    @State private var isLivePhoto = false
    @State private var isPlayingLive = false
    @State private var isHDR = false

    private let sizes: [CGSize] = [
        CGSize(width: 1500, height: 2000),
        PHImageManagerMaximumSize,
        CGSize(width: 600, height: 800)
    ]

    private var photoAspectRatio: CGFloat {
        let width = CGFloat(item.asset.pixelWidth)
        let height = CGFloat(item.asset.pixelHeight)
        guard width > 0, height > 0 else { return 3.0 / 4.0 }
        return width / height
    }

    var body: some View {
        ZStack {
            AmbientBackdrop()

            VStack(spacing: 18) {
                photoArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if image != nil || isLivePhoto {
                    PhotoInfoPanel(asset: item.asset)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .navigationTitle("照片详情")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        onRestore()
                    } label: {
                        Label("移出回收站", systemImage: "arrow.uturn.left")
                            .liquidActionLabel(tint: PhotoTinderPalette.accent)
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("永久删除", systemImage: "trash.fill")
                            .liquidActionLabel(tint: PhotoTinderPalette.rose, prominent: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .task(id: item.id) {
            image = nil
            loadFailed = false
            isLivePhoto = item.asset.mediaSubtypes.contains(.photoLive)
            isHDR = item.asset.mediaSubtypes.contains(.photoHDR)

            if isLivePhoto {
                loadLivePhoto()
            } else {
                let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
                if let result {
                    image = result
                } else {
                    loadFailed = true
                }
            }
        }
    }

    private var photoArea: some View {
        ZStack {
            if isLivePhoto, let livePhotoView {
                LivePhotoViewRepresentable(livePhotoView: livePhotoView, isPlaying: $isPlayingLive)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if loadFailed {
                errorContent
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            if isLivePhoto || isHDR {
                VStack {
                    HStack(spacing: 8) {
                        if isLivePhoto {
                            MediaBadge(title: "LIVE", symbol: "livephoto")
                        }

                        if isHDR {
                            MediaBadge(title: "HDR", symbol: nil)
                        }

                        Spacer()
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .aspectRatio(photoAspectRatio, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.28))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 0.9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 28, y: 18)
        .onLongPressGesture(minimumDuration: 0.1) {
            if isLivePhoto {
                isPlayingLive = true
            }
        } onPressingChanged: { pressing in
            if !pressing && isPlayingLive {
                isPlayingLive = false
            }
        }
    }

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
                view.isMuted = false
                self.livePhotoView = view
            }
        }
    }

    private var errorContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("无法加载此照片")
                .foregroundStyle(.secondary)
        }
    }
}
