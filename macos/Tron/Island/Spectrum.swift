import Accelerate
import Foundation

/// Frequency bands of the voice, for the island: each bar is one band, low pitches on the left.
/// Fed with 16 kHz chunks on the audio thread; `onBands` is called on the main queue.
final class Spectrum {
    static let bandCount = 24

    var onBands: (([Float]) -> Void)?

    private let size = 1024
    private let log2n: vDSP_Length = 10
    private let setup: FFTSetup
    private let window: [Float]
    private var ring: [Float]
    private var fill = 0
    private var smoothed = [Float](repeating: 0, count: Spectrum.bandCount)
    /// FFT bin range of each band, log spaced from 80 Hz to 6 kHz (where the voice is).
    private let bins: [Range<Int>]
    private let lock = NSLock()

    init() {
        setup = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2))!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: 1024, isHalfWindow: false)
        ring = [Float](repeating: 0, count: 1024)
        let hzPerBin = 16_000.0 / 1024
        let low = 80.0, high = 6_000.0
        bins = (0..<Spectrum.bandCount).map { i in
            let f0 = low * pow(high / low, Double(i) / Double(Spectrum.bandCount))
            let f1 = low * pow(high / low, Double(i + 1) / Double(Spectrum.bandCount))
            let b0 = Int(f0 / hzPerBin)
            return b0..<max(b0 + 1, Int(f1 / hzPerBin))
        }
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        ring = [Float](repeating: 0, count: size)
        fill = 0
        smoothed = [Float](repeating: 0, count: Self.bandCount)
    }

    func feed(_ chunk: [Float]) {
        lock.lock()
        // Keep the latest `size` samples.
        if chunk.count >= size {
            ring = Array(chunk.suffix(size))
        } else {
            ring.removeFirst(chunk.count)
            ring.append(contentsOf: chunk)
        }
        fill = min(size, fill + chunk.count)
        let bands = fill == size ? analyze() : nil
        lock.unlock()
        guard let bands else { return }
        DispatchQueue.main.async { [weak self] in self?.onBands?(bands) }
    }

    private func analyze() -> [Float] {
        let half = size / 2
        var input = vDSP.multiply(ring, window)
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var power = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { re in
            imag.withUnsafeMutableBufferPointer { im in
                var split = DSPSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                input.withUnsafeMutableBytes { raw in
                    vDSP_ctoz(raw.bindMemory(to: DSPComplex.self).baseAddress!, 2, &split, 1, vDSP_Length(half))
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(half))
            }
        }
        for (i, range) in bins.enumerated() {
            let r = range.clamped(to: 1..<half)
            let mean = r.isEmpty ? 0 : power[r].reduce(0, +) / Float(r.count)
            // Power in dB, mapped to 0...1. Higher bands are quieter in speech: give them a little lift.
            let db = 10 * log10(max(mean, 1e-10)) + Float(i) * 0.6
            let level = max(0, min(1, (db - 10) / 45))
            // Rise at once, fall slowly, so the bars do not flicker.
            smoothed[i] = level > smoothed[i] ? level : smoothed[i] * 0.82 + level * 0.18
        }
        return smoothed
    }
}
