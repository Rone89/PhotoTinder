import Foundation
import Photos
import UIKit

enum ReviewStatus: String, Codable {
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
    let isLivePhoto: Bool
}

extension PhotoMetadata {
    /// 从 PHAsset 提取基本信息（不需要加载图片数据）
    static func from(_ asset: PHAsset) -> PhotoMetadata {
        PhotoMetadata(
            creationDate: asset.creationDate,
            locationName: asset.location.flatMap { formatLocation($0) },
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            fileSize: formatFileSize(asset),
            deviceName: nil,
            isLivePhoto: asset.mediaSubtypes.contains(.photoLive)
        )
    }
    
    // MARK: - Helpers
    
    private static func formatLocation(_ location: CLLocation) -> String? {
        let lat = String(format: "%.4f", location.coordinate.latitude)
        let lon = String(format: "%.4f", location.coordinate.longitude)
        return "\(lat), \(lon)"
    }
    
    private static func formatFileSize(_ asset: PHAsset) -> String? {
        let pixels = asset.pixelWidth * asset.pixelHeight
        if pixels < 1_000_000 {
            return "\(pixels / 1000)K px"
        } else {
            return String(format: "%.1fM px", Double(pixels) / 1_000_000.0)
        }
    }
}

// MARK: - 异步提取完整元信息（设备名等需要加载数据）

/// 通过 PHAsset 异步获取设备名等信息
func fetchDeviceName(for asset: PHAsset) async -> String? {
    await withCheckedContinuation { continuation in
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImageData(for: asset, options: options) { data, _, _, _ in
            if let data {
                continuation.resume(returning: extractDevice(from: data))
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

private func extractDevice(from data: Data) -> String? {
    guard let imgSource = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(imgSource, 0, nil) as? [String: Any]
    else { return nil }
    
    if let tiffProps = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
        return tiffProps[kCGImagePropertyTIFFModel as String] as? String
               ?? tiffProps["Make"] as? String
    }
    if let exifProps = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
        return exifProps["LensModel"] as? String
    }
    return nil
}
