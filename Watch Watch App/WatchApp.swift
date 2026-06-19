import SwiftUI

@main
struct HapticHealWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize Watch Connectivity immediately on watchOS launch
        _ = WatchConnector.shared
    }
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("watchOS App entered active state. Activating connection.")
                WatchConnector.shared.activate()
                
                // If HealthKit permissions are already granted, resume biometric monitoring
                if WatchBiometricMonitor.shared.isAuthorized {
                    WatchBiometricMonitor.shared.startMonitoring()
                }
            case .background:
                print("watchOS App entered background state.")
                // Maintain workout session monitoring in the background
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
