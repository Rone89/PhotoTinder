import SwiftUI
import Photos

@MainActor
@Observable
class PhotoViewModel {
    var isAuthorized = false
    var isLoading = false
    var monthGroups: [MonthGroup] = []
    var currentGroupIndex: Int? = nil
    var currentCardIndex: Int = 0
    
    // 回收站相关状态
    var showConfirmDeleteAlert = false
    var showDeleteSuccessAlert = false
    var deletedCount = 0
    
    var currentGroup: MonthGroup? {
        guard let index = currentGroupIndex, monthGroups.indices.contains(index) else { return nil }
        return monthGroups[index]
    }
    
    /// 回收站：收集所有分组中标记为删除的照片（按月分组）
    var trashGroups: [MonthGroup] {
        monthGroups.compactMap { group in
            let deleteItems = group.items.filter { $0.status == .delete }
            if deleteItems.isEmpty { return nil }
            return MonthGroup(title: group.title, date: group.date, items: deleteItems)
        }
    }
    
    /// 回收站总数
    var totalTrashCount: Int {
        monthGroups.reduce(0) { $0 + $1.items.filter { $0.status == .delete }.count }
    }
    
    func checkPermissionAndFetch() async {
        isLoading = true
        isAuthorized = await PhotoLibraryService.shared.requestAuthorization()
        if isAuthorized {
            monthGroups = await PhotoLibraryService.shared.fetchAndGroupPhotos()
        }
        isLoading = false
    }
    
    func startReviewing(index: Int) {
        currentGroupIndex = index
        currentCardIndex = monthGroups[index].items.firstIndex(where: { $0.status == .unreviewed }) ?? 0
    }
    
    func handleSwipe(direction: SwipeDirection) {
        guard let gIdx = currentGroupIndex else { return }
        switch direction {
        case .left: monthGroups[gIdx].items[currentCardIndex].status = .keep
        case .up: monthGroups[gIdx].items[currentCardIndex].status = .delete
        case .right:
            if currentCardIndex > 0 {
                currentCardIndex -= 1
                monthGroups[gIdx].items[currentCardIndex].status = .unreviewed
                return
            }
        case .down: break
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.currentCardIndex += 1
        }
    }
    
    // MARK: - 回收站操作
    
    /// 从回收站恢复（取消删除标记）
    func restoreFromTrash(_ item: PhotoItem) {
        for groupIndex in monthGroups.indices {
            if let itemIndex = monthGroups[groupIndex].items.firstIndex(where: { $0.id == item.id }) {
                monthGroups[groupIndex].items[itemIndex].status = .keep
                return
            }
        }
    }
    
    /// 从回收站恢复全部
    func restoreAllFromTrash() {
        for groupIndex in monthGroups.indices {
            for itemIndex in monthGroups[groupIndex].items.indices {
                if monthGroups[groupIndex].items[itemIndex].status == .delete {
                    monthGroups[groupIndex].items[itemIndex].status = .keep
                }
            }
        }
    }
    
    /// 确认删除回收站中所有照片（真正从相册删除）
    func confirmDeleteAllTrash() async {
        let allDeleteAssets = monthGroups.flatMap { group in
            group.items.filter { $0.status == .delete }.map { $0.asset }
        }
        guard !allDeleteAssets.isEmpty else { return }
        
        try? await PhotoLibraryService.shared.deleteAssets(allDeleteAssets)
        
        // 从分组中移除已删除的照片
        for groupIndex in monthGroups.indices {
            monthGroups[groupIndex].items.removeAll { $0.status == .delete }
        }
        
        deletedCount = allDeleteAssets.count
        showDeleteSuccessAlert = true
    }
    
    /// 确认删除回收站中指定照片
    func confirmDeleteItems(_ items: [PhotoItem]) async {
        let assets = items.map { $0.asset }
        try? await PhotoLibraryService.shared.deleteAssets(assets)
        
        let deleteIds = Set(items.map { $0.id })
        for groupIndex in monthGroups.indices {
            monthGroups[groupIndex].items.removeAll { deleteIds.contains($0.id) }
        }
        
        deletedCount = items.count
        showDeleteSuccessAlert = true
    }
    
    /// 删除当前组中标记的照片（ReviewView 中的提交删除按钮）
    func commitDeletion() async {
        guard let gIdx = currentGroupIndex else { return }
        let assets = monthGroups[gIdx].items.filter { $0.status == .delete }.map { $0.asset }
        try? await PhotoLibraryService.shared.deleteAssets(assets)
        monthGroups[gIdx].items.removeAll { $0.status == .delete }
    }
    
    func cancelDelete(for id: String) {
        guard let gIdx = currentGroupIndex else { return }
        if let iIdx = monthGroups[gIdx].items.firstIndex(where: { $0.id == id }) {
            monthGroups[gIdx].items[iIdx].status = .keep
        }
    }
}

enum SwipeDirection { case left, right, up, down }
