import SwiftUI
import Photos

struct ReviewView: View {
    @Environment(PhotoViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if let group = viewModel.currentGroup {
                    ProgressView(value: Double(viewModel.currentCardIndex), total: Double(group.items.count))
                        .padding()
                    
                    if viewModel.currentCardIndex < group.items.count {
                        ZStack {
                            if viewModel.currentCardIndex + 1 < group.items.count {
                                let nextItem = group.items[viewModel.currentCardIndex + 1]
                                PhotoCardView(item: nextItem, onSwipe: { _ in })
                                    .id(nextItem.id) // 修复1
                                    .scaleEffect(0.95)
                                    .zIndex(0)
                            }
                            
                            let currentItem = group.items[viewModel.currentCardIndex]
                            PhotoCardView(item: currentItem, onSwipe: { direction in
                                viewModel.handleSwipe(direction: direction)
                            })
                            .id(currentItem.id) // 修复2：强制重置卡片位置
                            .zIndex(1)
                            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .opacity))
                        }
                        .padding()
                        
                        HStack(spacing: 40) {
                            InstructionView(icon: "arrow.left", text: "保留", color: .green)
                            InstructionView(icon: "arrow.up", text: "删除", color: .red)
                            InstructionView(icon: "arrow.right", text: "撤销", color: .orange)
                        }
                        .padding(.vertical, 20)
                    } else {
                        SummaryView()
                    }
                }
            }
            .navigationTitle(viewModel.currentGroup?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
