import SwiftUI
import Photos

struct SummaryView: View {
    @Environment(PhotoViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
    
    var body: some View {
        VStack {
            Text("待删除照片确认")
                .font(.headline)
                .padding(.top)
            
            if let groupIndex = viewModel.currentGroupIndex {
                let deleteItems = viewModel.monthGroups[groupIndex].items.filter { $0.status == .delete }
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(deleteItems) { item in
                            ThumbnailView(asset: item.asset)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "trash.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(.white))
                                        .padding(4)
                                }
                                .onTapGesture {
                                    withAnimation {
                                        viewModel.cancelDelete(for: item.id)
                                    }
                                }
                        }
                    }
                }
                
                VStack(spacing: 12) {
                    if !deleteItems.isEmpty {
                        Text("点击照片可恢复（取消删除）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            Task {
                                isDeleting = true
                                await viewModel.commitDeletion()
                                isDeleting = false
                                dismiss()
                            }
                        }) {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Text("确定删除 \(deleteItems.count) 张照片")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    } else {
                        Text("没有标记删除的照片")
                            .foregroundColor(.secondary)
                        Button("完成并返回") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
        }
    }
}

struct ThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { img, _ in
                self.image = img
            }
        }
    }
}
