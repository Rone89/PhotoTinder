import SwiftUI
import Photos

struct TrashView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @State private var deletedItems: [PhotoItem] = []
    @State private var isLoading = true
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                } else if deletedItems.isEmpty {
                    ContentUnavailableView {
                        Label("回收站为空", systemImage: "trash")
                    } description: {
                        Text("没有待恢复的照片")
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("共 \(deletedItems.count) 张照片")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    Task { await recoverAll() }
                                } label: {
                                    Label("全部恢复", systemImage: "arrow.uturn.left.circle")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                            
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(deletedItems) { item in
                                    ThumbnailView(asset: item.asset)
                                        .overlay(alignment: .bottom) {
                                            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                                                .frame(height: 30)
                                                .overlay(alignment: .bottomLeading) {
                                                    if let date = item.asset.creationDate {
                                                        Text(formatRemainingDays(date))
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .padding(4)
                                                    }
                                                }
                                        }
                                        .contextMenu {
                                            Button {
                                                Task { await viewModel.recoverAsset(item.asset) }
                                            } label: {
                                                Label("恢复照片", systemImage: "arrow.uturn.left")
                                            }
                                            Button(role: .destructive) {
                                                Task { await viewModel.permanentDelete([item.asset]) }
                                            } label: {
                                                Label("永久删除", systemImage: "trash.fill")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !deletedItems.isEmpty {
                        Menu {
                            Button(role: .destructive) {
                                Task { await viewModel.permanentDelete(deletedItems.map { $0.asset }) }
                            } label: {
                                Label("清空回收站", systemImage: "trash.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .task {
                deletedItems = await PhotoLibraryService.shared.fetchDeletedPhotos()
                isLoading = false
            }
            .refreshable {
                deletedItems = await PhotoLibraryService.shared.fetchDeletedPhotos()
            }
            .alert("提示", isPresented: $viewModel.showRecoveryAlert) {
                Button("去相册恢复") {
                    if let url = URL(string: "photos-redirect://recover") {
                        UIApplication.shared.open(url)
                    } else {
                        UIApplication.shared.open(URL(string: "photos-redirect://")!)
                    }
                }
                Button("知道了", role: .cancel) {}
            } message: {
                Text("由于系统限制，请在系统「照片」App 的「最近删除」中恢复照片。照片将在30天后自动永久删除。")
            }
        }
    }
    
    private func formatRemainingDays(_ date: Date) -> String {
        let remaining = 30 - Calendar.current.dateComponents([.day], from: date, to: Date()).day!
        return "剩余 \(max(0, remaining)) 天"
    }
    
    private func recoverAll() {
        viewModel.showRecoveryAlert = true
    }
}
