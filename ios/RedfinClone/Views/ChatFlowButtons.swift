import SwiftUI

struct TourRequestButton: View {
    let tourRequest: TourRequest
    var onCompleted: (String) -> Void = { _ in }

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Text("Request showing")
                .font(Theme.Typography.secondaryBold)
                .foregroundStyle(Theme.Colors.invertedPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.ButtonSize.compactVerticalPadding)
                .background(Color.primary, in: Capsule())
        }
        .padding(.leading, Theme.Spacing.md)
        .padding(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
        .fullScreenCover(isPresented: $isPresented) {
            TourBookingFlowView(tourRequest: tourRequest) { summary in
                isPresented = false
                onCompleted(summary)
            }
        }
    }
}

struct MortgageRequestButton: View {
    let mortgageRequest: MortgageRequest
    var onCompleted: (String) -> Void = { _ in }

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Text("Estimate my rate")
                .font(Theme.Typography.secondaryBold)
                .foregroundStyle(Theme.Colors.invertedPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.ButtonSize.compactVerticalPadding)
                .background(Color.primary, in: Capsule())
        }
        .padding(.leading, Theme.Spacing.md)
        .padding(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
        .fullScreenCover(isPresented: $isPresented) {
            MortgagePrequalFlowView(mortgageRequest: mortgageRequest) { summary in
                isPresented = false
                onCompleted(summary)
            }
        }
    }
}
