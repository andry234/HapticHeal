import Foundation
import AVFoundation
import Combine

public class SoundManager: ObservableObject {
    public static let shared = SoundManager()
    
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    
    private var isPlaying = false
    private var currentMode: HapticMode?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session in SoundManager: \(error.localizedDescription)")
        }
    }
    
    public func play(_ mode: HapticMode) {
        stop()
        currentMode = mode
        isPlaying = true
        
        let engine = AVAudioEngine()
        audioEngine = engine
        
        // Define Left & Right frequencies to generate the 6Hz Binaural Beat
        let leftFreq: Double
        let rightFreq: Double
        let isPurr = (mode == .purr)
        
        switch mode {
        case .breath:
            leftFreq = 144.0
            rightFreq = 150.0 // 6Hz Theta difference
        case .purr:
            leftFreq = 50.0
            rightFreq = 50.0 // Low hum resonance
        case .heartbeat:
            leftFreq = 194.0
            rightFreq = 200.0 // 6Hz Theta difference
        }
        
        var phase: Double = 0.0
        
        sourceNode = AVAudioSourceNode { (_, _, frameCount, audioBufferList) -> OSStatus in
            let ablist = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
                let sampleTime = phase / 44100.0
                
                let valL: Float
                let valR: Float
                
                if isPurr {
                    // Synthesize modulated cat purring acoustics:
                    // Modulate 50Hz hum volume dynamically to simulate respiration & vocal vibration
                    let lfo = sin(sampleTime * 4.2) * 0.3 + 0.7
                    let noise = Float.random(in: -0.05...0.05)
                    let signal = sin(2.0 * .pi * leftFreq * sampleTime)
                    let output = Float(signal) * Float(lfo) * 0.12 + noise * 0.015
                    valL = output
                    valR = output
                } else {
                    // Binaural Beats (Separated frequencies for Left and Right ear channels)
                    valL = Float(sin(2.0 * .pi * leftFreq * sampleTime) * 0.06)
                    valR = Float(sin(2.0 * .pi * rightFreq * sampleTime) * 0.06)
                }
                
                phase += 1.0
                
                for buffer in ablist {
                    let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)
                    if buffer.mNumberChannels == 2 {
                        ptr?[frame * 2] = valL
                        ptr?[frame * 2 + 1] = valR
                    } else {
                        // Mono fallback
                        ptr?[frame] = (valL + valR) / 2.0
                    }
                }
            }
            return noErr
        }
        
        guard let source = sourceNode else { return }
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            engine.mainMixerNode.outputVolume = 0.8
        } catch {
            print("Failed to start AVAudioEngine: \(error.localizedDescription)")
        }
    }
    
    public func stop() {
        guard isPlaying else { return }
        isPlaying = false
        
        audioEngine?.stop()
        audioEngine = nil
        sourceNode = nil
        currentMode = nil
    }
}
