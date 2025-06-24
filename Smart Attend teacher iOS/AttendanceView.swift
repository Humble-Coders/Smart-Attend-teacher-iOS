import SwiftUI

struct AttendanceView: View {
    let sessionData: SessionData?
    @StateObject private var firebaseManager = FirebaseManager()
    @State private var attendanceList: [AttendanceRecord] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
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
                   if let sessionData = sessionData {
                       VStack(spacing: 16) {
                           Text("Attendance Report")
                               .font(.title2)
                               .fontWeight(.bold)
                               .foregroundColor(.white)
                           
                           VStack(spacing: 12) {
                               // Subject badge
                               Text(sessionData.subject)
                                   .font(.title3)
                                   .fontWeight(.semibold)
                                   .foregroundColor(Color(red: 0.36, green: 0.72, blue: 1.0))
                                   .padding(.horizontal, 20)
                                   .padding(.vertical, 10)
                                   .background(Color.white)
                                   .cornerRadius(10)
                               
                               // Session details
                               HStack(spacing: 20) {
                                   VStack(spacing: 2) {
                                       Text("ROOM")
                                           .font(.caption2)
                                           .fontWeight(.medium)
                                           .foregroundColor(.white.opacity(0.7))
                                       Text(sessionData.room)
                                           .font(.subheadline)
                                           .fontWeight(.semibold)
                                           .foregroundColor(.white)
                                   }
                                   
                                   Rectangle()
                                       .fill(Color.white.opacity(0.4))
                                       .frame(width: 1, height: 35)
                                   
                                   VStack(spacing: 2) {
                                       Text("TYPE")
                                           .font(.caption2)
                                           .fontWeight(.medium)
                                           .foregroundColor(.white.opacity(0.7))
                                       Text(sessionData.type.uppercased())
                                           .font(.subheadline)
                                           .fontWeight(.semibold)
                                           .foregroundColor(.white)
                                   }
                                   
                                   if sessionData.isExtra {
                                       Rectangle()
                                           .fill(Color.white.opacity(0.4))
                                           .frame(width: 1, height: 35)
                                       
                                       VStack(spacing: 2) {
                                           Text("STATUS")
                                               .font(.caption2)
                                               .fontWeight(.medium)
                                               .foregroundColor(.white.opacity(0.7))
                                           Text("EXTRA")
                                               .font(.subheadline)
                                               .fontWeight(.semibold)
                                               .foregroundColor(.orange)
                                       }
                                   }
                               }
                               
                               Text(sessionData.date)
                                   .font(.caption)
                                   .foregroundColor(.white.opacity(0.8))
                                   .padding(.top, 4)
                           }
                           .padding()
                           .background(Color.white.opacity(0.15))
                           .cornerRadius(12)
                       }
                       .padding(.top, 20)
                   }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Present Students")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(attendanceList.count) students")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text("Loading attendance records...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        } else if attendanceList.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.slash.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("No students marked present")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Students will appear here once they mark their attendance")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(attendanceList, id: \.rollNumber) { record in
                                        AttendanceRowView(record: record)
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
            .navigationTitle("Attendance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadAttendance()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadAttendance()
        }
    }
    
    private func loadAttendance() {
        guard let sessionData = sessionData else { return }
        
        isLoading = true
        
        Task {
            let records = await firebaseManager.fetchAttendance(for: sessionData)
            
            await MainActor.run {
                attendanceList = records
                isLoading = false
            }
        }
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        // Parse the timestamp format from Firebase
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a zzz"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        
        if let date = inputFormatter.date(from: timestamp) {
            return outputFormatter.string(from: date)
        }
        return timestamp
    }
}

struct AttendanceRowView: View {
    let record: AttendanceRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Roll Number Badge
            Text(record.rollNumber)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.36, green: 0.72, blue: 1.0))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Group: \(record.group)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(formatTimestamp(record.timestamp))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        // Parse the timestamp format from Firebase
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm:ss a zzz"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        
        if let date = inputFormatter.date(from: timestamp) {
            return outputFormatter.string(from: date)
        }
        
        // If the above doesn't work, try simpler format
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = inputFormatter.date(from: timestamp) {
            return outputFormatter.string(from: date)
        }
        
        return "Time not available"
    }
}
