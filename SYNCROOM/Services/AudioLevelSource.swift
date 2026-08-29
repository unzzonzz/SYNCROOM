//  AudioLevelSource.swift
//  Drives the input-level meter on the audio check and broadcast screens.
//
//  The app captures no audio, so this generates a plausible envelope instead.
//  It is a service rather than view state because two screens read the same
//  meter, and because a real implementation would sit behind this same shape.

import Foundation
import Observation

@MainActor
@Observable
final class AudioLevelSource {

    enum Mode: Sendable {
        /// A signal is arriving.
        case signal
        /// Nothing on the input — drives the "no input detected" warning.
        case silent
    }

    /// Current input level, 0…1.
    private(set) var level: Double = 0
    private(set) var isRunning = false

    var mode: Mode = .signal

    /// True when the input is quiet enough to be worth warning about.
    var isSilent: Bool { mode == .silent }

    /// Round-trip latency in milliseconds. Held steady rather than re-rolled each
    /// tick, so the reading does not flicker between grades while being read.
    var latencyMilliseconds: Int = 28
    var latencyGrade: LatencyGrade { .grade(forMilliseconds: latencyMilliseconds) }

    private var task: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        task = Task { [weak self] in
            var phase = 0.0
            // Exits on the next tick once the owner is gone, so no explicit
            // teardown is required for correctness.
            while !Task.isCancelled, let source = self {
                switch source.mode {
                case .signal:
                    // A breathing envelope with a little grain on top, so the
                    // meter reads as a performance rather than a sine wave.
                    phase += 0.18
                    let envelope = 0.45 + 0.35 * (sin(phase) + 1) / 2
                    source.level = min(1, max(0, envelope + Double.random(in: -0.08...0.08)))
                case .silent:
                    source.level = Double.random(in: 0...0.02)
                }
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        level = 0
    }
}
