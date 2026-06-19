# HapticHeal 🧬✨

HapticHeal is a premium, high-fidelity iOS and watchOS ecosystem designed to detect anxiety anomalies and soothe stress in real-time through coordinated haptic feedback and dynamic glassmorphic animations.

Developed with a minimalist **Liquid Glass** aesthetic on a pitch-black background, it minimizes visual stimulation while delivering calming sensory stimulation.

---

## Key Features 🚀

- **Anxiety & Stress Detection**: Continuous background heart rate querying (via `HealthKit`) coupled with motion classification (via `CoreMotion` accelerometer tracking) to identify stress anomalies (elevated heart rate while stationary).
- **Soothing Haptic Engine**: Modulates custom, advanced haptic rhythms via `CoreHaptics` and `WKHapticType`:
  - ❤️ **Heartbeat**: 60 BPM tactile thumps aligned with double-beat scaling animations.
  - 🐾 **Cat Purr**: Randomly modulated low-frequency rumbles (20-50Hz) simulating a cat's respiratory purr.
  - 🌬️ **Breath Guide**: Structured 4-7-8 breathing cycles (Inhale, Hold, Exhale) with continuous intensity envelopes.
- **Bi-Directional Watch Sync**: Built on `WatchConnectivity` to coordinate active states, haptic selections, and stress alert notifications in real-time between iPhone and Apple Watch.
- **Premium Glassmorphic UI**: Ultra-thin materials, luminous inner glow layers, and glowing lime-green (`#9FE870`) accents optimized for OLED displays.

---

## Directory Structure 📂

The codebase is organized into modular components to support cross-device communication:

```
HapticHeal/
├── HapticHeal/               # iOS Application Target
│   ├── Assets.xcassets/      # Brand Icon and Visual Colors
│   ├── BiometricMonitor.swift# HealthKit & CoreMotion iOS Manager
│   ├── ContentView.swift     # Premium iOS UI & Glassmorphic Buttons
│   ├── HapticHealApp.swift   # Main iOS Application Lifecycle
│   ├── HapticManager.swift   # CoreHaptics iOS Sound Engine
│   └── WatchConnector.swift  # WatchConnectivity iOS Coordinator
│
├── Watch Watch App/          # watchOS Companion Target
│   ├── Assets.xcassets/      # watchOS App Icon & Assets
│   ├── ContentView.swift     # watchOS Mini Soothing Interface
│   ├── HapticManager.swift   # watchOS Haptic Trigger Fallback
│   ├── WatchBiometricMonitor.swift # Watch foreground/background HealthKit queries
│   └── WatchWatchApp.swift   # watchOS App Entry Point
│
└── README.md                 # Project Documentation
```

---

## Architecture & Code Map 🛠️

### 1. Haptic Engine (`HapticManager`)
The [HapticManager](file:///Users/andreariccelli/Desktop/HapticHeal/HapticHeal/HapticManager.swift) controls the tactical feedback. On iOS, it uses `CoreHaptics` to build custom haptic pattern players (dynamic curves for breathing, random amplitude intervals for purring). On watchOS, it gracefully falls back to the device's native `WKHapticType` sequences.

### 2. Biometric Tracking (`BiometricMonitor` & `WatchBiometricMonitor`)
- **iOS [BiometricMonitor](file:///Users/andreariccelli/Desktop/HapticHeal/HapticHeal/BiometricMonitor.swift)**: Requests HealthKit authorizations, sets up background query observers for heart rate updates, and polls `CMMotionActivityManager` to verify if the user is resting during heart rate spikes.
- **watchOS [WatchBiometricMonitor](file:///Users/andreariccelli/Desktop/HapticHeal/Watch%20Watch%20App/WatchBiometricMonitor.swift)**: Spins up an active `HKWorkoutSession` to capture optical heart rate data continuously, calculating standard deviations on CoreMotion acceleration to confirm stationary state.

### 3. State Synchronization (`WatchConnector`)
Built on `WCSession`, [WatchConnector](file:///Users/andreariccelli/Desktop/HapticHeal/HapticHeal/WatchConnector.swift) synchronizes:
- Active soothe state (on/off)
- Selected soothe mode (`.heartbeat`, `.purr`, `.breath`)
- Live heart rate metrics
- Stress spike alerts (triggering alert views on iOS to prompt immediate breath exercises)

---

## Setup & Installation ⚙️

### Prerequisites
- Xcode 15 or higher
- iOS 17.0+ / watchOS 10.0+ SDKs
- Active Apple Developer Account (required for HealthKit and Background Delivery entitlements)

### Signing & Capabilities
To run HapticHeal on physical devices, enable the following capabilities under **Signing & Capabilities** in Xcode:

1. **iOS App Target**:
   - **HealthKit**: Check *Background Delivery*.
   - **Background Modes**: Check *Background fetch* and *Background processing*.
2. **Watch Target**:
   - **HealthKit**: Check *Background Delivery*.
   - **Background Modes**: Check *Workout processing* (keeps sensors active when watch screen sleeps).

### Privacy Descriptions (Info.plist)
Add the following keys in your target `Info` settings to prompt users for sensor access:
- `Privacy - Health Share Usage Description`: "HapticHeal reads heart rate biometrics to detect stress anomalies."
- `Privacy - Health Update Usage Description`: "HapticHeal records workout logs to run background biometrics."
- `Privacy - Motion Usage Description`: "HapticHeal uses accelerometer readings to check if you are stationary during stress spikes."

---

## Design System & Palette 🎨

HapticHeal uses a customized palette to maintain visual serenity:

| Color Token | Hex | Usage |
| :--- | :--- | :--- |
| **Pitch Black** | `#000000` | Deep OLED calming background |
| **Lime Green** | `#9FE870` | Active states, branding highlights, glowing indicators |
| **Deep Green** | `#163300` | Glassmorphic gradient base, secondary accents |
| **Muted Gray** | `#999999` | Secondary descriptors and labels |

---

## License 📄
This project is licensed under the MIT License - see the LICENSE file for details.
