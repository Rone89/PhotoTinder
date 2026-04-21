import SwiftUI
import Photos

// MARK: - PhotoLoader（opportunistic + fast 确保回调一定触发）

enum PhotoLoader {
    /// 异步加载图片。deliveryMode=.opportunistic 保证一定会触发非降级回调。
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
            options.version = .current  // 获取当前版本（包含 HDR 渲染）

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: contentMode,
                options: options
            ) { image, info in
                if let image { bestImage = image }
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
            if let img = await load(for: asset, size: size, contentMode: contentMode) { return img }
        }
        return nil
    }
}

// MARK: - MiniThumbnail（用于回收站网格、删除托盘）
// 注意：不设 aspectRatio，由父级控制尺寸（网格 .aspectRatio(1, ...) 保证 1:1）

struct MiniThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @State private var loadFailed = false

    private let sizes: [CGSize] = [
        CGSize(width: 200, height: 200),
        CGSize(width: 100, height: 100)
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.white.opacity(0.18))
            .overlay {
                if let ui = image {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else if loadFailed {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView().scaleEffect(0.8).tint(.gray)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 0.8)
            }
            .task(id: asset.localIdentifier) {
                image = nil
                loadFailed = false
                let loadedImage = await PhotoLoader.loadWithFallback(for: asset, sizes: sizes, contentMode: .aspectFill)
                if let loadedImage {
                    image = loadedImage
                } else {
                    loadFailed = true
                }
            }
    }
}
