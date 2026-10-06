import SwiftUI

@main
struct TronApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var engine = TranscriptionEngine.shared
    @StateObject private var dictation = DictationController()
    @StateObject private var pending = PendingLaunch.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(engine)
                .environmentObject(dictation)
                .environmentObject(pending)
                .tint(TronColor.brand)
                .onAppear {
                    dictation.attach(store)
                    // Start the model download early, during onboarding.
                    engine.prepare()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            TronColor.paper.ignoresSafeArea()
            if store.onboardingDone {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.onboardingDone)
    }
}
