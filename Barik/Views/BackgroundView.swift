import SwiftUI

struct BackgroundView: View {
    @ObservedObject var configManager = ConfigManager.shared

    var body: some View {
        // Glass effects are now applied directly to widgets/groups in MenuBarView
        // BackgroundView is kept for potential future use
        EmptyView()
    }
}
