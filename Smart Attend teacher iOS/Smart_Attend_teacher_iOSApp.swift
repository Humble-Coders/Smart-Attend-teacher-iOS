import SwiftUI
import FirebaseCore
import FirebaseFirestore
import BackgroundTasks

@main
struct TeacherApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var sessionManager = SessionManager()
    
    init() {
        FirebaseApp.configure()
        
        // Register background tasks BEFORE app finishes launching
        registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(sessionManager)
        }
    }
    
    private func registerBackgroundTasks() {
        // Register the background task handler early
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.humblecoders.smartattend.session-timer",
            using: nil
        ) { task in
            handleBackgroundSessionTimer(task as! BGProcessingTask)
        }
    }
    
    private func handleBackgroundSessionTimer(_ task: BGProcessingTask) {
        print("🔄 Background task executing from app level")
        
        // Set expiration handler
        task.expirationHandler = {
            print("⚠️ Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Check if we need to end any active sessions
        // This is a backup mechanism - the SessionTimerManager handles the primary logic
        
        // For now, just complete the task
        // The actual session ending logic is handled by SessionTimerManager
        task.setTaskCompleted(success: true)
    }
}
