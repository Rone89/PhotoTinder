import SwiftUI
import Photos
import PhotosUI

struct ReviewView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var dragOffset: CGSize = .zero
    @State private var showDeleteTray = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if viewModel.isLoading && viewModel.currentPhotos.isEmpty {
                    loadingView
                } else if viewModel.currentPhotos.isEmpty {
                    noPhotosView
                } else if viewModel.isBatchComplete {
                    batchCompleteView
                } else if let photo = viewModel.currentPhoto {
                    mainContent(photo: photo)
                }
            }
            .navigationTitle("第 \(viewModel.batchNumber) 轮")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.isReviewing = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.currentBatchDeletedCount > 0 {
                        Button { showDeleteTray = true } label: {
                            Label("\(viewModel.currentBatchDeletedCount)", systemImage: "trash")
                                .font(.subheadline)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .sheet(isPresented: $showDeleteTray) {
                DeleteTrayView()
            }
        }
    }

    // MARK: - 子视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.blue)
            Text("加载照片中...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var noPhotosView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("没有更多照片了")
                .font(.title2.weight(.medium))
                .foregroundColor(.secondary)
            Text("所有照片已审查完毕")
                .font(.subheadline)
                .foregroundColor(Color(.tertiaryLabel))
            Button("返回主页") {
                viewModel.isReviewing = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
        }
    }

    private var batchCompleteView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                    )
            }

            Text("第 \(viewModel.batchNumber) 轮完成！")
                .font(.title2.bold())

            HStack(spacing: 50) {
                statLabel("保留", "\(viewModel.currentBatchKeptCount)", .green, "heart.fill")
                statLabel("删除", "\(viewModel.currentBatchDeletedCount)", .red, "trash.fill")
            }

            Text("共审查 \(viewModel.currentPhotos.count) 张")
                .font(.subheadline)
                .foregroundColor(Color(.tertiaryLabel))

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.isReviewing = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                    Text("返回主页")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)

            if viewModel.hasMorePhotos {
                Button {
                    Task { await viewModel.startNewRound() }
                } label: {
                    Text("再来一轮")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.blue)
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            } else {
                Text("所有照片已审查完毕")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
                    .padding(.bottom, 40)
            }
        }
    }

    private func statLabel(_ title: String, _ value: String, _ color: Color, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value).font(.title.bold()).foregroundColor(color)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - 主内容区

    /// iPad 上照片卡片限制最大宽度，iPhone 撑满
    private var cardMaxWidth: CGFloat {
        sizeClass == .regular ? 700 : .infinity
    }

    @ViewBuilder
    private func mainContent(photo: PhotoItem) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 进度条
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                // 照片卡片区（根据照片比例自动调整）
                ZStack {
                    PhotoCardView(item: photo)
                        .frame(maxWidth: cardMaxWidth, maxHeight: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .id(photo.id)
                        .offset(x: dragOffset.width, y: dragOffset.height)
                        .rotationEffect(.degrees(Double(dragOffset.width) / 25.0))
                        .gesture(cardDragGesture)
                        .overlay(alignment: .center) { swipeOverlay }
                }

                // 照片信息面板
                PhotoInfoPanel(asset: photo.asset)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                // 操作按钮行
                buttonsRow
                    .padding(.bottom, safeBottomInset + 8)
            }
        }
    }

    private var safeBottomInset: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return 34 }
        return window.safeAreaInsets.bottom
    }

    // MARK: - 进度条

    private var progressBar: some View {
        VStack(spacing: 3) {
            Text("\(min(viewModel.currentIndex + 1, viewModel.currentPhotos.count)) / \(viewModel.currentPhotos.count)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(Color(.tertiaryLabel))

            ProgressView(value: Double(min(viewModel.currentIndex, viewModel.currentPhotos.count)), total: Double(max(viewModel.currentPhotos.count, 1)))
                .tint(.blue)
                .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
        }
    }

    // MARK: - 滑动覆盖层

    private var swipeOverlay: some View {
        Group {
            if dragOffset.width < -80 {
                overlayBadge(text: "✓ 保留", color: .green)
            } else if dragOffset.width > 80 {
                overlayBadge(text: "← 返回", color: .orange)
            } else if dragOffset.height < -80 {
                overlayBadge(text: "✕ 删除", color: .red)
            }
        }
        .allowsHitTesting(false)
    }

    private func overlayBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.largeTitle.bold())
            .foregroundColor(color.opacity(0.75))
            .shadow(color: color.opacity(0.3), radius: 10)
            .scaleEffect(0.9 + min(abs(dragOffset.width) / 300.0, abs(dragOffset.height) / 300.0, 0.15))
    }

    // MARK: - 按钮行

    private var buttonsRow: some View {
        HStack(spacing: 36) {
            actionButton(icon: "arrow.left", label: "保留", color: .green) {
                performSwipe(action: .keep)
            }
            actionButton(icon: "arrow.up", label: "删除", color: .red) {
                performSwipe(action: .delete)
            }
            actionButton(icon: "arrow.right", label: "返回", color: .orange) {
                performSwipe(action: .goBack)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 28)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(color)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(color.opacity(0.9))
            }
            .frame(width: 66, height: 56)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 手势

    private enum SwipeAction { case keep, delete, goBack }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                let dx = value.translation.width
                let dy = value.translation.height
                let velocityX = value.predictedEndTranslation.width

                if abs(dx) > abs(dy) || (abs(velocityX) > 500 && abs(dx) > threshold * 0.5) {
                    if dx < -threshold || velocityX < -500 {
                        performSwipe(action: .keep)
                    } else if dx > threshold || velocityX > 500 {
                        performSwipe(action: .goBack)
                    } else {
                        resetDrag()
                    }
                } else {
                    if dy < -threshold {
                        performSwipe(action: .delete)
                    } else {
                        resetDrag()
                    }
                }
            }
    }

    private func resetDrag() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = .zero
        }
    }

    private func performSwipe(action: SwipeAction) {
        let target: CGSize
        switch action {
        case .keep:  target = CGSize(width: -1000, height: 0)
        case .delete: target = CGSize(width: 0, height: -1000)
        case .goBack: target = CGSize(width: 1000, height: 0)
        }
        withAnimation(.easeOut(duration: 0.22)) { dragOffset = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            dragOffset = .zero
            switch action {
            case .keep:   viewModel.markAsKeptAndAdvance()
            case .delete: viewModel.markForDeletionAndAdvance()
            case .goBack: viewModel.goToPrevious()
            }
        }
    }
}

// MARK: - PhotoCardView（审查界面照片卡片，根据照片比例自动调整大小）

struct PhotoCardView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    let item: PhotoItem
    @State private var livePhotoView: PHLivePhotoView?
    @State private var isLivePhoto = false
    @State private var isPlayingLive = false

    /// 根据照片像素计算宽高比
    private var photoAspectRatio: CGFloat {
        let w = CGFloat(item.asset.pixelWidth)
        let h = CGFloat(item.asset.pixelHeight)
        guard w > 0, h > 0 else { return 3.0 / 4.0 }
        return w / h
    }

    var body: some View {
        ZStack {
            // Live Photo
            if isLivePhoto, let livePhotoView {
                LivePhotoViewRepresentable(livePhotoView: livePhotoView, isPlaying: $isPlayingLive)
            } else {
                // 普通静态照片
                StaticPhotoView(item: item)
            }

            // LIVE 标记（左上角）
            if isLivePhoto {
                VStack {
                    HStack {
                        liveBadge
                        Spacer()
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
        // 根据照片实际比例自动调整卡片大小
        .aspectRatio(photoAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task(id: item.id) {
            isLivePhoto = item.asset.mediaSubtypes.contains(.photoLive)
            if isLivePhoto {
                loadLivePhoto()
            }
        }
        // 长按播放 Live Photo
        .onLongPressGesture(minimumDuration: 0.1) {
            if isLivePhoto {
                isPlayingLive = true
            }
        } onPressingChanged: { pressing in
            if !pressing && isPlayingLive {
                isPlayingLive = false
            }
        }
    }

    // MARK: - LIVE 标记

    private var liveBadge: some View {
        Text("LIVE")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(1.2)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.black.opacity(0.5))
                    .blur(radius: 1)
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
            )
    }

    // MARK: - 加载 Live Photo

    private func loadLivePhoto() {
        let targetSize = CGSize(width: 1024, height: 1024)
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestLivePhoto(
            for: item.asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { livePhoto, _ in
            guard let livePhoto else { return }
            DispatchQueue.main.async {
                let view = PHLivePhotoView()
                view.contentMode = .scaleAspectFit
                view.livePhoto = livePhoto
                view.isMuted = true
                self.livePhotoView = view
            }
        }
    }
}

// MARK: - StaticPhotoView（普通静态照片）

struct StaticPhotoView: View {
    let item: PhotoItem
    @State private var image: UIImage?
    @State private var loadFailed = false

    private let sizes: [CGSize] = [
        CGSize(width: 1500, height: 2000),
        PHImageManagerMaximumSize,
        CGSize(width: 600, height: 800)
    ]

    var body: some View {
        Group {
            if let ui = image {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else if loadFailed {
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("无法加载此照片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.gray)
            }
        }
        .task(id: item.id) {
            image = nil
            loadFailed = false
            let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
            if let result { image = result }
            else { loadFailed = true }
        }
    }
}

// MARK: - LivePhotoViewRepresentable

struct LivePhotoViewRepresentable: UIViewRepresentable {
    let livePhotoView: PHLivePhotoView
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> PHLivePhotoView {
        livePhotoView
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        if isPlaying {
            uiView.startPlayback(with: .full)
        } else {
            uiView.stopPlayback()
        }
    }
}
