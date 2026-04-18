import SwiftUI

struct HomeView: View {
    @State private var viewModel = PhotoViewModel()
    @State private var showTrash = false
    
    var body: some View {
        NavigationStack {
            List(viewModel.monthGroups.indices, id: \.self) { index in
                let group = viewModel.monthGroups[index]
                HStack {
                    VStack(alignment: .leading) {
                        Text(group.title).font(.headline)
                        Text("\(group.items.count) 张照片").font(.caption).secondary()
                    }
                    Spacer()
                    if group.deleteCount > 0 {
                        Text("\(group.deleteCount)")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Circle().fill(.red))
                            .font(.caption)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { viewModel.startReviewing(index: index) }
            }
            .navigationTitle("照片清理")
            .task { await viewModel.checkPermissionAndFetch() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTrash = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "trash")
                            if viewModel.totalTrashCount > 0 {
                                Text("\(viewModel.totalTrashCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(.red))
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: Binding(get: { viewModel.currentGroupIndex != nil }, set: { if !$0 { viewModel.currentGroupIndex = nil } })) {
                ReviewView().environment(viewModel)
            }
            .sheet(isPresented: $showTrash) {
                TrashView().environment(viewModel)
            }
        }
    }
}

extension View {
    func secondary() -> some View { self.foregroundColor(.secondary) }
}
