import SwiftUI
import Photos

struct TrashView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.trashGroups.isEmpty {
                    ContentUnavailableView {
                        Label("回收站为空", systemImage: "trash")
                    } description: {
                        Text("没有待删除的照片")
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.trashGroups) { group in
                                VStack(alignment: .leading, spacing: 8) {
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
                                                        Task { await viewModel.confirmDeleteItems([item]) }
                                                    } label: {
                                                        Label("立即删除", systemImage: "trash.fill")
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.trashGroups.isEmpty {
                        HStack(spacing: 16) {
                            Button {
                                viewModel.restoreAllFromTrash()
                            } label: {
                                Label("全部恢复", systemImage: "arrow.uturn.left.circle")
                                    .font(.subheadline)
                            }
                            
                            Button(role: .destructive) {
                                viewModel.showConfirmDeleteAlert = true
                            } label: {
                                Label("全部删除", systemImage: "trash.fill")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .alert("确认删除", isPresented: $viewModel.showConfirmDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task { await viewModel.confirmDeleteAllTrash() }
                }
            } message: {
                Text("确定要删除回收站中的 \(viewModel.totalTrashCount) 张照片吗？此操作不可撤销。")
            }
            .alert("删除完成", isPresented: $viewModel.showDeleteSuccessAlert) {
                Button("好的") {}
            } message: {
                Text("已成功删除 \(viewModel.deletedCount) 张照片")
            }
        }
    }
}
