import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("stressFrequency") private var stressFrequency = ""
    @AppStorage("primaryStressSymptom") private var primaryStressSymptom = ""
    @AppStorage("preferredSoothingMode") private var preferredSoothingMode = 0
    
    @State private var currentStep = 0
    @State private var demoPlaying = false
    @StateObject private var haptic = HapticManager.shared
    @StateObject private var monitor = BiometricMonitor.shared
    
    // UI Colors
    private let limeGreen = Color(red: 159/255, green: 232/255, blue: 112/255)
    private let deepGreen = Color(red: 22/255, green: 51/255, blue: 0/255)
    private let textGray = Color(red: 0.6, green: 0.6, blue: 0.6)
    
    var body: some View {
        ZStack {
            // Dynamic drifting background canvas
            FluidBackgroundView()
                .ignoresSafeArea()
            
            VStack {
                // Top Progress Bar
                progressBar
                    .padding(.top, 20)
                    .padding(.horizontal, 30)
                
                Spacer()
                
                // Screen contents based on current step
                ZStack {
                    switch currentStep {
                    case 0: welcomeStep
                    case 1: frequencyQuestionStep
                    case 2: symptomQuestionStep
                    case 3: soothingQuestionStep
                    case 4: demoStep
                    case 5: permissionsStep
                    case 6: completionStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentStep)
                
                Spacer()
                
                // Navigation controls
                navigationControls
                    .padding(.bottom, 20)
                    .padding(.horizontal, 30)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subviews
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<7) { step in
                Capsule()
                    .fill(step <= currentStep ? limeGreen : Color.white.opacity(0.15))
                    .frame(height: 6)
                    .animation(.easeInOut, value: currentStep)
            }
        }
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            ZStack {
                // Glass Droplet Vector Art
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .clear, limeGreen.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: limeGreen.opacity(0.2), radius: 25)
                
                // Pulsing ECG Wave
                Path { path in
                    path.move(to: CGPoint(x: 25, y: 70))
                    path.addLine(to: CGPoint(x: 50, y: 70))
                    path.addLine(to: CGPoint(x: 58, y: 40))
                    path.addLine(to: CGPoint(x: 68, y: 100))
                    path.addLine(to: CGPoint(x: 78, y: 50))
                    path.addLine(to: CGPoint(x: 86, y: 75))
                    path.addLine(to: CGPoint(x: 94, y: 70))
                    path.addLine(to: CGPoint(x: 115, y: 70))
                }
                .stroke(
                    limeGreen,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 140, height: 140)
                .shadow(color: limeGreen.opacity(0.5), radius: 6)
            }
            
            Text("HAPTICHEAL")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .kerning(8)
                .foregroundColor(.white)
            
            Text("Un santuario sensoriale progettato per rilevare le anomalie da stress e calmare il sistema nervoso in tempo reale.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(textGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)
        }
    }
    
    private var frequencyQuestionStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Frequenza dello Stress")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Quante volte provi episodi di stress o ansia?")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(textGray)
            }
            .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                questionButton(title: "Raramente", subtitle: "Qualche volta al mese", value: "rarely", selection: $stressFrequency)
                questionButton(title: "Occasionalmente", subtitle: "Una o due volte alla settimana", value: "occasionally", selection: $stressFrequency)
                questionButton(title: "Frequentemente", subtitle: "Quasi ogni giorno", value: "frequently", selection: $stressFrequency)
                questionButton(title: "Costantemente", subtitle: "Più volte al giorno", value: "constantly", selection: $stressFrequency)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var symptomQuestionStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Sintomi Principali")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Cosa risenti di più durante i picchi di stress?")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(textGray)
            }
            .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                questionButton(title: "Battito Accelerato", subtitle: "Tachicardia e palpitazioni", value: "heartbeat", selection: $primaryStressSymptom)
                questionButton(title: "Respiro Affannoso", subtitle: "Fame d'aria e oppressione al petto", value: "breath", selection: $primaryStressSymptom)
                questionButton(title: "Tensione Fisica", subtitle: "Muscoli contratti e tremori", value: "jitter", selection: $primaryStressSymptom)
                questionButton(title: "Mente Sovraccarica", subtitle: "Pensieri intrusivi e panico", value: "mind", selection: $primaryStressSymptom)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var soothingQuestionStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Metodo di Sollievo")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Quale tipo di feedback trovi più calmante?")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(textGray)
            }
            .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                soothingModeButton(title: "Ritmo Cardiaco", subtitle: "Rintocchi tattili lenti a 60 BPM", modeRaw: 0)
                soothingModeButton(title: "Fusa Terapeutiche", subtitle: "Vibrazione granulare profonda a 20-50Hz", modeRaw: 1)
                soothingModeButton(title: "Guida al Respiro", subtitle: "Rampa tattile sincronizzata 4-7-8", modeRaw: 2)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var demoStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Prova le Vibrazioni")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Sperimenta il feedback tattile rilassante di HapticHeal prima di iniziare.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(textGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // Large demo trigger button
            Button(action: {
                toggleDemoHaptics()
            }) {
                ZStack {
                    Circle()
                        .fill(demoPlaying ? AnyShapeStyle(LinearGradient(colors: [limeGreen.opacity(0.35), deepGreen.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.03)))
                        .frame(width: 160, height: 160)
                        .overlay(
                            Circle()
                                .stroke(demoPlaying ? limeGreen : Color.white.opacity(0.15), lineWidth: 1.5)
                        )
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .shadow(color: demoPlaying ? limeGreen.opacity(0.2) : Color.clear, radius: 20)
                    
                    VStack(spacing: 8) {
                        Image(systemName: demoPlaying ? "waveform.path.ecg" : "hand.tap.fill")
                            .font(.system(size: 38, weight: .light))
                            .foregroundColor(demoPlaying ? limeGreen : .white.opacity(0.9))
                        
                        Text(demoPlaying ? "IN PROVA..." : "TOCCA E PROVA")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .kerning(2)
                            .foregroundColor(demoPlaying ? limeGreen : .white.opacity(0.7))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Attiva la modalità di vibrazione scelta per testarla direttamente sul tuo palmo.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(textGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var permissionsStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 48))
                    .foregroundColor(limeGreen)
                    .shadow(color: limeGreen.opacity(0.4), radius: 10)
                
                Text("Monitoraggio Intelligente")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Per rilevare in tempo reale anomalie d'ansia in background, HapticHeal analizza i tuoi parametri sanitari:")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(textGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                permissionExplanationRow(icon: "heart.fill", title: "Frequenza Cardiaca (HealthKit)", description: "Osserva le variazioni del battito cardiaco in tempo reale, anche a schermo spento.")
                permissionExplanationRow(icon: "figure.walk", title: "Movimento & Attività (CoreMotion)", description: "Classifica l'attività fisica per confermare che il picco del battito si verifichi in stato di riposo.")
            }
            .padding(.horizontal, 30)
            
            Button(action: {
                requestBiometrics()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                    Text(monitor.isAuthorized ? "Sensori Collegati" : "Collega Dati Sanitari")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(monitor.isAuthorized ? Color.white : limeGreen)
                .cornerRadius(12)
                .padding(.horizontal, 30)
            }
            .disabled(monitor.isAuthorized)
        }
    }
    
    private var completionStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(limeGreen.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 54, weight: .ultraLight))
                    .foregroundColor(limeGreen)
                    .shadow(color: limeGreen.opacity(0.5), radius: 15)
            }
            
            Text("Sei Pronto")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Il tuo percorso personalizzato per gestire lo stress attraverso la sintonizzazione aptica ed acustica è pronto.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(textGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(3)
            
            VStack(alignment: .leading, spacing: 14) {
                onboardingGuideRow(
                    icon: "hand.tap.fill",
                    title: "Avvia le sessioni",
                    description: "Tocca il grande pulsante centrale nella schermata principale per iniziare o fermare la sintonizzazione."
                )
                
                onboardingGuideRow(
                    icon: "headphones",
                    title: "Suoni terapeutici (consigliati auricolari)",
                    description: "L'app riproduce toni binaurali a 6Hz ed onde Theta in tempo reale per amplificare l'efficacia delle vibrazioni."
                )
            }
            .padding(.horizontal, 30)
            .padding(.top, 8)
        }
    }
    
    private var navigationControls: some View {
        HStack {
            if currentStep > 0 && currentStep < 6 {
                Button(action: {
                    haptic.stop()
                    demoPlaying = false
                    withAnimation {
                        currentStep -= 1
                    }
                }) {
                    Text("Indietro")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(textGray)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                }
            }
            
            Spacer()
            
            Button(action: {
                advanceStep()
            }) {
                Text(currentStep == 6 ? "Entra nel Santuario" : "Avanti")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(canAdvance ? limeGreen : limeGreen.opacity(0.3))
                    .cornerRadius(10)
            }
            .disabled(!canAdvance)
        }
    }
    
    // MARK: - Helpers & Logic
    
    private var canAdvance: Bool {
        if currentStep == 1 { return !stressFrequency.isEmpty }
        if currentStep == 2 { return !primaryStressSymptom.isEmpty }
        if currentStep == 5 { return monitor.isAuthorized }
        return true
    }
    
    private func advanceStep() {
        haptic.stop()
        demoPlaying = false
        
        if currentStep == 6 {
            withAnimation {
                hasCompletedOnboarding = true
            }
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }
    
    private func toggleDemoHaptics() {
        if demoPlaying {
            haptic.stop()
            demoPlaying = false
        } else {
            if let mode = HapticMode(rawValue: preferredSoothingMode) {
                haptic.play(mode)
                demoPlaying = true
            }
        }
    }
    
    private func requestBiometrics() {
        monitor.requestAuthorization { success, _ in
            DispatchQueue.main.async {
                if success {
                    monitor.startMonitoring()
                    // Advance directly to next step once authorized
                    withAnimation {
                        currentStep = 6
                    }
                }
            }
        }
    }
    
    // Custom ViewBuilders for styled question options
    @ViewBuilder
    private func questionButton(title: String, subtitle: String, value: String, selection: Binding<String>) -> some View {
        let isSelected = selection.wrappedValue == value
        Button(action: {
            selection.wrappedValue = value
            // Soft click feedback when selecting
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .black : .white)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .black.opacity(0.7) : textGray)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(isSelected ? limeGreen : Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? limeGreen : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func soothingModeButton(title: String, subtitle: String, modeRaw: Int) -> some View {
        let isSelected = preferredSoothingMode == modeRaw
        Button(action: {
            preferredSoothingMode = modeRaw
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .black : .white)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .black.opacity(0.7) : textGray)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(isSelected ? limeGreen : Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? limeGreen : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func permissionExplanationRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(limeGreen)
                .frame(width: 24, height: 24)
                .background(limeGreen.opacity(0.1))
                .clipShape(Circle())
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textGray)
                    .lineSpacing(2)
            }
        }
    }
    
    @ViewBuilder
    private func onboardingGuideRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(limeGreen)
                .frame(width: 24, height: 24)
                .background(limeGreen.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(textGray)
                    .lineSpacing(2)
            }
        }
    }
}

