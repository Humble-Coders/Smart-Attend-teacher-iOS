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
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
