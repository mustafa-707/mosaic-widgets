// MOSAIC-GENERATED — do not edit
import SwiftUI
import UIKit
import WidgetKit

let kMosaicAppGroup = "group.com.example.demo_app.widgets"

/// Resolves a file-image path to a UIImage. Absolute paths are loaded directly;
/// relative paths are resolved against the App Group container. Returns nil when
/// the path is nil/empty or no image could be loaded.
func resolveFileImage(_ path: String?) -> UIImage? {
    guard let path = path, !path.isEmpty else { return nil }
    if path.hasPrefix("/") {
        return UIImage(contentsOfFile: path)
    }
    if let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kMosaicAppGroup) {
        let full = container.appendingPathComponent(path).path
        if let img = UIImage(contentsOfFile: full) { return img }
    }
    return UIImage(contentsOfFile: path)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Builds a color that resolves at render time to [light] or [dark] based on
    /// the current interface style. Used for adaptive (dark-mode) MColors.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

extension View {
    /// iOS 16/17-compatible container background helper.
    /// On iOS 17+ uses .containerBackground(for: .widget); on iOS 16 falls back
    /// to .background(_:) so the widget extension compiles at both targets.
    @ViewBuilder func mosaicContainerBackground<S: ShapeStyle>(_ style: S) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(style, for: .widget)
        } else {
            self.background(style)
        }
    }

    /// Per-corner rounded clip. UnevenRoundedRectangle is iOS 16.4+, so on
    /// older systems this falls back to a uniform RoundedRectangle using the
    /// largest of the four corner radii. Keeps the extension type-checking at
    /// the 16.1 deployment target.
    @ViewBuilder func mosaicCornerClip(
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomLeft: CGFloat,
        bottomRight: CGFloat
    ) -> some View {
        if #available(iOS 16.4, *) {
            self.clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: topLeft,
                    bottomLeadingRadius: bottomLeft,
                    bottomTrailingRadius: bottomRight,
                    topTrailingRadius: topRight
                )
            )
        } else {
            let maxRadius = max(max(topLeft, topRight), max(bottomLeft, bottomRight))
            self.clipShape(RoundedRectangle(cornerRadius: maxRadius))
        }
    }
}
