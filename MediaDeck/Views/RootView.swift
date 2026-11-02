import SwiftUI

enum RootTab: Hashable {
    case home
    case channels
    case favorites
    case configurations
    case settings
    case search
}

struct RootView: View {
    @StateObject private var library = ChannelLibrary.shared

    var body: some View {
        MediaDeckShell()
            .environmentObject(library)
            .preferredColorScheme(.dark)
    }
}
