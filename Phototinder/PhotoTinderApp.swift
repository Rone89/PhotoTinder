import SwiftUI

@main
struct PhotoTinderApp: App {
    @State private var viewModel = PhotoViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(viewModel)
                .task {
                    await viewModel.checkPermissionAndFetch()
                }
        }
    }
}

// MARK: - 主界面（系统 TabView，自动获得 iOS 26 Liquid Glass 样式）

struct MainTabView: View {
    @Environment(PhotoViewModel.self) var viewModel

    var body: some View {
        ZStack {
            TabView {
                Tab("主页", systemImage: "house.fill") {
                    NavigationStack {
                        homeContent
                    }
                }

                Tab("回收站", systemImage: "archivebox.fill") {
                    NavigationStack {
                        TrashView()
                    }
                }
            }

            // 审查界面全屏覆盖（在 TabView 之上，自动遮盖 tab bar）
            if viewModel.isReviewing {
                ReviewView()
                    .ignoresSafeArea()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isReviewing)
    }

    // MARK: - 主页内容

    private var homeContent: some View {
        VStack(spacing: 0) {
            Spacer()

            heroSection

            Spacer()

            if viewModel.totalReviewed > 0 {
                statsSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }

            Spacer()

            startButton
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

            Spacer()
        }
        .navigationTitle("照片清理")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("照片清理助手")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("每次随机 100 张，滑动审查你的照片")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
    }

    // MARK: - Stats（4 格：已审查 / 已清理 / 待删除 / 已保留）

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                statBox("已审查", "\(viewModel.totalReviewed)", "checkmark.circle", .green)
                Divider().frame(height: 50).padding(.vertical, 6)
                statBox("已清理", "\(viewModel.totalCleaned)", "trash.fill", .orange)
                Divider().frame(height: 50).padding(.vertical, 6)
                statBox("待删除", "\(viewModel.allDeletedPhotos.count)", "trash", .red)
                Divider().frame(height: 50).padding(.vertical, 6)
                statBox("已保留", "\(viewModel.totalKept)", "heart", .blue)
            }
        }
        .background(Color(.systemBackground).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.06), radius: 8))
    }

    private func statBox(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: - 开始按钮

    private var startButton: some View {
        Button {
            if viewModel.isLoading { return }
            if viewModel.currentPhotos.isEmpty {
                Task { await viewModel.loadRandomPhotos() }
            } else {
                viewModel.isReviewing = true
            }
        } label: {
            Label("开始清理", systemImage: "play.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundStyle(.white)
                .background(Capsule().fill(Color.blue))
                .shadow(color: .blue.opacity(0.25), radius: 4)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.6 : 1.0)
    }
}
