import SwiftUI
import Photos

@MainActor
@Observable
class PhotoViewModel {
    var isAuthorized: Bool = false
    var isLoading: Bool = false
    var monthGroups: [MonthGroup] = []
    
    // 当前正在阅览的月份和进度
    var currentGroupIndex: Int? = nil
    var currentCardIndex: Int = 0
    
    var errorMsg: String? = nil
    
    var currentGroup: MonthGroup? {
        guard let index = currentGroupIndex, monthGroups.indices.contains(index) else { return nil }
        return monthGroups[index]
    }
    
    func checkPermissionAndFetch() async {
        isLoading = true
        let hasPermission = await PhotoLibraryService.shared.requestAuthorization()
        self.isAuthorized = hasPermission
        
        if hasPermission {
            self.monthGroups = await PhotoLibraryService.shared.fetchAndGroupPhotos()
        }
        isLoading = false
    }
    
    // MARK: - 阅览与手势逻辑
    
    func startReviewing(groupIndex: Int) {
        currentGroupIndex = groupIndex
        // 找到第一个未处理的照片
        if let firstUnreviewed = monthGroups[groupIndex].items.firstIndex(where: { $0.status == .unreviewed }) {
            currentCardIndex = firstUnreviewed
        } else {
            currentCardIndex = 0
        }
    }
    
    func handleSwipe(direction: SwipeDirection) {
        guard let groupIndex = currentGroupIndex else { return }
        let itemsCount = monthGroups[groupIndex].items.count
        
        switch direction {
        case .left: // 保留 (Keep) -> 下一张
            if currentCardIndex < itemsCount {
                monthGroups[groupIndex].items[currentCardIndex].status = .keep
                advanceToNextCard()
            }
        case .up: // 删除 (Delete) -> 下一张
            if currentCardIndex < itemsCount {
                monthGroups[groupIndex].items[currentCardIndex].status = .delete
                advanceToNextCard()
            }
        case .right: // 撤销 (Undo) -> 上一张
            if currentCardIndex > 0 {
                currentCardIndex -= 1
                monthGroups[groupIndex].items[currentCardIndex].status = .unreviewed
            }
        case .down:
            break // 忽略下滑
        }
    }
    
    private func advanceToNextCard() {
        // 稍微延迟以等待动画完成（实际项目中可由 View 层的动画完成回调触发）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.currentCardIndex += 1
        }
    }
    
    // MARK: - 批量操作
    func commitDeletion() async {
        guard let groupIndex = currentGroupIndex else { return }
        let group = monthGroups[groupIndex]
        
        let assetsToDelete = group.items.filter { $0.status == .delete }.map { $0.asset }
        guard !assetsToDelete.isEmpty else { return }
        
        do {
            try await PhotoLibraryService.shared.deleteAssets(assetsToDelete)
            // 删除成功后，从数据源中移除
            monthGroups[groupIndex].items.removeAll { $0.status == .delete }
            currentCardIndex = monthGroups[groupIndex].items.count // 刷新状态
        } catch {
            self.errorMsg = "删除失败: \(error.localizedDescription)"
        }
    }
    
    func closeReview() {
        currentGroupIndex = nil
        currentCardIndex = 0
    }
}

enum SwipeDirection {
    case left, right, up, down
}