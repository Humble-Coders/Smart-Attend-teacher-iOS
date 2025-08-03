import Foundation
import UserNotifications
import UIKit

class SessionTimerManager: ObservableObject {
    @Published var isTimerActive = false
    @Published var timeRemaining: TimeInterval = 300 // 5 minutes
    @Published var showTimerDialog = false
    
    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let sessionDuration: TimeInterval = 300 // 5 minutes
    private var sessionEndTime: Date?
    private var onSessionEnd: (() -> Void)?
    
    var timeRemainingFormatted: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        return (sessionDuration - timeRemaining) / sessionDuration
    }
    
    init() {
        setupNotifications()
        setupAppStateObservers()
    }
    
    // MARK: - Timer Management
    func startTimer(onComplete: @escaping () -> Void) {
        self.onSessionEnd = onComplete
        
        // Calculate exact end time
        sessionEndTime = Date().addingTimeInterval(sessionDuration)
        timeRemaining = sessionDuration
        isTimerActive = true
        showTimerDialog = true
        
        // Schedule the guaranteed notification timer
        scheduleGuaranteedSessionEndNotification()
        
        // Start foreground timer
        startForegroundTimer()
        
        // Begin background task immediately
        beginBackgroundTask()
        
        print("✅ Session timer started - will end at: \(sessionEndTime!)")
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
        showTimerDialog = false
        timeRemaining = sessionDuration
        sessionEndTime = nil
        onSessionEnd = nil
        
        // Cancel all notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // End background task
        endBackgroundTask()
        
        print("🛑 Session timer stopped")
    }
    
    private func startForegroundTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.updateTimer()
            }
        }
    }
    
    private func updateTimer() {
        guard let endTime = sessionEndTime else { return }
        
        let now = Date()
        timeRemaining = max(0, endTime.timeIntervalSince(now))
        
        if timeRemaining <= 0 {
            executeSessionEnd()
        }
    }
    
    private func executeSessionEnd() {
        print("⏰ Timer completed - executing session end")
        
        timer?.invalidate()
        timer = nil
        
        // Execute the callback
        onSessionEnd?()
        
        // Reset state
        DispatchQueue.main.async {
            self.isTimerActive = false
            self.showTimerDialog = false
            self.timeRemaining = self.sessionDuration
            self.sessionEndTime = nil
            self.onSessionEnd = nil
        }
        
        // End background task
        endBackgroundTask()
        
        print("✅ Session ended successfully")
    }
    
    // MARK: - Notification Setup
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            } else if granted {
                print("✅ Notification permission granted")
            }
        }
    }
    
    private func scheduleGuaranteedSessionEndNotification() {
        // Clear any existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Create a time-sensitive notification that will fire exactly at session end
        let content = UNMutableNotificationContent()
        content.title = "Smart Attend - Session Ended"
        content.body = "Your 5-minute teaching session has ended automatically"
        content.sound = .defaultCritical // Use critical alert sound
        content.badge = 1
        content.categoryIdentifier = "SESSION_END"
        content.interruptionLevel = .timeSensitive
        
        // Add action buttons to the notification
        let viewAttendanceAction = UNNotificationAction(
            identifier: "VIEW_ATTENDANCE",
            title: "View Attendance",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "SESSION_END",
            actions: [viewAttendanceAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        // Schedule notification for exact session end time
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: sessionDuration, repeats: false)
        let request = UNNotificationRequest(identifier: "session_end_guaranteed", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Guaranteed session end notification scheduled")
            }
        }
        
        // Also schedule a live activity style notification for ongoing timer
        scheduleOngoingTimerNotification()
    }
    
    private func scheduleOngoingTimerNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Smart Attend - Session Active"
        content.body = "Teaching session in progress - \(timeRemainingFormatted) remaining"
        content.sound = nil // Silent
        content.badge = nil
        content.threadIdentifier = "ongoing_session"
        
        // Schedule immediately to show ongoing status
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "session_ongoing", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - App State Management
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterBackground() {
        if isTimerActive {
            print("📱 App entering background with active session")
            
            // Update ongoing notification
            updateBackgroundNotification()
            
            // Keep background task running
            beginBackgroundTask()
        }
    }
    
    @objc private func appDidBecomeActive() {
        if isTimerActive {
            print("📱 App became active - checking session status")
            
            // Check if session should have ended while in background
            if let endTime = sessionEndTime {
                let now = Date()
                let remaining = endTime.timeIntervalSince(now)
                
                if remaining <= 0 {
                    // Session should have ended
                    executeSessionEnd()
                } else {
                    // Update remaining time
                    timeRemaining = remaining
                    
                    // Restart foreground timer
                    startForegroundTimer()
                }
            }
            
            // Clear ongoing notification when app is active
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["session_ongoing"])
        }
    }
    
    private func updateBackgroundNotification() {
        guard isTimerActive else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Smart Attend - Session Active"
        content.body = "Teaching session in progress - \(timeRemainingFormatted) remaining"
        content.sound = nil
        content.badge = NSNumber(value: Int(timeRemaining / 60) + 1)
        content.threadIdentifier = "ongoing_session"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "session_ongoing", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SessionTimer") { [weak self] in
            print("⚠️ Background task expiring - ending task")
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    deinit {
        timer?.invalidate()
        endBackgroundTask()
        NotificationCenter.default.removeObserver(self)
    }
}

