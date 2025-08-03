import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firebaseManager = FirebaseManager()
    
    @State private var name = ""
    @State private var selectedDesignation = "Mr."
    @State private var selectedSubjects: [String] = []
    @State private var selectedClasses: [String] = []
    @State private var subjectSearchText = ""
    @State private var classSearchText = ""
    @State private var availableSubjects: [String] = []
    @State private var availableClasses: [String] = []
    @State private var showSubjectDropdown = false
    @State private var showClassDropdown = false
    @State private var isLoading = false
    @State private var availableSubjectsForAdding: [String] = []
    @State private var availableClassesForAdding: [String] = []
    @State private var showSubjectSelectionSheet = false
    @State private var showClassSelectionSheet = false
    
    private let designations = ["Mr.", "Mrs.", "Ms.", "Dr.", "Prof."]
    
    var filteredSubjects: [String] {
        if subjectSearchText.isEmpty {
            return availableSubjects
        }
        return availableSubjects.filter { $0.localizedCaseInsensitiveContains(subjectSearchText) }
    }
    
    var filteredClasses: [String] {
        if classSearchText.isEmpty {
            return availableClasses
        }
        return availableClasses.filter { $0.localizedCaseInsensitiveContains(classSearchText) }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.36, green: 0.72, blue: 1.0), Color(red: 0.58, green: 0.65, blue: 1.0)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 20) {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "graduationcap.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(Color(red: 0.36, green: 0.72, blue: 1.0))
                            )
                        
                        VStack(spacing: 8) {
                            Text("Smart Attend")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Teacher Portal")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 25) {
                        // Name and Designation
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Personal Information")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                TextField("Enter your name", text: $name)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .onSubmit {
                                        hideKeyboard()
                                    }
                                
                                Menu {
                                    ForEach(designations, id: \.self) { designation in
                                        Button(designation) {
                                            selectedDesignation = designation
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedDesignation)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        // Subjects Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Subjects You Teach")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    loadAvailableSubjects()
                                    showSubjectSelectionSheet = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                }
                            }
                            
                            VStack(spacing: 8) {
                                SearchableDropdown(
                                    searchText: $subjectSearchText,
                                    selectedItems: $selectedSubjects,
                                    showDropdown: $showSubjectDropdown,
                                    availableItems: filteredSubjects,
                                    placeholder: "Search subjects..."
                                )
                                
                                SelectedItemsView(items: selectedSubjects) { item in
                                    selectedSubjects.removeAll { $0 == item }
                                }
                            }
                        }
                        
                        // Classes Section
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Classes You Teach")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    loadAvailableClasses()
                                    showClassSelectionSheet = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                }
                            }
                            
                            VStack(spacing: 8) {
                                SearchableDropdown(
                                    searchText: $classSearchText,
                                    selectedItems: $selectedClasses,
                                    showDropdown: $showClassDropdown,
                                    availableItems: filteredClasses,
                                    placeholder: "Search classes..."
                                )
                                
                                SelectedItemsView(items: selectedClasses) { item in
                                    selectedClasses.removeAll { $0 == item }
                                }
                            }
                        }
                        
                        Button(action: handleLogin) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(isLoading || name.isEmpty || selectedSubjects.isEmpty || selectedClasses.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    
                    Text("A Humble Solutions Product")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showSubjectSelectionSheet) {
            SubjectSelectionSheet(
                availableSubjects: availableSubjectsForAdding,
                onSubjectSelected: addSubjectToSelection
            )
        }
        .sheet(isPresented: $showClassSelectionSheet) {
            ClassSelectionSheet(
                availableClasses: availableClassesForAdding,
                onClassSelected: addClassToSelection
            )
        }
    }
    
    private func loadData() {
        Task {
            async let subjects = firebaseManager.fetchSubjects()
            async let classes = firebaseManager.fetchClasses()
            
            availableSubjects = await subjects
            availableClasses = await classes
        }
    }
    
    private func loadAvailableSubjects() {
        Task {
            let allSubjects = await firebaseManager.fetchSubjects()
            
            await MainActor.run {
                // Show only subjects that aren't already selected
                availableSubjectsForAdding = allSubjects.filter { !selectedSubjects.contains($0) }
            }
        }
    }
    
    private func loadAvailableClasses() {
        Task {
            let allClasses = await firebaseManager.fetchClasses()
            
            await MainActor.run {
                // Show only classes that aren't already selected
                availableClassesForAdding = allClasses.filter { !selectedClasses.contains($0) }
            }
        }
    }
    
    private func addSubjectToSelection(_ subject: String) {
        if !selectedSubjects.contains(subject) {
            selectedSubjects.append(subject)
            // Update available list
            availableSubjectsForAdding.removeAll { $0 == subject }
        }
    }
    
    private func addClassToSelection(_ className: String) {
        if !selectedClasses.contains(className) {
            selectedClasses.append(className)
            // Update available list
            availableClassesForAdding.removeAll { $0 == className }
        }
    }
    
    private func handleLogin() {
        guard !name.isEmpty, !selectedSubjects.isEmpty, !selectedClasses.isEmpty else { return }
        
        isLoading = true
        
        let teacherData = TeacherData(
            name: name,
            designation: selectedDesignation,
            subjects: selectedSubjects,
            classes: selectedClasses
        )
        
        authManager.login(teacherData: teacherData)
        isLoading = false
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .autocapitalization(.words)
    }
}

struct SearchableDropdown: View {
    @Binding var searchText: String
    @Binding var selectedItems: [String]
    @Binding var showDropdown: Bool
    let availableItems: [String]
    let placeholder: String
    
    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $searchText)
                .onChange(of: searchText) { _ in
                    showDropdown = !searchText.isEmpty
                }
                .onTapGesture {
                    showDropdown = true
                }
                .onSubmit {
                    hideKeyboard()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            
            if showDropdown && !availableItems.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(availableItems, id: \.self) { item in
                            Button(action: {
                                if !selectedItems.contains(item) {
                                    selectedItems.append(item)
                                }
                                searchText = ""
                                showDropdown = false
                                hideKeyboard()
                            }) {
                                HStack {
                                    Text(item)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedItems.contains(item) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color(red: 0.36, green: 0.72, blue: 1.0))
                                    }
                                }
                                .padding()
                                .background(Color.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if item != availableItems.last {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 5)
            }
        }
    }
}

struct SelectedItemsView: View {
    let items: [String]
    let onRemove: (String) -> Void
    
    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item)
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                onRemove(item)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}


