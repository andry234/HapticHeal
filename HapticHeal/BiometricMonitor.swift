import Foundation
import HealthKit
import CoreMotion
import Combine

public class BiometricMonitor: ObservableObject {
    public static let shared = BiometricMonitor()
    
    private let healthStore = HKHealthStore()
    private let activityManager = CMMotionActivityManager()
    private let motionQueue = OperationQueue()
    
    @Published public var isAuthorized: Bool = false
    @Published public var currentHeartRate: Double = 0.0
    @Published public var isStationary: Bool = true
    @Published public var lastSpikeDetectionTime: Date?
    
    // Cache for sliding 2-minute window: array of (timestamp, bpm)
    private var heartRateSamples: [(Date, Double)] = []
    private var observerQuery: HKObserverQuery?
    private var isMonitoring: Bool = false
    
    private init() {
        checkHealthKitAvailability()
    }
    
    private func checkHealthKitAvailability() {
        if HKHealthStore.isHealthDataAvailable() {
            // Check if we already requested authorization in the past
            self.isAuthorized = UserDefaults.standard.bool(forKey: "hasRequestedHealthKit")
        }
    }
    
    // MARK: - Permissions
    
    public func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "com.hapticheal", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device."]))
            return
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(false, NSError(domain: "com.hapticheal", code: 2, userInfo: [NSLocalizedDescriptionKey: "Heart rate quantity type is unavailable."]))
            return
        }
        
        let typesToRead: Set<HKObjectType> = [heartRateType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    UserDefaults.standard.set(true, forKey: "hasRequestedHealthKit")
                }
                self?.isAuthorized = success
                completion(success, error)
            }
        }
    }
    
    // MARK: - Monitoring Start / Stop
    
    public func startMonitoring() {
        guard !isMonitoring && HKHealthStore.isHealthDataAvailable() else { return }
        isMonitoring = true
        
        startMotionMonitoring()
        startHeartRateMonitoring()
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        // Stop motion updates
        activityManager.stopActivityUpdates()
        
        // Stop observer query
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
        
        heartRateSamples.removeAll()
    }
    
    // MARK: - Motion Monitoring (CoreMotion)
    
    private func startMotionMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            // Fallback: assume stationary if motion hardware is unavailable (e.g. Simulator)
            DispatchQueue.main.async {
                self.isStationary = true
            }
            return
        }
        
        activityManager.startActivityUpdates(to: motionQueue) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            
            DispatchQueue.main.async {
                // If user is stationary, or not walking/running/cycling/automotive, assume stationary
                let stationary = activity.stationary || 
                                (!activity.walking && !activity.running && !activity.cycling && !activity.automotive)
                self.isStationary = stationary
                print("iOS Activity update: stationary=\(stationary), confidence=\(activity.confidence.rawValue)")
            }
        }
    }
    
    // MARK: - Heart Rate Monitoring (HealthKit)
    
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        // Set up background delivery for heart rate if supported
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if !success {
                print("Could not enable background delivery for heart rate: \(String(describing: error))")
            }
        }
        
        // Observer query to get notified when new heart rate samples are written to HealthKit
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Observer query error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            self?.fetchLatestHeartRateSample {
                completionHandler()
            }
        }
        
        healthStore.execute(query)
        self.observerQuery = query
    }
    
    private func fetchLatestHeartRateSample(completion: @escaping () -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion()
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, results, error in
            defer { completion() }
            
            guard let self = self,
                  let sample = results?.first as? HKQuantitySample else {
                return
            }
            
            let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            let date = sample.startDate
            
            DispatchQueue.main.async {
                self.currentHeartRate = bpm
                self.processNewHeartRateSample(bpm: bpm, date: date)
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Anxiety Spike Algorithm
    
    private func processNewHeartRateSample(bpm: Double, date: Date) {
        let now = Date()
        
        // 1. Add new sample
        heartRateSamples.append((date, bpm))
        
        // 2. Remove samples older than 2 minutes (120 seconds)
        let twoMinutesAgo = now.addingTimeInterval(-120)
        heartRateSamples = heartRateSamples.filter { $0.0 >= twoMinutesAgo }
        
        // 3. Ensure we have enough data (at least 2 samples, representing some span of time)
        guard heartRateSamples.count >= 2 else { return }
        
        // 4. Calculate baseline heart rate (average of the oldest half of samples in the 2-minute window)
        let sortedSamples = heartRateSamples.sorted(by: { $0.0 < $1.0 })
        let splitIndex = sortedSamples.count / 2
        let baselineSamples = Array(sortedSamples[0..<splitIndex])
        
        guard !baselineSamples.isEmpty else { return }
        
        let baselineBPM = baselineSamples.map { $0.1 }.reduce(0, +) / Double(baselineSamples.count)
        
        // 5. Compare the latest sample to the baseline
        let latestBPM = sortedSamples.last!.1
        let increasePercentage = ((latestBPM - baselineBPM) / baselineBPM) * 100.0
        
        print("Spike algorithm analysis: Baseline \(baselineBPM) BPM, Current \(latestBPM) BPM, Increase \(increasePercentage)%")
        
        // Check conditions: >30% rise, stationary (CoreMotion), and prevent spamming alerts (cooldown of 2 minutes)
        if increasePercentage >= 30.0 && isStationary {
            if lastSpikeDetectionTime == nil || now.timeIntervalSince(lastSpikeDetectionTime!) > 120 {
                lastSpikeDetectionTime = now
                triggerPanicAlert(bpm: latestBPM)
            }
        }
    }
    
    private func triggerPanicAlert(bpm: Double) {
        print("🚨 ANXIETY SPIKE DETECTED! BPM: \(bpm)")
        // Trigger local notification or synchronize with WCSession
        WatchConnector.shared.triggerManualSpikeAlert(bpm: bpm)
    }
}
