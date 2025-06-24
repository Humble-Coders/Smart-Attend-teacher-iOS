import SwiftUI
import Security
import FirebaseCore
import FirebaseFirestore


struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showSplash = true
    
    var body: some View {
        Group {
            if showSplash {
                SplashScreenView()
                    .onAppear {
                        // Hide splash after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                if authManager.isLoggedIn {
                    HomeView()
                        .environmentObject(authManager)
                        .environmentObject(sessionManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
    }
}


// MARK: - Auth Manager
class AuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var teacherData: TeacherData?
    
    private let keychain = KeychainManager()
    
    init() {
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        if let data = keychain.getTeacherData() {
            self.teacherData = data
            self.isLoggedIn = true
        }
    }
    
    func login(teacherData: TeacherData) {
        keychain.saveTeacherData(teacherData)
        self.teacherData = teacherData
        self.isLoggedIn = true
    }
    
    func logout() {
        keychain.deleteTeacherData()
        self.teacherData = nil
        self.isLoggedIn = false
    }
}

// MARK: - Session Manager
class SessionManager: ObservableObject {
    @Published var isSessionActive = false
    @Published var currentSessionData: SessionData?
    
    private let firebaseManager = FirebaseManager()
    
    func startSession(_ sessionData: SessionData) {
        self.currentSessionData = sessionData
        self.isSessionActive = true
    }
    
    func endActiveSession() {
        guard let sessionData = currentSessionData, isSessionActive else { return }
        
        print("📱 App minimized/closed - ending active session")
        
        Task {
            let success = await firebaseManager.endSession(sessionData)
            
            await MainActor.run {
                if success {
                    print("✅ Session ended successfully due to app state change")
                } else {
                    print("❌ Failed to end session due to app state change")
                }
                
                // Reset session state completely when app is closed
                self.isSessionActive = false
                self.currentSessionData = nil
            }
        }
    }
    
    func manualEndSession() async -> Bool {
        guard let sessionData = currentSessionData, isSessionActive else { return false }
        
        let success = await firebaseManager.endSession(sessionData)
        
        if success {
            await MainActor.run {
                self.isSessionActive = false
                // Keep currentSessionData for potential attendance viewing
            }
        }
        
        return success
    }
}

// MARK: - Data Models
struct TeacherData: Codable {
    let name: String
    let designation: String
    let subjects: [String]
    let classes: [String]
}

struct SessionData {
    let classes: [String]
    let subject: String
    let room: String
    let type: String // "lect", "lab", "tut"
    let isExtra: Bool
    let date: String
    let sessionId: String
    let isActive: Bool
}

struct AttendanceRecord {
    let rollNumber: String
    let group: String
    let timestamp: String
}

// MARK: - Keychain Manager
class KeychainManager: ObservableObject {
    private let teacherDataKey = "TeacherData"
    private let roomsKey = "CachedRooms"
    
    func saveTeacherData(_ data: TeacherData) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(data) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: teacherDataKey,
                kSecValueData as String: encoded
            ]
            
            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
        }
    }
    
    func getTeacherData() -> TeacherData? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: teacherDataKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                let decoder = JSONDecoder()
                return try? decoder.decode(TeacherData.self, from: data)
            }
        }
        return nil
    }
    
    func deleteTeacherData() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: teacherDataKey
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    func saveCachedRooms(_ rooms: [String]) {
        UserDefaults.standard.set(rooms, forKey: roomsKey)
    }
    
    func getCachedRooms() -> [String] {
        return UserDefaults.standard.stringArray(forKey: roomsKey) ?? []
    }
}

// MARK: - Firebase Manager
class FirebaseManager: ObservableObject {
    private let db = Firestore.firestore()
    
    func fetchSubjects() async -> [String] {
        do {
            let document = try await db.collection("subjects_list").document("subjects_list").getDocument()
            return document.data()?["subjects_list"] as? [String] ?? []
        } catch {
            print("Error fetching subjects: \(error)")
            return []
        }
    }
    
    func fetchClasses() async -> [String] {
        do {
            let document = try await db.collection("classes").document("classes_list").getDocument()
            return document.data()?["classes_list"] as? [String] ?? []
        } catch {
            print("Error fetching classes: \(error)")
            return []
        }
    }
    
    func fetchRooms() async -> [String] {
        do {
            let document = try await db.collection("rooms").document("rooms_list").getDocument()
            return document.data()?["rooms_list"] as? [String] ?? []
        } catch {
            print("Error fetching rooms: \(error)")
            return []
        }
    }
    
    func activateSession(_ sessionData: SessionData) async -> Bool {
        do {
            // First, activate the session in activeSessions
            for className in sessionData.classes {
                let sessionRef = db.collection("activeSessions").document(className)
                let data: [String: Any] = [
                    "date": sessionData.date,
                    "isActive": true,
                    "isExtra": sessionData.isExtra,
                    "room": sessionData.room,
                    "sessionId": sessionData.sessionId,
                    "subject": sessionData.subject,
                    "type": sessionData.type
                ]
                try await sessionRef.setData(data)
            }

            // Then increment the subject counters
            let subjectRef = db.collection("subjects").document(sessionData.subject)
            
            for className in sessionData.classes {
                let subjectDoc = try await subjectRef.getDocument()
                
                if subjectDoc.exists {
                    // Get existing data for this class
                    let existingData = subjectDoc.data() ?? [:]
                    var classData = existingData[className] as? [String: Int] ?? [:]

                    // Initialize missing fields with 0
                    if classData["lect"] == nil { classData["lect"] = 0 }
                    if classData["lab"] == nil { classData["lab"] = 0 }
                    if classData["tut"] == nil { classData["tut"] = 0 }

                    // Increment the specific type when session STARTS
                    classData[sessionData.type] = (classData[sessionData.type] ?? 0) + 1

                    // Update only this class data in the document
                    try await subjectRef.updateData([className: classData])
                } else {
                    // Create new document with proper structure for this class only
                    let newClassData: [String: Int] = [
                        "lect": sessionData.type == "lect" ? 1 : 0,
                        "lab": sessionData.type == "lab" ? 1 : 0,
                        "tut": sessionData.type == "tut" ? 1 : 0
                    ]

                    // Use merge to avoid overwriting other classes that might exist
                    try await subjectRef.setData([className: newClassData], merge: true)
                }
            }

            return true
        } catch {
            print("Error activating session: \(error)")
            return false
        }
    }
    
    func endSession(_ sessionData: SessionData) async -> Bool {
        do {
            // Only end session in activeSessions - NO counter incrementing here
            for className in sessionData.classes {
                let sessionRef = db.collection("activeSessions").document(className)
                try await sessionRef.updateData(["isActive": false])
            }
            
            return true
        } catch {
            print("Error ending session: \(error)")
            return false
        }
    }
    
    func fetchAttendance(for sessionData: SessionData) async -> [AttendanceRecord] {
        do {
            let currentDate = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy_MM"
            let collectionName = "attendance_\(formatter.string(from: currentDate))"
            
            print("🔍 Searching in collection: \(collectionName)")
            print("📅 Session date: \(sessionData.date)")
            print("📚 Subject: \(sessionData.subject)")
            print("🏢 Room: \(sessionData.room)")
            print("📝 Type: \(sessionData.type)")
            print("👥 Classes: \(sessionData.classes)")
            print("➕ IsExtra: \(sessionData.isExtra)")
            
            var attendanceRecords: [AttendanceRecord] = []
            
            // Search for each class/group
            for className in sessionData.classes {
                print("🔍 Searching for class: \(className)")
                
                // Query with present=true (boolean, not number)
                let querySnapshot = try await db.collection(collectionName)
                    .whereField("present", isEqualTo: true)
                    .getDocuments()
                
                print("✅ Found \(querySnapshot.documents.count) documents with present=true")
                
                for doc in querySnapshot.documents {
                    let data = doc.data()
                    print("📊 Processing document: \(doc.documentID)")
                    print("📊 Document data: \(data)")
                    
                    // Handle Firebase data types properly
                    if let rollNumberValue = data["rollNumber"], // Can be Int or String
                       let group = data["group"] as? String,
                       let timestamp = data["timestamp"] as? Timestamp, // Firebase Timestamp
                       let docDate = data["date"] as? String,
                       let docSubject = data["subject"] as? String,
                       let docType = data["type"] as? String,
                       let docIsExtraValue = data["isExtra"] { // Can be Int or Bool
                        
                        // Convert rollNumber to String regardless of type
                        let rollNumber: String
                        if let intValue = rollNumberValue as? Int {
                            rollNumber = String(intValue)
                        } else if let stringValue = rollNumberValue as? String {
                            rollNumber = stringValue
                        } else {
                            print("⚠️ Could not convert rollNumber: \(rollNumberValue)")
                            continue
                        }
                        
                        // Convert isExtra to Bool regardless of type
                        let docIsExtra: Bool
                        if let boolValue = docIsExtraValue as? Bool {
                            docIsExtra = boolValue
                        } else if let intValue = docIsExtraValue as? Int {
                            docIsExtra = intValue == 1
                        } else {
                            print("⚠️ Could not convert isExtra: \(docIsExtraValue)")
                            continue
                        }
                        
                        // Handle deviceRoom (can be empty string)
                        let deviceRoom = data["deviceRoom"] as? String ?? ""
                        
                        let timestampString = formatFirebaseTimestamp(timestamp)
                        
                        print("🔍 Checking document for \(rollNumber):")
                        print("   📅 Date match: '\(docDate)' == '\(sessionData.date)' ? \(docDate == sessionData.date)")
                        print("   📚 Subject match: '\(docSubject)' == '\(sessionData.subject)' ? \(docSubject == sessionData.subject)")
                        print("   📝 Type match: '\(docType)' == '\(sessionData.type)' ? \(docType == sessionData.type)")
                        print("   👥 Group match: '\(group)' == '\(className)' ? \(group == className)")
                        print("   🏢 DeviceRoom: '\(deviceRoom)' (empty: \(deviceRoom.isEmpty))")
                        print("   🏢 Room check: '\(deviceRoom)' starts with '\(sessionData.room)' ? \(deviceRoom.hasPrefix(sessionData.room))")
                        print("   ➕ Extra match: \(docIsExtra) == \(sessionData.isExtra) ? \(docIsExtra == sessionData.isExtra)")
                        
                        // Check all conditions manually
                        let dateMatch = docDate == sessionData.date
                        let subjectMatch = docSubject == sessionData.subject
                        let typeMatch = docType == sessionData.type
                        let groupMatch = group == className
                        let extraMatch = docIsExtra == sessionData.isExtra
                        let roomMatch = !deviceRoom.isEmpty && deviceRoom.hasPrefix(sessionData.room)
                        
                        print("   🎯 All checks: date=\(dateMatch), subject=\(subjectMatch), type=\(typeMatch), group=\(groupMatch), extra=\(extraMatch), room=\(roomMatch)")
                        
                        if dateMatch && subjectMatch && typeMatch && groupMatch && extraMatch && roomMatch {
                            print("✅ Adding attendance record for: \(rollNumber)")
                            attendanceRecords.append(AttendanceRecord(
                                rollNumber: rollNumber,
                                group: group,
                                timestamp: timestampString
                            ))
                        } else {
                            print("❌ Document doesn't match all criteria")
                        }
                    } else {
                        print("⚠️ Document missing required fields")
                        print("   Available fields: \(data.keys)")
                        if let rollNumber = data["rollNumber"] {
                            print("   rollNumber type: \(type(of: rollNumber)) value: \(rollNumber)")
                        }
                        if let timestamp = data["timestamp"] {
                            print("   timestamp type: \(type(of: timestamp)) value: \(timestamp)")
                        }
                        if let isExtra = data["isExtra"] {
                            print("   isExtra type: \(type(of: isExtra)) value: \(isExtra)")
                        }
                    }
                }
            }
            
            print("📊 Total attendance records found: \(attendanceRecords.count)")
            return attendanceRecords.sorted { $0.rollNumber < $1.rollNumber }
            
        } catch {
            print("❌ Error fetching attendance: \(error)")
            return []
        }
    }
    
    private func formatFirebaseTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a zzz"
        return formatter.string(from: date)
    }
}
