import SwiftUI
import Photos

struct DeleteTrayView: View {
    @Environment(PhotoViewModel.self) var viewModel

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
                    Button("完成") {}
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        ContentUnavailableView("暂无待删除照片", systemImage: "trash")
    }

    // MARK: - Grid

    private var thumbnailGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                ForEach(deletedItems) { item in
                    deleteCell(item)
                }
            }
            .padding()
        }
    }

    private func deleteCell(_ item: PhotoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            MiniThumbnail(asset: item.asset)

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

