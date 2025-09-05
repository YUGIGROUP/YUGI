import SwiftUI

struct AIAnalysisView: View {
    @ObservedObject var aiService: AIVenueDataService
    let location: Location
    let onUpdateLocation: ((VenueFacilities) -> Void)?
    let onBookClass: (() -> Void)?
    @State private var facilities: VenueFacilities?
    @State private var showingResults = false
    @State private var showingSuccessMessage = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Debug info
            Text("AI Venue Check View Loaded")
                .font(.headline)
                .foregroundColor(.black)
            
            Text("Location: \(location.name)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            if aiService.isAnalyzing {
                analyzingView
            } else if let facilities = facilities {
                resultsView(facilities)
            } else {
                startAnalysisView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .overlay(
            Group {
                if showingSuccessMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("Location Updated!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        Text("AI data has been applied to this venue")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingSuccessMessage)
    }
    
    private var startAnalysisView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            Text("AI-Powered Venue Check")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            Text("Get real-time information about parking and baby changing facilities using AI")
                .font(.system(size: 14))
                .foregroundColor(.yugiGray.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button(action: startAnalysis) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                    Text("Analyse Venue")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "#BC6C5C"))
                .cornerRadius(12)
            }
        }
    }
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            // Progress indicator
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "#BC6C5C").opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: aiService.analysisProgress)
                        .stroke(Color(hex: "#BC6C5C"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: aiService.analysisProgress)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                
                Text("AI is analysing venue...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Text("\(Int(aiService.analysisProgress * 100))%")
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.8))
            }
            
            // Analysis steps
            VStack(alignment: .leading, spacing: 8) {
                AnalysisStep(
                    title: "Google Places",
                    isCompleted: aiService.analysisProgress >= 0.3,
                    isActive: aiService.analysisProgress >= 0.1 && aiService.analysisProgress < 0.6
                )
                
                AnalysisStep(
                    title: "Website Analysis",
                    isCompleted: aiService.analysisProgress >= 0.6,
                    isActive: aiService.analysisProgress >= 0.4 && aiService.analysisProgress < 0.9
                )
                
                AnalysisStep(
                    title: "Review Analysis",
                    isCompleted: aiService.analysisProgress >= 0.9,
                    isActive: aiService.analysisProgress >= 0.7 && aiService.analysisProgress < 1.0
                )
                
                AnalysisStep(
                    title: "Consolidating Results",
                    isCompleted: aiService.analysisProgress >= 1.0,
                    isActive: aiService.analysisProgress >= 0.9 && aiService.analysisProgress < 1.0
                )
            }
        }
    }
    
    private func resultsView(_ facilities: VenueFacilities) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("Analysis Complete")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.yugiGray)
                
                Spacer()
                
                Button(action: startAnalysis) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
            
            // Confidence indicator
            HStack {
                Text("Confidence:")
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.8))
                
                Text("\(Int(facilities.confidence * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(confidenceColor(facilities.confidence))
                
                Spacer()
                
                Text("Sources: \(facilities.sources.joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundColor(.yugiGray.opacity(0.6))
            }
            
            // Results
            VStack(spacing: 12) {
                FacilityResultRow(
                    icon: "car.fill",
                    title: "Parking",
                    value: facilities.parkingInfo ?? "Information not available"
                )
                
                FacilityResultRow(
                    icon: "baby",
                    title: "Baby Changing",
                    value: facilities.babyChangingFacilities ?? "Information not available"
                )
                
                if let accessibility = facilities.accessibilityNotes {
                    FacilityResultRow(
                        icon: "figure.roll",
                        title: "Accessibility",
                        value: accessibility
                    )
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    showingResults = true
                }) {
                    Text("View Details")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#BC6C5C"))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    // Update the location with AI data
                    updateLocationWithAIData(facilities)
                }) {
                    Text("Save Venue Data")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#BC6C5C").opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Book Class Button
            if onBookClass != nil {
                Button(action: {
                    onBookClass?()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16))
                        Text("Book This Class")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color(hex: "#BC6C5C").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showingResults) {
            AIAnalysisDetailView(facilities: facilities, location: location)
        }
    }
    
    private func startAnalysis() {
        Task {
            facilities = await aiService.gatherVenueFacilities(for: location)
        }
    }
    
    private func updateLocationWithAIData(_ facilities: VenueFacilities) {
        // Update the location with AI-gathered data
        onUpdateLocation?(facilities)
        
        // Show success message
        showingSuccessMessage = true
        
        // Dismiss the sheet after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

struct AnalysisStep: View {
    let title: String
    let isCompleted: Bool
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(textColor)
            
            Spacer()
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return Color(hex: "#BC6C5C")
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    private var textColor: Color {
        if isCompleted || isActive {
            return .yugiGray
        } else {
            return .yugiGray.opacity(0.5)
        }
    }
}

struct FacilityResultRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(hex: "#BC6C5C").opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
        )
    }
}

struct AIAnalysisDetailView: View {
    let facilities: VenueFacilities
    let location: Location
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(location.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.yugiGray)
                        
                        Text(location.address.formatted)
                            .font(.system(size: 16))
                            .foregroundColor(.yugiGray.opacity(0.8))
                    }
                    
                    // Confidence and sources
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis Confidence")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        HStack {
                            Text("\(Int(facilities.confidence * 100))%")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(confidenceColor(facilities.confidence))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("High confidence")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Based on \(facilities.sources.count) sources")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yugiGray.opacity(0.6))
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(hex: "#BC6C5C").opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Detailed results
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Facility Information")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        VStack(spacing: 12) {
                            DetailedFacilityCard(
                                icon: "car.fill",
                                title: "Parking Information",
                                value: facilities.parkingInfo ?? "Information not available",
                                color: .blue
                            )
                            
                            DetailedFacilityCard(
                                icon: "baby",
                                title: "Baby Changing Facilities",
                                value: facilities.babyChangingFacilities ?? "Information not available",
                                color: .pink
                            )
                            
                            if let accessibility = facilities.accessibilityNotes {
                                DetailedFacilityCard(
                                    icon: "figure.roll",
                                    title: "Accessibility Features",
                                    value: accessibility,
                                    color: .green
                                )
                            }
                        }
                    }
                    
                    // Sources
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Sources")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        VStack(spacing: 8) {
                            ForEach(facilities.sources, id: \.self) { source in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                    
                                    Text(source)
                                        .font(.system(size: 14))
                                        .foregroundColor(.yugiGray)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(hex: "#BC6C5C").opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("AI Venue Check Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

struct DetailedFacilityCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yugiGray)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.yugiGray.opacity(0.8))
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    AIAnalysisView(
        aiService: AIVenueDataService(),
        location: Location(
            id: UUID(),
            name: "Sample Venue",
            address: Address(
                street: "123 High Street",
                city: "Richmond",
                state: "London",
                postalCode: "TW9 1AA",
                country: "UK"
            ),
            coordinates: Location.Coordinates(latitude: 51.4613, longitude: -0.3037),
            accessibilityNotes: nil,
            parkingInfo: nil,
            babyChangingFacilities: nil
        ),
        onUpdateLocation: nil,
        onBookClass: nil
    )
} 