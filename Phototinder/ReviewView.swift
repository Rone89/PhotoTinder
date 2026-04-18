import SwiftUI
import Photos

struct ReviewView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingTray = false

    var body: some View {
        NavigationStack {
            VStack {
                if let group = viewModel.currentGroup {
                    if !group.items.isEmpty {
                        progressSection(group: group)
                    }

                    if viewModel.currentCardIndex < group.items.count {
                        cardStackSection(group: group)
                        buttonSection
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
            .sheet(isPresented: $showingTray) {
                DeleteTrayView()
                    .environment(viewModel)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func progressSection(group: MonthGroup) -> some View {
        VStack(spacing: 4) {
            Text("\(viewModel.currentCardIndex + 1) / \(group.items.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            ProgressView(value: Double(viewModel.currentCardIndex + 1), total: Double(group.items.count))
                .tint(.blue)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func cardStackSection(group: MonthGroup) -> some View {
        ZStack {
            if viewModel.currentCardIndex + 1 < group.items.count {
                PhotoCardView(item: group.items[viewModel.currentCardIndex + 1], onSwipe: { _ in })
                    .scaleEffect(0.95)
                    .offset(y: 10)
                    .opacity(0.7)
            }
            PhotoCardView(item: group.items[viewModel.currentCardIndex], onSwipe: { viewModel.handleSwipe(direction: $0) })
        }
        .padding()
    }

    private var buttonSection: some View {
        HStack(spacing: 50) {
            actionButton(icon: "arrow.left", color: .green, label: "保留")
            actionButton(icon: "arrow.up", color: .red, label: "删除")
            actionButton(icon: "arrow.right", color: .orange, label: "撤销")
        }
        .font(.caption)
        .padding(.bottom)
    }

    private func actionButton(icon: String, color: Color, label: String) -> some View {
        VStack {
            Image(systemName: icon).foregroundColor(color)
            Text(label)
        }
    }
}

struct PhotoCardView: View {
    let item: PhotoItem
    let onSwipe: (SwipeDirection) -> Void
    @State private var offset: CGSize = .zero
    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground))

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }

                overlayLabel
            }
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(swipeGesture)
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                loadFileSync()
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { offset = $0.translation }
            .onEnded { value in
                if value.translation.width < -100 {
                    withAnimation(.bouncy) { offset = CGSize(width: -600, height: 0) }
                    onSwipe(.left)
                } else if value.translation.height < -100 {
                    withAnimation(.bouncy) { offset = CGSize(width: 0, height: -800) }
                    onSwipe(.up)
                } else if value.translation.width > 100 {
                    onSwipe(.right)
                    withAnimation(.spring()) { offset = .zero }
                } else {
                    withAnimation(.spring()) { offset = .zero }
                }
            }
    }

    @ViewBuilder var overlayLabel: some View {
        if offset.width < -50 {
            Text("KEEP")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.green)
                .opacity(0.5)
        } else if offset.height < -50 {
            Text("DELETE")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.red)
                .opacity(0.5)
        }
    }

    /// 同步加载图片，彻底避免白屏问题
    private func loadFileSync() {
        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isSynchronous = true

            var result: UIImage?
            PHImageManager.default().requestImage(
                for: item.asset,
                targetSize: CGSize(width: 800, height: 1200),
                contentMode: .aspectFill,
                options: options
            ) { img, _ in
                result = img
            }

            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}
