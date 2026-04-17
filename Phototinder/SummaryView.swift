import SwiftUI

struct SummaryView: View {
    @Environment(PhotoViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundColor(.green)
            Text("筛选完成！").font(.title).bold()
            
            if let group = viewModel.currentGroup {
                Text("待删除照片: \(group.deleteCount) 张").foregroundColor(.red)
                Button("立即执行批量删除") {
                    Task { await viewModel.commitDeletion(); dismiss() }
                }
                .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
            }
            Button("稍后处理") { dismiss() }.secondary()
        }
    }
}