import SwiftUI
import Photos

struct ReviewView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @State private var dragOffset: CGSize = .zero
    @State private var showDeleteTray = false
    @State private var showTrashView = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.currentPhotos.isEmpty {
                    loadingView
                } else if viewModel.currentPhotos.isEmpty {
                    noPhotosView
                } else if viewModel.currentPhoto == nil {
                    batchCompleteView
                } else {
                    mainContent
                }
            }
            .navigationTitle("第 \(viewModel.batchNumber) 轮")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { viewModel.isReviewing = false }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.currentBatchDeletedCount > 0 {
                        Button { showDeleteTray = true } label: {
                            Label("\(viewModel.currentBatchDeletedCount)", systemImage: "trash")
                                .font(.subheadline)
                        }
                    }
                    Button { showTrashView = true } label: {
                        Label("回收站", systemImage: "archivebox")
                            .font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showDeleteTray) {
                DeleteTrayView()
            }
            .fullScreenCover(isPresented: $showTrashView) {
                NavigationStack { TrashView() }
            }
        }
    }

    // MARK: - 子视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("加载照片中...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var noPhotosView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("没有更多照片了")
                .font(.headline)
        }
    }

    private var batchCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.green)
            Text("本轮完成")
                .font(.title.bold())
            HStack(spacing: 40) {
                statLabel("保留", "\(viewModel.currentBatchKeptCount)", .green)
                statLabel("删除", "\(viewModel.currentBatchDeletedCount)", .red)
            }
            if viewModel.hasMorePhotos {
                Button("继续下一轮") {
                    Task { await viewModel.loadNextBatch() }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            } else {
                Text("所有照片已审查完毕")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func statLabel(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title.bold()).foregroundColor(color)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal)
                .padding(.top, 8)
            cardArea
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            buttonsRow
                .padding(.bottom, 8)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 2) {
            Text("\(viewModel.currentBatchReviewedCount) / \(viewModel.currentPhotos.count)")
                .font(.caption2)
                .foregroundColor(.secondary)
            ProgressView(value: Double(viewModel.currentBatchReviewedCount), total: Double(viewModel.currentPhotos.count))
                .tint(.blue)
        }
    }

    private var cardArea: some View {
        ZStack {
            if let photo = viewModel.currentPhoto {
                PhotoCardView(item: photo, onZoomChanged: { isZoomed in
                    // 缩放时禁用滑动，还原后恢复
                })
                    .id(photo.id)
                    .offset(x: dragOffset.width, y: dragOffset.height)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 25.0))
                    .gesture(cardDragGesture)
                    .overlay { swipeOverlay }
            }
        }
    }

    private var swipeOverlay: some View {
        Group {
            if dragOffset.width < -80 {
                Text("✓ 保留")
                    .font(.largeTitle.bold())
                    .foregroundColor(.green.opacity(0.7))
            } else if dragOffset.width > 80 {
                Text("← 返回")
                    .font(.largeTitle.bold())
                    .foregroundColor(.orange.opacity(0.7))
            } else if dragOffset.height < -80 {
                Text("✕ 删除")
                    .font(.largeTitle.bold())
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .allowsHitTesting(false)
    }

    private var buttonsRow: some View {
        GlassEffectContainer(spacing: 40) {
            HStack(spacing: 40) {
                circleButton(icon: "arrow.left", color: .green, label: "保留") {
                    performSwipe(action: .keep)
                }
                circleButton(icon: "arrow.up", color: .red, label: "删除") {
                    performSwipe(action: .delete)
                }
                circleButton(icon: "arrow.right", color: .orange, label: "返回") {
                    performSwipe(action: .goBack)
                }
            }
            .padding(.top, 8)
        }
    }

    private func circleButton(icon: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption)
                    .foregroundColor(color)
            }
            .frame(width: 70, height: 55)
            .glassEffect(.regular.tint(color).interactive())
        }
    }

    // MARK: - 手势

    private enum SwipeAction { case keep, delete, goBack }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 120
                let dx = value.translation.width
                let dy = value.translation.height

                if abs(dx) > abs(dy) {
                    if dx < -threshold { performSwipe(action: .keep) }
                    else if dx > threshold { performSwipe(action: .goBack) }
                    else { resetDrag() }
                } else {
                    if dy < -threshold { performSwipe(action: .delete) }
                    else { resetDrag() }
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
        case .keep:  target = CGSize(width: -800, height: 0)
        case .delete: target = CGSize(width: 0, height: -800)
        case .goBack: target = CGSize(width: 800, height: 0)
        }
        withAnimation(.easeOut(duration: 0.25)) { dragOffset = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            dragOffset = .zero
            switch action {
            case .keep:   viewModel.markAsKeptAndAdvance()
            case .delete: viewModel.markForDeletionAndAdvance()
            case .goBack: viewModel.goToPrevious()
            }
        }
    }
}

// MARK: - PhotoLoader（opportunistic + fast 确保回调一定触发）

enum PhotoLoader {
    /// 异步加载图片。deliveryMode=.opportunistic 保证一定会触发非降级回调，不会挂起。
    /// resizeMode=.fast 对 HEIF/Live Photo 等格式更宽容。
    static func load(for asset: PHAsset,
                     size: CGSize,
                     contentMode: PHImageContentMode = .aspectFit) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var bestImage: UIImage?
            var resumed = false

            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: contentMode,
                options: options
            ) { image, info in
                if let image { bestImage = image }
                // 非降级回调 = 最终结果，无论有没有图片都必须 resume
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded && !resumed {
                    resumed = true
                    continuation.resume(returning: bestImage)
                }
            }
        }
    }

    /// 逐级降级尝试多种尺寸
    static func loadWithFallback(for asset: PHAsset,
                                  sizes: [CGSize],
                                  contentMode: PHImageContentMode = .aspectFit) async -> UIImage? {
        for size in sizes {
            if let img = await load(for: asset, size: size, contentMode: contentMode) {
                return img
            }
        }
        return nil
    }
}

// MARK: - PhotoCardView（支持自由缩放，照片跟随手势放大缩小）

struct PhotoCardView: View {
    let item: PhotoItem
    var onZoomChanged: ((Bool) -> Void)?
    @State private var image: UIImage?
    @State private var loadFailed = false

    // 缩放状态
    @State private var scale: CGFloat = 1.0
    @State private var anchor: UnitPoint = .center
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let sizes: [CGSize] = [
        CGSize(width: 1200, height: 1800),
        PHImageManagerMaximumSize,
        CGSize(width: 400, height: 600)
    ]

    /// 是否正在缩放（放大状态）
    private var isZoomed: Bool { scale > 1.05 }

    var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let imageSize = calculateImageSize(in: containerSize)

            ZStack {
                // 卡片背景 — 仅在未缩放时显示圆角卡片
                RoundedRectangle(cornerRadius: isZoomed ? 0 : 20)
                    .fill(Color(.systemGray6))
                    .shadow(color: isZoomed ? .clear : .black.opacity(0.12), radius: 8, x: 0, y: 4)

                if let ui = image {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize.width, height: imageSize.height)
                        .scaleEffect(scale, anchor: anchor)
                        .offset(offset)
                        .clipped(when: !isZoomed) // 未缩放时裁剪到卡片形状
                        .gesture(magnificationGesture)
                        .simultaneousGesture(dragGesture)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                resetZoom()
                            }
                        }
                        // 缩放过渡动画
                        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: scale)
                } else if loadFailed {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.title).foregroundColor(.secondary)
                        Text("无法加载此照片")
                            .font(.caption).foregroundColor(.secondary)
                    }
                } else {
                    ProgressView().scaleEffect(1.5).tint(.gray)
                }
            }
            .frame(width: containerSize.width, height: containerSize.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .task(id: item.id) {
            image = nil
            loadFailed = false
            withAnimation(.easeInOut(duration: 0.2)) { resetZoom() }
            let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
            if let result { image = result }
            else { loadFailed = true }
        }
    }

    // MARK: - 图片尺寸计算

    private func calculateImageSize(in container: CGSize) -> CGSize {
        guard let ui = image else {
            return container
        }
        let imgAspect = ui.size.width / ui.size.height
        let boxAspect = container.width / container.height

        if imgAspect > boxAspect {
            // 图片更宽 — 以容器宽度为准
            return CGSize(width: container.width, height: container.width / imgAspect)
        } else {
            // 图片更高 — 以容器高度为准
            return CGSize(width: container.height * imgAspect, height: container.height)
        }
    }

    // MARK: - 手势

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 8.0)
                onZoomChanged?(isZoomed)
            }
            .onEnded { value in
                if scale < 1.1 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                } else {
                    lastScale = scale
                    lastOffset = offset
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                if scale > 1.0 {
                    lastOffset = offset
                }
            }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
        anchor = .center
        onZoomChanged?(false)
    }
}

// MARK: - ThumbnailView

struct ThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    private let sizes: [CGSize] = [
        CGSize(width: 200, height: 200),
        CGSize(width: 100, height: 100)
    ]

    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let ui = image {
                    Image(uiImage: ui).resizable().scaledToFill().clipped()
                } else {
                    ProgressView().scaleEffect(0.8).tint(.gray)
                }
            }
            .task(id: asset.localIdentifier) {
                image = nil
                image = await PhotoLoader.loadWithFallback(for: asset, sizes: sizes, contentMode: .aspectFill)
            }
    }
}

// MARK: - Clipped 条件修饰器

private extension View {
    /// 仅在 condition 为 true 时裁剪内容
    @ViewBuilder
    func clipped(when condition: Bool) -> some View {
        if condition {
            self.clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            self
        }
    }
}
