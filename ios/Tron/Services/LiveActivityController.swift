import ActivityKit
import Foundation

/// Starts, updates and ends the dictation Live Activity.
@MainActor
final class LiveActivityController {
    private var activity: Activity<DictationAttributes>?
    private var lastUpdate = Date.distantPast

    /// Returns false when iOS refused the Live Activity (needed to record in the background).
    @discardableResult
    func start(startedAt: Date) -> Bool {
        // Mic armed for the keyboard: the session activity is reused (no new request from the background).
        if let activity, activity.activityState == .active {
            let state = DictationAttributes.ContentState(phase: .recording, startedAt: startedAt, levels: [])
            Task { await activity.update(.init(state: state, staleDate: nil)) }
            return true
        }
        endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[Tron] Live Activities disabled")
            return false
        }
        let state = DictationAttributes.ContentState(phase: .recording, startedAt: startedAt, levels: [])
        do {
            activity = try Activity.request(
                attributes: DictationAttributes(),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            return true
        } catch {
            print("[Tron] Live Activity failed: \(error)")
            return false
        }
    }

    /// About five updates a second, so the bars follow the voice.
    func update(levels: [Float], startedAt: Date) {
        guard let activity, Date().timeIntervalSince(lastUpdate) >= 0.2 else { return }
        lastUpdate = Date()
        let state = DictationAttributes.ContentState(
            phase: .recording,
            startedAt: startedAt,
            levels: Self.downsample(levels, to: 16)
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func transcribing(startedAt: Date) {
        guard let activity else { return }
        let state = DictationAttributes.ContentState(phase: .transcribing, startedAt: startedAt, levels: [])
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    /// Shows the result for a moment, then ends the activity, or goes back to "ready" when the mic stays armed.
    func finish(_ phase: DictationAttributes.ContentState.Phase, message: String, startedAt: Date, keepAlive: Bool) {
        guard let activity else { return }
        if !keepAlive { self.activity = nil }
        let state = DictationAttributes.ContentState(phase: phase, startedAt: startedAt, levels: [], message: message)
        // Ended activities leave the Dynamic Island at once, so the result stays visible a moment first.
        Task {
            await activity.update(.init(state: state, staleDate: nil))
            try? await Task.sleep(for: .seconds(2.5))
            if keepAlive {
                guard self.activity === activity, activity.content.state.phase == phase else { return }
                let ready = DictationAttributes.ContentState(phase: .ready, startedAt: Date(), levels: [])
                await activity.update(.init(state: ready, staleDate: nil))
            } else {
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
        }
    }

    /// Session activity while the mic is armed, started from the foreground.
    func startReady() {
        guard activity?.activityState != .active else { ready(); return }
        endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = DictationAttributes.ContentState(phase: .ready, startedAt: Date(), levels: [])
        activity = try? Activity.request(attributes: DictationAttributes(), content: .init(state: state, staleDate: nil), pushType: nil)
    }

    func ready() {
        guard let activity else { return }
        let state = DictationAttributes.ContentState(phase: .ready, startedAt: Date(), levels: [])
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func endAll() {
        activity = nil
        for old in Activity<DictationAttributes>.activities {
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// The last `count` levels (about 1 s of audio), with a curve that makes speech clearly visible.
    private static func downsample(_ levels: [Float], to count: Int) -> [Double] {
        levels.suffix(count).map { Double(pow(max(0, min(1, $0)), 0.7)) }
    }
}
