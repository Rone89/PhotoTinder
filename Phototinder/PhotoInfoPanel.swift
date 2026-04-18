import SwiftUI
import Photos
import MapKit

/// 照片元信息面板 —— 显示在审查界面的照片下方
struct PhotoInfoPanel: View {
    let asset: PHAsset
    @State private var metadata: PhotoMetadata?
    
    // 展开/收起状态
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 点击展开/收起
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                if metadata == nil {
                    Task { metadata = await PhotoMetadata.fullFrom(asset) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(isExpanded ? "收起信息" : "照片详情")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 快速预览：时间 + 尺寸
                    quickPreview
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // 展开后的详细信息
            if isExpanded {
                detailGrid
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
    }

    // MARK: - 快速预览（始终可见）
    
    private var quickPreview: some View {
        HStack(spacing: 8) {
            if let date = asset.creationDate {
                Text(formatDate(date))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Text("\u{00B7}")
                    .foregroundColor(Color(.tertiaryLabel))
            }
            
            Text("\(asset.pixelWidth) \u{00D7} \(asset.pixelHeight)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            
            if asset.location != nil {
                Text("\u{00B7}")
                    .foregroundColor(Color(.tertiaryLabel))
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
            }
        }
    }

    // MARK: - 详细网格

    private var detailGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            infoRow(icon: "calendar", title: "拍摄时间", value: asset.creationDate.map { fullDate($0) } ?? "未知")
            
            infoRow(icon: "crop", title: "分辨率", value: "\(asset.pixelWidth) × \(asset.pixelHeight)")
            
            locationRow
            
            infoRow(icon: "iphone", title: "设备", value: metadata?.deviceName ?? "加载中...")
            
            infoRow(icon: "photo", title: "文件大小", value: metadata?.fileSize ?? "计算中...")
        }
        .animation(.easeInOut(duration: 0.2), value: metadata)
    }

    @ViewBuilder
    private var locationRow: some View {
        if let loc = asset.location {
            infoRow(icon: "mappin.circle.fill", title: "位置", value: "\(String(format: "%.4f", loc.coordinate.latitude)), \(String(format: "%.4f", loc.coordinate.longitude))")
        } else {
            infoRow(icon: "location.slash", title: "位置", value: "无位置信息")
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue.opacity(0.7))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabel))
                Text(value)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - 日期格式化

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM/dd HH:mm"
        return fmt.string(from: date)
    }

    private func fullDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
