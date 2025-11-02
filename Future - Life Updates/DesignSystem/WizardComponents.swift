import SwiftUI

struct WizardStepHeader: View {
	let title: String
	let subtitle: String
	let stepIndex: Int
	let totalSteps: Int
	@Environment(\.designStyle) private var designStyle

	var body: some View {
		Group {
			if designStyle == .brutalist {
				VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
					Text("Step \(stepIndex + 1) of \(totalSteps)".uppercased())
						.font(AppTheme.BrutalistTypography.overline)
						.foregroundColor(AppTheme.BrutalistPalette.secondary)

					GeometryReader { geometry in
						ZStack(alignment: .leading) {
							Rectangle()
								.fill(AppTheme.BrutalistPalette.border.opacity(0.2))
							Rectangle()
								.fill(AppTheme.BrutalistPalette.accent)
								.frame(
									width: geometry.size.width * CGFloat(stepProgress)
								)
						}
						.frame(height: 6)
					}
					.frame(height: 6)

					Text(title.uppercased())
						.font(AppTheme.BrutalistTypography.title)
						.foregroundColor(AppTheme.BrutalistPalette.foreground)

					Text(subtitle)
						.font(AppTheme.BrutalistTypography.body)
						.foregroundColor(AppTheme.BrutalistPalette.secondary)
				}
				.padding(.vertical, AppTheme.BrutalistSpacing.md)
			} else {
				VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
					ProgressView(value: Double(stepIndex + 1), total: Double(totalSteps))
						.progressViewStyle(.linear)
					Text(title)
						.font(AppTheme.Typography.title)
					Text(subtitle)
						.font(AppTheme.Typography.body)
						.foregroundStyle(.secondary)
				}
				.padding(.vertical, AppTheme.Spacing.lg)
			}
		}
	}

	private var stepProgress: Double {
		guard totalSteps > 0 else { return 0 }
		return Double(stepIndex + 1) / Double(totalSteps)
	}
}

struct WizardNavigationButtons: View {
	let canGoBack: Bool
	let isFinalStep: Bool
	let isForwardEnabled: Bool
	let guidance: String?
	let onBack: () -> Void
	let onNext: () -> Void
	@Environment(\.designStyle) private var designStyle

	var body: some View {
		Group {
			if designStyle == .brutalist {
				VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
					HStack(spacing: AppTheme.BrutalistSpacing.sm) {
						if canGoBack {
							Button("Back", action: onBack)
								.brutalistButton(style: .secondary)
								.accessibilityIdentifier("wizardBackButton")
						}

						Button(isFinalStep ? "Create Goal" : "Next", action: onNext)
							.brutalistButton(style: .primary)
							.disabled(!isForwardEnabled)
							.accessibilityIdentifier("wizardNextButton")
					}

					if let guidance, !isForwardEnabled {
						Text(guidance.uppercased())
							.font(AppTheme.BrutalistTypography.captionMono)
							.foregroundColor(AppTheme.BrutalistPalette.secondary)
					}
				}
			} else {
				VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
					HStack(spacing: AppTheme.Spacing.sm) {
						if canGoBack {
							Button("Back", action: onBack)
								.buttonStyle(.secondaryProminent)
								.accessibilityIdentifier("wizardBackButton")
						}

						Button(isFinalStep ? "Create Goal" : "Next", action: onNext)
							.buttonStyle(.primaryProminent)
							.disabled(!isForwardEnabled)
							.accessibilityIdentifier("wizardNextButton")
					}

					if let guidance, !isForwardEnabled {
						Text(guidance)
							.font(AppTheme.Typography.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
		}
	}
}
