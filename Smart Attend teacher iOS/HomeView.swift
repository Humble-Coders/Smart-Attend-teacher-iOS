import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firebaseManager = FirebaseManager()
    @StateObject private var keychainManager = KeychainManager()
    
    @State private var selectedClasses: [String] = []
    @State private var selectedSubject = ""
    @State private var selectedRoom = ""
    @State private var selectedType = "lect"
    @State private var isExtraClass = false
    @State private var isSessionActive = false
    @State private var currentSessionData: SessionData?
    @State private var availableRooms: [String] = []
    @State private var roomSearchText = ""
    @State private var showRoomDropdown = false
    @State private var showAttendance = false
    @State private var attendanceList: [String] = []
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showEndSessionConfirm = false
    @State private var showAddSubjectDialog = false
    @State private var showAddClassDialog = false
    @State private var newSubjectText = ""
    @State private var newClassText = ""
    
    private let sessionTypes = [
        ("lect", "Lecture"),
        ("lab", "Lab"),
        ("tut", "Tutorial")
    ]
    
    var filteredRooms: [String] {
        if roomSearchText.isEmpty {
            return availableRooms
        }
        return availableRooms.filter { $0.localizedCaseInsensitiveContains(roomSearchText) }
    }
    
    var canActivateSession: Bool {
        !selectedClasses.isEmpty && !selectedSubject.isEmpty && !selectedRoom.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.36, green: 0.72, blue: 1.0), Color(red: 0.58, green: 0.65, blue: 1.0)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Welcome, \(authManager.teacherData?.designation ?? "") \(authManager.teacherData?.name ?? "")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Manage your attendance sessions")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 20) {
                            // Classes Selection
                            SessionCard(title: "Select Classes") {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Choose the classes you're teaching:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(authManager.teacherData?.classes ?? [], id: \.self) { className in
                                        HStack {
                                            Button(action: {
                                                if selectedClasses.contains(className) {
                                                    selectedClasses.removeAll { $0 == className }
                                                } else {
                                                    selectedClasses.append(className)
                                                }
                                            }) {
                                                HStack {
                                                    Image(systemName: selectedClasses.contains(className) ? "checkmark.square.fill" : "square")
                                                        .foregroundColor(selectedClasses.contains(className) ? Color(red: 0.36, green: 0.72, blue: 1.0) : .secondary)
                                                    
                                                    Text(className)
                                                        .foregroundColor(.primary)
                                                    
                                                    Spacer()
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                            
                            // Subject Selection
                            SessionCard(title: "Select Subject") {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Choose the subject:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 8) {
                                        Menu {
                                            ForEach(authManager.teacherData?.subjects ?? [], id: \.self) { subject in
                                                Button(subject) {
                                                    selectedSubject = subject
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(selectedSubject.isEmpty ? "Select Subject" : selectedSubject)
                                                    .foregroundColor(selectedSubject.isEmpty ? .secondary : .primary)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        
                                        Button(action: {
                                            showAddSubjectDialog = true
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(Color(red: 0.36, green: 0.72, blue: 1.0))
                                                .font(.title2)
                                        }
                                    }
                                }
                            }
                            
                            // Room Selection
                            SessionCard(title: "Select Room") {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Choose the room:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    VStack(spacing: 0) {
                                        HStack(spacing: 8) {
                                            TextField("Search room...", text: $roomSearchText)
                                                .onChange(of: roomSearchText) { _ in
                                                    showRoomDropdown = !roomSearchText.isEmpty
                                                }
                                                .onTapGesture {
                                                    showRoomDropdown = true
                                                }
                                                .onSubmit {
                                                    hideKeyboard()
                                                }
                                                .padding()
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(8)
                                            
                                            Button(action: {
                                                // Room addition can be handled by admin/backend
                                                alertMessage = "Contact admin to add new rooms"
                                                showAlert = true
                                            }) {
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(Color.gray.opacity(0.6))
                                                    .font(.title2)
                                            }
                                        }
                                        
                                        if showRoomDropdown && !filteredRooms.isEmpty {
                                            ScrollView {
                                                LazyVStack(spacing: 0) {
                                                    ForEach(filteredRooms, id: \.self) { room in
                                                        Button(action: {
                                                            selectedRoom = room
                                                            roomSearchText = room
                                                            showRoomDropdown = false
                                                            hideKeyboard()
                                                        }) {
                                                            HStack {
                                                                Text(room)
                                                                    .foregroundColor(.primary)
                                                                Spacer()
                                                            }
                                                            .padding()
                                                            .background(Color.white)
                                                        }
                                                        .buttonStyle(PlainButtonStyle())
                                                        
                                                        if room != filteredRooms.last {
                                                            Divider()
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(maxHeight: 150)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .shadow(radius: 2)
                                        }
                                    }
                                }
                            }
                            
                            // Session Type
                            SessionCard(title: "Session Type") {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Select session type:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 12) {
                                        ForEach(sessionTypes, id: \.0) { type, label in
                                            Button(action: {
                                                selectedType = type
                                            }) {
                                                Text(label)
                                                    .font(.caption)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(selectedType == type ? Color(red: 0.36, green: 0.72, blue: 1.0) : Color.gray.opacity(0.2))
                                                    .foregroundColor(selectedType == type ? .white : .primary)
                                                    .cornerRadius(20)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    
                                    HStack {
                                        Button(action: {
                                            isExtraClass.toggle()
                                        }) {
                                            HStack {
                                                Image(systemName: isExtraClass ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(isExtraClass ? Color(red: 0.36, green: 0.72, blue: 1.0) : .secondary)
                                                
                                                Text("Extra Class")
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Spacer()
                                    }
                                }
                            }
                            
                            // Action Buttons
                            if !isSessionActive {
                                Button(action: activateSession) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "play.circle.fill")
                                            Text("Activate Session")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(canActivateSession ? Color.green : Color.gray)
                                    .cornerRadius(12)
                                }
                                .disabled(!canActivateSession || isLoading)
                            } else {
                                HStack(spacing: 12) {
                                    Button(action: restartSession) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Restart")
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                    }
                                    
                                    Button(action: {
                                        showEndSessionConfirm = true
                                    }) {
                                        HStack {
                                            Image(systemName: "stop.circle.fill")
                                            Text("End Session")
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Smart Attend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        authManager.logout()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadRooms()
        }
        .confirmationDialog("End Session", isPresented: $showEndSessionConfirm) {
            Button("End Session", role: .destructive) {
                endSession()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to end the session?")
        }
        .alert("Session Ended", isPresented: $showAlert) {
            if alertMessage.contains("ended successfully") {
                Button("Show Attendance") {
                    showAttendance = true
                }
                Button("OK") { }
            } else {
                Button("OK") { }
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Add New Subject", isPresented: $showAddSubjectDialog) {
            TextField("Subject name", text: $newSubjectText)
            Button("Add") {
                addNewSubject()
            }
            Button("Cancel", role: .cancel) {
                newSubjectText = ""
            }
        }
        .fullScreenCover(isPresented: $showAttendance) {
            AttendanceView(sessionData: currentSessionData)
        }
    }
    
    private func loadRooms() {
        // Load cached rooms first
        availableRooms = keychainManager.getCachedRooms()
        
        // Fetch fresh data from Firebase
        Task {
            let rooms = await firebaseManager.fetchRooms()
            await MainActor.run {
                availableRooms = rooms
                keychainManager.saveCachedRooms(rooms)
            }
        }
    }
    
    private func activateSession() {
        guard canActivateSession else { return }
        
        isLoading = true
        
        let sessionId = UUID().uuidString
        let currentDate = getCurrentDate()
        
        let sessionData = SessionData(
            classes: selectedClasses,
            subject: selectedSubject,
            room: selectedRoom,
            type: selectedType,
            isExtra: isExtraClass,
            date: currentDate,
            sessionId: sessionId,
            isActive: true
        )
        
        Task {
            let success = await firebaseManager.activateSession(sessionData)
            
            await MainActor.run {
                isLoading = false
                if success {
                    isSessionActive = true
                    currentSessionData = sessionData
                    alertMessage = "Session activated successfully!"
                } else {
                    alertMessage = "Failed to activate session. Please try again."
                }
                showAlert = true
            }
        }
    }
    
    private func restartSession() {
        guard let sessionData = currentSessionData else { return }
        
        // Check if session is already active
        alertMessage = "Session is already active for the selected classes."
        showAlert = true
    }
    
    private func endSession() {
        guard let sessionData = currentSessionData else { return }
        
        Task {
            let success = await firebaseManager.endSession(sessionData)
            
            await MainActor.run {
                if success {
                    isSessionActive = false
                    // Keep currentSessionData for potential attendance viewing
                    resetForm()
                    alertMessage = "Session ended successfully!"
                } else {
                    alertMessage = "Failed to end session. Please try again."
                }
                showAlert = true
            }
        }
    }
    
    private func addNewSubject() {
        guard !newSubjectText.isEmpty else { return }
        
        if var teacherData = authManager.teacherData {
            var updatedSubjects = teacherData.subjects
            if !updatedSubjects.contains(newSubjectText) {
                updatedSubjects.append(newSubjectText)
                let updatedTeacherData = TeacherData(
                    name: teacherData.name,
                    designation: teacherData.designation,
                    subjects: updatedSubjects,
                    classes: teacherData.classes
                )
                authManager.login(teacherData: updatedTeacherData)
            }
        }
        newSubjectText = ""
    }
    
    private func resetForm() {
        selectedClasses = []
        selectedSubject = ""
        selectedRoom = ""
        roomSearchText = ""
        selectedType = "lect"
        isExtraClass = false
        // Don't reset currentSessionData here - keep it for attendance viewing
    }
    
    private func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct SessionCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color.white.opacity(0.95))
            .cornerRadius(12)
        }
    }
}
