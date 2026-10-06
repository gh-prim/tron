import ActivityKit
import Foundation

/// Starts, updates and ends the dictation Live Activity.
@MainActor
final class LiveActivityController {
    private var activity: Activity<DictationAttributes>?
    private var lastUpdate = Date.distantPast

    func start(startedAt: Date) {
        endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[Tron] Live Activities disabled")
            return
        }
        let state = DictationAttributes.ContentState(phase: .recording, startedAt: startedAt, levels: [])
        do {
            activity = try Activity.request(
                attributes: DictationAttributes(),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("[Tron] Live Activity failed: \(error)")
        }
    }

    /// Throttled to about two updates a second.
    func update(levels: [Float], startedAt: Date) {
        guard let activity, Date().timeIntervalSince(lastUpdate) >= 0.5 else { return }
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

    func finish(_ phase: DictationAttributes.ContentState.Phase, message: String, startedAt: Date) {
        guard let activity else { return }
        self.activity = nil
        let state = DictationAttributes.ContentState(phase: phase, startedAt: startedAt, levels: [], message: message)
        Task {
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(4)))
        }
    }

    func endAll() {
        activity = nil
        for old in Activity<DictationAttributes>.activities {
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func downsample(_ levels: [Float], to count: Int) -> [Double] {
        let recent = Array(levels.suffix(count * 3))
        guard !recent.isEmpty else { return [] }
        let size = max(1, recent.count / count)
        return stride(from: 0, to: recent.count, by: size).map { i in
            let chunk = recent[i..<min(i + size, recent.count)]
            return Double(chunk.max() ?? 0)
        }
    }
}
