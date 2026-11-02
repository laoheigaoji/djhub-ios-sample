import SwiftUI

extension Notification.Name {
    static let roveReplayPosterOnboarding = Notification.Name(
        "com.djhub.replayPosterOnboarding"
    )
}

@main
struct DJHUBApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootContainer()
        }
    }
}

private struct AppRootContainer: View {
    @AppStorage("djhub.launch.poster-onboarding.seen.v1")
    private var hasSeenPosterOnboarding = false
    @State private var isReplayingPosterOnboarding = false
    @StateObject private var duoPosture = DuoPlayerPostureModel()

    var body: some View {
        ZStack {
            RootView()

            if !hasSeenPosterOnboarding || isReplayingPosterOnboarding {
                RoveLaunchCoverView {
                    hasSeenPosterOnboarding = true
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isReplayingPosterOnboarding = false
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .roveReplayPosterOnboarding)) { _ in
            withAnimation(.easeInOut(duration: 0.24)) {
                isReplayingPosterOnboarding = true
            }
        }
        .background {
            DuoHingeObserver(model: duoPosture)
                .allowsHitTesting(false)
        }
    }
}
