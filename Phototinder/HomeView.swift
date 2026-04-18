import SwiftUI
import Photos

// Note: 主界面已迁移到 PhotoTinderApp.swift 的 MainTabView
// 此文件保留为备用，不再使用 GlassEffect 等 iOS 18+ API

struct HomeView: View {
    @Environment(PhotoViewModel.self) var viewModel

    var body: some View {
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
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            Text("照片清理助手")
                .font(.largeTitle.bold())
            Text("每次随机 100 张，滑动审查你的照片")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                statBox("已审查", "\(viewModel.totalReviewed)", "checkmark.circle", .green)
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
        .padding(.vertical, 16)
    }

    // MARK: - Start Button

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
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Capsule().fill(Color.blue))
                .shadow(color: .blue.opacity(0.25), radius: 4)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.6 : 1.0)
    }
}
