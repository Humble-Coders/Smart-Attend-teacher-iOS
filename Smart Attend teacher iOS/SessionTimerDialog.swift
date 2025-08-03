//
//  SessionTimerDialog.swift
//  Smart Attend teacher iOS
//
//  Created by Ansh Bajaj on 24/06/25.
//


import SwiftUI

struct SessionTimerDialog: View {
    @ObservedObject var timerManager: SessionTimerManager
    let onRestart: () -> Void
    let onEnd: () -> Void
    let onDismiss: () -> Void
    
    @State private var isMinimized = false
    
    var body: some View {
        ZStack {
            // Overlay background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isMinimized {
                        withAnimation(.spring()) {
                            isMinimized = true
                        }
                    }
                }
            
            VStack {
                Spacer()
                
                if !isMinimized {
                    // Full dialog
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.green.opacity(0.3), lineWidth: 4)
                                            .scaleEffect(timerManager.isTimerActive ? 1.5 : 1.0)
                                            .opacity(timerManager.isTimerActive ? 0 : 1)
                                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: timerManager.isTimerActive)
                                    )
                                
                                Text("Session Active")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        isMinimized = true
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Text("Session will end automatically when timer reaches 00:00")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Timer Display
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                    .frame(width: 120, height: 120)
                                
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(timerManager.progress))
                                    .stroke(
                                        LinearGradient(
                                            colors: timerManager.timeRemaining < 60 ? [.red, .orange] : [.green, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 1.0), value: timerManager.progress)
                                
                                VStack(spacing: 2) {
                                    Text(timerManager.timeRemainingFormatted)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .monospacedDigit()
                                    
                                    Text("remaining")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if timerManager.timeRemaining < 60 {
                                Text("Session ending soon!")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .fontWeight(.medium)
                                    .opacity(timerManager.timeRemaining < 60 ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.5), value: timerManager.timeRemaining < 60)
                            }
                        }
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button(action: onRestart) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Restart")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .cornerRadius(10)
                            }
                            
                            Button(action: onEnd) {
                                HStack(spacing: 6) {
                                    Image(systemName: "stop.fill")
                                    Text("End Now")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(10)
                            }
                        }
                        
                        // Background info
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "app.badge")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text("Timer continues in background")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("You'll receive a notification when the session ends")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 20)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Minimized floating widget
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring()) {
                                isMinimized = false
                            }
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Text(timerManager.timeRemainingFormatted)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.semibold)
                                
                                Image(systemName: "chevron.up.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(UIColor.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                if !isMinimized {
                    Spacer()
                }
            }
        }
        .onAppear {
            // Minimize after 10 seconds automatically
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if !isMinimized {
                    withAnimation(.spring()) {
                        isMinimized = true
                    }
                }
            }
        }
    }
}