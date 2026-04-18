import SwiftUI
import Photos

struct ReviewView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @State private var dragOffset: CGFloat = 0
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
            if viewModel.currentIndex + 1 < viewModel.currentPhotos.count {
                behindCard
            }
            if let photo = viewModel.currentPhoto {
                frontCard(photo)
            }
        }
    }

    private var behindCard: some View {
        let item = viewModel.currentPhotos[viewModel.currentIndex + 1]
        return PhotoCardView(item: item)
            .id(item.id)
            .scaleEffect(0.9)
            .offset(y: 12)
            .opacity(0.5)
    }

    private func frontCard(_ item: PhotoItem) -> some View {
        PhotoCardView(item: item)
            .id(item.id)
            .offset(x: dragOffset)
            .rotationEffect(.degrees(Double(dragOffset) / 25.0))
            .gesture(cardDragGesture)
            .overlay {
                swipeOverlay
            }
    }

    private var swipeOverlay: some View {
        Group {
            if dragOffset > 50 {
                Text("保留")
                    .font(.largeTitle.bold())
                    .foregroundColor(.green.opacity(0.6))
            } else if dragOffset < -50 {
                Text("删除")
                    .font(.largeTitle.bold())
                    .foregroundColor(.red.opacity(0.6))
            }
        }
        .allowsHitTesting(false)
    }

    private var buttonsRow: some View {
        HStack(spacing: 40) {
            circleButton(icon: "arrow.uturn.left", color: .orange, label: "撤销") {
                viewModel.undoLastSwipe()
            }
            circleButton(icon: "checkmark.circle", color: .green, label: "保留") {
                performSwipe(isKeep: true)
            }
            circleButton(icon: "trash", color: .red, label: "删除") {
                performSwipe(isKeep: false)
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

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 120
                if value.translation.width > threshold {
                    performSwipe(isKeep: true)
                } else if value.translation.width < -threshold {
                    performSwipe(isKeep: false)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func performSwipe(isKeep: Bool) {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = isKeep ? 800 : -800
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            dragOffset = 0
            if isKeep {
                viewModel.markAsKept()
            } else {
                viewModel.markForDeletion()
            }
        }
    }
}

// MARK: - PhotoCardView（纯展示，不持有手势和偏移状态）

struct PhotoCardView: View {
    let item: PhotoItem
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemGray6))
            .overlay {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                if isLoading && image == nil {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.gray)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            .onAppear { loadImage() }
    }

    private func loadImage() {
        guard image == nil else { return }
        isLoading = true

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

            DispatchQueue.main.async {
                self.image = result
                self.isLoading = false
            }
        }
    }
}

// MARK: - ThumbnailView（网格缩略图）

struct ThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @State private var didLoad = false

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
                }
            }
            .onAppear { loadImage() }
    }

    private func loadImage() {
        guard !didLoad else { return }
        didLoad = true

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

            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}
