import SwiftUI
import Photos
import MapKit

struct ReviewView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
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
                    // 一轮完成 → 显示总结并返回主页（不再自动进入下一轮）
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
                                .glassEffect(.regular.interactive())
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

    /// 一轮完成视图 —— 返回主页而非继续下一轮
    private var batchCompleteView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // 完成动画图标
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

            // 返回主页按钮
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
            
            // 可选的"再来一轮"
            if viewModel.hasMorePhotos {
                Button {
                    Task {
                        await viewModel.startNewRound()
                    }
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

    // MARK: - 主内容区（照片卡片 + 元信息）

    @ViewBuilder
    private func mainContent(photo: PhotoItem) -> some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height - 160 // 留出按钮区域
            
            VStack(spacing: 0) {
                // 进度条
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // 照片卡片区（占据大部分空间）
                ZStack {
                    photoCard(photo: photo, size: CGSize(width: geo.size.width - 32, height: availableHeight - 80))
                        .id(photo.id)
                        .offset(x: dragOffset.width, y: dragOffset.height)
                        .rotationEffect(.degrees(Double(dragOffset.width) / 25.0))
                        .gesture(cardDragGesture)
                        .overlay(alignment: .center) { swipeOverlay }
                    
                    // 缩放时禁用滑动提示
                    if abs(dragOffset.width) < 10 && abs(dragOffset.height) < 10 {
                        // 静态状态
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

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
            
            ProgressView(value: Double(min(viewModel.currentIndex, viewModel.currentPhotos.count)), total: Double(currentNonZeroCount))
                .tint(.blue)
                .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
        }
    }

    private var currentNonZeroCount: Int {
        max(viewModel.currentPhotos.count, 1)
    }

    // MARK: - 照片卡片（自由缩放版本）

    @ViewBuilder
    private func photoCard(photo: PhotoItem, size: CGSize) -> some View {
        ZoomablePhotoCard(item: photo)
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

    // MARK: - 按钮行（iOS 26 Liquid Glass）

    private var buttonsRow: some View {
        GlassEffectContainer(spacing: 36) {
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
            .padding(.vertical, 10)
        }
        .glassEffect(.regular.tint().interactive())
        .clipShape(Capsule())
        .padding(.horizontal, 24)
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
                    // 水平主导或快速水平滑动
                    if dx < -threshold || velocityX < -500 {
                        performSwipe(action: .keep)
                    } else if dx > threshold || velocityX > 500 {
                        performSwipe(action: .goBack)
                    } else {
                        resetDrag()
                    }
                } else {
                    // 垂直主导
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

// MARK: - ZoomablePhotoCard（核心：照片在整个视窗内自由缩放）

struct ZoomablePhotoCard: View {
    let item: PhotoItem
    @State private var image: UIImage?
    @State private var loadFailed = false
    
    // 缩放/平移状态
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var translation: CGSize = .zero
    @State private var lastTranslation: CGSize = .zero

    private let sizes: [CGSize] = [
        CGSize(width: 1500, height: 2000),
        PHImageManagerMaximumSize,
        CGSize(width: 600, height: 800)
    ]

    private var isZoomed: Bool { scale > 1.05 }

    var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            
            ZStack {
                // 背景 — 未缩放时有圆角和阴影
                RoundedRectangle(cornerRadius: isZoomed ? 0 : 20)
                    .fill(Color(.systemGray6))
                    .shadow(color: isZoomed ? .clear : .black.opacity(0.08), radius: 10, y: 4)
                
                if let ui = image {
                    // 图片 — 关键：使用整个容器作为参考系
                    imageContent(uiImage: ui, container: containerSize)
                } else if loadFailed {
                    errorContent
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.gray)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .task(id: item.id) {
            image = nil
            loadFailed = false
            resetZoom()
            let result = await PhotoLoader.loadWithFallback(for: item.asset, sizes: sizes)
            if let result { image = result }
            else { loadFailed = true }
        }
    }

    // MARK: - 图片内容（核心缩放逻辑）
    
    @ViewBuilder
    private func imageContent(uiImage: UIImage, container: CGSize) -> some View {
        // 计算图片在容器中的基础显示尺寸（fit 模式）
        let baseSize = fittedImageSize(uiImage.size, in: container)
        
        Image(uiImage: uiImage)
            .resizable()
            // 先设置基础 frame（fit 尺寸），然后通过 scale 和 offset 变换
            .frame(width: baseSize.width, height: baseSize.height)
            // 缩放以 center 为锚点
            .scaleEffect(scale, anchor: .center)
            // 平移偏移量直接叠加
            .offset(x: translation.width, y: translation.height)
            // 未缩放时裁剪到圆角矩形，放大后不裁剪让照片溢出到全屏
            .clipped(when: !isZoomed)
            // 双击重置
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    resetZoom()
                }
            }
            // 动画过渡
            .animation(.spring(response: 0.2, dampingFraction: 0.85), value: scale)
            .animation(.smooth(duration: 0.15), value: translation)
            // 手势
            .gesture(magnificationGesture(baseSize: baseSize))
            .simultaneousGesture(dragGesture)
    }

    /// 计算图片在容器内 fit 模式下的显示尺寸
    private func fittedImageSize(_ imgSize: CGSize, in container: CGSize) -> CGSize {
        let imgAspect = imgSize.width / imgSize.height
        let boxAspect = container.width / container.height
        
        if imgAspect > boxAspect {
            return CGSize(width: container.width, height: container.width / imgAspect)
        } else {
            return CGSize(width: container.height * imgAspect, height: container.height)
        }
    }

    // MARK: - 错误内容
    
    private var errorContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("无法加载此照片")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 手势

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 10.0)
            }
            .onEnded { _ in
                if scale < 1.05 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                } else {
                    lastScale = scale
                    lastTranslation = translation
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.02 {
                    translation = CGSize(
                        width: lastTranslation.width + value.translation.width,
                        height: lastTranslation.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                if scale > 1.02 {
                    lastTranslation = translation
                }
            }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        translation = .zero
        lastTranslation = .zero
    }
}

// MARK: - 条件裁剪修饰器

private extension View {
    @ViewBuilder
    func clipped(when condition: Bool) -> some View {
        if condition {
            self.clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            self
        }
    }
}
