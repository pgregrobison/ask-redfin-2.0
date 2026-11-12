import SwiftUI

enum Theme {

    // MARK: - Legacy (backward-compatible)

    static let accent = Nova.Color.text
    static let redfinGreenColor = Nova.Color.green700
    static let cardBackground = Nova.Color.bgSecondary
    static let darkCardBackground = Nova.Color.bgDark

    enum IconSize {
        static let medium: CGFloat = 17
        static let mediumTap: CGFloat = 44
        static let small: CGFloat = 15
        static let smallTap: CGFloat = 36
        static let tabBar: CGFloat = 19
        static let mapPin: CGFloat = 13
    }

    // MARK: - Colors (mapped onto Nova)

    enum Colors {
        static let brandRed = Nova.Color.brand500
        static let brandGreen = Nova.Color.green600
        static let invertedPrimary = Nova.Color.bgPrimary

        static let background = Nova.Color.bgPrimary
        static let secondaryBackground = Nova.Color.bgSecondary
        static let tertiaryBackground = Nova.Color.bgTertiary

        static let fill = Nova.Color.overlay
        static let separator = Nova.Color.border

        static let inset = Nova.Color.overlay

        enum Chat {
            static let inputCornerRadius: CGFloat = Nova.Radius.round
        }

        static let stepIndicator = Nova.Color.gray800

        enum Badge {
            /// "HOT HOME" badge on carousel cards (iOS Vision prototype).
            static let hot = Color(red: 166 / 255, green: 80 / 255, blue: 0)
            /// "OPEN HOUSE" badge on carousel cards.
            static let openHouse = Color(red: 91 / 255, green: 112 / 255, blue: 3 / 255)
            static let listedByRedfin = Nova.Color.brandFixed
            static let compass = Nova.Color.gray800
            static let daysAgo = Nova.Color.green700
        }

        enum MapPin {
            static let selectedLight = Nova.Color.brandFixed
            static let selectedDark = Nova.Color.brandFixed
        }

        /// Rocket Mortgage prequal confirmation surface — Nova success tokens.
        enum RocketCard {
            static let background = Nova.Color.successBg
            static let border = Nova.Color.successBorder
        }

        enum Card {
            static let price = Nova.Color.text
            static let stats = Nova.Color.text
            static let statsDot = Nova.Color.borderEmphasis
            static let address = Nova.Color.textSubtle
        }

        enum Chart {
            static let blue = Nova.Color.Data.blue02
            static let green = Nova.Color.Data.green02
            static let amber = Nova.Color.Data.orange02
            static let purple = Nova.Color.Data.purple02
        }
    }

    // MARK: - Corner Radius

    enum Radius {
        static let xs: CGFloat = Nova.Radius.tag
        static let small: CGFloat = Nova.Radius.fieldSmall
        static let medium: CGFloat = Nova.Radius.field
        static let large: CGFloat = Nova.Radius.widget
        static let xl: CGFloat = Nova.Radius.card
        static let full: CGFloat = 9999
        static let chatBubble: CGFloat = Nova.Radius.widget
        static let widget: CGFloat = Nova.Radius.widget
        static let pill: CGFloat = Nova.Radius.field
        static let inputField: CGFloat = Nova.Radius.field
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

    // MARK: - Typography (mapped onto the Nova ramp)

    enum Typography {
        static let heroPrice: Font = .nova(32, .demibold)
        static let sectionTitle: Font = .nova(20, .demibold)
        static let cardTitle: Font = .nova(18, .demibold)
        static let headline: Font = Nova.Typography.label16
        static let body: Font = Nova.Typography.body16
        static let secondary: Font = Nova.Typography.body14
        static let secondaryBold: Font = Nova.Typography.label14
        static let caption: Font = Nova.Typography.caption12
        static let captionBold: Font = Nova.Typography.label12
        static let micro: Font = .nova(11)

        static let cardPrice: Font = .nova(20, .demibold)
        static let cardPriceCompact: Font = .nova(16, .demibold)

        static let heroNumber: Font = Nova.Typography.heading32
        static let largeNumber: Font = Nova.Typography.heading28
        static let decorativeXL: Font = Nova.Typography.decorative48
        static let decorativeLG: Font = Nova.Typography.heading40
        static let decorativeMD: Font = Nova.Typography.heading36
    }

    // MARK: - Shadows (Nova elevation 2–5)

    enum Shadow {
        static let subtleColor = Color.black.opacity(Nova.Elevation.level2.opacity)
        static let subtleRadius: CGFloat = Nova.Elevation.level2.radius
        static let subtleY: CGFloat = Nova.Elevation.level2.y

        static let mediumColor = Color.black.opacity(Nova.Elevation.level3.opacity)
        static let mediumRadius: CGFloat = Nova.Elevation.level3.radius
        static let mediumY: CGFloat = Nova.Elevation.level3.y

        static let elevatedColor = Color.black.opacity(Nova.Elevation.level4.opacity)
        static let elevatedRadius: CGFloat = Nova.Elevation.level4.radius
        static let elevatedY: CGFloat = Nova.Elevation.level4.y

        static let overlayColor = Color.black.opacity(Nova.Elevation.level5.opacity)
        static let overlayRadius: CGFloat = Nova.Elevation.level5.radius
        static let overlayY: CGFloat = Nova.Elevation.level5.y
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
        static let font: Font = Nova.Typography.label12
        static let horizontalPadding: CGFloat = Spacing.xs
        static let verticalPadding: CGFloat = Spacing.xxs
        static let cornerRadius: CGFloat = Nova.Radius.tag
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
        static let borderWidth: CGFloat = 1
    }

    enum IconTag {
        static let iconSize: CGFloat = 32
        static let gridSpacing: CGFloat = Spacing.md
        static let iconColor: Color = Nova.Color.iconSecondary
    }
}
