//
//  AppTerminationHandler.swift
//  Smart Attend teacher iOS
//
//  Created by Ansh Bajaj on 25/06/25.
//


import Foundation
import UIKit
import UserNotifications
import BackgroundTasks

// MARK: - App Termination Handler
class AppTerminationHandler: ObservableObject {
    static let shared = AppTerminationHandler()
    
    private let userDefaults = UserDefaults.standard
    private let activeSessionKey = "active_session_data"
    private let sessionEndTimeKey = "session_end_time"
    private let appLastActiveKey = "app_last_active_time"
    
    private init() {
        setupTerminationDetection()
    }
    
    // MARK: - Session Persistence
    func saveActiveSession(_ sessionData: SessionData, endTime: Date) {
        print("💾 Saving active session to persistent storage")
        
        // Convert session data to dictionary for UserDefaults
        let sessionDict: [String: Any] = [
            "classes": sessionData.classes,
            "subject": sessionData.subject,
            "room": sessionData.room,
            "type": sessionData.type,
            "isExtra": sessionData.isExtra,
            "date": sessionData.date,
            "sessionId": sessionData.sessionId,
            "isActive": sessionData.isActive
        ]
        
        userDefaults.set(sessionDict, forKey: activeSessionKey)
        userDefaults.set(endTime.timeIntervalSince1970, forKey: sessionEndTimeKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: appLastActiveKey)
        userDefaults.synchronize() // Force immediate save
        
        // Schedule background app refresh to check for termination
        scheduleTerminationCheckTask()
        
        print("✅ Session data saved to persistent storage")
    }
    
    func clearActiveSession() {
        print("🗑️ Clearing active session from persistent storage")
        userDefaults.removeObject(forKey: activeSessionKey)
        userDefaults.removeObject(forKey: sessionEndTimeKey)
        userDefaults.removeObject(forKey: appLastActiveKey)
        userDefaults.synchronize()
    }
    
    func getActiveSession() -> (SessionData?, Date?) {
        guard let sessionDict = userDefaults.dictionary(forKey: activeSessionKey),
              let classes = sessionDict["classes"] as? [String],
              let subject = sessionDict["subject"] as? String,
              let room = sessionDict["room"] as? String,
              let type = sessionDict["type"] as? String,
              let isExtra = sessionDict["isExtra"] as? Bool,
              let date = sessionDict["date"] as? String,
              let sessionId = sessionDict["sessionId"] as? String,
              let isActive = sessionDict["isActive"] as? Bool else {
            return (nil, nil)
        }
        
        let sessionData = SessionData(
            classes: classes,
            subject: subject,
            room: room,
            type: type,
            isExtra: isExtra,
            date: date,
            sessionId: sessionId,
            isActive: isActive
        )
        
        let endTimeInterval = userDefaults.double(forKey: sessionEndTimeKey)
        let endTime = endTimeInterval > 0 ? Date(timeIntervalSince1970: endTimeInterval) : nil
        
        return (sessionData, endTime)
    }
    
    // MARK: - Termination Detection
    private func setupTerminationDetection() {
        // Listen for app termination signals
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // Listen for app entering background (potential kill state)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Listen for app becoming active (to check for kills)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appWillTerminate() {
        print("🚨 App is terminating - attempting emergency session end")
        handleEmergencySessionEnd()
    }
    
    @objc private func appDidEnterBackground() {
        print("📱 App entered background - updating last active time")
        userDefaults.set(Date().timeIntervalSince1970, forKey: appLastActiveKey)
        userDefaults.synchronize()
        
        // Schedule immediate background task to end session if timer expires
        scheduleImmediateSessionCheck()
    }
    
    @objc private func appDidBecomeActive() {
        print("📱 App became active - checking for potential app kill")
        checkForAppKillAndRecovery()
    }
    
    // MARK: - Emergency Session End
    private func handleEmergencySessionEnd() {
        let (sessionData, endTime) = getActiveSession()
        
        guard let sessionData = sessionData else {
            print("ℹ️ No active session to end")
            return
        }
        
        print("🔥 Emergency session end for: \(sessionData.sessionId)")
        
        // Use synchronous Firebase call in termination
        Task {
            await endSessionSynchronously(sessionData)
        }
        
        // Clear the session immediately
        clearActiveSession()
        
        // Schedule critical notification
        scheduleEmergencyNotification()
    }
    
    private func endSessionSynchronously(_ sessionData: SessionData) async {
        let firebaseManager = FirebaseManager()
        
        // Multiple rapid attempts with shorter timeouts
        for attempt in 1...5 {
            print("🔄 Emergency Firebase attempt \(attempt)/5")
            
            let success = await firebaseManager.endSession(sessionData)
            
            if success {
                print("✅ Emergency Firebase update successful")
                
                // Send success notification
                scheduleSuccessNotification()
                return
            } else {
                print("❌ Emergency Firebase attempt \(attempt) failed")
                
                // Very short delay between attempts
                if attempt < 5 {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
            }
        }
        
        print("💥 All emergency Firebase attempts failed")
        scheduleFailureNotification()
    }
    
    // MARK: - Background Tasks for Kill Detection
    private func scheduleTerminationCheckTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.humblecoders.smartattend.termination-check")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // Check in 30 seconds
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Termination check task scheduled")
        } catch {
            print("❌ Failed to schedule termination check: \(error)")
        }
    }
    
    private func scheduleImmediateSessionCheck() {
        let (sessionData, endTime) = getActiveSession()
        
        guard let sessionData = sessionData, let endTime = endTime else { return }
        
        let timeUntilEnd = endTime.timeIntervalSince(Date())
        
        if timeUntilEnd <= 0 {
            // Session should end now
            print("⏰ Session expired while in background - ending immediately")
            
            Task {
                await endSessionSynchronously(sessionData)
                await MainActor.run {
                    clearActiveSession()
                }
            }
        } else {
            // Schedule notification for exact end time
            scheduleExactEndNotification(in: timeUntilEnd, for: sessionData)
        }
    }
    
    // MARK: - Kill Detection and Recovery
    private func checkForAppKillAndRecovery() {
        let (sessionData, endTime) = getActiveSession()
        
        guard let sessionData = sessionData, let endTime = endTime else {
            print("ℹ️ No active session found on app resume")
            return
        }
        
        let lastActiveTime = Date(timeIntervalSince1970: userDefaults.double(forKey: appLastActiveKey))
        let timeSinceLastActive = Date().timeIntervalSince(lastActiveTime)
        
        print("🔍 App was inactive for: \(timeSinceLastActive) seconds")
        
        // Check if session should have ended while app was killed
        let now = Date()
        let sessionShouldHaveEnded = now >= endTime
        
        if sessionShouldHaveEnded {
            print("🚨 Session should have ended while app was killed - ending now")
            
            Task {
                await endSessionSynchronously(sessionData)
                await MainActor.run {
                    clearActiveSession()
                    
                    // Notify user about missed session end
                    scheduleRecoveryNotification()
                }
            }
        } else {
            print("✅ Session is still valid - continuing normally")
        }
    }
    
    // MARK: - Notification Helpers
    private func scheduleEmergencyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Smart Attend - Emergency Session End"
        content.body = "App was closed during active session. Attempting to update Firebase..."
        content.sound = .defaultCritical
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "emergency_session_end", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleSuccessNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Smart Attend - Session Ended Successfully"
        content.body = "Your session was ended successfully despite app closure"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: "emergency_success", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleFailureNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Smart Attend - Manual Check Required"
        content.body = "App was closed during session. Please check Firebase manually to ensure session was ended."
        content.sound = .defaultCritical
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2.0, repeats: false)
        let request = UNNotificationRequest(identifier: "emergency_failure", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleRecoveryNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Smart Attend - Session Recovered"
        content.body = "Your session was ended after app recovery. Firebase has been updated."
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: "session_recovery", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleExactEndNotification(in timeInterval: TimeInterval, for sessionData: SessionData) {
        let content = UNMutableNotificationContent()
        content.title = "Smart Attend - Session Auto-Ended"
        content.body = "Your teaching session has ended automatically while app was in background"
        content.sound = .defaultCritical
        content.badge = 1
        content.userInfo = [
            "sessionId": sessionData.sessionId,
            "autoEnd": true
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "auto_end_\(sessionData.sessionId)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}