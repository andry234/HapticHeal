import Foundation
import WatchConnectivity
import Combine

public enum HapticMode: Int, CaseIterable, Identifiable {
    case heartbeat = 0
    case purr = 1
    case breath = 2
    
    public var id: Int { self.rawValue }
    
    public var name: String {
        switch self {
        case .heartbeat: return "Heartbeat"
        case .purr: return "Cat Purr"
        case .breath: return "Breath Guide"
        }
    }
}

public class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchConnector()
    
    @Published public var selectedMode: HapticMode = .heartbeat {
        didSet {
            sendStateToCounterpart()
        }
    }
    
    @Published public var isActive: Bool = false {
        didSet {
            sendStateToCounterpart()
        }
    }
    
    @Published public var stressSpikeDetected: Bool = false
    @Published public var currentBPM: Double = 0.0
    @Published public var isConnected: Bool = false
    
    private var session: WCSession?
    private var isSending: Bool = false
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    public func activate() {
        if WCSession.isSupported() && session?.activationState != .activated {
            session?.activate()
        }
    }
    
    // MARK: - Communication Methods
    
    public func triggerManualSpikeAlert(bpm: Double) {
        stressSpikeDetected = true
        currentBPM = bpm
        sendMessage(["action": "stressSpike", "bpm": bpm])
    }
    
    public func clearSpikeAlert() {
        stressSpikeDetected = false
        sendMessage(["action": "clearSpike"])
    }
    
    private func sendStateToCounterpart() {
        // Prevent feedback loops during synchronization
        guard !isSending else { return }
        isSending = true
        
        let message: [String: Any] = [
            "action": "syncState",
            "selectedMode": selectedMode.rawValue,
            "isActive": isActive
        ]
        
        sendMessage(message)
        isSending = false
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard let session = session, session.activationState == .activated else {
            return
        }
        
        #if os(iOS)
        guard session.isWatchAppInstalled else { return }
        #endif
        
        // Use transferUserInfo as a reliable background fallback, or sendMessage if reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send message: \(error.localizedDescription)")
                // Fallback to transferUserInfo in case of temporary disconnects
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }
    
    // MARK: - WCSessionDelegate
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated)
            print("WCSession activated. State: \(activationState.rawValue). Error: \(String(describing: error))")
        }
    }
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    
    public func sessionDidDeactivate(_ session: WCSession) {
        // Required for iOS to support multi-watch pairing scenarios
        session.activate()
    }
    #endif
    
    // Handle live messages
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        processIncomingMessage(message)
    }
    
    // Handle background transferred user info
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        processIncomingMessage(userInfo)
    }
    
    private func processIncomingMessage(_ message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let action = message["action"] as? String else { return }
            
            self.isSending = true // Temporarily lock updates to prevent feedback loop
            
            switch action {
            case "syncState":
                if let modeRawValue = message["selectedMode"] as? Int,
                   let mode = HapticMode(rawValue: modeRawValue) {
                    self.selectedMode = mode
                }
                if let active = message["isActive"] as? Bool {
                    self.isActive = active
                }
                
            case "stressSpike":
                if let bpm = message["bpm"] as? Double {
                    self.stressSpikeDetected = true
                    self.currentBPM = bpm
                }
                
            case "clearSpike":
                self.stressSpikeDetected = false
                
            default:
                break
            }
            
            self.isSending = false
        }
    }
}
