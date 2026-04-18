import SwiftUI

struct SummaryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .glassEffect(.regular.tint(.green), in: .circle)
            Text("审查完成")
                .font(.title.bold())
        }
    }
}
