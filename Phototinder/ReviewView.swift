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
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
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
                .buttonStyle(.borderedProminent)
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
                PhotoCardView(item: photo)
                    .id(photo.id)
                    .offset(x: dragOffset.width, y: dragOffset.height)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 25.0))
                    .gesture(cardDragGesture)
                    .overlay {
                        swipeOverlay
                    }
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
        HStack(spacing: 40) {
            // 左滑 = 保留
            circleButton(icon: "arrow.left", color: .green, label: "保留") {
                performSwipe(action: .keep)
            }
            // 上滑 = 删除
            circleButton(icon: "arrow.up", color: .red, label: "删除") {
                performSwipe(action: .delete)
            }
            // 右滑 = 返回上一张
            circleButton(icon: "arrow.right", color: .orange, label: "返回") {
                performSwipe(action: .goBack)
            }
        }
        .padding(.top, 8)
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

                // 判断主导方向
                let isHorizontal = abs(dx) > abs(dy)

                if isHorizontal {
                    if dx < -threshold {
                        performSwipe(action: .keep)       // 左滑 = 保留
                    } else if dx > threshold {
                        performSwipe(action: .goBack)     // 右滑 = 返回
                    } else {
                        resetDrag()
                    }
                } else {
                    if dy < -threshold {
                        performSwipe(action: .delete)     // 上滑 = 删除
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
        let targetOffset: CGSize
        switch action {
        case .keep:
            targetOffset = CGSize(width: -800, height: 0)
        case .delete:
            targetOffset = CGSize(width: 0, height: -800)
        case .goBack:
            targetOffset = CGSize(width: 800, height: 0)
        }

        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            dragOffset = .zero
            switch action {
            case .keep:
                viewModel.markAsKeptAndAdvance()
            case .delete:
                viewModel.markForDeletionAndGoBack()
            case .goBack:
                viewModel.goToPrevious()
            }
        }
    }
}

// MARK: - PhotoCardView（纯展示）

struct PhotoCardView: View {
    let item: PhotoItem
    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemGray6))
            .overlay {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.gray)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            .task(id: item.id) {
                await loadPhoto()
            }
    }

    private func loadPhoto() async {
        image = nil
        let loaded = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .exact
                options.isSynchronous = true
                options.version = .current

                let targetSize = CGSize(width: 1200, height: 1800)
                var result: UIImage?
                PHImageManager.default().requestImage(
                    for: item.asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options
                ) { img, _ in
                    result = img
                }
                continuation.resume(returning: result)
            }
        }
        image = loaded
    }
}

// MARK: - ThumbnailView（网格缩略图）

struct ThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.gray)
                }
            }
            .task(id: asset.localIdentifier) {
                await loadThumbnail()
            }
    }

    private func loadThumbnail() async {
        image = nil
        let loaded = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = true
                options.resizeMode = .exact
                options.isSynchronous = true
                options.deliveryMode = .highQualityFormat

                let targetSize = CGSize(width: 200, height: 200)
                var result: UIImage?
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { img, _ in
                    result = img
                }
                continuation.resume(returning: result)
            }
        }
        image = loaded
    }
}
