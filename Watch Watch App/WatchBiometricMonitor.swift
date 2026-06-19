import Foundation
import HealthKit
import CoreMotion
import Combine

#if os(watchOS)
import WatchKit
#endif

public class WatchBiometricMonitor: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    public static let shared = WatchBiometricMonitor()
    
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    
    @Published public var isAuthorized: Bool = false
    @Published public var currentHeartRate: Double = 0.0
    @Published public var isStationary: Bool = true
    @Published public var isMonitoring: Bool = false
    
    // HealthKit workout session variables (needed for background HR monitoring)
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    // Heart rate tracking (sliding 2-minute window)
    private var heartRateSamples: [(Date, Double)] = []
    private var lastSpikeDetectionTime: Date?
    
    // Accelerometer variables
    private var motionTimer: Timer?
    private var accelerometerMagnitudeSum: Double = 0.0
    private var accelerometerSampleCount: Int = 0
    private var recentMagnitudes: [Double] = []
    
    private override init() {
        super.init()
        if HKHealthStore.isHealthDataAvailable() {
            self.isAuthorized = UserDefaults.standard.bool(forKey: "hasRequestedHealthKit_Watch")
        }
    }
    
    // MARK: - Permissions
    
    public func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "com.hapticheal.watch", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available."]))
            return
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(false, NSError(domain: "com.hapticheal.watch", code: 2, userInfo: [NSLocalizedDescriptionKey: "Heart rate quantity type is unavailable."]))
            return
        }
        
        let typesToRead: Set<HKObjectType> = [heartRateType, HKWorkoutType.workoutType()]
        let typesToShare: Set<HKSampleType> = [HKWorkoutType.workoutType()] // Needed to run workout session
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    UserDefaults.standard.set(true, forKey: "hasRequestedHealthKit_Watch")
                }
                self?.isAuthorized = success
                completion(success, error)
            }
        }
    }
    
    // MARK: - Start / Stop monitoring
    
    public func startMonitoring() {
        guard !isMonitoring && HKHealthStore.isHealthDataAvailable() else { return }
        
        // Start workout session to keep heart rate sensors active in background
        startWorkoutSession()
        startMotionMonitoring()
        
        DispatchQueue.main.async {
            self.isMonitoring = true
        }
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        stopWorkoutSession()
        stopMotionMonitoring()
        
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.heartRateSamples.removeAll()
        }
    }
    
    // MARK: - HealthKit Workout Session (Background HR Active Stream)
    
    private func startWorkoutSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            // Set data source to watch sensors
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { success, error in
                if success {
                    print("Workout session collection started successfully.")
                } else {
                    print("Error starting workout collection: \(String(describing: error))")
                }
            }
        } catch {
            print("Failed to build workout session: \(error.localizedDescription)")
        }
    }
    
    private func stopWorkoutSession() {
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { _, _ in
            self.workoutBuilder?.finishWorkout { _, _ in
                // Session fully ended
            }
        }
    }
    
    // MARK: - CoreMotion Accelerometer Monitoring
    
    private func startMotionMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            DispatchQueue.main.async {
                self.isStationary = true
            }
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.2 // Sample 5 times a second
        motionManager.startAccelerometerUpdates()
        
        recentMagnitudes.removeAll()
        
        // Timer to aggregate and check movement variance every 2 seconds
        motionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.evaluateMotionState()
        }
    }
    
    private func stopMotionMonitoring() {
        motionManager.stopAccelerometerUpdates()
        motionTimer?.invalidate()
        motionTimer = nil
    }
    
    private func evaluateMotionState() {
        guard let data = motionManager.accelerometerData else { return }
        
        let acc = data.acceleration
        // Compute total magnitude (gravity is approx 1G under stationary state)
        let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        
        recentMagnitudes.append(magnitude)
        
        // Keep a rolling 10-sample history (representing last 20 seconds of aggregated checks)
        if recentMagnitudes.count > 10 {
            recentMagnitudes.removeFirst()
        }
        
        // Calculate standard deviation of acceleration magnitude
        // Stationary state will have standard deviation close to 0. Moving states will vary heavily.
        let count = Double(recentMagnitudes.count)
        guard count > 1 else { return }
        
        let mean = recentMagnitudes.reduce(0, +) / count
        let sumOfSquaredDiffs = recentMagnitudes.map { pow($0 - mean, 2.0) }.reduce(0, +)
        let standardDeviation = sqrt(sumOfSquaredDiffs / (count - 1))
        
        DispatchQueue.main.async {
            // If the standard deviation is very low (< 0.15G fluctuation), the user is stationary
            let stationary = standardDeviation < 0.15
            self.isStationary = stationary
            print("Watch Activity: SD=\(standardDeviation), stationary=\(stationary)")
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate
    
    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("Workout session state changed from \(fromState.rawValue) to \(toState.rawValue)")
    }
    
    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed with error: \(error.localizedDescription)")
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    
    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        if types.contains(heartRateType) {
            if let statistics = workoutBuilder.statistics(for: heartRateType),
               let quantity = statistics.mostRecentQuantity() {
                let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let bpm = quantity.doubleValue(for: bpmUnit)
                
                DispatchQueue.main.async {
                    self.currentHeartRate = bpm
                    self.processNewHeartRateSample(bpm: bpm)
                }
            }
        }
    }
    
    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    
    // MARK: - Watch Spike Detection Algorithm
    
    private func processNewHeartRateSample(bpm: Double) {
        let now = Date()
        
        heartRateSamples.append((now, bpm))
        
        // Remove samples older than 2 minutes
        let twoMinutesAgo = now.addingTimeInterval(-120)
        heartRateSamples = heartRateSamples.filter { $0.0 >= twoMinutesAgo }
        
        guard heartRateSamples.count >= 2 else { return }
        
        // Calculate baseline heart rate (average of oldest half of samples in the 2-minute window)
        let sortedSamples = heartRateSamples.sorted(by: { $0.0 < $1.0 })
        let splitIndex = sortedSamples.count / 2
        let baselineSamples = Array(sortedSamples[0..<splitIndex])
        
        guard !baselineSamples.isEmpty else { return }
        
        let baselineBPM = baselineSamples.map { $0.1 }.reduce(0, +) / Double(baselineSamples.count)
        let latestBPM = sortedSamples.last!.1
        let increasePercentage = ((latestBPM - baselineBPM) / baselineBPM) * 100.0
        
        print("Watch Spike check: Baseline \(baselineBPM) BPM, Current \(latestBPM) BPM, Increase \(increasePercentage)%")
        
        // Trigger if >30% rise, stationary, and outside the 2-minute cooldown
        if increasePercentage >= 30.0 && isStationary {
            if lastSpikeDetectionTime == nil || now.timeIntervalSince(lastSpikeDetectionTime!) > 120 {
                lastSpikeDetectionTime = now
                triggerPanicAlert(bpm: latestBPM)
            }
        }
    }
    
    private func triggerPanicAlert(bpm: Double) {
        print("🚨 WATCH ANXIETY SPIKE DETECTED! BPM: \(bpm)")
        
        #if os(watchOS)
        // Trigger strong haptic alert on watch:
        // "Stress spike detected. Tap to activate HapticHeal."
        // We play multiple heavy notifications so it is felt clearly through panic
        let device = WKInterfaceDevice.current()
        device.play(.failure)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            device.play(.retry)
        }
        #endif
        
        // Alert phone companion app
        WatchConnector.shared.triggerManualSpikeAlert(bpm: bpm)
    }
}
