import Photos
import SwiftUI

struct PhotoInfoPanel: View {
    let asset: PHAsset

    @State private var deviceName: String?
    @State private var isExpanded = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            LazyVGrid(columns: columns, spacing: 12) {
                detailTile(title: "拍摄时间", value: asset.creationDate.map(fullDate) ?? "未知", systemImage: "calendar")
                detailTile(title: "分辨率", value: "\(asset.pixelWidth) × \(asset.pixelHeight)", systemImage: "crop")
                detailTile(title: "类型", value: mediaTypeText, systemImage: mediaTypeSymbol)
                detailTile(title: "设备", value: deviceName ?? "轻点后加载", systemImage: "iphone")
                detailTile(title: "位置", value: locationText, systemImage: asset.location == nil ? "location.slash" : "mappin.circle.fill")
                detailTile(title: "像素规模", value: formatFileSize(asset), systemImage: "doc.text.magnifyingglass")
            }
            .padding(.top, 14)
            .animation(.easeInOut(duration: 0.2), value: deviceName)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Label("照片详情", systemImage: "info.circle")
                        .font(.headline.weight(.semibold))

                    Spacer(minLength: 12)

                    quickPreview
                }

                Text(isExpanded ? "收起元数据面板" : "展开查看时间、设备、位置和照片类型。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.8)
        }
        .onChange(of: isExpanded) { _, expanded in
            guard expanded, deviceName == nil else { return }
            Task { deviceName = await fetchDeviceName(for: asset) }
        }
    }

    private var quickPreview: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                previewBadges
                previewDate
                previewResolution
                previewLocation
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    previewBadges
                    previewDate
                    previewResolution
                    previewLocation
                }
            }
        }
    }

    private var previewBadges: some View {
        HStack(spacing: 6) {
            if asset.mediaSubtypes.contains(.photoLive) {
                MediaBadge(title: "LIVE", symbol: "livephoto")
            }

            if asset.mediaSubtypes.contains(.photoHDR) {
                MediaBadge(title: "HDR", symbol: nil)
            }
        }
    }

    @ViewBuilder
    private var previewDate: some View {
        if let date = asset.creationDate {
            Text(formatDate(date))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var previewResolution: some View {
        Text("\(asset.pixelWidth) × \(asset.pixelHeight)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var previewLocation: some View {
        if asset.location != nil {
            Image(systemName: "location.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PhotoTinderPalette.accent)
        }
    }

    private var mediaTypeText: String {
        if asset.mediaSubtypes.contains(.photoLive) {
            return "Live Photo"
        }
        if asset.mediaSubtypes.contains(.photoHDR) {
            return "HDR 照片"
        }
        return "静态照片"
    }

    private var mediaTypeSymbol: String {
        if asset.mediaSubtypes.contains(.photoLive) {
            return "livephoto"
        }
        return "photo"
    }

    private var locationText: String {
        guard let location = asset.location else { return "无位置信息" }
        return "\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))"
    }

    private func detailTile(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatFileSize(_ asset: PHAsset) -> String {
        let pixels = asset.pixelWidth * asset.pixelHeight
        if pixels < 1_000_000 {
            return "\(pixels / 1000)K px"
        }
        return String(format: "%.1fM px", Double(pixels) / 1_000_000.0)
    }
}
