import SwiftUI
import Photos

struct TrashView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss

    @State private var showConfirmDeleteAlert = false
    @State private var showDeleteSuccessAlert = false
    @State private var lastDeletedCount = 0
    @State private var selectedItem: PhotoItem?
    @State private var showDetail = false
    @State private var isEditMode = false
    @State private var selectedIds: Set<String> = []

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    private var trashItems: [PhotoItem] {
        viewModel.allDeletedPhotos
    }

    private var deleteTargetCount: Int {
        if isEditMode && !selectedIds.isEmpty { return selectedIds.count }
        return trashItems.count
    }

    var body: some View {
        Group {
            if trashItems.isEmpty {
                emptyState
            } else {
                trashGrid
            }
        }
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            leadingToolbar
            trailingToolbar
        }
        .fullScreenCover(isPresented: $showDetail) {
            if let item = selectedItem {
                TrashDetailView(
                    item: item,
                    onRestore: {
                        viewModel.restoreFromTrash(item)
                        showDetail = false
                    },
                    onDelete: {
                        deleteSingle(item)
                        showDetail = false
                    },
                    onClose: {
                        showDetail = false
                    }
                )
            }
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

    // MARK: - 子视图

    private var emptyState: some View {
        ContentUnavailableView {
            Label("回收站为空", systemImage: "archivebox")
        } description: {
            Text("没有待删除的照片")
        }
    }

    private var trashGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(trashItems) { item in
                    gridCell(item)
                }
            }
            .padding()
        }
    }

    private func gridCell(_ item: PhotoItem) -> some View {
        ThumbnailView(asset: item.asset)
            .overlay(alignment: .topLeading) {
                if isEditMode {
                    checkBadge(item)
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
                    showDetail = true
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

    private func checkBadge(_ item: PhotoItem) -> some View {
        let isSelected = selectedIds.contains(item.id)
        return Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(isSelected ? .blue : .white)
            .background(
                Circle().fill(.white).shadow(radius: 1).padding(1)
            )
            .padding(4)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var leadingToolbar: some ToolbarContent {
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
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        if isEditMode {
            ToolbarItem(placement: .topBarTrailing) {
                editActions
            }
        } else if !trashItems.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                normalActions
            }
        }
    }

    private var normalActions: some View {
        HStack(spacing: 16) {
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

    private var editActions: some View {
        HStack(spacing: 16) {
            if !selectedIds.isEmpty {
                Button {
                    viewModel.restoreSelectedFromTrash(selectedIds)
                    selectedIds.removeAll()
                    isEditMode = false
                } label: {
                    Label("移出", systemImage: "arrow.uturn.left.circle")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Button(role: .destructive) {
                    showConfirmDeleteAlert = true
                } label: {
                    Label("删除", systemImage: "trash.fill")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Actions

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

// MARK: - TrashDetailView（纯 ZStack，不嵌套 NavigationStack，用浮动按钮）

struct TrashDetailView: View {
    let item: PhotoItem
    let onRestore: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var image: UIImage?
    @State private var loadFailed = false
    @State private var showMenu = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 图片区域
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else if loadFailed {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.6))
                    Text("无法加载此照片")
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                ProgressView()
                    .scaleEffect(2)
                    .tint(.white)
            }

            // 顶部浮动按钮
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding(20)
                    Spacer()
                    Button(action: { withAnimation { showMenu.toggle() } }) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding(20)
                }
                Spacer()
            }

            // 底部操作菜单（自定义，不依赖系统 Menu）
            if showMenu {
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation { showMenu = false }
                        onRestore()
                    }) {
                        HStack {
                            Image(systemName: "arrow.uturn.left")
                            Text("移出回收站")
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .foregroundColor(.blue)
                    }

                    Divider().background(Color.white.opacity(0.3))

                    Button(role: .destructive, action: {
                        withAnimation { showMenu = false }
                        onDelete()
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("永久删除")
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }

                    Divider().background(Color.white.opacity(0.3))

                    Button(action: { withAnimation { showMenu = false } }) {
                        HStack {
                            Text("取消")
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                    }
                }
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: item.id) {
            image = nil
            loadFailed = false
            let sizes: [CGSize] = [
                CGSize(width: 1500, height: 2000),
                PHImageManagerMaximumSize,
                CGSize(width: 600, height: 800)
            ]
            let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
            if let result = result {
                image = result
            } else {
                loadFailed = true
            }
        }
    }
}
