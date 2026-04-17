import SwiftUI

struct HomeView: View {
    @State private var viewModel = PhotoViewModel()
    
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
                        Text("\(group.deleteCount)").foregroundColor(.red).bold()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { viewModel.startReviewing(index: index) }
            }
            .navigationTitle("照片清理")
            .task { await viewModel.checkPermissionAndFetch() }
            .fullScreenCover(isPresented: Binding(get: { viewModel.currentGroupIndex != nil }, set: { if !$0 { viewModel.currentGroupIndex = nil } })) {
                ReviewView().environment(viewModel)
            }
        }
    }
}

extension View {
    func secondary() -> some View { self.foregroundColor(.secondary) }
}