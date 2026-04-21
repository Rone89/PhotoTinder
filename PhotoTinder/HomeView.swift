import SwiftUI

struct HomeView: View {
    @Environment(PhotoViewModel.self) private var viewModel

    private let statsColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var primaryActionTitle: String {
        if viewModel.isLoading {
            return "正在载入"
        }
        if viewModel.isBatchComplete {
            return viewModel.hasMorePhotos ? "开始下一轮" : "全部完成"
        }
        return viewModel.currentPhotos.isEmpty ? "开始清理" : "继续审查"
    }

    private var primaryActionSymbol: String {
        if viewModel.isLoading {
            return "hourglass"
        }
        if viewModel.isBatchComplete {
            return viewModel.hasMorePhotos ? "sparkles" : "checkmark.circle"
        }
        return viewModel.currentPhotos.isEmpty ? "play.fill" : "arrow.clockwise.circle.fill"
    }

    private var remainingCount: Int {
        max(viewModel.currentPhotos.count - viewModel.currentBatchReviewedCount, 0)
    }

    var body: some View {
        ZStack {
            AmbientBackdrop()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    heroPanel

                    if viewModel.totalReviewed > 0 {
                        statsSection
                    } else {
                        onboardingPanel
                    }

                    rhythmPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 160)
            }
        }
        .navigationTitle("照片清理")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            actionDock
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
        }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.white.opacity(0.16))
                        .frame(width: 96, height: 116)

                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PhotoTinderPalette.accent, PhotoTinderPalette.turquoise],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .glassEffect()

                VStack(alignment: .leading, spacing: 10) {
                    Text("整理你的相册")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("点击底部按钮进入审查，标记为待删除的照片会保存在回收站。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .dashboardPanel()
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("清理进度")
                .font(.headline.weight(.semibold))

            LazyVGrid(columns: statsColumns, spacing: 14) {
                StatTile(title: "已审查", value: "\(viewModel.totalReviewed)", systemImage: "checkmark.circle.fill", tint: PhotoTinderPalette.success)
                StatTile(title: "已清理", value: "\(viewModel.totalCleaned)", systemImage: "trash.fill", tint: PhotoTinderPalette.rose)
                StatTile(title: "待删除", value: "\(viewModel.allDeletedPhotos.count)", systemImage: "tray.full.fill", tint: PhotoTinderPalette.sun)
                StatTile(title: "已保留", value: "\(viewModel.totalKept)", systemImage: "heart.fill", tint: PhotoTinderPalette.accent)
            }
        }
    }

    private var onboardingPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("开始之前", systemImage: "photo.on.rectangle.angled")
                .font(.headline.weight(.semibold))

            Text("应用会向系统相册申请读写权限。不会在启动时自动进入审查，点击底部按钮后才会开始或继续当前批次。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .dashboardPanel()
    }

    private var rhythmPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("当前节奏", systemImage: "gauge.with.needle")
                .font(.headline.weight(.semibold))

            VStack(spacing: 12) {
                LabeledContent("当前批次", value: viewModel.batchNumber == 0 ? "尚未开始" : "第 \(viewModel.batchNumber) 轮")
                LabeledContent("待审照片", value: viewModel.currentPhotos.isEmpty ? "100 张 / 轮" : "\(remainingCount) 张")
                LabeledContent("回收站状态", value: viewModel.allDeletedPhotos.isEmpty ? "空" : "\(viewModel.allDeletedPhotos.count) 张待处理")
                LabeledContent("当前状态", value: viewModel.isLoading ? "正在同步相册" : (viewModel.isBatchComplete ? "本轮完成" : "随时可以继续"))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .dashboardPanel()
    }

    private var actionDock: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: handlePrimaryAction) {
                    Label(primaryActionTitle, systemImage: primaryActionSymbol)
                        .liquidActionLabel(tint: PhotoTinderPalette.accent, prominent: true)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading || (!viewModel.hasMorePhotos && viewModel.isBatchComplete))

                if viewModel.totalReviewed > 0 {
                    Button("重新开始", role: .destructive) {
                        viewModel.reset()
                    }
                    .buttonStyle(.plain)
                    .liquidActionLabel(tint: PhotoTinderPalette.rose)
                }
            }
        }
    }

    private func handlePrimaryAction() {
        guard !viewModel.isLoading else { return }

        if viewModel.currentPhotos.isEmpty {
            Task {
                await viewModel.loadRandomPhotos()
                if !viewModel.currentPhotos.isEmpty {
                    viewModel.isReviewing = true
                }
            }
            return
        }

        if viewModel.isBatchComplete {
            guard viewModel.hasMorePhotos else { return }
            Task {
                await viewModel.startNewRound()
                if !viewModel.currentPhotos.isEmpty {
                    viewModel.isReviewing = true
                }
            }
            return
        }

        viewModel.isReviewing = true
    }
}
