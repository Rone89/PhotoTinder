import Foundation
import Photos
import SwiftUI

@MainActor
@Observable
class PhotoViewModel {
    private static let stateStoreKey = "PhotoTinder.AppState"

    private struct PersistedPhotoItem: Codable {
        let id: String
        let status: ReviewStatus
    }

    private struct PersistedState: Codable {
        let currentPhotos: [PersistedPhotoItem]
        let currentIndex: Int
        let batchNumber: Int
        let seenAssetIds: [String]
        let totalReviewed: Int
        let totalKept: Int
        let totalCleaned: Int
        let deletedAssetIds: [String]
        let hasMorePhotos: Bool
    }

    // MARK: - 当前批次

    var currentPhotos: [PhotoItem] = []
    var currentIndex: Int = 0
    var batchNumber: Int = 0

    // MARK: - 跨批次追踪

    var seenAssetIds: Set<String> = []
    var totalReviewed: Int = 0
    var totalKept: Int = 0
    var totalCleaned: Int = 0

    // MARK: - 回收站

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
        !currentPhotos.isEmpty && currentIndex >= currentPhotos.count
    }

    // MARK: - 启动

    func prepareForLaunch() async {
        isLoading = true
        defer { isLoading = false }

        let authorized = await PhotoLibraryService.shared.requestAuthorization()
        guard authorized else { return }

        restorePersistedState()
        isReviewing = false
    }

    // MARK: - 加载照片

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

        guard !available.isEmpty else {
            hasMorePhotos = false
            persistState()
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
        hasMorePhotos = available.count > count
        persistState()
    }

    func startNewRound() async {
        currentPhotos = []
        currentIndex = 0
        persistState()
        await loadRandomPhotos()
    }

    // MARK: - 滑动操作

    func markAsKeptAndAdvance() {
        guard let photo = currentPhoto else { return }
        if let index = currentPhotos.firstIndex(where: { $0.id == photo.id }) {
            currentPhotos[index].status = .keep
        }
        totalKept += 1
        totalReviewed += 1
        advanceCard()
    }

    func markForDeletionAndAdvance() {
        guard let photo = currentPhoto else { return }
        if let index = currentPhotos.firstIndex(where: { $0.id == photo.id }) {
            currentPhotos[index].status = .delete
            let updatedItem = currentPhotos[index]
            if !allDeletedPhotos.contains(where: { $0.id == updatedItem.id }) {
                allDeletedPhotos.append(updatedItem)
            }
        }
        totalReviewed += 1
        advanceCard()
    }

    private func advanceCard() {
        currentIndex += 1
        persistState()
    }

    func goToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        persistState()
    }

    func markAsKept() {
        markAsKeptAndAdvance()
    }

    func markForDeletion() {
        markForDeletionAndAdvance()
    }

    func undoLastSwipe() {
        goToPrevious()
    }

    // MARK: - 回收站操作

    func restoreFromTrash(_ item: PhotoItem) {
        allDeletedPhotos.removeAll { $0.id == item.id }
        if let index = currentPhotos.firstIndex(where: { $0.id == item.id }) {
            currentPhotos[index].status = .unreviewed
        }
        persistState()
    }

    func restoreSelectedFromTrash(_ ids: Set<String>) {
        for id in ids {
            allDeletedPhotos.removeAll { $0.id == id }
            if let index = currentPhotos.firstIndex(where: { $0.id == id }) {
                currentPhotos[index].status = .unreviewed
            }
        }
        persistState()
    }

    func restoreAllFromTrash() {
        let ids = Set(allDeletedPhotos.map(\.id))
        allDeletedPhotos.removeAll()
        for index in currentPhotos.indices where ids.contains(currentPhotos[index].id) {
            currentPhotos[index].status = .unreviewed
        }
        persistState()
    }

    func deleteItemsFromTrash(_ items: [PhotoItem]) async {
        let assets = items.map(\.asset)
        let ids = Set(items.map(\.id))

        try? await PhotoLibraryService.shared.deleteAssets(assets)
        totalCleaned += items.count
        allDeletedPhotos.removeAll { ids.contains($0.id) }

        let before = currentPhotos.count
        currentPhotos.removeAll { ids.contains($0.id) }
        let removed = before - currentPhotos.count
        totalReviewed = max(0, totalReviewed - removed)

        if currentIndex > currentPhotos.count {
            currentIndex = currentPhotos.count
        }

        persistState()
    }

    func deleteAllFromTrash() async {
        let assets = allDeletedPhotos.map(\.asset)
        let ids = Set(allDeletedPhotos.map(\.id))
        guard !assets.isEmpty else { return }

        try? await PhotoLibraryService.shared.deleteAssets(assets)
        totalCleaned += assets.count
        allDeletedPhotos.removeAll()

        let before = currentPhotos.count
        currentPhotos.removeAll { ids.contains($0.id) }
        let removed = before - currentPhotos.count
        totalReviewed = max(0, totalReviewed - removed)

        if currentIndex > currentPhotos.count {
            currentIndex = currentPhotos.count
        }

        persistState()
    }

    // MARK: - 删除托盘

    func cancelDelete(for id: String) {
        if let index = currentPhotos.firstIndex(where: { $0.id == id }) {
            currentPhotos[index].status = .unreviewed
        }
        allDeletedPhotos.removeAll { $0.id == id }
        persistState()
    }

    // MARK: - 重置

    func reset() {
        currentPhotos = []
        currentIndex = 0
        seenAssetIds = []
        totalReviewed = 0
        totalKept = 0
        totalCleaned = 0
        batchNumber = 0
        allDeletedPhotos = []
        hasMorePhotos = true
        isReviewing = false
        clearPersistedState()
    }

    // MARK: - 持久化

    private func persistState() {
        let state = PersistedState(
            currentPhotos: currentPhotos.map { PersistedPhotoItem(id: $0.id, status: $0.status) },
            currentIndex: currentIndex,
            batchNumber: batchNumber,
            seenAssetIds: Array(seenAssetIds),
            totalReviewed: totalReviewed,
            totalKept: totalKept,
            totalCleaned: totalCleaned,
            deletedAssetIds: uniqueIdentifiers(allDeletedPhotos.map(\.id)),
            hasMorePhotos: hasMorePhotos
        )

        guard let encoded = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.stateStoreKey)
    }

    private func restorePersistedState() {
        guard let data = UserDefaults.standard.data(forKey: Self.stateStoreKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return
        }

        seenAssetIds = Set(state.seenAssetIds)
        totalReviewed = state.totalReviewed
        totalKept = state.totalKept
        totalCleaned = state.totalCleaned
        batchNumber = state.batchNumber
        hasMorePhotos = state.hasMorePhotos

        let currentAssets = assetsByIdentifier(for: state.currentPhotos.map(\.id))
        currentPhotos = state.currentPhotos.compactMap { item in
            guard let asset = currentAssets[item.id] else { return nil }
            return PhotoItem(id: item.id, asset: asset, status: item.status)
        }

        let deletedAssets = assetsByIdentifier(for: state.deletedAssetIds)
        allDeletedPhotos = uniqueIdentifiers(state.deletedAssetIds).compactMap { id in
            guard let asset = deletedAssets[id] else { return nil }
            let status = currentPhotos.first(where: { $0.id == id })?.status ?? .delete
            return PhotoItem(id: id, asset: asset, status: status)
        }

        currentIndex = min(max(state.currentIndex, 0), currentPhotos.count)
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: Self.stateStoreKey)
    }

    private func assetsByIdentifier(for identifiers: [String]) -> [String: PHAsset] {
        guard !identifiers.isEmpty else { return [:] }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: uniqueIdentifiers(identifiers), options: nil)
        var assets: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            assets[asset.localIdentifier] = asset
        }
        return assets
    }

    private func uniqueIdentifiers(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        return identifiers.filter { seen.insert($0).inserted }
    }
}
