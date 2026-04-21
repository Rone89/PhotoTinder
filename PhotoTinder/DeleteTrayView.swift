import Photos
import SwiftUI

struct DeleteTrayView: View {
    @Environment(PhotoViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    private var deletedItems: [PhotoItem] {
        viewModel.currentPhotos.filter { $0.status == .delete }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop()

                Group {
                    if deletedItems.isEmpty {
                        ContentUnavailableView(
                            "暂无待删除照片",
                            systemImage: "trash",
                            description: Text("上滑照片后，它会先进入这个待删除托盘。")
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("本轮待删除", systemImage: "tray.full.fill")
                                        .font(.headline.weight(.semibold))

                                    Text("轻点任意缩略图即可把它移出待删除队列。")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text("\(deletedItems.count) 张")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                }
                                .dashboardPanel()

                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(deletedItems) { item in
                                        deleteCell(item)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationTitle("待删除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func deleteCell(_ item: PhotoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            MiniThumbnail(asset: item.asset)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.8)
                }

            Image(systemName: "minus.circle.fill")
                .font(.title3)
                .foregroundStyle(PhotoTinderPalette.rose)
                .padding(8)
                .glassEffect()
                .padding(8)
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            viewModel.cancelDelete(for: item.id)
        }
    }
}
