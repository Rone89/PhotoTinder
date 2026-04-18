import SwiftUI
import Photos

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
                    .glassEffect(.regular.interactive())
                    
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
        // 大图查看
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
            
            // 统计信息栏
            statsBar
                .padding(.horizontal)
                .padding(.vertical, 16)
        }
    }

    // MARK: - 底部统计

    private var statsBar: some View {
        GlassEffectContainer(spacing: 12) {
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
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
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

// MARK: - ZoomableImageView（回收站大图查看 — 自由缩放）

struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var translation: CGSize = .zero
    @State private var lastTranslation: CGSize = .zero

    /// 计算图片在容器内的基础显示尺寸（fit 模式）
    private func fittedSize(in container: CGSize) -> CGSize {
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
            let baseSize = fittedSize(in: geo.size)

            Image(uiImage: image)
                .resizable()
                .frame(width: baseSize.width, height: baseSize.height)
                .scaleEffect(scale, anchor: .center)
                .offset(x: translation.width, y: translation.height)
                .gesture(magnificationGesture)
                .simultaneousGesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.85), value: scale)
                .animation(.smooth(duration: 0.15), value: translation)
        }
    }

    // MARK: - 手势

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 10.0)
            }
            .onEnded { _ in
                if scale < 1.05 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                } else {
                    lastScale = scale
                    lastTranslation = translation
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.02 {
                    translation = CGSize(
                        width: lastTranslation.width + value.translation.width,
                        height: lastTranslation.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                if scale > 1.02 {
                    lastTranslation = translation
                }
            }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        translation = .zero
        lastTranslation = .zero
    }
}

// MARK: - 回收站详情页

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

            VStack(spacing: 0) {
                // 照片区域（占据主要空间）
                if let ui = image {
                    ZoomableImageView(image: ui)
                } else if loadFailed {
                    errorContent
                } else {
                    ProgressView().controlSize(.large).tint(.white)
                }
                
                // 照片信息面板
                if let ui = image {
                    PhotoInfoPanel(asset: item.asset)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
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
            let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
            if let result { image = result }
            else { loadFailed = true }
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
