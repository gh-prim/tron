import AppKit
import SwiftUI

/// The island that comes out of the notch (or the top center of a screen without one) while dictating.
@MainActor
final class IslandController {
    enum Stage: Equatable {
        case hidden
        case listening
        case transcribing
        case pasted
        /// No text field under the cursor: the text is in the clipboard.
        case copied
        case error(String)
    }

    final class Model: ObservableObject {
        @Published var stage: Stage = .hidden
        @Published var levels: [Float] = []
        @Published var locked = false
        /// Size of the notch on this screen; zero when there is none.
        @Published var notch: CGSize = .zero
    }

    let model = Model()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    /// Room for the largest stage, centered under the top of the screen.
    private static let canvas = CGSize(width: 420, height: 120)

    func show(_ stage: Stage) {
        hideWork?.cancel()
        place()
        panel?.orderFrontRegardless()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { model.stage = stage }
    }

    /// Shows a final stage for a moment, then hides.
    func flash(_ stage: Stage) {
        show(stage)
        let seconds: Double
        switch stage {
        case .pasted: seconds = 0.7
        case .copied: seconds = 2.5
        default: seconds = 2
        }
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { model.stage = .hidden }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.model.stage == .hidden else { return }
            self.panel?.orderOut(nil)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// The screen being used: the one with the mouse.
    private var screen: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    private func place() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        guard let screen else { return }
        let frame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            model.notch = CGSize(width: frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        } else {
            model.notch = .zero
        }
        let size = Self.canvas
        panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height), display: false)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.canvas),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Above the menu bar, so it can come out of the notch.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: IslandView(model: model))
        host.frame = NSRect(origin: .zero, size: Self.canvas)
        panel.contentView = host
        return panel
    }
}
