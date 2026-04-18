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

// MARK: - MiniThumbnail（用于删除托盘和回收站网格）

struct MiniThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    private let sizes: [CGSize] = [
        CGSize(width: 200, height: 200),
        CGSize(width: 100, height: 100)
    ]

    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let ui = image {
                    Image(uiImage: ui).resizable().scaledToFill().clipped()
                } else {
                    ProgressView().scaleEffect(0.8).tint(.gray)
                }
            }
            .task(id: asset.localIdentifier) {
                image = nil
                image = await PhotoLoader.loadWithFallback(for: asset, sizes: sizes, contentMode: .aspectFill)
            }
    }
}
