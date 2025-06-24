//
//  Smart_Attend_teacher_iOSApp.swift
//  Smart Attend teacher iOS
//
//  Created by Ansh Bajaj on 16/06/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct TeacherApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var sessionManager = SessionManager()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(sessionManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    sessionManager.endActiveSession()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    sessionManager.endActiveSession()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    sessionManager.endActiveSession()
                }
        }
    }
}
