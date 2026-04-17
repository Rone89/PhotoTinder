import SwiftUI
import Photos

struct DeleteTrayView: View {
    @Environment(PhotoViewModel.self) var viewModel
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let group = viewModel.currentGroup {
                    let items = group.items.filter { $0.status == .delete }
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(items) { item in
                            ThumbnailView(asset: item.asset)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "minus.circle.fill").foregroundColor(.red).background(Circle().fill(.white))
                                }
                                .onTapGesture { viewModel.cancelDelete(for: item.id) }
                        }
                    }
                }
            }
            .navigationTitle("待删除预览")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    var body: some View {
        Color.gray.opacity(0.2).aspectRatio(1, contentMode: .fill)
            .overlay { if let image = image { Image(uiImage: image).resizable().scaledToFill() } }
            .clipped()
            .onAppear {
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: nil) { self.image = $0 }
            }
    }
}