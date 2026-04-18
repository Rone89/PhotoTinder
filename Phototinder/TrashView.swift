import SwiftUI
import Photos

struct TrashView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    @State private var showConfirmDeleteAlert = false
    @State private var showDeleteSuccessAlert = false
    @State private var lastDeletedCount = 0

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    private var contentBody: some View {
        Group {
            if viewModel.trashGroups.isEmpty {
                ContentUnavailableView {
                    Label("回收站为空", systemImage: "trash")
                } description: {
                    Text("没有待删除的照片")
                }
            } else {
                trashScrollView
            }
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
            Button {
                for item in group.items {
                    viewModel.restoreFromTrash(item)
                }
            } label: {
                Label("恢复此组", systemImage: "arrow.uturn.left.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }

    private func thumbnailGrid(_ group: MonthGroup) -> some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(group.items) { item in
                ThumbnailView(asset: item.asset)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                            .background(Circle().fill(.white).padding(1))
                            .padding(4)
                    }
                    .contextMenu {
                        Button {
                            viewModel.restoreFromTrash(item)
                        } label: {
                            Label("恢复", systemImage: "arrow.uturn.left")
                        }
                        Button(role: .destructive) {
                            deleteSingleItem(item)
                        } label: {
                            Label("立即删除", systemImage: "trash.fill")
                        }
                    }
            }
        }
        .padding(.horizontal)
    }

    private func deleteSingleItem(_ item: PhotoItem) {
        Task {
            let assets = [item.asset]
            try? await PhotoLibraryService.shared.deleteAssets(assets)
            let deleteId = item.id
            for groupIndex in viewModel.monthGroups.indices {
                viewModel.monthGroups[groupIndex].items.removeAll { $0.id == deleteId }
            }
            lastDeletedCount = 1
            showDeleteSuccessAlert = true
        }
    }

    var body: some View {
        NavigationStack {
            contentBody
                .navigationTitle("回收站")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("完成") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if !viewModel.trashGroups.isEmpty {
                            toolbarButtons
                        }
                    }
                }
                .alert("确认删除", isPresented: $showConfirmDeleteAlert) {
                    Button("取消", role: .cancel) {}
                    Button("删除", role: .destructive) {
                        deleteAll()
                    }
                } message: {
                    Text("确定要删除回收站中的 \(viewModel.totalTrashCount) 张照片吗？此操作不可撤销。")
                }
                .alert("删除完成", isPresented: $showDeleteSuccessAlert) {
                    Button("好的") {}
                } message: {
                    Text("已成功删除 \(lastDeletedCount) 张照片")
                }
        }
    }

    private var toolbarButtons: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.restoreAllFromTrash()
            } label: {
                Label("全部恢复", systemImage: "arrow.uturn.left.circle")
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

    private func deleteAll() {
        Task {
            let allDeleteAssets = viewModel.monthGroups.flatMap { group in
                group.items.filter { $0.status == .delete }.map { $0.asset }
            }
            guard !allDeleteAssets.isEmpty else { return }

            try? await PhotoLibraryService.shared.deleteAssets(allDeleteAssets)

            for groupIndex in viewModel.monthGroups.indices {
                viewModel.monthGroups[groupIndex].items.removeAll { $0.status == .delete }
            }

            lastDeletedCount = allDeleteAssets.count
            showDeleteSuccessAlert = true
        }
    }
}
