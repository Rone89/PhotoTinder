import Photos
import UIKit

actor PhotoLibraryService {
    static let shared = PhotoLibraryService()
    
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }
    
    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }
}
