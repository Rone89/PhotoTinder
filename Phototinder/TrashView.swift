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
    @State private var selectedItems: Set<String> = []

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.trashGroups.isEmpty {
                    emptyView
                } else {
                    trashScrollView
                }
            }
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditMode {
                        Button("完成") { isEditMode = false; selectedItems.removeAll() }
                    } else {
                        Button("完成") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditMode {
                        editToolbarButtons
                    } else if !viewModel.trashGroups.isEmpty {
                        normalToolbarButtons
                    }
                }
            }
            .alert("确认删除", isPresented: $showConfirmDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { deleteSelectedOrAll() }
            } message: {
                Text("确定要删除选中的 \(deleteTargetCount) 张照片吗？此操作不可撤销。")
            }
            .alert("删除完成", isPresented: $showDeleteSuccessAlert) {
                Button("好的") {}
            } message: {
                Text("已成功删除 \(lastDeletedCount) 张照片")
            }
            .fullScreenCover(isPresented: $showDetail) {
                if let item = selectedItem {
                    TrashDetailView(item: item) {
                        viewModel.restoreFromTrash(item)
                        showDetail = false
                    } onDelete: {
                        deleteSingleItem(item)
                        showDetail = false
                    } onDismiss: {
                        showDetail = false
                    }
                }
            }
        }
    }

    // MARK: - Computed

    private var deleteTargetCount: Int {
        if isEditMode && !selectedItems.isEmpty { return selectedItems.count }
        return viewModel.totalTrashCount
    }

    // MARK: - Subviews

    private var emptyView: some View {
        ContentUnavailableView {
            Label("回收站为空", systemImage: "trash")
        } description: {
            Text("没有待删除的照片")
        }
    }

    private var trashScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.trashGroups) { group in
                    sectionForGroup(group)
                }
            }
            .padding(.vertical)
        }
    }

    private func sectionForGroup(_ group: MonthGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeaderView(group)
            thumbnailGrid(group)
        }
    }

    private func groupHeaderView(_ group: MonthGroup) -> some View {
        HStack {
            Text(group.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("\(group.items.count) 张")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if isEditMode {
                Button {
                    let ids = Set(group.items.map(\.id))
                    if selectedItems.isSuperset(of: ids) {
                        selectedItems.subtract(ids)
                    } else {
                        selectedItems.formUnion(ids)
                    }
                } label: {
                    let allSelected = selectedItems.isSuperset(of: Set(group.items.map(\.id)))
                    Text(allSelected ? "取消全选" : "全选")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            } else {
                Button {
                    for item in group.items { viewModel.restoreFromTrash(item) }
                } label: {
                    Label("恢复此组", systemImage: "arrow.uturn.left.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal)
    }

    private func thumbnailGrid(_ group: MonthGroup) -> some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(group.items) { item in
                ThumbnailView(asset: item.asset)
                    .overlay(alignment: .topTrailing) {
                        if isEditMode {
                            selectionBadge(item)
                        } else {
                            deleteBadge
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if isEditMode && selectedItems.contains(item.id) {
                            Color.blue.opacity(0.3)
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
                                deleteSingleItem(item)
                            } label: {
                                Label("立即删除", systemImage: "trash.fill")
                            }
                        }
                    }
            }
        }
        .padding(.horizontal)
    }

    private func selectionBadge(_ item: PhotoItem) -> some View {
        let isSelected = selectedItems.contains(item.id)
        return Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(isSelected ? .blue : .white)
            .background(
                Circle().fill(.white).shadow(radius: 1).padding(1)
            )
            .padding(4)
    }

    private var deleteBadge: some View {
        Image(systemName: "minus.circle.fill")
            .foregroundColor(.red)
            .font(.title3)
            .background(Circle().fill(.white).padding(1))
            .padding(4)
    }

    // MARK: - Toolbar

    private var normalToolbarButtons: some View {
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

    private var editToolbarButtons: some View {
        HStack(spacing: 16) {
            if !selectedItems.isEmpty {
                Button {
                    for id in selectedItems {
                        if let item = findItemById(id) {
                            viewModel.restoreFromTrash(item)
                        }
                    }
                    selectedItems.removeAll()
                    isEditMode = false
                } label: {
                    Label("移出回收站", systemImage: "arrow.uturn.left.circle")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Button(role: .destructive) {
                    showConfirmDeleteAlert = true
                } label: {
                    Label("删除选中", systemImage: "trash.fill")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ item: PhotoItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func findItemById(_ id: String) -> PhotoItem? {
        for group in viewModel.monthGroups {
            if let item = group.items.first(where: { $0.id == id }) {
                return item
            }
        }
        return nil
    }

    private func deleteSingleItem(_ item: PhotoItem) {
        Task {
            try? await PhotoLibraryService.shared.deleteAssets([item.asset])
            let deleteId = item.id
            for groupIndex in viewModel.monthGroups.indices {
                viewModel.monthGroups[groupIndex].items.removeAll { $0.id == deleteId }
            }
            lastDeletedCount = 1
            showDeleteSuccessAlert = true
        }
    }

    private func deleteSelectedOrAll() {
        Task {
            if isEditMode && !selectedItems.isEmpty {
                // 删除选中的
                var assets: [PHAsset] = []
                for id in selectedItems {
                    if let item = findItemById(id) {
                        assets.append(item.asset)
                    }
                }
                guard !assets.isEmpty else { return }
                try? await PhotoLibraryService.shared.deleteAssets(assets)
                let idsToDelete = selectedItems
                for groupIndex in viewModel.monthGroups.indices {
                    viewModel.monthGroups[groupIndex].items.removeAll { idsToDelete.contains($0.id) }
                }
                lastDeletedCount = assets.count
            } else {
                // 删除全部
                let allDeleteAssets = viewModel.monthGroups.flatMap { group in
                    group.items.filter { $0.status == .delete }.map { $0.asset }
                }
                guard !allDeleteAssets.isEmpty else { return }
                try? await PhotoLibraryService.shared.deleteAssets(allDeleteAssets)
                for groupIndex in viewModel.monthGroups.indices {
                    viewModel.monthGroups[groupIndex].items.removeAll { $0.status == .delete }
                }
                lastDeletedCount = allDeleteAssets.count
            }
            selectedItems.removeAll()
            isEditMode = false
            showDeleteSuccessAlert = true
        }
    }
}

// MARK: - Trash Detail View (大图查看)

struct TrashDetailView: View {
    let item: PhotoItem
    let onRestore: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { onDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { onRestore() } label: {
                            Label("移出回收站", systemImage: "arrow.uturn.left")
                        }
                        Button(role: .destructive) { onDelete() } label: {
                            Label("立即删除", systemImage: "trash.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { loadImage() }
        }
    }

    private func loadImage() {
        guard image == nil, !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isSynchronous = true

            var resultImage: UIImage?
            PHImageManager.default().requestImage(
                for: item.asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { img, _ in
                resultImage = img
            }

            DispatchQueue.main.async {
                self.image = resultImage
                self.isLoading = false
            }
        }
    }
}
