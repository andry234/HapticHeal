import SwiftUI
import Combine

struct WatchContentView: View {
    @StateObject private var connector = WatchConnector.shared
    @StateObject private var monitor = WatchBiometricMonitor.shared
    @StateObject private var haptic = HapticManager.shared
    
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var purrOffset: CGFloat = 0.0
    @State private var pulseTimer: Timer? = nil
    @State private var breathPhaseText: String = "INHALE"
    
    // UI Local Colors
    private let limeGreen = Color(red: 159/255, green: 232/255, blue: 112/255) // #9FE870
    private let deepGreen = Color(red: 22/255, green: 51/255, blue: 0/255)   // #163300
    private let textGray = Color(red: 0.6, green: 0.6, blue: 0.6)
    
    var body: some View {
        ZStack {
            // Absolute Pitch Black background to prevent overstimulation
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 6) {
                // Top Biometric Status
                HStack {
                    if monitor.isAuthorized {
                        Image(systemName: "heart.fill")
                            .foregroundColor(connector.stressSpikeDetected ? .red : limeGreen)
                            .font(.system(size: 11))
                        Text(monitor.currentHeartRate > 0 ? "\(Int(monitor.currentHeartRate))" : "--")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "heart.slash.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 11))
                        Text("No Auth")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(textGray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: monitor.isStationary ? "person.fill.turn.right" : "figure.walk")
                        .foregroundColor(monitor.isStationary ? .green : .blue)
                        .font(.system(size: 11))
                    Text(monitor.isStationary ? "Quiet" : "Active")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(textGray)
                }
                .padding(.horizontal, 8)
                .frame(height: 16)
                
                // Center Action Button (Liquid Glass Style)
                ZStack {
                    if connector.isActive {
                        Circle()
                            .stroke(limeGreen.opacity(0.2), lineWidth: 15)
                            .scaleEffect(pulseScale * 1.05)
                            .opacity(glowOpacity)
                            .blur(radius: 4)
                    }
                    
                    Button(action: {
                        toggleHaptics()
                    }) {
                        Circle()
                            .fill(
                                connector.isActive ? 
                                    AnyShapeStyle(
                                        LinearGradient(
                                            colors: [limeGreen, deepGreen],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    ) : 
                                    AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color.black.opacity(0.85), deepGreen.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            // Glossy overlay border (liquid glass look)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4),
                                                Color.white.opacity(0.05),
                                                limeGreen.opacity(0.25)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.2
                                    )
                            )
                            // Glossy highlight reflection
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.12), Color.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 76, height: 76)
                                    .offset(y: -2)
                                    .mask(
                                        Circle()
                                            .inset(by: 2)
                                    )
                            )
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: connector.isActive ? "waveform.path.ecg" : "hand.tap")
                                        .font(.system(size: connector.isActive && connector.selectedMode == .breath ? 16 : 24, weight: .light))
                                        .foregroundColor(connector.isActive ? .black : limeGreen)
                                    
                                    if connector.isActive && connector.selectedMode == .breath {
                                        Text(breathPhaseText)
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundColor(.black)
                                    }
                                }
                            )
                            .offset(y: connector.isActive && connector.selectedMode == .purr ? purrOffset : 0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 86, height: 86)
                    .shadow(color: connector.isActive ? limeGreen.opacity(0.3) : Color.black.opacity(0.5), radius: connector.isActive ? 12 : 5)
                }
                
                // Stress Spike Banner overlay for Apple Watch
                if connector.stressSpikeDetected {
                    Button(action: {
                        connector.clearSpikeAlert()
                        connector.selectedMode = .breath
                        connector.isActive = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.black)
                                .font(.system(size: 11))
                            Text("SPIKE! Tap to soothe")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(limeGreen)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(height: 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal, 6)
                } else {
                    // Custom Sliding Haptic Mode Picker (Liquid Glass Style)
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let itemWidth = width / 3.0
                        let selectedIndex = CGFloat(connector.selectedMode.rawValue)
                        
                        ZStack(alignment: .leading) {
                            // Sliding Indicator
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [limeGreen, limeGreen.opacity(0.85)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.4), Color.clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                                .frame(width: itemWidth - 2, height: geometry.size.height - 2)
                                .offset(x: selectedIndex * itemWidth + 1, y: 1)
                                .shadow(color: limeGreen.opacity(0.2), radius: 3)
                            
                            // Labels Layer
                            HStack(spacing: 0) {
                                ForEach(HapticMode.allCases) { mode in
                                    Text(modeIcon(for: mode))
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(connector.selectedMode == mode ? .black : .white)
                                        .frame(width: itemWidth, height: geometry.size.height)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                connector.selectedMode = mode
                                                if connector.isActive {
                                                    haptic.play(mode)
                                                    restartAnimations()
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(deepGreen.opacity(0.15))
                            .background(Color.white.opacity(0.01))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.04), lineWidth: 0.8)
                            )
                    )
                    .padding(.horizontal, 4)
                }
            }
            
            // Authorization Request Overlay for Apple Watch
            if !monitor.isAuthorized {
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            Image(systemName: "suit.heart.fill")
                                .font(.system(size: 28))
                                .foregroundColor(limeGreen)
                            
                            Text("Health Permission")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Required for HR spike check.")
                                .font(.system(size: 10))
                                .foregroundColor(textGray)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                monitor.requestAuthorization { success, _ in
                                    if success {
                                        monitor.startMonitoring()
                                        connector.activate()
                                    }
                                }
                            }) {
                                Text("Allow")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(limeGreen)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: connector.isActive) { newActive in
            if newActive {
                haptic.play(connector.selectedMode)
                startAnimations()
            } else {
                haptic.stop()
                stopAnimations()
            }
        }
        .onChange(of: connector.selectedMode) { _ in
            if connector.isActive {
                restartAnimations()
            }
        }
        .onAppear {
            if monitor.isAuthorized {
                monitor.startMonitoring()
            }
            connector.activate()
        }
    }
    
    // MARK: - Controller Actions
    
    private func toggleHaptics() {
        connector.isActive.toggle()
    }
    
    private func modeIcon(for mode: HapticMode) -> String {
        switch mode {
        case .heartbeat: return "Pulse"
        case .purr: return "Purr"
        case .breath: return "Breath"
        }
    }
    
    // MARK: - Animation Drivers
    
    private func startAnimations() {
        stopAnimations()
        
        switch connector.selectedMode {
        case .heartbeat:
            // Heartbeat: 60 BPM -> 1 beat per second. Double-beat animation.
            pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // Lub
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                    pulseScale = 1.05
                    glowOpacity = 0.8
                }
                
                // REST
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        pulseScale = 1.0
                        glowOpacity = 0.3
                    }
                }
                
                // Dub
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                        pulseScale = 1.03
                        glowOpacity = 0.9
                    }
                }
                
                // REST
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        pulseScale = 1.0
                        glowOpacity = 0.2
                    }
                }
            }
            
        case .purr:
            // Purr: Continuous low-frequency micro-jitter
            pulseScale = 1.01
            glowOpacity = 0.6
            pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                withAnimation(.linear(duration: 0.08)) {
                    purrOffset = CGFloat.random(in: -1.0...1.0)
                    pulseScale = CGFloat.random(in: 1.0...1.015)
                    glowOpacity = Double.random(in: 0.5...0.7)
                }
            }
            
        case .breath:
            // Breath Guide: 19-second cycle (4-7-8 method)
            let cycle = {
                // Inhale (4s)
                breathPhaseText = "INHALE"
                withAnimation(.linear(duration: 4.0)) {
                    pulseScale = 1.15
                    glowOpacity = 1.0
                }
                
                // Retain (7s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    guard self.connector.isActive && self.connector.selectedMode == .breath else { return }
                    breathPhaseText = "HOLD"
                    withAnimation(.easeInOut(duration: 7.0)) {
                        pulseScale = 1.17
                        glowOpacity = 0.9
                    }
                }
                
                // Exhale (8s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 11.0) {
                    guard self.connector.isActive && self.connector.selectedMode == .breath else { return }
                    breathPhaseText = "EXHALE"
                    withAnimation(.linear(duration: 8.0)) {
                        pulseScale = 1.0
                        glowOpacity = 0.2
                    }
                }
            }
            
            cycle()
            pulseTimer = Timer.scheduledTimer(withTimeInterval: 19.0, repeats: true) { _ in
                cycle()
            }
        }
    }
    
    private func stopAnimations() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.0
            glowOpacity = 0.3
            purrOffset = 0.0
        }
    }
    
    private func restartAnimations() {
        stopAnimations()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if self.connector.isActive {
                self.startAnimations()
            }
        }
    }
}
