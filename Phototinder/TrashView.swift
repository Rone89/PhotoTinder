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

    // MARK: - Body

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
                NavigationStack {
                    TrashDetailView(item: item, onRestore: {
                        viewModel.restoreFromTrash(item)
                        showDetail = false
                    }, onDelete: {
                        deleteSingle(item)
                        showDetail = false
                    })
                }
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

    // MARK: - States

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
            .overlay(alignment: .bottomLeading) {
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

// MARK: - TrashDetailView

struct TrashDetailView: View {
    let item: PhotoItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                ProgressView()
                    .scaleEffect(2)
                    .tint(.white)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { onRestore() } label: {
                        Label("移出回收站", systemImage: "arrow.uturn.left")
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("永久删除", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: item.id) {
            await loadImage()
        }
    }

    private func loadImage() async {
        image = nil
        let loaded = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .exact
                options.isSynchronous = true

                var result: UIImage?
                PHImageManager.default().requestImage(
                    for: item.asset,
                    targetSize: CGSize(width: 1500, height: 2000),
                    contentMode: .aspectFit,
                    options: options
                ) { img, _ in
                    result = img
                }
                continuation.resume(returning: result)
            }
        }
        image = loaded
    }
}
