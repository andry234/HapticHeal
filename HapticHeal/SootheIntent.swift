import AppIntents
import SwiftUI

struct StartSootheIntent: AppIntent {
    static var title: LocalizedStringResource = "Avvia Sollievo HapticHeal"
    static var description: LocalizedStringResource = "Avvia immediatamente la sintonizzazione haptic preferita di HapticHeal."
    
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Trigger soothing haptics on
        WatchConnector.shared.isActive = true
        
        // Apply pre-selected default mode from onboarding
        if let savedModeRaw = UserDefaults.standard.value(forKey: "preferredSoothingMode") as? Int,
           let savedMode = HapticMode(rawValue: savedModeRaw) {
            WatchConnector.shared.selectedMode = savedMode
        }
        
        return .result(dialog: "Avvio della sintonizzazione di HapticHeal in corso. Rilassati ed espira.")
    }
}

struct HapticHealShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSootheIntent(),
            phrases: [
                "Avvia sollievo con \(.applicationName)",
                "Ho l'ansia con \(.applicationName)",
                "Calmami con \(.applicationName)"
            ],
            shortTitle: "Sollievo HapticHeal",
            systemImageName: "sparkles"
        )
    }
}
