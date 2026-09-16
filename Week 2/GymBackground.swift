import SwiftUI

struct GymBackground: View {
    var body: some View {
        Color.white
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
