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

// MARK: - 主界面（底部 Dock 栏）

struct MainTabView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "主页"
        case trash = "回收站"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容区域
            Group {
                switch selectedTab {
                case .home:
                    homeContent
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .trash:
                    trashContent
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedTab)

            // 底部 Dock 栏
            dockBar
                .padding(.bottom, 8)

            // 审查界面全屏覆盖
            if viewModel.isReviewing {
                ReviewView()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isReviewing)
    }

    // MARK: - Dock 栏

    private var dockBar: some View {
        HStack(spacing: 60) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Button {
                    if tab == .home && viewModel.isReviewing {
                        // 审查中点击主页 → 返回
                        viewModel.isReviewing = false
                    } else {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab == .home ? "house.fill" : "archivebox.fill")
                            .font(.title2)
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                        Text(tab.rawValue)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .background(
            GlassEffectContainer(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -2)
            }
        )
    }

    // MARK: - 主页内容

    private var homeContent: some View {
        NavigationStack {
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
    }

    // MARK: - 回收站内容

    private var trashContent: some View {
        NavigationStack { TrashView() }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
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

    // MARK: - Stats

    private var statsSection: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 0) {
                statBox("已审查", "\(viewModel.totalReviewed)", "checkmark.circle", .green)
                Divider().frame(height: 50).padding(.vertical, 6)
                statBox("待删除", "\(viewModel.allDeletedPhotos.count)", "trash", .red)
                Divider().frame(height: 50).padding(.vertical, 6)
                statBox("已保留", "\(viewModel.totalKept)", "heart", .blue)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
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

    // MARK: - 开始按钮（iOS 26 Liquid Glass 风格）

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
                .glassEffect(.prominent.tint(.blue))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.6 : 1.0)
    }
}
