import SwiftUI

struct HomeView: View {
    @State private var viewModel = PhotoViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.isAuthorized {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("需要相册权限才能帮您清理照片")
                            .font(.headline)
                        Button("授权访问") {
                            Task { await viewModel.checkPermissionAndFetch() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if viewModel.isLoading {
                    ProgressView("正在扫描相册...")
                } else if viewModel.monthGroups.isEmpty {
                    Text("相册中没有找到照片 📭").foregroundColor(.gray)
                } else {
                    List {
                        ForEach(viewModel.monthGroups.indices, id: \.self) { index in
                            let group = viewModel.monthGroups[index]
                            MonthRow(group: group)
                                .onTapGesture {
                                    viewModel.startReviewing(groupIndex: index)
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("照片清理")
            .fullScreenCover(isPresented: Binding(
                get: { viewModel.currentGroupIndex != nil },
                set: { if !$0 { viewModel.closeReview() } }
            )) {
                ReviewView()
                    .environment(viewModel)
            }
            .task {
                await viewModel.checkPermissionAndFetch()
            }
        }
    }
}

struct MonthRow: View {
    let group: MonthGroup
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(group.title)
                    .font(.headline)
                HStack(spacing: 12) {
                    Label("\(group.items.count) 张", systemImage: "photo")
                    if group.deleteCount > 0 {
                        Label("\(group.deleteCount) 待删", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .contentShape(Rectangle())
    }
}