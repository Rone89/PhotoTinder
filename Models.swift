import Foundation
import Photos

enum ReviewStatus {
    case unreviewed
    case keep
    case delete
}

struct PhotoItem: Identifiable, Equatable {
    let id: String // 使用 PHAsset 的 localIdentifier
    let asset: PHAsset
    var status: ReviewStatus = .unreviewed
    
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
}

struct MonthGroup: Identifiable {
    let id = UUID()
    let title: String // 例如 "2023年10月"
    let date: Date // 用于排序
    var items: [PhotoItem]
    
    var unreviewedCount: Int { items.filter { $0.status == .unreviewed }.count }
    var deleteCount: Int { items.filter { $0.status == .delete }.count }
    var keepCount: Int { items.filter { $0.status == .keep }.count }
}