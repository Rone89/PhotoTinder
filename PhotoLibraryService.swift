import Foundation
import Photos
import UIKit

actor PhotoLibraryService {
    static let shared = PhotoLibraryService()
    
    /// 请求相册权限
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    /// 获取并按月份分组所有照片
    func fetchAndGroupPhotos() async -> [MonthGroup] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        // 仅获取图片
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        var groupedDict: [String: [PhotoItem]] = [:]
        var dateDict: [String: Date] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月"
        
        // 遍历所有照片进行分组 (此过程在 Actor 的后台线程进行，不卡主线程)
        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            guard let creationDate = asset.creationDate else { continue }
            
            let monthKey = dateFormatter.string(from: creationDate)
            let item = PhotoItem(id: asset.localIdentifier, asset: asset)
            
            if groupedDict[monthKey] != nil {
                groupedDict[monthKey]?.append(item)
            } else {
                groupedDict[monthKey] = [item]
                // 记录该月份的第一天用于排序
                let components = Calendar.current.dateComponents([.year, .month], from: creationDate)
                if let firstDay = Calendar.current.date(from: components) {
                    dateDict[monthKey] = firstDay
                }
            }
        }
        
        // 转换为数组并按日期降序排列
        return groupedDict.map { key, items in
            MonthGroup(title: key, date: dateDict[key] ?? Date(), items: items)
        }.sorted { $0.date > $1.date }
    }
    
    /// 批量删除指定的 Assets
    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }
}