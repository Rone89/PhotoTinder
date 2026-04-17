import SwiftUI

struct ReviewView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingTray = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if let group = viewModel.currentGroup {
                    ProgressView(value: Double(viewModel.currentCardIndex), total: Double(group.items.count))
                        .padding()
                    
                    if viewModel.currentCardIndex < group.items.count {
                        ZStack {
                            if viewModel.currentCardIndex + 1 < group.items.count {
                                PhotoCardView(item: group.items[viewModel.currentCardIndex+1], onSwipe: { _ in })
                                    .id(group.items[viewModel.currentCardIndex+1].id)
                                    .scaleEffect(0.95).offset(y: 10).opacity(0.7)
                            }
                            PhotoCardView(item: group.items[viewModel.currentCardIndex], onSwipe: { viewModel.handleSwipe(direction: $0) })
                                .id(group.items[viewModel.currentCardIndex].id)
                        }
                        .padding()
                        
                        HStack(spacing: 50) {
                            VStack { Image(systemName: "arrow.left").foregroundColor(.green); Text("保留") }
                            VStack { Image(systemName: "arrow.up").foregroundColor(.red); Text("删除") }
                            VStack { Image(systemName: "arrow.right").foregroundColor(.orange); Text("撤销") }
                        }.font(.caption).padding()
                    } else {
                        SummaryView()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingTray = true } label: {
                        Image(systemName: "trash")
                            .symbolEffect(.bounce, value: viewModel.currentGroup?.deleteCount)
                    }.disabled(viewModel.currentGroup?.deleteCount == 0)
                }
            }
            .sheet(isPresented: $showingTray) { DeleteTrayView().environment(viewModel).presentationDetents([.medium, .large]) }
        }
    }
}

struct PhotoCardView: View {
    let item: PhotoItem
    let onSwipe: (SwipeDirection) -> Void
    @State private var offset: CGSize = .zero
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground))
                if let image = image {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipShape(RoundedRectangle(cornerRadius: 20))
                }
                overlayLabel
            }
            .offset(offset).rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(DragGesture().onChanged { offset = $0.translation }.onEnded { value in
                if value.translation.width < -100 { withAnimation(.bouncy) { offset = CGSize(width: -600, height: 0) }; onSwipe(.left) }
                else if value.translation.height < -100 { withAnimation(.bouncy) { offset = CGSize(width: 0, height: -800) }; onSwipe(.up) }
                else if value.translation.width > 100 { onSwipe(.right); offset = .zero }
                else { withAnimation(.spring()) { offset = .zero } }
            })
            .onAppear {
                PHImageManager.default().requestImage(for: item.asset, targetSize: CGSize(width: 800, height: 1200), contentMode: .aspectFill, options: nil) { self.image = $0 }
            }
        }
    }
    
    @ViewBuilder var overlayLabel: some View {
        if offset.width < -50 { Text("KEEP").font(.largeTitle).bold().foregroundColor(.green).opacity(0.5) }
        else if offset.height < -50 { Text("DELETE").font(.largeTitle).bold().foregroundColor(.red).opacity(0.5) }
    }
}