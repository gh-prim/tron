import AVFoundation
import Foundation

/// Captures the microphone and keeps the audio as 16 kHz mono Float samples, the format Parakeet expects.
final class AudioRecorder {
    static let sampleRate: Double = 16_000

    /// Called on the main queue with a 0...1 level, about 20 times a second.
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    private(set) var isRunning = false

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    static var permissionGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    func start() throws {
        guard !isRunning else { return }
        lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else { throw RecorderError.noMicrophone }
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    /// Stops capture and returns everything recorded since `start()`.
    @discardableResult
    func stop() -> [Float] {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        return snapshot()
    }

    func snapshot() -> [Float] {
        lock.lock(); defer { lock.unlock() }
        return samples
    }

    var duration: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return Double(samples.count) / Self.sampleRate
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = out.floatChannelData?[0] else { return }
        let count = Int(out.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channel, count: count))

        lock.lock(); samples.append(contentsOf: chunk); lock.unlock()

        // RMS in dB, mapped to 0...1 for the waveform.
        var sum: Float = 0
        for s in chunk { sum += s * s }
        let rms = count > 0 ? sqrt(sum / Float(count)) : 0
        let db = 20 * log10(max(rms, 0.000_01))
        let level = max(0, min(1, (db + 55) / 45))
        DispatchQueue.main.async { [weak self] in self?.onLevel?(level) }
    }

    /// Writes samples to a 16 kHz mono WAV file.
    static func writeWAV(_ samples: [Float], to url: URL) throws {
        guard !samples.isEmpty else { return }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        try file.write(from: buffer)
    }

    enum RecorderError: LocalizedError {
        case noMicrophone
        var errorDescription: String? { "Aucun micro disponible." }
    }
}
