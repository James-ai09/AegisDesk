import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AegisDeviceClass {
    case phone, pad, mac

    static var current: Self {
        #if os(macOS)
        return .mac
        #elseif canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #else
        return .pad
        #endif
    }
}

enum AegisLayout {
    static var pageMaxWidth: CGFloat {
        switch AegisDeviceClass.current { case .phone: .infinity; case .pad: 980; case .mac: 1180 }
    }
    static var pagePadding: CGFloat {
        switch AegisDeviceClass.current { case .phone: 6; case .pad: 22; case .mac: 28 }
    }
    static var editorialCardWidth: CGFloat {
        switch AegisDeviceClass.current { case .phone: 196; case .pad: 310; case .mac: 330 }
    }
    static var editorialCardHeight: CGFloat {
        switch AegisDeviceClass.current { case .phone: 184; case .pad: 310; case .mac: 330 }
    }
    static var heroMinimumHeight: CGFloat {
        switch AegisDeviceClass.current { case .phone: 164; case .pad: 290; case .mac: 320 }
    }

    static func contentMaxWidth(_ preferred: CGFloat) -> CGFloat {
        AegisDeviceClass.current == .phone ? .infinity : min(pageMaxWidth, preferred)
    }
}

struct AppleEditorialBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        TimelineView(.animation(minimumInterval: AegisDeviceClass.current == .phone ? 1 / 8 : 1 / 24, paused: reduceMotion || lowPowerMode)) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let animationsPaused = reduceMotion || lowPowerMode
                let travel = animationsPaused ? 0.0 : sin(time * 0.22)
                let counterTravel = animationsPaused ? 0.0 : cos(time * 0.18)

                ZStack {
                    LinearGradient(
                        colors: [Color.primary.opacity(0.018), Color.accentColor.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(Color.cyan.opacity(AegisDeviceClass.current == .phone ? 0.09 : 0.11))
                        .frame(width: min(proxy.size.width * 0.9, 520))
                        .blur(radius: AegisDeviceClass.current == .phone ? 42 : 90)
                        .offset(x: proxy.size.width * 0.34 + travel * 36, y: -proxy.size.height * 0.28 + counterTravel * 22)
                    Circle()
                        .fill(Color.purple.opacity(AegisDeviceClass.current == .phone ? 0.065 : 0.08))
                        .frame(width: min(proxy.size.width * 0.82, 460))
                        .blur(radius: AegisDeviceClass.current == .phone ? 46 : 100)
                        .offset(x: -proxy.size.width * 0.36 + counterTravel * 30, y: proxy.size.height * 0.30 + travel * 26)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)) { _ in
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

struct AegisPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, AegisDeviceClass.current == .phone ? 12 : 20)
            .padding(.vertical, AegisDeviceClass.current == .phone ? 7 : 12)
            .foregroundStyle(.primary)
            .glassEffect(.regular.tint(.accentColor.opacity(0.24)).interactive(), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct AegisSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .padding(.horizontal, AegisDeviceClass.current == .phone ? 11 : 18)
            .padding(.vertical, AegisDeviceClass.current == .phone ? 7 : 11)
            .glassEffect(.regular.interactive(), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.76), value: configuration.isPressed)
    }
}

struct AegisIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(width: AegisDeviceClass.current == .phone ? 34 : 44, height: AegisDeviceClass.current == .phone ? 34 : 44)
            .glassEffect(.regular.tint(.accentColor.opacity(0.12)).interactive(), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func aegisResponsivePage(maxWidth: CGFloat = AegisLayout.pageMaxWidth) -> some View {
        if AegisDeviceClass.current == .phone {
            self.padding(AegisLayout.pagePadding)
        } else {
            self
                .padding(AegisLayout.pagePadding)
                .frame(maxWidth: maxWidth, alignment: .leading)
        }
    }

    func appleEditorialPage() -> some View {
        background { AppleEditorialBackground() }
    }

    func appleEditorialCard(tint: Color = .clear) -> some View {
        padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.7)
            }
            .shadow(color: tint.opacity(0.12), radius: 22, y: 10)
    }
}

struct AegisIconTile: View {
    let symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 0.6)
            }
    }
}
