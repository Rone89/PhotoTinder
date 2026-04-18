import Foundation
import Photos
import CoreLocation

enum ReviewStatus {
    case unreviewed, keep, delete
}

struct PhotoItem: Identifiable, Equatable, Hashable {
    let id: String
    let asset: PHAsset
    var status: ReviewStatus = .unreviewed
    
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 照片元信息

struct PhotoMetadata: Sendable {
    let creationDate: Date?
    let locationName: String?
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: String?
    let deviceName: String?
    let duration: String?  // 视频时长，图片为 nil
}

extension PhotoMetadata {
    /// 从 PHAsset 提取基本信息（不需要加载图片数据）
    static func from(_ asset: PHAsset) -> PhotoMetadata {
        PhotoMetadata(
            creationDate: asset.creationDate,
            locationName: asset.location.flatMap { locationString($0) },
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            fileSize: formatFileSize(asset),
            deviceName: nil,  // 需要加载数据才能获取
            duration: asset.mediaType == .video ? formatDuration(asset.duration) : nil
        )
    }
    
    /// 异步获取完整元信息（包括需要加载数据的设备名）
    static async func fullFrom(_ asset: PHAsset) -> PhotoMetadata {
        let base = from(asset)
        
        // 通过 imageData 获取设备信息
        var device: String? = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageData(for: asset, options: options) { data, _, _, _ in
                if let data {
                    device = extractDevice(from: data)
                }
                continuation.resume()
            }
        }
        
        return PhotoMetadata(
            creationDate: base.creationDate,
            locationName: base.locationName,
            pixelWidth: base.pixelWidth,
            pixelHeight: base.pixelHeight,
            fileSize: base.fileSize,
            deviceName: device,
            duration: base.duration
        )
    }
    
    // MARK: - Helpers
    
    private static func locationString(_ location: CLLocation) -> String? {
        // 简单格式：纬度,经度（反向地理编码太慢，先用坐标）
        let lat = String(format: "%.4f", location.coordinate.latitude)
        let lon = String(format: "%.4f", location.coordinate.longitude)
        return "\(lat), \(lon)"
    }
    
    private static func formatFileSize(_ asset: PHAsset) -> String? {
        // PHAsset 没有直接暴露文件大小，返回像素尺寸作为替代
        let pixels = asset.pixelWidth * asset.pixelHeight
        if pixels < 1_000_000 {
            return "\(pixels / 1000)K 像素"
        } else {
            return String(format: "%.1fM 像素", Double(pixels) / 1_000_000.0)
        }
    }
    
    private static func formatDuration(_ seconds: TimeInterval) -> String? {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
    
    private static func extractDevice(from data: Data) -> String? {
        let imgSource = CGImageSourceCreateWithData(data as CFData, nil)
        guard let properties = imgSource.flatMap({ CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [String: Any]) else {
            return nil
        }
        // 尝试多种 EXIF 键
        if let tiffProps = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            return tiffProps[kCGImagePropertyTIFFModel as String] as? String
                   ?? tiffProps["Make"] as? String
        }
        if let exifProps = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            return exifProps["LensModel"] as? String
        }
        return nil
    }
}
