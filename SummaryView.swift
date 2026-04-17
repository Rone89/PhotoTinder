import SwiftUI

struct SummaryView: View {
    @Environment(PhotoViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("本月整理完成！")
                .font(.title)
                .bold()
            
            if let group = viewModel.currentGroup {
                HStack(spacing: 40) {
                    VStack {
                        Text("\(group.keepCount)")
                            .font(.title2).bold().foregroundColor(.green)
                        Text("保留").foregroundColor(.secondary)
                    }
                    VStack {
                        Text("\(group.deleteCount)")
                            .font(.title2).bold().foregroundColor(.red)
                        Text("待删除").foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                
                if group.deleteCount > 0 {
                    Button(action: {
                        Task {
                            isDeleting = true
                            await viewModel.commitDeletion()
                            isDeleting = false
                            dismiss() // 删除完毕后返回首页
                        }
                    }) {
                        if isDeleting {
                            ProgressView().tint(.white)
                        } else {
                            Text("批量删除 \(group.deleteCount) 张照片")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .padding(.top, 20)
                    .disabled(isDeleting)
                } else {
                    Button("完成") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 20)
                }
            }
        }
        .padding()
    }
}