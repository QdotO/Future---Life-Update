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
				VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.md) {
					// Step indicator with dots
					HStack(spacing: AppTheme.BrutalistSpacing.xs) {
						ForEach(0..<totalSteps, id: \.self) { index in
							Circle()
								.fill(
									index <= stepIndex
										? AppTheme.BrutalistPalette.accent
										: AppTheme.BrutalistPalette.border.opacity(0.3)
								)
								.frame(
									width: index == stepIndex ? 10 : 8,
									height: index == stepIndex ? 10 : 8
								)
								.animation(.spring(response: 0.3), value: stepIndex)
						}

						Spacer()

						Text("Step \(stepIndex + 1) of \(totalSteps)")
							.font(AppTheme.BrutalistTypography.captionMono)
							.foregroundColor(AppTheme.BrutalistPalette.secondary)
					}

					// Progress bar with rounded ends
					GeometryReader { geometry in
						ZStack(alignment: .leading) {
							RoundedRectangle(cornerRadius: 3)
								.fill(AppTheme.BrutalistPalette.border.opacity(0.15))
							RoundedRectangle(cornerRadius: 3)
								.fill(
									LinearGradient(
										colors: [
											AppTheme.BrutalistPalette.accent,
											AppTheme.BrutalistPalette.accent.opacity(0.8),
										],
										startPoint: .leading,
										endPoint: .trailing
									)
								)
								.frame(width: geometry.size.width * CGFloat(stepProgress))
								.animation(
									.spring(response: 0.4, dampingFraction: 0.8),
									value: stepProgress)
						}
						.frame(height: 4)
					}
					.frame(height: 4)

					VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.xs) {
						Text(title)
							.font(AppTheme.BrutalistTypography.display)
							.foregroundColor(AppTheme.BrutalistPalette.foreground)

						Text(subtitle)
							.font(AppTheme.BrutalistTypography.body)
							.foregroundColor(AppTheme.BrutalistPalette.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.padding(.vertical, AppTheme.BrutalistSpacing.lg)
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
				VStack(alignment: .leading, spacing: AppTheme.BrutalistSpacing.sm) {
					HStack(spacing: AppTheme.BrutalistSpacing.md) {
						if canGoBack {
							Button(action: onBack) {
								HStack(spacing: AppTheme.BrutalistSpacing.xs) {
									Image(systemName: "chevron.left")
										.font(.system(size: 14, weight: .semibold))
									Text("Back")
								}
								.font(AppTheme.BrutalistTypography.bodyBold)
								.foregroundColor(AppTheme.BrutalistPalette.foreground)
								.padding(.vertical, AppTheme.BrutalistSpacing.sm)
								.padding(.horizontal, AppTheme.BrutalistSpacing.md)
								.background(
									RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
										.fill(AppTheme.BrutalistPalette.surface)
								)
								.overlay(
									RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
										.stroke(
											AppTheme.BrutalistPalette.border,
											lineWidth: AppTheme.BrutalistBorder.thin)
								)
							}
							.buttonStyle(.plain)
							.accessibilityIdentifier("wizardBackButton")
						}

						Button(action: onNext) {
							HStack(spacing: AppTheme.BrutalistSpacing.xs) {
								Text(isFinalStep ? "Create Goal" : "Continue")
								Image(systemName: isFinalStep ? "checkmark" : "chevron.right")
									.font(.system(size: 14, weight: .semibold))
							}
							.font(AppTheme.BrutalistTypography.bodyBold)
							.foregroundColor(.white)
							.padding(.vertical, AppTheme.BrutalistSpacing.sm)
							.padding(.horizontal, AppTheme.BrutalistSpacing.lg)
							.background(
								RoundedRectangle(cornerRadius: AppTheme.BrutalistRadius.soft)
									.fill(
										isForwardEnabled
											? AppTheme.BrutalistPalette.accent
											: AppTheme.BrutalistPalette.border)
							)
							.shadow(
								color: isForwardEnabled
									? AppTheme.BrutalistPalette.accent.opacity(0.3) : .clear,
								radius: 8,
								x: 0,
								y: 4
							)
						}
						.buttonStyle(.plain)
						.disabled(!isForwardEnabled)
						.animation(.easeInOut(duration: 0.2), value: isForwardEnabled)
						.accessibilityIdentifier("wizardNextButton")

						Spacer()
					}

					if let guidance, !isForwardEnabled {
						HStack(spacing: AppTheme.BrutalistSpacing.xs) {
							Image(systemName: "info.circle")
								.font(.system(size: 12))
							Text(guidance)
								.font(AppTheme.BrutalistTypography.caption)
						}
						.foregroundColor(AppTheme.BrutalistPalette.secondary)
						.padding(.top, AppTheme.BrutalistSpacing.xs)
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
