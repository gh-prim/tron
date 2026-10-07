import SwiftUI

@main
struct TronApp: App {
    @StateObject private var store = AppStore.shared
    @StateObject private var engine = TranscriptionEngine.shared
    @StateObject private var dictation = DictationController.shared
    @StateObject private var pending = PendingLaunch.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Line-buffered logs, so the console keeps them even if the app is stopped in the background.
        setvbuf(stdout, nil, _IOLBF, 0)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(engine)
                .environmentObject(dictation)
                .environmentObject(pending)
                .tint(TronColor.brand)
                .onAppear {
                    // Start the model download early, during onboarding.
                    engine.prepare()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Each time Tron is opened, the mic is armed for the keyboard Tron key.
                    if phase == .active, store.onboardingDone { dictation.armSession() }
                }
                .onOpenURL { url in
                    // tron://dictate, sent by the mic key of the Tron keyboard.
                    if url.host == "dictate" { pending.dictateRequested = true }
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
