import SwiftUI

struct WizardStepHeader: View {
	let title: String
	let subtitle: String
	let stepIndex: Int
	let totalSteps: Int

	var body: some View {
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

struct WizardNavigationButtons: View {
	let canGoBack: Bool
	let isFinalStep: Bool
	let isForwardEnabled: Bool
	let guidance: String?
	let onBack: () -> Void
	let onNext: () -> Void

	var body: some View {
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
