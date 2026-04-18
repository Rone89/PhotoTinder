import SwiftUI
import Photos

struct TrashView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss

    @State private var showConfirmDeleteAlert = false
    @State private var showDeleteSuccessAlert = false
    @State private var lastDeletedCount = 0
    @State private var selectedItem: PhotoItem?
    @State private var isEditMode = false
    @State private var selectedIds: Set<String> = []

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    private var trashItems: [PhotoItem] { viewModel.allDeletedPhotos }

    private var deleteTargetCount: Int {
        if isEditMode && !selectedIds.isEmpty { return selectedIds.count }
        return trashItems.count
    }

    var body: some View {
        Group {
            if trashItems.isEmpty {
                ContentUnavailableView {
                    Label("回收站为空", systemImage: "archivebox")
                } description: {
                    Text("没有待删除的照片")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(trashItems) { item in
                            ThumbnailView(asset: item.asset)
                                .overlay(alignment: .topLeading) {
                                    if isEditMode { checkBadge(item) }
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
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isEditMode ? "取消" : "完成") {
                    if isEditMode {
                        isEditMode = false
                        selectedIds.removeAll()
                    } else {
                        dismiss()
                    }
                }
            }
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
                } else if !trashItems.isEmpty {
                    Button {
                        viewModel.restoreAllFromTrash()
                    } label: {
                        Label("全部恢复", systemImage: "arrow.uturn.left.circle")
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
        // 大图查看 — 用 NavigationLink 而非 fullScreenCover
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

    private func checkBadge(_ item: PhotoItem) -> some View {
        let sel = selectedIds.contains(item.id)
        return Image(systemName: sel ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(sel ? .blue : .white)
            .background(Circle().fill(.white).shadow(radius: 1).padding(1))
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

// MARK: - ZoomableImageView（照片自由缩放查看器）

struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// 计算图片在容器内的实际显示尺寸（1x 时）
    private func calculateImageSize(in container: CGSize) -> CGSize {
        let imgAspect = image.size.width / image.size.height
        let boxAspect = container.width / container.height

        if imgAspect > boxAspect {
            return CGSize(width: container.width, height: container.width / imgAspect)
        } else {
            return CGSize(width: container.height * imgAspect, height: container.height)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let displaySize = calculateImageSize(in: geo.size)

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: displaySize.width, height: displaySize.height)
                .scaleEffect(scale, anchor: .center)
                .offset(offset)
                .gesture(magnificationGesture)
                .simultaneousGesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.85), value: scale)
        }
    }

    // MARK: - 手势

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 8.0)
            }
            .onEnded { value in
                if scale < 1.1 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                } else {
                    lastScale = scale
                    lastOffset = offset
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                if scale > 1.0 {
                    lastOffset = offset
                }
            }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - TrashDetailView（NavigationLink 目标页面，自动带返回按钮）

struct TrashDetailView: View {
    let item: PhotoItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var image: UIImage?
    @State private var loadFailed = false

    private let sizes: [CGSize] = [
        CGSize(width: 1500, height: 2000),
        PHImageManagerMaximumSize,
        CGSize(width: 600, height: 800)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let ui = image {
                ZoomableImageView(image: ui)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.6))
                    Text("无法加载此照片")
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                ProgressView().scaleEffect(2).tint(.white)
            }
        }
        .navigationTitle("照片详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        onRestore()
                    } label: {
                        Label("移出回收站", systemImage: "arrow.uturn.left")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("永久删除", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .task(id: item.id) {
            image = nil
            loadFailed = false
            let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
            if let result { image = result }
            else { loadFailed = true }
        }
    }
}
