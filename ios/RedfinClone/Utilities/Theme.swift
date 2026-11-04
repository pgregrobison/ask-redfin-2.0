import SwiftUI

enum Theme {

    // MARK: - Legacy (backward-compatible)

    static let accent = Color.primary
    static let redfinGreenColor = Color(red: 27/255, green: 107/255, blue: 58/255)
    static let cardBackground = Color(.secondarySystemBackground)
    static let darkCardBackground = Color(white: 0.11)

    enum IconSize {
        static let medium: CGFloat = 17
        static let mediumTap: CGFloat = 44
        static let small: CGFloat = 15
        static let smallTap: CGFloat = 36
        static let tabBar: CGFloat = 19
        static let mapPin: CGFloat = 13
    }

    // MARK: - Brand Colors

    enum Colors {
        static let brandRed = Color(red: 0.78, green: 0.13, blue: 0.13)
        static let brandGreen = Color(red: 1/255, green: 120/255, blue: 62/255)
        static let invertedPrimary = Color(.systemBackground)

        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)

        static let fill = Color(.tertiarySystemFill)
        static let separator = Color(.separator)

        static let inset = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 254/255, green: 254/255, blue: 254/255, alpha: 0.12)
                : UIColor(red: 56/255, green: 52/255, blue: 48/255, alpha: 0.06)
        })

        enum Chat {
            static let inputCornerRadius: CGFloat = 24
        }

        static let stepIndicator = Color(white: 0.15)

        enum Badge {
            static let hot = Color(white: 0.15)
            static let listedByRedfin = Colors.brandRed
            static let compass = Color.black
            static let daysAgo = Colors.brandGreen
        }

        enum MapPin {
            static let selectedLight = Color(red: 0.87, green: 0.2, blue: 0.25)
            static let selectedDark = Color(red: 0.88, green: 0.23, blue: 0.23)
        }

        /// Rocket Mortgage-branded prequal card (Figma node 1929:19840): a
        /// mint-green surface distinct from the app's usual neutral cards,
        /// used only for the prequalification confirmation.
        enum RocketCard {
            static let background = Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0x0d / 255, green: 0x1f / 255, blue: 0x16 / 255, alpha: 1)
                    : UIColor(red: 0xeb / 255, green: 0xfe / 255, blue: 0xee / 255, alpha: 1)
            })
            static let border = Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 1 / 255, green: 120 / 255, blue: 62 / 255, alpha: 0.35)
                    : UIColor(red: 0xda / 255, green: 0xee / 255, blue: 0xe2 / 255, alpha: 1)
            })
        }

        /// Text colors lifted from the desktop prototype's listing card
        /// (Figma node 1927:18714) so the iOS card reads as the same design.
        enum Card {
            static let price = Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.95, alpha: 1)
                    : UIColor(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255, alpha: 1)
            })
            static let stats = Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.78, alpha: 1)
                    : UIColor(red: 0x3a / 255, green: 0x3a / 255, blue: 0x3a / 255, alpha: 1)
            })
            static let statsDot = Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.2)
                    : UIColor.black.withAlphaComponent(0.2)
            })
            static let address = Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.55, alpha: 1)
                    : UIColor(red: 0x71 / 255, green: 0x71 / 255, blue: 0x82 / 255, alpha: 1)
            })
        }

        enum Chart {
            static let blue = Color(red: 0.2, green: 0.4, blue: 0.8)
            static let green = Color(red: 0.3, green: 0.7, blue: 0.4)
            static let amber = Color(red: 0.95, green: 0.7, blue: 0.2)
            static let purple = Color(red: 0.6, green: 0.4, blue: 0.8)
        }
    }

    // MARK: - Corner Radius

    enum Radius {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 9999
        static let chatBubble: CGFloat = 18
        static let widget: CGFloat = 16
        static let pill: CGFloat = 10
        static let inputField: CGFloat = 10
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let tabBarClearance: CGFloat = 100
    }

    // MARK: - Typography

    enum Typography {
        static let heroPrice: Font = .inter(34, .bold)
        static let sectionTitle: Font = .inter(22, .bold)
        static let cardTitle: Font = .inter(20, .bold)
        static let headline: Font = .inter(17, .semibold)
        static let body: Font = .inter(16)
        static let secondary: Font = .inter(15)
        static let secondaryBold: Font = .inter(15, .bold)
        static let caption: Font = .inter(12)
        static let captionBold: Font = .inter(12, .bold)
        static let micro: Font = .inter(11)

        static let cardPrice: Font = .inter(24, .medium)
        static let cardPriceCompact: Font = .inter(16, .medium)

        static let heroNumber: Font = .inter(32, .bold)
        static let largeNumber: Font = .inter(28, .bold)
        static let decorativeXL: Font = .inter(48)
        static let decorativeLG: Font = .inter(40)
        static let decorativeMD: Font = .inter(36)
    }

    // MARK: - Shadows

    enum Shadow {
        static let subtleColor = Color.black.opacity(0.08)
        static let subtleRadius: CGFloat = 4
        static let subtleY: CGFloat = 2

        static let mediumColor = Color.black.opacity(0.12)
        static let mediumRadius: CGFloat = 10
        static let mediumY: CGFloat = 4

        static let elevatedColor = Color.black.opacity(0.20)
        static let elevatedRadius: CGFloat = 16
        static let elevatedY: CGFloat = 6

        static let overlayColor = Color.black.opacity(0.25)
        static let overlayRadius: CGFloat = 16
        static let overlayY: CGFloat = 4
    }

    // MARK: - Card Size Tokens

    enum CardSize {
        enum PhotoHeight {
            static let large: CGFloat = 240
            static let medium: CGFloat = 220
            static let compact: CGFloat = 180
        }

        enum FixedWidth {
            static let medium: CGFloat = 300
            static let compactDefault: CGFloat = 280
        }

        enum InfoPadding {
            static let large = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
            static let medium = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            static let compact = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        }
    }

    // MARK: - Divider Size

    enum DividerSize {
        static let standard: CGFloat = 32
    }

    // MARK: - Button Size Tokens

    enum ButtonSize {
        static let verticalPadding: CGFloat = 14
        static let compactVerticalPadding: CGFloat = 12
        static let pillHorizontalPadding: CGFloat = 18
        static let minHeight: CGFloat = 44
        static let iconSize: CGFloat = 16
        static let circleSize: CGFloat = 44
        static let fabSize: CGFloat = 62
        static let tabItemPadding: CGFloat = 11
    }

    enum DividerInset {
        static let stepIndicator: CGFloat = 48
        static let disclosureRow: CGFloat = 42
    }

    enum MapPin {
        static let horizontalPadding: CGFloat = 10
        static let outerPadding: CGFloat = 2
    }

    enum Tag {
        static let font: Font = Typography.caption
        static let horizontalPadding: CGFloat = Spacing.xs
        static let verticalPadding: CGFloat = Spacing.xxs
        static let cornerRadius: CGFloat = Radius.xs
        static let background: Color = Colors.inset
        static let gridMinimum: CGFloat = 100
        static let gridSpacing: CGFloat = Spacing.xs
        static let rowSpacing: CGFloat = Spacing.xxs + 2
        static let rowMaxCount: Int = 3
    }

    enum Container {
        static let radius: CGFloat = Radius.xl
        static let padding: CGFloat = Spacing.xl
        static let spacing: CGFloat = Spacing.md
        static let borderColor: Color = Colors.separator
        static let borderWidth: CGFloat = 0.5
    }

    enum IconTag {
        static let iconSize: CGFloat = 32
        static let gridSpacing: CGFloat = Spacing.md
        static let iconColor: Color = Color.secondary
    }
}
