import AppKit
import SwiftUI

@main
struct TronMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var store = AppStore.shared
    @ObservedObject private var engine = TranscriptionEngine.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Tron", id: "main") {
            MainView()
                .environmentObject(AppStore.shared)
                .environmentObject(TranscriptionEngine.shared)
                .environmentObject(MacDictation.shared)
        }
        .defaultSize(width: 960, height: 640)
        .windowToolbarStyle(.unifiedCompact)

        Settings {
            SettingsView()
                .environmentObject(AppStore.shared)
        }

        MenuBarExtra("Tron", systemImage: "waveform") {
            Text(status)
            Divider()
            Picker("Langue", selection: $store.language) {
                ForEach(SpokenLanguage.allCases) { Text($0.name).tag($0) }
            }
            Menu("Dernières dictées") {
                if store.history.isEmpty {
                    Text("Rien pour l'instant")
                }
                ForEach(store.history.prefix(10)) { item in
                    Button(item.text.count > 60 ? item.text.prefix(60) + "…" : item.text) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.text, forType: .string)
                    }
                }
            }
            Button("Ouvrir Tron") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Dictionnaire…") {
                WindowRouter.shared.tab = .dictionary
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            SettingsLink { Text("Réglages…") }
            Button("Autorisations…") { delegate.showOnboarding() }
            Divider()
            Button("Quitter Tron") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private var status: String {
        switch engine.state {
        case .idle, .loading: return "Préparation du modèle…"
        case .downloading(let p): return "Téléchargement du modèle : \(Int(p * 100)) %"
        case .ready: return Permissions.accessibility ? "Maintenez fn pour dicter" : "Autorisez l'accessibilité"
        case .failed: return "Le modèle n'a pas pu se charger"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = FnKeyMonitor()
    private lazy var gesture = FnGesture(dictation: MacDictation.shared)
    private var onboarding: NSWindow?
    private var tapTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setvbuf(stdout, nil, _IOLBF, 0)
        TranscriptionEngine.shared.prepare()

        monitor.onDown = { [weak self] in MainActor.assumeIsolated { self?.gesture.fnDown() } }
        monitor.onUp = { [weak self] in MainActor.assumeIsolated { self?.gesture.fnUp() } }
        monitor.onChord = { [weak self] in MainActor.assumeIsolated { self?.gesture.chord() } }
        monitor.onEscape = { [weak self] in MainActor.assumeIsolated { self?.gesture.escape() ?? false } }
        startMonitor()

        if !AppStore.shared.onboardingDone || !Permissions.microphone || !Permissions.accessibility {
            showOnboarding()
        }
    }

    /// The event tap only works once Accessibility is granted: retry until it is.
    private func startMonitor() {
        if monitor.start() {
            print("[Tron] fn key monitor on")
            return
        }
        tapTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, self.monitor.start() else { return }
                print("[Tron] fn key monitor on")
                timer.invalidate()
                self.tapTimer = nil
            }
        }
    }

    func showOnboarding() {
        if onboarding == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.title = "Tron"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: OnboardingView { [weak self] in
                AppStore.shared.onboardingDone = true
                self?.onboarding?.close()
            })
            window.center()
            onboarding = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboarding?.makeKeyAndOrderFront(nil)
    }
}
