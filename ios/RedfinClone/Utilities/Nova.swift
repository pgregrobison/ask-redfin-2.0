import SwiftUI
import UIKit

/// Rocket Design System (Nova) — foundations for the Redfin branch.
///
/// Values are lifted from the Nova `colors_and_type.css` token file used by the
/// "iOS Vision" Claude Design prototype. Light values are `:root`; dark values
/// are `[data-nova-theme="dark"]`. Views should prefer the semantic tokens
/// (`Nova.Color.text`, `.bgSecondary`, …) and reach for ramp steps only when a
/// spec calls for one explicitly. `Theme` maps the app's older token names
/// onto these.
enum Nova {

    // MARK: - Color

    enum Color {
        // Brand red — the core Rocket color (#DE3341 at 500).
        static let brand5 = dynamic(rgb(255, 242, 242), dark: rgb(46, 4, 3))
        static let brand50 = dynamic(rgb(254, 231, 231), dark: rgb(38, 4, 8))
        static let brand100 = dynamic(rgb(255, 202, 206), dark: rgb(49, 6, 10))
        static let brand200 = dynamic(rgb(255, 172, 179), dark: rgb(61, 8, 13))
        static let brand300 = dynamic(rgb(241, 135, 143), dark: rgb(72, 9, 16))
        static let brand400 = dynamic(rgb(233, 93, 104), dark: rgb(97, 11, 18))
        static let brand500 = dynamic(rgb(222, 51, 65), dark: rgb(132, 22, 31))
        static let brand600 = dynamic(rgb(193, 42, 54), dark: rgb(163, 32, 43))
        static let brand700 = dynamic(rgb(163, 32, 43), dark: rgb(193, 42, 54))
        static let brand800 = dynamic(rgb(132, 22, 31), dark: rgb(222, 51, 65))
        static let brand900 = dynamic(rgb(97, 11, 18), dark: rgb(233, 93, 104))
        /// Brand red that stays #DE3341 in both themes — for accents that sit
        /// on photos or dark glass (selected pins, saved hearts, focus rings).
        static let brandFixed = SwiftUI.Color(uiColor: rgb(222, 51, 65))

        // Nova blue — secondary / accent.
        static let blue50 = dynamic(rgb(237, 241, 255))
        static let blue100 = dynamic(rgb(210, 217, 244))
        static let blue200 = dynamic(rgb(182, 196, 247))
        static let blue300 = dynamic(rgb(154, 175, 249))
        static let blue400 = dynamic(rgb(115, 146, 252))
        static let blue500 = dynamic(rgb(94, 121, 217), dark: rgb(72, 95, 177))
        static let blue600 = dynamic(rgb(65, 86, 161))
        static let blue700 = dynamic(rgb(42, 57, 111), dark: rgb(127, 161, 255))
        static let blue800 = dynamic(rgb(41, 54, 98))
        static let blue900 = dynamic(rgb(33, 39, 61))

        // Neutral gray (800 is the near-black workhorse, not pure black).
        static let gray50 = dynamic(rgb(247, 247, 247), dark: rgb(5, 5, 5))
        static let gray100 = dynamic(rgb(242, 242, 242), dark: rgb(17, 17, 17))
        static let gray200 = dynamic(rgb(233, 233, 233), dark: rgb(20, 20, 20))
        static let gray300 = dynamic(rgb(193, 193, 193), dark: rgb(27, 27, 27))
        static let gray400 = dynamic(rgb(148, 148, 148), dark: rgb(35, 35, 35))
        static let gray500 = dynamic(rgb(123, 123, 123), dark: rgb(42, 42, 42))
        static let gray600 = dynamic(rgb(84, 84, 84), dark: rgb(50, 50, 50))
        static let gray700 = dynamic(rgb(43, 43, 43), dark: rgb(83, 83, 83))
        static let gray800 = dynamic(rgb(17, 17, 17), dark: rgb(115, 115, 115))
        static let gray900 = dynamic(rgb(5, 5, 5), dark: rgb(148, 148, 148))
        static let white = SwiftUI.Color.white
        static let black = SwiftUI.Color.black

        // Black / white opacity ramps.
        static let gray04Opacity = SwiftUI.Color.black.opacity(0.04)
        static let gray08Opacity = SwiftUI.Color.black.opacity(0.08)
        static let gray15Opacity = SwiftUI.Color.black.opacity(0.15)
        static let gray50Opacity = SwiftUI.Color.black.opacity(0.5)
        static let gray60Opacity = SwiftUI.Color.black.opacity(0.6)
        static let gray80Opacity = SwiftUI.Color.black.opacity(0.8)
        static let white10Opacity = SwiftUI.Color.white.opacity(0.1)
        static let white15Opacity = SwiftUI.Color.white.opacity(0.15)
        static let white20Opacity = SwiftUI.Color.white.opacity(0.2)
        static let white30Opacity = SwiftUI.Color.white.opacity(0.3)
        static let white60Opacity = SwiftUI.Color.white.opacity(0.6)

        // Status ramps (Nova uses yellow, not red, for warnings).
        static let green50 = dynamic(rgb(239, 247, 243))
        static let green100 = dynamic(rgb(181, 221, 198))
        static let green200 = dynamic(rgb(148, 207, 173))
        static let green300 = dynamic(rgb(118, 193, 150))
        static let green400 = dynamic(rgb(81, 177, 121))
        static let green500 = dynamic(rgb(47, 162, 95))
        static let green600 = dynamic(rgb(10, 145, 66), dark: rgb(51, 178, 104))
        static let green700 = dynamic(rgb(11, 94, 54))
        static let green800 = dynamic(rgb(9, 74, 43))
        static let green900 = dynamic(rgb(6, 54, 31))

        static let yellow50 = dynamic(rgb(255, 245, 228))
        static let yellow100 = dynamic(rgb(255, 229, 184))
        static let yellow200 = dynamic(rgb(254, 212, 141))
        static let yellow300 = dynamic(rgb(254, 204, 116))
        static let yellow400 = dynamic(rgb(255, 191, 81))
        static let yellow500 = dynamic(rgb(211, 150, 45))
        static let yellow600 = dynamic(rgb(165, 106, 6))
        static let yellow700 = dynamic(rgb(134, 84, 4))
        static let yellow800 = dynamic(rgb(108, 65, 3))
        static let yellow900 = dynamic(rgb(73, 40, 0))

        // Data-viz palette (01 deepest → 05 lightest).
        enum Data {
            static let blue01 = dynamic(rgb(33, 39, 61))
            static let blue02 = dynamic(rgb(115, 146, 252))
            static let blue03 = dynamic(rgb(173, 198, 246))
            static let blue04 = dynamic(rgb(210, 217, 244))
            static let blue05 = dynamic(rgb(237, 241, 255))
            static let green01 = dynamic(rgb(55, 54, 32))
            static let green02 = dynamic(rgb(147, 145, 100))
            static let green03 = dynamic(rgb(203, 201, 150))
            static let green04 = dynamic(rgb(223, 221, 195))
            static let green05 = dynamic(rgb(240, 238, 217))
            static let orange01 = dynamic(rgb(115, 38, 18))
            static let orange02 = dynamic(rgb(210, 117, 64))
            static let orange03 = dynamic(rgb(255, 158, 102))
            static let orange04 = dynamic(rgb(253, 188, 150))
            static let orange05 = dynamic(rgb(244, 228, 218))
            static let purple01 = dynamic(rgb(68, 18, 39))
            static let purple02 = dynamic(rgb(158, 63, 113))
            static let purple03 = dynamic(rgb(240, 153, 199))
            static let purple04 = dynamic(rgb(241, 219, 231))
            static let purple05 = dynamic(rgb(251, 240, 246))
        }

        // MARK: Semantic

        static let bgPrimary = dynamic(rgb(255, 255, 255), dark: rgb(17, 17, 17))
        static let bgSecondary = dynamic(rgb(247, 247, 247), dark: rgb(27, 27, 27))
        static let bgTertiary = dynamic(rgb(242, 242, 242), dark: rgb(35, 35, 35))
        static let bgBrand = dynamic(rgb(222, 51, 65), dark: rgb(222, 51, 65))
        static let bgDark = dynamic(rgb(17, 17, 17), dark: rgb(115, 115, 115))
        static let bgDisabled = gray200

        static let text = dynamic(rgb(17, 17, 17), dark: rgb(255, 255, 255))
        static let textSubtle = dynamic(rgb(84, 84, 84), dark: rgba(255, 255, 255, 0.6))
        static let textOnDark = SwiftUI.Color.white
        static let textDisabled = gray400

        static let border = dynamic(rgb(233, 233, 233), dark: rgba(255, 255, 255, 0.15))
        static let borderEmphasis = dynamic(rgb(193, 193, 193), dark: rgba(255, 255, 255, 0.2))
        static let borderPrimary = gray400
        static let borderFocused = text

        static let iconPrimary = text
        static let iconSecondary = textSubtle
        static let iconOnDark = SwiftUI.Color.white

        /// Translucent wash for hover/press and "subtle" surfaces
        /// (`gray-08-opacity`), flipped to a white wash in dark mode.
        static let overlay = dynamic(rgba(0, 0, 0, 0.08), dark: rgba(255, 255, 255, 0.10))
        static let overlayStrong = dynamic(rgba(0, 0, 0, 0.15), dark: rgba(255, 255, 255, 0.18))

        static let infoBg = blue50
        static let infoBorder = blue200
        static let infoPrimary = blue500
        static let successBg = green50
        static let successBorder = green200
        static let successPrimary = green600
        static let warningBg = yellow50
        static let warningBorder = yellow200
        static let warningPrimary = yellow600

        /// Modal scrim (`rgba(17,17,17,.4)`).
        static let scrim = SwiftUI.Color(uiColor: rgba(17, 17, 17, 0.4))

        // MARK: Helpers

        private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
            UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
        }

        private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> UIColor {
            UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
        }

        /// Colors with no dark override in the Nova branch keep their light value.
        private static func dynamic(_ light: UIColor, dark: UIColor? = nil) -> SwiftUI.Color {
            guard let dark else { return SwiftUI.Color(uiColor: light) }
            return SwiftUI.Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        }
    }

    // MARK: - Typography

    /// Nova type ramp. Heading/label weight is Medium (500) per Nova; headings
    /// at 36pt and up carry −1pt tracking (apply `.novaHeadingTracking()`).
    enum Typography {
        static let heading40: Font = .nova(40, .medium)
        static let heading36: Font = .nova(36, .medium)
        static let heading32: Font = .nova(32, .medium)
        static let heading28: Font = .nova(28, .medium)
        static let heading24: Font = .nova(24, .medium)
        static let heading20: Font = .nova(20, .medium)
        static let heading18: Font = .nova(18, .medium)

        static let label20: Font = .nova(20, .medium)
        static let label18: Font = .nova(18, .medium)
        static let label16: Font = .nova(16, .medium)
        static let label14: Font = .nova(14, .medium)
        static let label12: Font = .nova(12, .medium)

        static let body18: Font = .nova(18)
        static let body16: Font = .nova(16)
        static let body14: Font = .nova(14)

        static let caption12: Font = .nova(12)
        static let caption10: Font = .nova(10)

        /// Uppercase eyebrows — pair with `.textCase(.uppercase)` and the
        /// matching tracking (`trackedTracking12` / `16`).
        static let tracked16: Font = .nova(16)
        static let tracked12: Font = .nova(12)
        static let trackedTracking16: CGFloat = 2.4
        static let trackedTracking12: CGFloat = 0.72

        static let decorative56: Font = .nova(56, .medium)
        static let decorative48: Font = .nova(48, .medium)

        static let headingTracking: CGFloat = -1
    }

    // MARK: - Radius

    /// Nova has no upstream radius scale; these are captured from components.
    enum Radius {
        /// Buttons.
        static let pill: CGFloat = 100
        /// Chips, badges.
        static let round: CGFloat = 24
        /// Cards (Nova uses 16 on mobile web; the iOS Vision prototype keeps 20).
        static let card: CGFloat = 20
        /// Widget cards, suggestion chips, user chat bubble.
        static let widget: CGFloat = 16
        /// Form fields, banners, popovers.
        static let field: CGFloat = 12
        static let fieldSmall: CGFloat = 8
        /// Tags, match badges, checkboxes.
        static let tag: CGFloat = 6
    }

    // MARK: - Elevation

    /// Whisper-soft shadows, all `0 10px …`. CSS blur ≈ 2 × SwiftUI radius.
    enum Elevation: Int {
        case level1 = 1, level2, level3, level4, level5

        var opacity: Double {
            switch self {
            case .level1: 0.02
            case .level2: 0.05
            case .level3: 0.08
            case .level4: 0.10
            case .level5: 0.12
            }
        }

        var radius: CGFloat {
            switch self {
            case .level1: 10
            case .level2: 6
            default: 15
            }
        }

        var y: CGFloat { 10 }
    }

    // MARK: - Motion

    enum Motion {
        static let durationMin: Double = 0.15
        static let durationRegular: Double = 0.30
        static let durationMedium: Double = 0.40
        static let durationLong: Double = 0.60
        static let durationMax: Double = 0.80

        /// `--nova-ease-out` — the default.
        static func easeOut(_ duration: Double = durationMin) -> Animation {
            .timingCurve(0.33, 1, 0.68, 1, duration: duration)
        }

        static func easeIn(_ duration: Double = durationMin) -> Animation {
            .timingCurve(0.32, 0, 0.67, 0, duration: duration)
        }

        static func easeInOut(_ duration: Double = durationRegular) -> Animation {
            .timingCurve(0.65, 0, 0.35, 1, duration: duration)
        }

        // Ask Redfin curves.
        static func glide(_ duration: Double = durationMedium) -> Animation {
            .timingCurve(0.2, 0.8, 0.2, 1, duration: duration)
        }

        static func settle(_ duration: Double = durationLong) -> Animation {
            .timingCurve(0.34, 1.35, 0.64, 1, duration: duration)
        }

        static func pop(_ duration: Double = 0.45) -> Animation {
            .timingCurve(0.34, 1.56, 0.64, 1, duration: duration)
        }
    }

    /// `ASK_REDFIN_MOTION` — timing for the Ask Redfin conversation, in seconds.
    enum AskMotion {
        static let holdAfterSend: Double = 1.1
        static let dotsDelay: Double = 0.55
        static let dotCycle: Double = 1.1
        static let dotStagger: Double = 0.15
        static let workingStepsAfter: Double = 3.0
        static let workingStepEvery: Double = 1.1
        static let charDelay: Double = 0.014
        static let commaPause: Double = 0.11
        static let sentencePause: Double = 0.34
        static let paragraphPause: Double = 0.52
        static let scrollDuration: Double = 0.8
        static let panelDuration: Double = 0.4
        static let revealDuration: Double = 0.3
        static let toastDuration: Double = 6.0
    }
}

// MARK: - View helpers

extension View {
    func novaElevation(_ level: Nova.Elevation) -> some View {
        shadow(color: .black.opacity(level.opacity), radius: level.radius, y: level.y)
    }

    /// −1pt tracking Nova applies to headings 36pt and larger.
    func novaHeadingTracking() -> some View {
        tracking(Nova.Typography.headingTracking)
    }
}
