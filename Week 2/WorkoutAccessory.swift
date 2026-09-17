import SwiftUI

/// The native accessory stays attached to the tab bar across the app tabs.
struct WorkoutAccessory: ViewModifier {
    let active: ActiveWorkout?
    let open: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: active != nil) { accessory }
        } else if active != nil {
            // iOS 26.0 retains the previous accessory when its builder becomes empty.
            content.tabViewBottomAccessory { accessory }
        } else {
            content
        }
    }

    @ViewBuilder private var accessory: some View {
        if let active {
            Button(action: open) {
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3).foregroundStyle(.blue)
                    Text(active.plan.name.isEmpty ? "進行中的運動" : active.plan.name)
                        .font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 8)
                    WorkoutClock(startedAt: active.startedAt, compact: true)
                        .fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resume-workout-bar")
            .accessibilityHint("展開進行中的運動")
        }
    }
}
