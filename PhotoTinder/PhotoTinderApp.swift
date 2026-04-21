import SwiftUI

@main
struct PhotoTinderApp: App {
    @State private var viewModel = PhotoViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(viewModel)
                .task {
                    await viewModel.prepareForLaunch()
                }
        }
    }
}

struct MainTabView: View {
    @Environment(PhotoViewModel.self) private var viewModel
    @State private var selectedTab = 0

    private var reviewBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isReviewing },
            set: { viewModel.isReviewing = $0 }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("清理", systemImage: "sparkles.rectangle.stack.fill")
            }
            .tag(0)

            NavigationStack {
                TrashView()
            }
            .tabItem {
                Label("回收站", systemImage: "trash.slash.fill")
            }
            .tag(1)
        }
        .tint(PhotoTinderPalette.accent)
        .fullScreenCover(isPresented: reviewBinding) {
            ReviewView()
        }
    }
}
