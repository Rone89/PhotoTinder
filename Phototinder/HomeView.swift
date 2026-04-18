import SwiftUI
import Photos

struct HomeView: View {
    @State private var viewModel = PhotoViewModel()
    @State private var showTrash = false

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

                trashButton
                    .padding(.bottom, 40)
            }
            .navigationTitle("照片清理")
            .fullScreenCover(isPresented: Binding(
                get: { viewModel.isReviewing },
                set: { if !$0 { viewModel.isReviewing = false } }
            )) {
                ReviewView()
                    .environment(viewModel)
            }
            .sheet(isPresented: $showTrash) {
                NavigationStack {
                    TrashView()
                        .environment(viewModel)
                }
            }
            .task {
                await viewModel.checkPermissionAndFetch()
            }
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

    // MARK: - Stats（Liquid Glass 卡片）

    private var statsSection: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 0) {
                statBox("已审查", "\(viewModel.totalReviewed)", "checkmark.circle", .green)
                statBox("待删除", "\(viewModel.allDeletedPhotos.count)", "trash", .red)
                statBox("已保留", "\(viewModel.totalKept)", "heart", .blue)
            }
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
        .padding(.vertical, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Buttons（Liquid Glass）

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
        }
        .buttonStyle(.glassProminent)
        .tint(.blue)
        .disabled(viewModel.isLoading)
    }

    private var trashButton: some View {
        Button {
            showTrash = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "archivebox")
                Text("回收站")
                if !viewModel.allDeletedPhotos.isEmpty {
                    Text("\(viewModel.allDeletedPhotos.count)")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                }
            }
            .font(.headline)
            .foregroundColor(.secondary)
        }
        .glassEffect(.regular.interactive())
    }
}
