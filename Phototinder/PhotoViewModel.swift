import SwiftUI
import Photos

@MainActor
@Observable
class PhotoViewModel {
    // MARK: - 当前批次
    var currentPhotos: [PhotoItem] = []
    var currentIndex: Int = 0
    var batchNumber: Int = 0

    // MARK: - 跨批次追踪
    var seenAssetIds: Set<String> = []
    var totalReviewed: Int = 0
    var totalKept: Int = 0

    // MARK: - 跨批次回收站（持久保存）
    var allDeletedPhotos: [PhotoItem] = []

    // MARK: - 状态
    var isLoading: Bool = false
    var hasMorePhotos: Bool = true
    var isReviewing: Bool = false

    // MARK: - 计算属性
    var currentPhoto: PhotoItem? {
        guard currentIndex >= 0, currentIndex < currentPhotos.count else { return nil }
        return currentPhotos[currentIndex]
    }

    var currentBatchDeletedCount: Int {
        currentPhotos.filter { $0.status == .delete }.count
    }

    var currentBatchKeptCount: Int {
        currentPhotos.filter { $0.status == .keep }.count
    }

    var currentBatchReviewedCount: Int {
        currentPhotos.filter { $0.status != .unreviewed }.count
    }

    var isBatchComplete: Bool {
        currentBatchReviewedCount >= currentPhotos.count && !currentPhotos.isEmpty
    }

    // MARK: - 加载照片
    func checkPermissionAndFetch() async {
        isLoading = true
        let authorized = await PhotoLibraryService.shared.requestAuthorization()
        if authorized {
            await loadRandomPhotos()
        }
        isLoading = false
    }

    func loadRandomPhotos(count: Int = 100) async {
        isLoading = true
        defer { isLoading = false }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var available: [PHAsset] = []
        allPhotos.enumerateObjects { [self] asset, _, _ in
            if !seenAssetIds.contains(asset.localIdentifier) {
                available.append(asset)
            }
        }

        if available.isEmpty {
            hasMorePhotos = false
            return
        }

        available.shuffle()
        let selected = Array(available.prefix(count))

        for asset in selected {
            seenAssetIds.insert(asset.localIdentifier)
        }

        currentPhotos = selected.map { PhotoItem(id: $0.localIdentifier, asset: $0) }
        currentIndex = 0
        batchNumber += 1
        isReviewing = true
    }

    func loadNextBatch() async {
        await loadRandomPhotos()
    }

    // MARK: - 滑动操作

    /// 左滑 = 保留，前进到下一张
    func markAsKeptAndAdvance() {
        guard let photo = currentPhoto else { return }
        if let idx = currentPhotos.firstIndex(where: { $0.id == photo.id }) {
            currentPhotos[idx].status = .keep
        }
        totalKept += 1
        totalReviewed += 1
        advanceCard()
    }

    /// 上滑 = 删除，返回上一张
    func markForDeletionAndGoBack() {
        guard let photo = currentPhoto else { return }
        if let idx = currentPhotos.firstIndex(where: { $0.id == photo.id }) {
            currentPhotos[idx].status = .delete
        }
        if !allDeletedPhotos.contains(where: { $0.id == photo.id }) {
            allDeletedPhotos.append(photo)
        }
        totalReviewed += 1
        goBack()
    }

    private func advanceCard() {
        currentIndex += 1
        if isBatchComplete {
            Task { await loadNextBatch() }
        }
    }

    /// 右滑 = 返回上一张（不修改状态）
    func goToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    /// 返回上一张（内部使用）
    private func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func markAsKept() {
        markAsKeptAndAdvance()
    }

    func markForDeletion() {
        markForDeletionAndGoBack()
    }

    func undoLastSwipe() {
        goToPrevious()
    }

    // MARK: - 回收站操作

    func restoreFromTrash(_ item: PhotoItem) {
        allDeletedPhotos.removeAll { $0.id == item.id }
        if let idx = currentPhotos.firstIndex(where: { $0.id == item.id }) {
            currentPhotos[idx].status = .unreviewed
        }
    }

    func restoreSelectedFromTrash(_ ids: Set<String>) {
        for id in ids {
            allDeletedPhotos.removeAll { $0.id == id }
            if let idx = currentPhotos.firstIndex(where: { $0.id == id }) {
                currentPhotos[idx].status = .unreviewed
            }
        }
    }

    func restoreAllFromTrash() {
        let ids = Set(allDeletedPhotos.map { $0.id })
        allDeletedPhotos.removeAll()
        for idx in currentPhotos.indices {
            if ids.contains(currentPhotos[idx].id) {
                currentPhotos[idx].status = .unreviewed
            }
        }
    }

    func deleteItemsFromTrash(_ items: [PhotoItem]) async {
        let assets = items.map { $0.asset }
        let ids = Set(items.map { $0.id })
        try? await PhotoLibraryService.shared.deleteAssets(assets)
        allDeletedPhotos.removeAll { ids.contains($0.id) }
        let before = currentPhotos.count
        currentPhotos.removeAll { ids.contains($0.id) }
        let removed = before - currentPhotos.count
        totalReviewed = max(0, totalReviewed - removed)
        if currentIndex >= currentPhotos.count {
            currentIndex = max(0, currentPhotos.count - 1)
        }
    }

    func deleteAllFromTrash() async {
        let assets = allDeletedPhotos.map { $0.asset }
        let ids = Set(allDeletedPhotos.map { $0.id })
        guard !assets.isEmpty else { return }
        try? await PhotoLibraryService.shared.deleteAssets(assets)
        allDeletedPhotos.removeAll()
        let before = currentPhotos.count
        currentPhotos.removeAll { ids.contains($0.id) }
        let removed = before - currentPhotos.count
        totalReviewed = max(0, totalReviewed - removed)
        if currentIndex >= currentPhotos.count {
            currentIndex = max(0, currentPhotos.count - 1)
        }
    }

    // MARK: - 删除托盘（当前批次）

    func cancelDelete(for id: String) {
        if let idx = currentPhotos.firstIndex(where: { $0.id == id }) {
            currentPhotos[idx].status = .unreviewed
        }
        allDeletedPhotos.removeAll { $0.id == id }
    }

    // MARK: - 重置

    func reset() {
        currentPhotos = []
        currentIndex = 0
        seenAssetIds = []
        totalReviewed = 0
        totalKept = 0
        batchNumber = 0
        allDeletedPhotos = []
        hasMorePhotos = true
        isReviewing = false
    }
}
