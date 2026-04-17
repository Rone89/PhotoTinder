import SwiftUI
import Photos

struct SummaryView: View {
    @Environment(PhotoViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    
    // 定义网格布局，自适应宽度
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
    
    var body: some View {
        VStack {
            Text("待删除照片确认")
                .font(.headline)
                .padding(.top)
            
            if let groupIndex = viewModel.currentGroupIndex {
                // 筛选出所有标记为删除的照片
                let deleteItems = viewModel.monthGroups[groupIndex].items.filter { $0.status == .delete }
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(deleteItems) { item in
                            ThumbnailView(asset: item.asset)
                                .overlay(alignment: .bottomTrailing) {
                                    // 右下角的删除标记图标
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(.white))
                                        .padding(4)
                                }
                                .onTapGesture {
                                    // 点击照片取消删除
                                    withAnimation {
                                        viewModel.cancelDelete(for: item.id)
                                    }
                                }
                        }
                    }
                }
                
                if deleteItems.isEmpty {
                    VStack {
                        Spacer()
                        Text("没有需要删除的照片 🎉")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                
                // 底部操作区
                VStack(spacing: 10) {
                    Text("点击照片可取消删除")
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
                            Text("确认删除 \(deleteItems.count) 张")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .disabled(isDeleting || deleteItems.isEmpty)
                    
                    if deleteItems.isEmpty {
                        Button("直接返回") { dismiss() }
                            .padding(.bottom)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// 高效的方形缩略图视图
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
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: geo.size.width, height: geo.size.width) // 强制正方形
            .clipped()
            .task {
                let manager = PHImageManager.default()
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = true
                // 请求低分辨率的缩略图以保证列表滑动极度流畅
                let size = CGSize(width: 200, height: 200)
                manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { img, _ in
                    if let img = img {
                        DispatchQueue.main.async { self.image = img }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
