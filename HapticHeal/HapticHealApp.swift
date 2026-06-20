import SwiftUI

@main
struct HapticHealApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        // Initialize Watch Connectivity immediately on launch
        _ = WatchConnector.shared
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("iOS App entered active state. Activating connection.")
                WatchConnector.shared.activate()
                
                // If HealthKit permissions are already granted, resume background monitoring
                if BiometricMonitor.shared.isAuthorized {
                    BiometricMonitor.shared.startMonitoring()
                }
            case .background:
                print("iOS App entered background state.")
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
