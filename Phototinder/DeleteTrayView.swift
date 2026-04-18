import SwiftUI

struct DeleteTrayView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    private var deletedItems: [PhotoItem] {
        viewModel.currentPhotos.filter { $0.status == .delete }
    }

    var body: some View {
        NavigationStack {
            Group {
                if deletedItems.isEmpty {
                    emptyView
                } else {
                    thumbnailGrid
                }
            }
            .navigationTitle("待删除 (\(deletedItems.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView("暂无待删除照片", systemImage: "trash")
    }

    private var thumbnailGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(deletedItems) { item in
                    gridCell(item)
                }
            }
            .padding()
        }
    }

    private func gridCell(_ item: PhotoItem) -> some View {
        ThumbnailView(asset: item.asset)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
                    .background(Circle().fill(.white).padding(1))
                    .padding(4)
            }
            .onTapGesture {
                viewModel.cancelDelete(for: item.id)
            }
    }
}
