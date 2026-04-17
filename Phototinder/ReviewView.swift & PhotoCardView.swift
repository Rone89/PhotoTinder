import SwiftUI
import Photos

struct ReviewView: View {
    @Environment(PhotoViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if let group = viewModel.currentGroup {
                    // 顶部进度指示器
                    ProgressView(value: Double(viewModel.currentCardIndex), total: Double(group.items.count))
                        .padding()
                        .tint(.blue)
                    
                    if viewModel.currentCardIndex < group.items.count {
                        // 卡片堆叠区域 (显示当前卡片和下一张卡片作为底层)
                        ZStack {
                            // 预加载下一张 (提高流畅度)
                            if viewModel.currentCardIndex + 1 < group.items.count {
                                let nextItem = group.items[viewModel.currentCardIndex + 1]
                                PhotoCardView(item: nextItem, onSwipe: { _ in })
                                    .scaleEffect(0.95)
                                    .zIndex(0)
                            }
                            
                            // 当前卡片
                            let currentItem = group.items[viewModel.currentCardIndex]
                            PhotoCardView(item: currentItem, onSwipe: { direction in
                                viewModel.handleSwipe(direction: direction)
                            })
                            .zIndex(1)
                            // 加上一个转场动画让退回（右滑）时平滑
                            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .opacity))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.currentCardIndex)
                        }
                        .padding()
                        
                        // 底部操作提示
                        HStack(spacing: 40) {
                            InstructionView(icon: "arrow.left", text: "保留", color: .green)
                            InstructionView(icon: "arrow.up", text: "删除", color: .red)
                            InstructionView(icon: "arrow.right", text: "撤销", color: .orange)
                        }
                        .padding(.vertical, 20)
                        
                    } else {
                        // 阅览完毕，显示汇总页
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

struct InstructionView: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct PhotoCardView: View {
    let item: PhotoItem
    let onSwipe: (SwipeDirection) -> Void
    
    @State private var offset: CGSize = .zero
    @State private var image: UIImage? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(radius: 5)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    ProgressView()
                }
                
                // 覆盖层：根据滑动的方向显示 "DELETE" 或 "KEEP" 或 "UNDO" 蒙版
                overlayMask
            }
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        offset = gesture.translation
                    }
                    .onEnded { gesture in
                        handleGestureEnd(gesture)
                    }
            )
            .task(id: item.id) {
                loadImage(size: geometry.size)
            }
        }
    }
    
    @ViewBuilder
    private var overlayMask: some View {
        ZStack {
            // 左滑变绿 (Keep)
            if offset.width < -50 {
                Color.green.opacity(Double(-offset.width / 200).clamp(to: 0...0.5))
                Text("KEEP").font(.system(size: 40, weight: .bold)).foregroundColor(.green).rotationEffect(.degrees(15)).padding()
                    .position(x: 100, y: 100)
            }
            // 上滑变红 (Delete)
            else if offset.height < -50 && abs(offset.width) < 50 {
                Color.red.opacity(Double(-offset.height / 200).clamp(to: 0...0.5))
                Text("DELETE").font(.system(size: 40, weight: .bold)).foregroundColor(.red).rotationEffect(.degrees(-15)).padding()
                    .position(x: 100, y: 100)
            }
            // 右滑变橙 (Undo/Back)
            else if offset.width > 50 {
                Color.orange.opacity(Double(offset.width / 200).clamp(to: 0...0.5))
                Text("UNDO").font(.system(size: 40, weight: .bold)).foregroundColor(.orange).rotationEffect(.degrees(-15)).padding()
                    .position(x: 100, y: 100)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func handleGestureEnd(_ gesture: DragGesture.Value) {
        let width = gesture.translation.width
        let height = gesture.translation.height
        let threshold: CGFloat = 100
        
        withAnimation(.spring()) {
            if width < -threshold {
                offset = CGSize(width: -500, height: 0) // 飞出屏幕左侧
                onSwipe(.left)
            } else if width > threshold {
                offset = .zero // 撤销不飞出屏幕，恢复原位，ViewModel去退回上一张
                onSwipe(.right)
            } else if height < -threshold {
                offset = CGSize(width: 0, height: -800) // 飞出屏幕上方
                onSwipe(.up)
            } else {
                offset = .zero // 恢复原位
            }
        }
    }
    
    // 使用 PhotoKit 高效加载适合屏幕尺寸的图片
    private func loadImage(size: CGSize) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true // 允许从 iCloud 下载
        options.deliveryMode = .opportunistic
        
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        manager.requestImage(for: item.asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { result, _ in
            if let result = result {
                DispatchQueue.main.async { self.image = result }
            }
        }
    }
}

// 辅助扩展：限制透明度范围
extension Double {
    func clamp(to limits: ClosedRange<Double>) -> Double {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}