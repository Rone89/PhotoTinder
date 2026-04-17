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
    
    var currentGroup: MonthGroup? {
        guard let index = currentGroupIndex, monthGroups.indices.contains(index) else { return nil }
        return monthGroups[index]
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
    
    func cancelDelete(for id: String) {
        guard let gIdx = currentGroupIndex else { return }
        if let iIdx = monthGroups[gIdx].items.firstIndex(where: { $0.id == id }) {
            monthGroups[gIdx].items[iIdx].status = .keep
        }
    }
    
    func commitDeletion() async {
        guard let gIdx = currentGroupIndex else { return }
        let assets = monthGroups[gIdx].items.filter { $0.status == .delete }.map { $0.asset }
        try? await PhotoLibraryService.shared.deleteAssets(assets)
        monthGroups[gIdx].items.removeAll { $0.status == .delete }
    }
}

enum SwipeDirection { case left, right, up, down }