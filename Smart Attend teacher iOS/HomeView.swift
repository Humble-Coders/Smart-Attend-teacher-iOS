import SwiftUI

struct HomeView: View {
   @EnvironmentObject var authManager: AuthManager
   @EnvironmentObject var sessionManager: SessionManager
   @StateObject private var firebaseManager = FirebaseManager()
   @StateObject private var keychainManager = KeychainManager()
   
   @State private var selectedClasses: [String] = []
   @State private var selectedSubject = ""
   @State private var selectedRoom = ""
   @State private var selectedType = "lect"
   @State private var isExtraClass = false
   @State private var availableRooms: [String] = []
   @State private var roomSearchText = ""
   @State private var showRoomDropdown = false
   @State private var showAttendance = false
   @State private var isLoading = false
   @State private var showAlert = false
   @State private var alertMessage = ""
   @State private var showEndSessionConfirm = false
   @State private var showAddSubjectDialog = false
   @State private var showAddClassDialog = false
   @State private var availableSubjectsForAdding: [String] = []
   @State private var availableClassesForAdding: [String] = []
   @State private var showSubjectSelectionSheet = false
   @State private var showClassSelectionSheet = false
   @State private var showLogoutConfirm = false
   
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
                       // Enhanced Header
                       // Enhanced Header with Teacher Card Only
                       VStack(spacing: 20) {
                          // Professional Teacher Greeting Card
                          VStack(spacing: 12) {
                              HStack {
                                  VStack(alignment: .leading, spacing: 8) {
                                      Text("Welcome back,")
                                          .font(.subheadline)
                                          .foregroundColor(.white.opacity(0.9))
                                      
                                      Text("\(authManager.teacherData?.designation ?? "") \(authManager.teacherData?.name ?? "")")
                                          .font(.title2)
                                          .fontWeight(.semibold)
                                          .foregroundColor(.white)
                                  }
                                  
                                  Spacer()
                                  
                                  // Professional Avatar/Icon
                                  Circle()
                                      .fill(Color.white.opacity(0.2))
                                      .frame(width: 50, height: 50)
                                      .overlay(
                                          Image(systemName: "person.fill")
                                              .font(.title2)
                                              .foregroundColor(.white)
                                      )
                              }
                              
                              // Status and Logout Section
                              HStack {
                                  HStack(spacing: 6) {
                                      Circle()
                                          .fill(sessionManager.isSessionActive ? Color.green : Color.orange)
                                          .frame(width: 8, height: 8)
                                      
                                      Text(sessionManager.isSessionActive ? "Session Active" : "Ready to start session")
                                          .font(.caption)
                                          .foregroundColor(.white.opacity(0.9))
                                  }
                                  
                                  Spacer()
                                  
                                  // Professional Logout Button
                                  Button(action: {
                                      showLogoutConfirm = true
                                  }) {
                                      HStack(spacing: 6) {
                                          Text("Logout")
                                              .font(.system(size: 14, weight: .medium))
                                          Image(systemName: "rectangle.portrait.and.arrow.right")
                                              .font(.system(size: 14, weight: .medium))
                                      }
                                      .foregroundColor(.white)
                                      .padding(.horizontal, 16)
                                      .padding(.vertical, 8)
                                      .background(Color.white.opacity(0.2))
                                      .cornerRadius(20)
                                      .overlay(
                                          RoundedRectangle(cornerRadius: 20)
                                              .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                      )
                                  }
                              }
                          }
                          .padding(20)
                          .background(
                              RoundedRectangle(cornerRadius: 16)
                                  .fill(Color.white.opacity(0.15))
                                  .overlay(
                                      RoundedRectangle(cornerRadius: 16)
                                          .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                  )
                          )
                          .padding(.horizontal, 20)
                       }
                       .padding(.top, 20)
                       
                       VStack(spacing: 20) {
                           // Classes Selection
                           SessionCard(title: "Select Classes") {
                               VStack(alignment: .leading, spacing: 12) {
                                   HStack {
                                       Text("Choose the classes you're teaching:")
                                           .font(.caption)
                                           .foregroundColor(.secondary)
                                       
                                       Spacer()
                                       
                                       Button(action: {
                                           loadAvailableClasses()
                                           showClassSelectionSheet = true
                                       }) {
                                           Image(systemName: "plus.circle.fill")
                                               .foregroundColor(Color(red: 0.36, green: 0.72, blue: 1.0))
                                               .font(.title2)
                                       }
                                   }
                                   
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
                                           loadAvailableSubjects()
                                           showSubjectSelectionSheet = true
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
                           if !sessionManager.isSessionActive {
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
           .navigationBarHidden(true)
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
       .alert(alertMessage.contains("ended successfully") ? "Session Ended" : "Smart Attend", isPresented: $showAlert) {
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
       .sheet(isPresented: $showSubjectSelectionSheet) {
           SubjectSelectionSheet(
               availableSubjects: availableSubjectsForAdding,
               onSubjectSelected: addSubjectToTeacher
           )
       }
       .sheet(isPresented: $showClassSelectionSheet) {
           ClassSelectionSheet(
               availableClasses: availableClassesForAdding,
               onClassSelected: addClassToTeacher
           )
       }
       .fullScreenCover(isPresented: $showAttendance) {
           AttendanceView(sessionData: sessionManager.currentSessionData)
       }
       .confirmationDialog("Logout", isPresented: $showLogoutConfirm) {
           Button("Logout", role: .destructive) {
               authManager.logout()
           }
           Button("Cancel", role: .cancel) { }
       } message: {
           Text("Are you sure you want to logout?")
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
                   sessionManager.startSession(sessionData)
                   alertMessage = "Session activated successfully!"
               } else {
                   alertMessage = "Failed to activate session. Please try again."
               }
               showAlert = true
           }
       }
   }
   
   private func restartSession() {
       // For restart, we don't actually restart anything since session is already active
       alertMessage = "Session is already active for the selected classes."
       showAlert = true
   }
   
   private func endSession() {
       Task {
           let success = await sessionManager.manualEndSession()
           
           await MainActor.run {
               if success {
                   resetForm()
                   alertMessage = "Session ended successfully!"
               } else {
                   alertMessage = "Failed to end session. Please try again."
               }
               showAlert = true
           }
       }
   }
   
   private func loadAvailableSubjects() {
       Task {
           let allSubjects = await firebaseManager.fetchSubjects()
           let teacherSubjects = authManager.teacherData?.subjects ?? []
           
           await MainActor.run {
               // Show only subjects that teacher doesn't already have
               availableSubjectsForAdding = allSubjects.filter { !teacherSubjects.contains($0) }
           }
       }
   }
   
   private func loadAvailableClasses() {
       Task {
           let allClasses = await firebaseManager.fetchClasses()
           let teacherClasses = authManager.teacherData?.classes ?? []
           
           await MainActor.run {
               // Show only classes that teacher doesn't already have
               availableClassesForAdding = allClasses.filter { !teacherClasses.contains($0) }
           }
       }
   }
   
   private func addSubjectToTeacher(_ subject: String) {
       guard let teacherData = authManager.teacherData else { return }
       
       var updatedSubjects = teacherData.subjects
       if !updatedSubjects.contains(subject) {
           updatedSubjects.append(subject)
           let updatedTeacherData = TeacherData(
               name: teacherData.name,
               designation: teacherData.designation,
               subjects: updatedSubjects,
               classes: teacherData.classes
           )
           authManager.login(teacherData: updatedTeacherData)
           
           // Update available list
           availableSubjectsForAdding.removeAll { $0 == subject }
       }
   }
   
   private func addClassToTeacher(_ className: String) {
       guard let teacherData = authManager.teacherData else { return }
       
       var updatedClasses = teacherData.classes
       if !updatedClasses.contains(className) {
           updatedClasses.append(className)
           let updatedTeacherData = TeacherData(
               name: teacherData.name,
               designation: teacherData.designation,
               subjects: teacherData.subjects,
               classes: updatedClasses
           )
           authManager.login(teacherData: updatedTeacherData)
           
           // Update available list
           availableClassesForAdding.removeAll { $0 == className }
       }
   }
   
   private func resetForm() {
       selectedClasses = []
       selectedSubject = ""
       selectedRoom = ""
       roomSearchText = ""
       selectedType = "lect"
       isExtraClass = false
       // Don't reset sessionManager data here - it manages its own state
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

struct SubjectSelectionSheet: View {
   let availableSubjects: [String]
   let onSubjectSelected: (String) -> Void
   @Environment(\.dismiss) private var dismiss
   
   @State private var searchText = ""
   
   var filteredSubjects: [String] {
       if searchText.isEmpty {
           return availableSubjects
       }
       return availableSubjects.filter { $0.localizedCaseInsensitiveContains(searchText) }
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
               
               VStack(spacing: 20) {
                   VStack(spacing: 8) {
                       Text("Add Subject")
                           .font(.title2)
                           .fontWeight(.bold)
                           .foregroundColor(.white)
                       
                       Text("Select subjects from the master list to add to your teaching profile")
                           .font(.subheadline)
                           .foregroundColor(.white.opacity(0.9))
                           .multilineTextAlignment(.center)
                   }
                   .padding(.top, 20)
                   
                   VStack(spacing: 12) {
                       // Search Bar
                       TextField("Search subjects...", text: $searchText)
                           .padding()
                           .background(Color.white.opacity(0.9))
                           .cornerRadius(12)
                           .onSubmit {
                               hideKeyboard()
                           }
                       
                       // Subjects List
                       if filteredSubjects.isEmpty {
                           VStack(spacing: 16) {
                               Image(systemName: "book.closed")
                                   .font(.system(size: 40))
                                   .foregroundColor(.white.opacity(0.6))
                               
                               Text(searchText.isEmpty ? "All subjects already added" : "No subjects found")
                                   .font(.subheadline)
                                   .foregroundColor(.white.opacity(0.8))
                           }
                           .frame(maxWidth: .infinity)
                           .padding(40)
                           .background(Color.white.opacity(0.1))
                           .cornerRadius(12)
                       } else {
                           ScrollView {
                               LazyVStack(spacing: 8) {
                                   ForEach(filteredSubjects, id: \.self) { subject in
                                       Button(action: {
                                           onSubjectSelected(subject)
                                           dismiss()
                                       }) {
                                           HStack {
                                               VStack(alignment: .leading, spacing: 4) {
                                                   Text(subject)
                                                       .font(.headline)
                                                       .foregroundColor(.primary)
                                                   
                                                   Text("Tap to add to your subjects")
                                                       .font(.caption)
                                                       .foregroundColor(.secondary)
                                               }
                                               
                                               Spacer()
                                               
                                               Image(systemName: "plus.circle.fill")
                                                   .font(.title2)
                                                   .foregroundColor(Color(red: 0.36, green: 0.72, blue: 1.0))
                                           }
                                           .padding()
                                           .background(Color.white.opacity(0.95))
                                           .cornerRadius(12)
                                       }
                                       .buttonStyle(PlainButtonStyle())
                                   }
                               }
                               .padding()
                           }
                           .background(Color.white.opacity(0.1))
                           .cornerRadius(12)
                       }
                   }
                   .padding(.horizontal, 20)
                   
                   Spacer()
               }
           }
           .navigationTitle("Add Subject")
           .navigationBarTitleDisplayMode(.inline)
           .toolbar {
               ToolbarItem(placement: .navigationBarTrailing) {
                   Button("Cancel") {
                       dismiss()
                   }
                   .foregroundColor(.white)
               }
           }
       }
   }
}

struct ClassSelectionSheet: View {
   let availableClasses: [String]
   let onClassSelected: (String) -> Void
   @Environment(\.dismiss) private var dismiss
   
   @State private var searchText = ""
   
   var filteredClasses: [String] {
       if searchText.isEmpty {
           return availableClasses
       }
       return availableClasses.filter { $0.localizedCaseInsensitiveContains(searchText) }
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
               
               VStack(spacing: 20) {
                   VStack(spacing: 8) {
                       Text("Add Class")
                           .font(.title2)
                           .fontWeight(.bold)
                           .foregroundColor(.white)
                       
                       Text("Select classes from the master list to add to your teaching profile")
                           .font(.subheadline)
                           .foregroundColor(.white.opacity(0.9))
                           .multilineTextAlignment(.center)
                   }
                   .padding(.top, 20)
                   
                   VStack(spacing: 12) {
                       // Search Bar
                       TextField("Search classes...", text: $searchText)
                           .padding()
                           .background(Color.white.opacity(0.9))
                           .cornerRadius(12)
                           .onSubmit {
                               hideKeyboard()
                           }
                       
                       // Classes List
                       if filteredClasses.isEmpty {
                           VStack(spacing: 16) {
                               Image(systemName: "person.3")
                                   .font(.system(size: 40))
                                   .foregroundColor(.white.opacity(0.6))
                               
                               Text(searchText.isEmpty ? "All classes already added" : "No classes found")
                                   .font(.subheadline)
                                   .foregroundColor(.white.opacity(0.8))
                           }
                           .frame(maxWidth: .infinity)
                           .padding(40)
                           .background(Color.white.opacity(0.1))
                           .cornerRadius(12)
                       } else {
                           ScrollView {
                               LazyVStack(spacing: 8) {
                                   ForEach(filteredClasses, id: \.self) { className in
                                       Button(action: {
                                           onClassSelected(className)
                                           dismiss()
                                       }) {
                                           HStack {
                                               VStack(alignment: .leading, spacing: 4) {
                                                   Text(className)
                                                       .font(.headline)
                                                       .foregroundColor(.primary)
                                                   
                                                   Text("Tap to add to your classes")
                                                       .font(.caption)
                                                       .foregroundColor(.secondary)
                                               }
                                               
                                               Spacer()
                                               
                                               Image(systemName: "plus.circle.fill")
                                                   .font(.title2)
                                                   .foregroundColor(Color(red: 0.36, green: 0.72, blue: 1.0))
                                           }
                                           .padding()
                                           .background(Color.white.opacity(0.95))
                                           .cornerRadius(12)
                                       }
                                       .buttonStyle(PlainButtonStyle())
                                   }
                               }
                               .padding()
                           }
                           .background(Color.white.opacity(0.1))
                           .cornerRadius(12)
                       }
                   }
                   .padding(.horizontal, 20)
                   
                   Spacer()
               }
           }
           .navigationTitle("Add Class")
           .navigationBarTitleDisplayMode(.inline)
           .toolbar {
               ToolbarItem(placement: .navigationBarTrailing) {
                   Button("Cancel") {
                       dismiss()
                   }
                   .foregroundColor(.white)
               }
           }
       }
   }
}
