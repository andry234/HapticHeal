import Foundation
#if !os(watchOS)
import CoreHaptics
#endif
import Combine

#if os(watchOS)
import WatchKit
#endif

public class HapticManager: ObservableObject {
    public static let shared = HapticManager()
    
    #if !os(watchOS)
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: CHHapticPatternPlayer?
    private var breathPlayer: CHHapticAdvancedPatternPlayer?
    #endif
    private var timer: Timer?
    private var currentMode: HapticMode?
    
    @Published public var isEngineRunning: Bool = false
    
    private init() {
        #if !os(watchOS)
        createEngine()
        #endif
    }
    
    #if !os(watchOS)
    private func createEngine() {
        do {
            hapticEngine = try CHHapticEngine()
            
            // Handle engine reset in case of audio server interruption
            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic Engine reset handler triggered.")
                self?.isEngineRunning = false
                do {
                    try self?.hapticEngine?.start()
                    self?.isEngineRunning = true
                    // Restart haptics if we were playing
                    if let mode = self?.currentMode {
                        self?.play(mode)
                    }
                } catch {
                    print("Failed to restart haptic engine after reset: \(error.localizedDescription)")
                }
            }
            
            // Handle engine stopped
            hapticEngine?.stoppedHandler = { reason in
                print("Haptic Engine stopped. Reason: \(reason.rawValue)")
                DispatchQueue.main.async {
                    self.isEngineRunning = false
                }
            }
            
        } catch {
            print("Failed to initialize CoreHaptics engine: \(error.localizedDescription)")
        }
    }
    
    private func startEngineIfNeeded() -> Bool {
        guard let engine = hapticEngine else { return false }
        if isEngineRunning { return true }
        
        do {
            try engine.start()
            isEngineRunning = true
            return true
        } catch {
            print("Failed to start Haptic Engine: \(error.localizedDescription)")
            return false
        }
    }
    #endif
    
    // MARK: - Public Playback Control
    
    public func play(_ mode: HapticMode) {
        stop()
        currentMode = mode
        
        #if !os(watchOS)
        // If CoreHaptics is supported and starts, use it
        if startEngineIfNeeded() {
            switch mode {
            case .heartbeat:
                playHeartbeatPattern()
            case .purr:
                playPurrPattern()
            case .breath:
                playBreathGuidePattern()
            }
            return
        }
        #endif
        
        // Fallback for watchOS or non-CoreHaptics hardware
        playFallbackPattern(for: mode)
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        
        #if !os(watchOS)
        do {
            try hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            try breathPlayer?.stop(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to stop haptic players: \(error.localizedDescription)")
        }
        
        hapticPlayer = nil
        breathPlayer = nil
        currentMode = nil
        
        // Stop engine to save power when not playing
        if isEngineRunning {
            hapticEngine?.stop { error in
                if let error = error {
                    print("Error stopping haptic engine: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.isEngineRunning = false
                    }
                }
            }
        }
        #else
        currentMode = nil
        #endif
    }
    
    #if !os(watchOS)
    // MARK: - Core Haptics Patterns
    
    private func playHeartbeatPattern() {
        // Heartbeat at 60 BPM (1 beat per second)
        // We play a synchronized double-beat (Lub-dub) matching the UI animation:
        // Lub at 0.0s, Dub at 0.28s
        let timeInterval = 1.0
        
        let playDoubleThump = { [weak self] in
            guard let self = self, self.isEngineRunning else { return }
            
            // Lub: First beat (deeper and slightly stronger)
            let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
            let event1 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity1, sharpness1], relativeTime: 0.0)
            
            // Dub: Second beat (slightly softer)
            let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85)
            let sharpness2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
            let event2 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity2, sharpness2], relativeTime: 0.28)
            
            do {
                let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
                let player = try self.hapticEngine?.makePlayer(with: pattern)
                try player?.start(atTime: CHHapticTimeImmediate)
            } catch {
                print("Error playing heartbeat thumps: \(error.localizedDescription)")
            }
        }
        
        // Play first double-beat immediately
        playDoubleThump()
        
        // Schedule repeating double-beats
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            playDoubleThump()
        }
    }
    
    private func playPurrPattern() {
        // Cat Purr: Continuous low-frequency rumble (20Hz-50Hz corresponds to very low sharpness)
        // with a granular texture (slight intensity modulation over time)
        
        let duration = 30.0 // Play for 30s before needing loop/restart
        
        // Create continuous event
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.08) // Low sharpness = low frequency rumble
        
        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: duration
        )
        
        // Create a parameter curve to modulate intensity slightly and create a granular texture
        var controlPoints: [CHHapticParameterCurve.ControlPoint] = []
        for time in stride(from: 0.0, through: duration, by: 0.15) {
            // Modulate between 0.35 and 0.55 intensity to simulate breathing/purring texture
            let randomOffset = Float.random(in: -0.08...0.08)
            let modulatedValue = 0.45 + sin(Float(time) * 4.0) * 0.06 + randomOffset
            controlPoints.append(
                CHHapticParameterCurve.ControlPoint(relativeTime: time, value: modulatedValue)
            )
        }
        
        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: controlPoints,
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(events: [continuousEvent], parameterCurves: [intensityCurve])
            hapticPlayer = try hapticEngine?.makePlayer(with: pattern)
            try hapticPlayer?.start(atTime: CHHapticTimeImmediate)
            
            // Loop pattern when it finishes
            timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { [weak self] _ in
                self?.playPurrPattern()
            }
        } catch {
            print("Error playing purr pattern: \(error.localizedDescription)")
        }
    }
    
    private func playBreathGuidePattern() {
        // Breath Guide: 19-second cycle (4-7-8 method):
        // - Inhale (4s): intensity ramp 0.0 -> 1.0, sharpness 0.15 -> 0.6
        // - Retain (7s): STILLNESS (intensity 0.0, sharpness 0.0) to represent holding breath.
        // - Exhale (8s): intensity ramp 0.8 -> 0.0, sharpness 0.5 -> 0.15
        
        let cycleDuration = 19.0
        
        // Base continuous haptic event covering the whole 19 seconds
        let baseIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let baseSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        
        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [baseIntensity, baseSharpness],
            relativeTime: 0,
            duration: cycleDuration
        )
        
        // Tactile marker: Single heavy transient click at 4.0s (Inhale -> HOLD transition)
        let holdTick = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0), // Max power for the boundary tick
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ],
            relativeTime: 4.0
        )
        
        // Tactile marker: Double tick at 11.0s and 11.15s (HOLD -> EXHALE transition)
        let exhaleTick1 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
            ],
            relativeTime: 11.0
        )
        let exhaleTick2 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
            ],
            relativeTime: 11.15
        )
        
        // Intensity curve: ramps up to 1.0 at 3.9s, drops to 0.0 at 4.0s (HOLD starts), and ramps down from 0.8 to 0.0 during exhale
        let intensityPoints = [
            CHHapticParameterCurve.ControlPoint(relativeTime: 0.0, value: 0.0),
            CHHapticParameterCurve.ControlPoint(relativeTime: 3.9, value: 1.0),
            
            CHHapticParameterCurve.ControlPoint(relativeTime: 4.0, value: 0.0),  // HOLD starts (silence)
            CHHapticParameterCurve.ControlPoint(relativeTime: 11.0, value: 0.0), // HOLD ends
            
            CHHapticParameterCurve.ControlPoint(relativeTime: 11.1, value: 0.8), // EXHALE starts
            CHHapticParameterCurve.ControlPoint(relativeTime: 19.0, value: 0.0)  // EXHALE ends
        ]
        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: intensityPoints,
            relativeTime: 0
        )
        
        // Sharpness curve (ramps frequency up and down)
        let sharpnessPoints = [
            CHHapticParameterCurve.ControlPoint(relativeTime: 0.0, value: 0.15),
            CHHapticParameterCurve.ControlPoint(relativeTime: 3.9, value: 0.6),
            
            CHHapticParameterCurve.ControlPoint(relativeTime: 4.0, value: 0.0),
            CHHapticParameterCurve.ControlPoint(relativeTime: 11.0, value: 0.0),
            
            CHHapticParameterCurve.ControlPoint(relativeTime: 11.1, value: 0.5),
            CHHapticParameterCurve.ControlPoint(relativeTime: 19.0, value: 0.15)
        ]
        let sharpnessCurve = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: sharpnessPoints,
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(
                events: [continuousEvent, holdTick, exhaleTick1, exhaleTick2],
                parameterCurves: [intensityCurve, sharpnessCurve]
            )
            
            // Use advanced player to loop indefinitely
            let advancedPlayer = try hapticEngine?.makeAdvancedPlayer(with: pattern)
            advancedPlayer?.loopEnabled = true
            advancedPlayer?.loopEnd = cycleDuration
            
            try advancedPlayer?.start(atTime: CHHapticTimeImmediate)
            breathPlayer = advancedPlayer
        } catch {
            print("Error playing breath guide pattern: \(error.localizedDescription)")
        }
    }
    #endif
    
    // MARK: - Fallback Haptic Player (for WatchKit / non-CoreHaptics hardware)
    
    private func playFallbackPattern(for mode: HapticMode) {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        
        switch mode {
        case .heartbeat:
            // Loop heartbeat haptic (Lub-dub) every 1 second
            let playWatchHeartbeat = {
                device.play(.start)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    device.play(.click)
                }
            }
            playWatchHeartbeat()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                playWatchHeartbeat()
            }
            
        case .purr:
            // Continuous rumble simulator using repeating soft vibrations
            timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                device.play(.directionDown)
            }
            device.play(.directionDown)
            
        case .breath:
            // Simulating 4-7-8 breathing method (19-second cycle)
            let playBreathCycle = {
                device.play(.directionUp) // Inhale (0s)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    device.play(.retry) // Retain (4s)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 11.0) {
                    device.play(.directionDown) // Exhale (11s)
                }
            }
            
            // Play first cycle immediately
            playBreathCycle()
            
            // Loop every 19 seconds
            timer = Timer.scheduledTimer(withTimeInterval: 19.0, repeats: true) { _ in
                playBreathCycle()
            }
        }
        #else
        print("CoreHaptics unavailable on iOS. Cannot play haptics.")
        #endif
    }
}
