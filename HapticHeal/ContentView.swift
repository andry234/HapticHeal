import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var connector = WatchConnector.shared
    @StateObject private var monitor = BiometricMonitor.shared
    @StateObject private var haptic = HapticManager.shared
    
    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var purrOffset: CGFloat = 0.0
    @State private var pulseTimer: Timer? = nil
    @State private var breathPhaseText: String = "INHALE"
    @State private var isPressingNavBar: Bool = false
    @State private var dragX: CGFloat = 160.0
    @State private var showProfile = false
    @State private var sessionStartTime: Date? = nil
    
    // UI Local Colors
    private let limeGreen = Color(red: 159/255, green: 232/255, blue: 112/255) // #9FE870
    private let deepGreen = Color(red: 22/255, green: 51/255, blue: 0/255)   // #163300
    private let textGray = Color(red: 0.6, green: 0.6, blue: 0.6)
    
    var body: some View {
        ZStack {
            // Dynamic Fluid Background Canvas to minimize visual overstimulation
            FluidBackgroundView()
                .ignoresSafeArea()
            
            // Bioluminescent Breath Glow Layer
            if connector.isActive && connector.selectedMode == .breath {
                limeGreen
                    .opacity(Double(pulseScale - 1.0) * 0.4) // scales between 0% and 10% opacity
                    .ignoresSafeArea()
                    .blur(radius: 60)
                    .animation(.easeInOut(duration: 0.3), value: pulseScale)
            }
            
            VStack(spacing: 40) {
                // Top Header Row
                HStack {
                    // Spacer of size 44 for visual symmetry with the profile button
                    Spacer()
                        .frame(width: 44)
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("HAPTICHEAL")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .kerning(6)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(connector.isConnected ? limeGreen : textGray)
                                .frame(width: 8, height: 8)
                            Text(connector.isConnected ? "Watch Sync Active" : "Searching Watch...")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(textGray)
                        }
                    }
                    
                    Spacer()
                    
                    // Profile Button (Liquid Glass Style)
                    Button(action: {
                        showProfile = true
                    }) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.04)))
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.2), radius: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Real-time Biometrics Display
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HEART RATE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textGray)
                            .kerning(1)
                        
                        Text(monitor.isAuthorized ? (monitor.currentHeartRate > 0 ? "\(Int(monitor.currentHeartRate)) BPM" : "-- BPM") : "Unauthorized")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(monitor.isAuthorized ? .white : .red)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("ACTIVITY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textGray)
                            .kerning(1)
                        
                        Text(monitor.isStationary ? "Stationary" : "Moving")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(monitor.isStationary ? limeGreen : .blue)
                    }
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: 400)
                
                Spacer()
                
                // Center Pulse Area
                ZStack {
                    // Active Haptic Mode Visual Rings (centered exactly on the button)
                    if connector.isActive {
                        switch connector.selectedMode {
                        case .heartbeat:
                            // Concentric heartbeat ripples centered on button
                            Circle()
                                .stroke(limeGreen.opacity(0.08), lineWidth: 2)
                                .scaleEffect(pulseScale * 1.8)
                                .blur(radius: 1.5)
                            
                            Circle()
                                .stroke(limeGreen.opacity(0.03), lineWidth: 1)
                                .scaleEffect(pulseScale * 2.4)
                                .blur(radius: 3)
                            
                            // Soft pulsing ambient glow
                            Circle()
                                .fill(limeGreen.opacity(0.04))
                                .scaleEffect(pulseScale * 1.28)
                                .opacity(glowOpacity)
                                .blur(radius: 15)
                            
                        case .purr:
                            // Soft purr humming rings
                            Circle()
                                .stroke(limeGreen.opacity(0.06), lineWidth: 30)
                                .scaleEffect(pulseScale * 1.12)
                                .opacity(glowOpacity)
                                .blur(radius: 6)
                            
                            Circle()
                                .fill(limeGreen.opacity(0.03))
                                .scaleEffect(pulseScale * 1.25)
                                .opacity(glowOpacity)
                                .blur(radius: 15)
                            
                        case .breath:
                            // Breath Guide: Expands and contracts in sync with the button
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [limeGreen.opacity(0.08), Color.clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 200
                                    )
                                )
                                .scaleEffect(pulseScale)
                                .blur(radius: 40)
                            
                            Circle()
                                .stroke(limeGreen.opacity(0.12), lineWidth: 1.5)
                                .scaleEffect(pulseScale)
                                .blur(radius: 1)
                        }
                    }
                    
                    // Main Action Circle (Liquid Glass Style)
                    centralActionButton
                }
                
                Spacer()
                
                // Stress Spike Banner Warning
                if connector.stressSpikeDetected {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.black)
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stress Spike Detected")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                                Text("Biometrics flagged an elevated heart rate (\(Int(connector.currentBPM)) BPM) while stationary.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black.opacity(0.8))
                            }
                        }
                        .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                connector.clearSpikeAlert()
                                connector.selectedMode = .breath // Default to breath guide for panic
                                connector.isActive = true
                            }) {
                                Text("Start Soothing Now")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {
                                connector.clearSpikeAlert()
                            }) {
                                Text("Dismiss")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                        }
                    }
                    .padding()
                    .background(limeGreen)
                    .cornerRadius(16)
                    .padding(.horizontal, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: connector.stressSpikeDetected)
                }
                
                // Floating Navigation Bar (Liquid Glass Capsule Style)
                floatingNavigationBar
            }
            
            // Authorization Request Overlay
            authorizationOverlay
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .preferredColorScheme(.dark)
        .onChange(of: connector.isActive) { newActive in
            if newActive {
                sessionStartTime = Date()
                haptic.play(connector.selectedMode)
                startAnimations()
            } else {
                haptic.stop()
                stopAnimations()
                
                // Track session completion and save stats
                if let startTime = sessionStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    saveCalmSession(duration: duration)
                    sessionStartTime = nil
                }
            }
        }
        .onChange(of: connector.selectedMode) { newMode in
            if !isPressingNavBar {
                dragX = xCenter(for: newMode)
            }
            if connector.isActive {
                restartAnimations()
            }
        }
        .onAppear {
            if monitor.isAuthorized {
                monitor.startMonitoring()
            }
            connector.activate()
            
            // Apply pre-selected soothing mode from onboarding
            if let savedModeRaw = UserDefaults.standard.value(forKey: "preferredSoothingMode") as? Int,
               let savedMode = HapticMode(rawValue: savedModeRaw) {
                connector.selectedMode = savedMode
            }
            
            dragX = xCenter(for: connector.selectedMode)
        }
    }
    
    // MARK: - Controller Actions
    
    private func toggleHaptics() {
        connector.isActive.toggle()
    }
    
    private func saveCalmSession(duration: Double) {
        guard duration >= 1.0 else { return } // Ignore micro sessions of less than 1 second
        let minutes = duration / 60.0
        
        let currentTotal = UserDefaults.standard.double(forKey: "calmMinutesTotal")
        UserDefaults.standard.set(currentTotal + minutes, forKey: "calmMinutesTotal")
        
        // Count as completed session only if it meets the clinical standard (5 minutes = 300 seconds)
        if duration >= 300.0 {
            let currentSessions = UserDefaults.standard.integer(forKey: "calmSessionsThisWeek")
            UserDefaults.standard.set(currentSessions + 1, forKey: "calmSessionsThisWeek")
        }
    }

    
    private func xCenter(for mode: HapticMode) -> CGFloat {
        let itemWidth: CGFloat = 320.0 / 3.0
        let index = CGFloat(mode.rawValue)
        return index * itemWidth + itemWidth / 2.0
    }
    
    private func triggerSelectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    private func modeIconName(for mode: HapticMode) -> String {
        switch mode {
        case .heartbeat: return "heart.fill"
        case .purr: return "pawprint.fill"
        case .breath: return "wind"
        }
    }
    
    // MARK: - Animation Drivers
    
    private func startAnimations() {
        stopAnimations()
        
        switch connector.selectedMode {
        case .heartbeat:
            // Heartbeat: 60 BPM -> 1 beat per second. Double-beat animation.
            // Lub-dub pulse sequence repeating every 1.0 second.
            pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // Lub: First beat
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    pulseScale = 1.08
                    glowOpacity = 0.8
                }
                
                // Back to baseline
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        pulseScale = 1.0
                        glowOpacity = 0.4
                    }
                }
                
                // Dub: Second beat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                        pulseScale = 1.05
                        glowOpacity = 0.9
                    }
                }
                
                // Back to resting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        pulseScale = 1.0
                        glowOpacity = 0.2
                    }
                }
            }
            
        case .purr:
            // Purr: Continuous low-frequency micro-jitter
            // Quick random/fast oscillations to mirror tactile texture
            pulseScale = 1.01
            glowOpacity = 0.6
            pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                withAnimation(.linear(duration: 0.08)) {
                    purrOffset = CGFloat.random(in: -1.5...1.5)
                    pulseScale = CGFloat.random(in: 1.0...1.02)
                    glowOpacity = Double.random(in: 0.5...0.7)
                }
            }
            
        case .breath:
            // Breath Guide: 19-second cycle (4-7-8 method)
            // 4s Inhale (expand), 7s Retain (hold maximum), 8s Exhale (contract)
            let cycle = {
                // Inhale: 4s
                breathPhaseText = "INHALE"
                withAnimation(.linear(duration: 4.0)) {
                    pulseScale = 1.25
                    glowOpacity = 1.0
                }
                
                // Retain: 7s (starts at +4s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    guard self.connector.isActive && self.connector.selectedMode == .breath else { return }
                    breathPhaseText = "HOLD"
                    withAnimation(.easeInOut(duration: 7.0)) {
                        pulseScale = 1.27
                        glowOpacity = 0.9
                    }
                }
                
                // Exhale: 8s (starts at +11s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 11.0) {
                    guard self.connector.isActive && self.connector.selectedMode == .breath else { return }
                    breathPhaseText = "EXHALE"
                    withAnimation(.linear(duration: 8.0)) {
                        pulseScale = 1.0
                        glowOpacity = 0.15
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
    
    // MARK: - Modular UI Sub-views (fixes compiler type-check timeout)
    
    @ViewBuilder
    private var centralActionButton: some View {
        Button(action: {
            toggleHaptics()
        }) {
            Circle()
                .fill(buttonFillStyle)
                .background(buttonBackgroundLayer)
                .overlay(buttonInnerGlowOverlay)
                .overlay(buttonBorderOverlay)
                .overlay(buttonHighlightOverlay)
                .overlay(buttonLabelContent)
                .frame(width: 200, height: 200)
                .shadow(
                    color: connector.isActive ? limeGreen.opacity(0.25) : Color.black.opacity(0.40),
                    radius: connector.isActive ? 30 : 15,
                    x: 0,
                    y: 10
                )
                .offset(y: connector.isActive && connector.selectedMode == .purr ? purrOffset : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var buttonFillStyle: AnyShapeStyle {
        if connector.isActive {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.35),
                        deepGreen.opacity(0.65)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        deepGreen.opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
    
    @ViewBuilder
    private var buttonBackgroundLayer: some View {
        Circle()
            .fill(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private var buttonInnerGlowOverlay: some View {
        if connector.isActive {
            Circle()
                .stroke(
                    RadialGradient(
                        colors: [limeGreen.opacity(0.25), Color.clear],
                        center: .center,
                        startRadius: 80,
                        endRadius: 100
                    ),
                    lineWidth: 12
                )
                .blur(radius: 4)
        }
    }
    
    @ViewBuilder
    private var buttonBorderOverlay: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: connector.isActive ? [
                        limeGreen.opacity(0.85),
                        limeGreen.opacity(0.25),
                        deepGreen.opacity(0.40),
                        limeGreen.opacity(0.60)
                    ] : [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.04),
                        deepGreen.opacity(0.10),
                        Color.white.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: connector.isActive ? 2.0 : 1.2
            )
    }
    
    @ViewBuilder
    private var buttonHighlightOverlay: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(connector.isActive ? 0.08 : 0.04),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 190, height: 190)
            .offset(y: -2)
            .mask(
                Circle()
                    .inset(by: 2)
            )
    }
    
    @ViewBuilder
    private var buttonLabelContent: some View {
        VStack(spacing: 12) {
            Image(systemName: connector.isActive ? modeIconName(for: connector.selectedMode) : "hand.tap")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(connector.isActive ? limeGreen : .white.opacity(0.9))
                .shadow(color: connector.isActive ? limeGreen.opacity(0.6) : Color.clear, radius: 8)
                .scaleEffect(connector.isActive ? pulseScale : 1.0)
            
            if connector.isActive {
                if connector.selectedMode == .breath {
                    Text(breathPhaseText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .kerning(4)
                        .foregroundColor(.white)
                        .shadow(color: limeGreen.opacity(0.4), radius: 4)
                } else {
                    Text("ACTIVE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .kerning(3)
                        .foregroundColor(limeGreen)
                        .shadow(color: limeGreen.opacity(0.4), radius: 4)
                }
            } else {
                Text("TAP TO SOOTHE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .kerning(2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    @ViewBuilder
    private var floatingNavigationBar: some View {
        ZStack(alignment: .leading) {
            // Selected Mode indicator
            GeometryReader { geometry in
                slidingGlassIndicator(geometry: geometry)
            }
            
            HStack(spacing: 0) {
                ForEach(HapticMode.allCases) { mode in
                    VStack(spacing: 4) {
                        Image(systemName: modeIconName(for: mode))
                            .font(.system(size: 20, weight: .medium))
                            .shadow(color: connector.selectedMode == mode ? limeGreen.opacity(0.5) : Color.clear, radius: 4)
                            .scaleEffect(connector.selectedMode == mode ? 1.15 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0), value: connector.selectedMode)
                        Text(mode.name)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(connector.selectedMode == mode ? limeGreen : .white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .hoverEffectDisabled()
                }
            }
        }
        .frame(width: 320, height: 68)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            deepGreen.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .inset(by: 1)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 12, x: 0, y: 6)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    let locationX = gesture.location.x
                    dragX = max(34, min(286, locationX))
                    isPressingNavBar = true
                    
                    let percentage = max(0, min(1, locationX / 320.0))
                    let index = Int(round(percentage * 2.0))
                    if let mode = HapticMode(rawValue: index), connector.selectedMode != mode {
                        triggerSelectionFeedback()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            connector.selectedMode = mode
                            if connector.isActive {
                                haptic.play(mode)
                                restartAnimations()
                            }
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isPressingNavBar = false
                    }
                }
        )
        .padding(.bottom, 15)
        .hoverEffectDisabled()
    }
    
    @ViewBuilder
    private var authorizationOverlay: some View {
        if !monitor.isAuthorized {
            ZStack {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "suit.heart.fill")
                        .font(.system(size: 64))
                        .foregroundColor(limeGreen)
                    
                    Text("Connect Health Data")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("HapticHeal requires HealthKit permissions to monitor heart rate spikes and detect anxiety anomalies in the background.")
                        .font(.system(size: 14))
                        .foregroundColor(textGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        
                    Button(action: {
                        monitor.requestAuthorization { success, _ in
                            if success {
                                monitor.startMonitoring()
                                connector.activate()
                            }
                        }
                    }) {
                        Text("Grant Access")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 40)
                            .background(limeGreen)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func slidingGlassIndicator(geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let itemWidth = width / 3.0
        let baseWidth = itemWidth - 8
        
        let currentCenter = xCenter(for: connector.selectedMode)
        let targetX = isPressingNavBar ? dragX : currentCenter
        let dist = abs(targetX - currentCenter)
        
        let indicatorWidth = baseWidth + dist
        let indicatorHeight = max(42, 60 - dist * 0.18)
        let centerX = (currentCenter + targetX) / 2.0
        
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        limeGreen.opacity(0.25),
                        deepGreen.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.02))
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.65),
                                Color.white.opacity(0.08),
                                limeGreen.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .overlay(
                // Top Highlight reflection
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 28)
                    .allowsHitTesting(false),
                alignment: .top
            )
            .mask(Capsule()) // Clips the highlight overlay exactly to the parent Capsule shape bounds
            .frame(width: indicatorWidth, height: indicatorHeight)
            .background(
                Capsule()
                    .fill(limeGreen.opacity(0.25))
                    .blur(radius: 8)
                    .offset(y: 3)
            )
            .position(x: centerX, y: 34)
            .animation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0), value: indicatorWidth)
            .animation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0), value: indicatorHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0), value: centerX)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct FluidBackgroundView: View {
    // Animation properties for ambient drift
    @State private var driftOffset1 = CGSize(width: -20, height: -30)
    @State private var driftOffset2 = CGSize(width: 30, height: 20)
    
    // UI Local Colors
    private let limeGreen = Color(red: 159/255, green: 232/255, blue: 112/255) // #9FE870
    private let deepGreen = Color(red: 22/255, green: 51/255, blue: 0/255)   // #163300
    
    var body: some View {
        ZStack {
            // Absolute Pitch Black base
            Color.black
                .ignoresSafeArea()
            
            // Ambient slow floating blobs
            ZStack {
                Circle()
                    .fill(limeGreen.opacity(0.04))
                    .frame(width: 350, height: 350)
                    .offset(driftOffset1)
                    .blur(radius: 60)
                
                Circle()
                    .fill(deepGreen.opacity(0.18))
                    .frame(width: 400, height: 400)
                    .offset(driftOffset2)
                    .blur(radius: 80)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    driftOffset1 = CGSize(width: 40, height: 20)
                    driftOffset2 = CGSize(width: -30, height: -40)
                }
            }
        }
    }
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("stressFrequency") private var stressFrequency = ""
    @AppStorage("primaryStressSymptom") private var primaryStressSymptom = ""
    @AppStorage("preferredSoothingMode") private var preferredSoothingMode = 0
    @AppStorage("calmMinutesTotal") private var totalCalmMinutes = 0.0
    @AppStorage("calmSessionsThisWeek") private var sessionsThisWeek = 0
    
    // UI Local Colors
    private let limeGreen = Color(red: 159/255, green: 232/255, blue: 112/255)
    private let deepGreen = Color(red: 22/255, green: 51/255, blue: 0/255)
    private let textGray = Color(red: 0.6, green: 0.6, blue: 0.6)
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [limeGreen.opacity(0.2), deepGreen.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 76, height: 76)
                        .overlay(
                            Circle()
                                .stroke(limeGreen.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: limeGreen.opacity(0.15), radius: 10)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(limeGreen)
                }
                
                VStack(spacing: 4) {
                    Text("Bio-Profilo")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Configurazione biometrica HapticHeal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textGray)
                }
            }
            .padding(.top, 20)
            
            // Profile Card (Unified Liquid Glass style container)
            VStack(spacing: 20) {
                profileRow(icon: "waveform", title: "Frequenza dello Stress", value: formattedFrequency)
                
                Divider().background(Color.white.opacity(0.08))
                
                profileRow(icon: "exclamationmark.triangle", title: "Sintomo Principale", value: formattedSymptom)
                
                Divider().background(Color.white.opacity(0.08))
                
                // Default Mode Selector (unified within the same card)
                VStack(alignment: .leading, spacing: 8) {
                    Text("MODALITÀ DI SOLLIEVO PREFERITA")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .kerning(1.5)
                        .foregroundColor(textGray)
                        .padding(.horizontal, 4)
                    
                    Picker("Default Mode", selection: $preferredSoothingMode) {
                        Text("Battito").tag(0)
                        Text("Fusa").tag(1)
                        Text("Respiro").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: preferredSoothingMode) { newModeRaw in
                        if let newMode = HapticMode(rawValue: newModeRaw) {
                            WatchConnector.shared.selectedMode = newMode
                        }
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1.2)
            )
            .padding(.horizontal, 24)
            
            // Statistics Card (Liquid Glass style container)
            VStack(alignment: .leading, spacing: 14) {
                Text("STATISTICHE DI CALMA")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .kerning(1.5)
                    .foregroundColor(textGray)
                    .padding(.horizontal, 4)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tempo Totale")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textGray)
                        Text(String(format: "%.1f min", totalCalmMinutes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(limeGreen)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sessioni (Settimana)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textGray)
                        Text("\(sessionsThisWeek) completate")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                // Visual progress bar toward weekly goal (e.g. goal = 7 sessions)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Obiettivo Settimanale")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textGray)
                        Spacer()
                        Text("\(sessionsThisWeek)/7 sessioni")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(limeGreen)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [limeGreen, deepGreen], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * CGFloat(min(1.0, Double(sessionsThisWeek) / 7.0)), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 4)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1.2)
            )
            .padding(.horizontal, 24)
            
            Spacer()
            
            // App Management Actions
            VStack(spacing: 12) {
                Button(action: {
                    // Reset onboarding, stats and dismiss
                    stressFrequency = ""
                    primaryStressSymptom = ""
                    totalCalmMinutes = 0.0
                    sessionsThisWeek = 0
                    hasCompletedOnboarding = false
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Resetta Onboarding")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.red.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.20), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Chiudi")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(limeGreen)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Formatters
    
    private var formattedFrequency: String {
        switch stressFrequency {
        case "rarely": return "Raramente"
        case "occasionally": return "Occasionalmente"
        case "frequently": return "Frequentemente"
        case "constantly": return "Costantemente"
        default: return "Non specificato"
        }
    }
    
    private var formattedSymptom: String {
        switch primaryStressSymptom {
        case "heartbeat": return "Battito Accelerato"
        case "breath": return "Respiro Affannoso"
        case "jitter": return "Tensione Fisica"
        case "mind": return "Mente Sovraccarica"
        default: return "Non specificato"
        }
    }
    
    @ViewBuilder
    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(limeGreen)
                .frame(width: 32, height: 32)
                .background(Circle().fill(limeGreen.opacity(0.08)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textGray)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }
}
