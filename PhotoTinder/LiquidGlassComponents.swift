import SwiftUI

enum PhotoTinderPalette {
    static let accent = Color(red: 0.12, green: 0.48, blue: 0.98)
    static let turquoise = Color(red: 0.08, green: 0.78, blue: 0.84)
    static let sun = Color(red: 0.98, green: 0.72, blue: 0.34)
    static let rose = Color(red: 0.90, green: 0.32, blue: 0.42)
    static let success = Color(red: 0.18, green: 0.66, blue: 0.36)
}

struct AmbientBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.00),
                    Color(red: 0.92, green: 0.96, blue: 1.00),
                    Color(red: 0.98, green: 0.95, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(PhotoTinderPalette.accent.opacity(0.24))
                .frame(width: 340, height: 340)
                .blur(radius: 30)
                .offset(x: -150, y: -230)

            Circle()
                .fill(PhotoTinderPalette.turquoise.opacity(0.18))
                .frame(width: 290, height: 290)
                .blur(radius: 28)
                .offset(x: 150, y: -70)

            Circle()
                .fill(PhotoTinderPalette.sun.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: 120, y: 280)

            RoundedRectangle(cornerRadius: 140, style: .continuous)
                .fill(.white.opacity(0.38))
                .frame(width: 380, height: 220)
                .rotationEffect(.degrees(-16))
                .blur(radius: 88)
                .offset(x: -70, y: 310)
        }
        .ignoresSafeArea()
    }
}

private struct DashboardPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackgroundEffect()
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 0.8)
            }
    }
}

extension View {
    func dashboardPanel() -> some View {
        modifier(DashboardPanelModifier())
    }
}

struct FeatureChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect()
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 40, height: 40)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .glassBackgroundEffect()
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.8)
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PhotoTinderPalette.accent)
                .frame(width: 24)

            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassBackgroundEffect()
    }
}

struct MediaBadge: View {
    let title: String
    let symbol: String?

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffect()
    }
}
