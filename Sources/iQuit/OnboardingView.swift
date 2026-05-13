import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 54, height: 54)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to iQuit")
                        .font(.largeTitle.weight(.bold))
                    Text("iQuit watches for apps you are no longer using, then asks before it hides or quits them.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                OnboardingCard(
                    title: "Visible Windows",
                    subtitle: "Default: 20 minutes",
                    bodyText: "When an inactive app still has windows on screen, iQuit offers Hide or Quit. This is the clutter cleanup system.",
                    systemImage: "macwindow",
                    tint: .blue
                )

                OnboardingCard(
                    title: "Idle Quit",
                    subtitle: "Default: 1 hour",
                    bodyText: "When an app is idle in the background, iQuit offers Quit only. Set it to Never for apps you want left alone.",
                    systemImage: "power",
                    tint: .red
                )

                OnboardingCard(
                    title: "Protected Apps",
                    subtitle: "Per bundle",
                    bodyText: "Use the lock button or the hand button on a prompt to ignore apps iQuit should never touch.",
                    systemImage: "lock.fill",
                    tint: .orange
                )

                OnboardingCard(
                    title: "Window Access",
                    subtitle: model.accessibilityTrusted ? "Enabled" : "Optional permission",
                    bodyText: "Accessibility access lets iQuit minimize individual windows. Without it, Hide falls back to hiding the whole app.",
                    systemImage: model.accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                    tint: model.accessibilityTrusted ? .green : .purple
                )
            }

            HStack(spacing: 10) {
                Button {
                    model.requestAccessibilityAccess()
                } label: {
                    Label(model.accessibilityTrusted ? "Window Access Enabled" : "Enable Window Access", systemImage: "checkmark.shield")
                }
                .buttonStyle(.bordered)
                .tint(model.accessibilityTrusted ? .green : .purple)

                Spacer()

                Button {
                    model.completeOnboarding()
                } label: {
                    Label("Get Started", systemImage: "arrow.right")
                        .frame(minWidth: 112)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 680)
    }
}

private struct OnboardingCard: View {
    var title: String
    var subtitle: String
    var bodyText: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }

            Text(bodyText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
