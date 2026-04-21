import Photos
import PhotosUI
import SwiftUI

struct ReviewView: View {
    @Environment(PhotoViewModel.self) private var viewModel

    @State private var dragOffset: CGSize = .zero
    @State private var showDeleteTray = false

    private enum SwipeAction {
        case keep
        case delete
        case goBack
    }

    private var currentStep: Int {
        guard !viewModel.currentPhotos.isEmpty else { return 0 }
        return min(viewModel.currentIndex + 1, viewModel.currentPhotos.count)
    }

    private var showsActionDock: Bool {
        !viewModel.currentPhotos.isEmpty && !viewModel.isBatchComplete && !viewModel.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackdrop()

                Group {
                    if viewModel.isLoading && viewModel.currentPhotos.isEmpty {
                        loadingView
                    } else if viewModel.currentPhotos.isEmpty {
                        noPhotosView
                    } else if viewModel.isBatchComplete {
                        batchCompleteView
                    } else if let photo = viewModel.currentPhoto {
                        reviewContent(for: photo)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle(viewModel.batchNumber == 0 ? "照片审查" : "第 \(viewModel.batchNumber) 轮")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            viewModel.isReviewing = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .padding(14)
                            .glassEffect(.regular.interactive())
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.currentBatchDeletedCount > 0 {
                        Button {
                            showDeleteTray = true
                        } label: {
                            Label("\(viewModel.currentBatchDeletedCount)", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .glassEffect(.regular.interactive())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .sheet(isPresented: $showDeleteTray) {
                DeleteTrayView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .safeAreaInset(edge: .bottom) {
                if showsActionDock {
                    buttonsRow
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("正在载入这批照片…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noPhotosView: some View {
        VStack(spacing: 18) {
            ContentUnavailableView(
                "没有更多照片了",
                systemImage: "photo.on.rectangle.angled",
                description: Text("当前相册里没有新的照片可供审查。")
            )

            Button {
                viewModel.isReviewing = false
            } label: {
                Label("返回主页", systemImage: "house.fill")
                    .liquidActionLabel(tint: PhotoTinderPalette.accent, prominent: true)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var batchCompleteView: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Label("本轮已完成", systemImage: "checkmark.seal.fill")
                    .font(.headline.weight(.semibold))

                Text("第 \(viewModel.batchNumber) 轮已经整理完毕。")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("你已经完成了 \(viewModel.currentPhotos.count) 张照片的快速筛选，现在可以回到主页继续管理回收站，或者直接开始下一轮。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    StatTile(title: "保留", value: "\(viewModel.currentBatchKeptCount)", systemImage: "heart.fill", tint: PhotoTinderPalette.success)
                    StatTile(title: "删除", value: "\(viewModel.currentBatchDeletedCount)", systemImage: "trash.fill", tint: PhotoTinderPalette.rose)
                }

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.isReviewing = false
                        } label: {
                            Label("回到主页", systemImage: "house.fill")
                                .liquidActionLabel(tint: PhotoTinderPalette.accent)
                        }
                        .buttonStyle(.plain)

                        if viewModel.hasMorePhotos {
                            Button {
                                Task { await viewModel.startNewRound() }
                            } label: {
                                Label("下一轮", systemImage: "sparkles")
                                    .liquidActionLabel(tint: PhotoTinderPalette.accent, prominent: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .dashboardPanel()

            Spacer()
        }
    }

    private func reviewContent(for photo: PhotoItem) -> some View {
        VStack(spacing: 18) {
            progressPanel

            ZStack {
                PhotoCardView(item: photo)
                    .padding(.horizontal, 4)
                    .id(photo.id)
                    .offset(x: dragOffset.width, y: dragOffset.height)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 28.0))
                    .gesture(cardDragGesture)
                    .overlay(alignment: .center) {
                        swipeOverlay
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PhotoInfoPanel(asset: photo.asset)
                .padding(.bottom, 8)
        }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("左滑保留，上滑删除，右滑返回")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(currentStep) / \(max(viewModel.currentPhotos.count, 1))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            ProgressView(value: Double(currentStep), total: Double(max(viewModel.currentPhotos.count, 1)))
                .tint(PhotoTinderPalette.accent)
                .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var swipeOverlay: some View {
        Group {
            if dragOffset.width < -80 {
                overlayBadge(text: "保留")
            } else if dragOffset.width > 80 {
                overlayBadge(text: "返回")
            } else if dragOffset.height < -80 {
                overlayBadge(text: "删除")
            }
        }
        .allowsHitTesting(false)
    }

    private func overlayBadge(text: String) -> some View {
        Text(text)
            .font(.title2.weight(.bold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .glassEffect()
            .scaleEffect(0.92 + min(max(abs(dragOffset.width), abs(dragOffset.height)) / 240.0, 0.14))
    }

    private var buttonsRow: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 12) {
                actionButton(title: "保留", systemImage: "arrow.left", tint: PhotoTinderPalette.success, prominent: false) {
                    performSwipe(action: .keep)
                }

                actionButton(title: "删除", systemImage: "arrow.up", tint: PhotoTinderPalette.rose, prominent: true) {
                    performSwipe(action: .delete)
                }

                actionButton(title: "返回", systemImage: "arrow.right", tint: PhotoTinderPalette.sun, prominent: false) {
                    performSwipe(action: .goBack)
                }
            }
        }
    }

    private func actionButton(title: String, systemImage: String, tint: Color, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .liquidActionLabel(tint: tint, prominent: prominent)
        }
        .buttonStyle(.plain)
    }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 24)
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
                } else if dy < -threshold {
                    performSwipe(action: .delete)
                } else {
                    resetDrag()
                }
            }
    }

    private func resetDrag() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.74)) {
            dragOffset = .zero
        }
    }

    private func performSwipe(action: SwipeAction) {
        let target: CGSize
        switch action {
        case .keep:
            target = CGSize(width: -1000, height: 0)
        case .delete:
            target = CGSize(width: 0, height: -1000)
        case .goBack:
            target = CGSize(width: 1000, height: 0)
        }

        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            dragOffset = .zero

            switch action {
            case .keep:
                viewModel.markAsKeptAndAdvance()
            case .delete:
                viewModel.markForDeletionAndAdvance()
            case .goBack:
                viewModel.goToPrevious()
            }
        }
    }
}

struct PhotoCardView: View {
    let item: PhotoItem

    @State private var livePhotoView: PHLivePhotoView?
    @State private var isLivePhoto = false
    @State private var isPlayingLive = false
    @State private var isHDR = false

    private var photoAspectRatio: CGFloat {
        let width = CGFloat(item.asset.pixelWidth)
        let height = CGFloat(item.asset.pixelHeight)
        guard width > 0, height > 0 else { return 3.0 / 4.0 }
        return width / height
    }

    var body: some View {
        ZStack {
            if isLivePhoto, let livePhotoView {
                LivePhotoViewRepresentable(livePhotoView: livePhotoView, isPlaying: $isPlayingLive)
            } else {
                StaticPhotoView(item: item)
            }

            if isLivePhoto || isHDR {
                VStack {
                    HStack(spacing: 8) {
                        if isLivePhoto {
                            MediaBadge(title: "LIVE", symbol: "livephoto")
                        }

                        if isHDR {
                            MediaBadge(title: "HDR", symbol: nil)
                        }

                        Spacer()
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .aspectRatio(photoAspectRatio, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.28))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 0.9)
        }
        .shadow(color: .black.opacity(0.14), radius: 28, y: 18)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .task(id: item.id) {
            isLivePhoto = item.asset.mediaSubtypes.contains(.photoLive)
            isHDR = item.asset.mediaSubtypes.contains(.photoHDR)
            if isLivePhoto {
                loadLivePhoto()
            }
        }
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
                view.isMuted = false
                self.livePhotoView = view
            }
        }
    }
}

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
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if loadFailed {
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("无法加载此照片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .task(id: item.id) {
            image = nil
            loadFailed = false
            let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
            if let result {
                image = result
            } else {
                loadFailed = true
            }
        }
    }
}

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
