import Photos
import UIKit

actor PhotoLibraryService {
    static let shared = PhotoLibraryService()
    
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    func fetchAndGroupPhotos() async -> [MonthGroup] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        var groupedDict: [String: [PhotoItem]] = [:]
        var dateDict: [String: Date] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月"
        
        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            guard let creationDate = asset.creationDate else { continue }
            let monthKey = dateFormatter.string(from: creationDate)
            let item = PhotoItem(id: asset.localIdentifier, asset: asset)
            
            if groupedDict[monthKey] != nil {
                groupedDict[monthKey]?.append(item)
            } else {
                groupedDict[monthKey] = [item]
                let components = Calendar.current.dateComponents([.year, .month], from: creationDate)
                dateDict[monthKey] = Calendar.current.date(from: components)
            }
        }
        
        return groupedDict.map { MonthGroup(title: $0.key, date: dateDict[$0.key] ?? Date(), items: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }
}