import SwiftUI

// MARK: - Provider Profile Popup

struct ProviderProfilePopup: View {
    let provider: Provider
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Full background
            Color(hex: "#BC6C5C")
                .ignoresSafeArea()
            
            VStack {
                // Header with Done button
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with Profile Picture
                        VStack(spacing: 16) {
                            // Profile Picture Placeholder
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String(provider.name.prefix(1).uppercased()))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            Text(provider.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        // Bio Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.text.rectangle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Text("About")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(provider.description)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "#BC6C5C"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        // Qualifications Section
                        if !provider.qualifications.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "graduationcap.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                    
                                    Text("Qualifications")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(provider.qualifications, id: \.self) { qualification in
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                            
                                            Text(qualification)
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    }
                                }
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "#BC6C5C"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Contact Information
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                
                                Text("Contact")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                
                                    Text(provider.contactEmail)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "phone")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                
                                    Text(provider.contactPhone)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                
                                if let website = provider.website {
                                    HStack(spacing: 8) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Text(website)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "#BC6C5C"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
    }
}

#Preview {
    ProviderProfilePopup(provider: Provider(
        id: UUID(),
        name: "Sensory World",
        description: "Specialists in early development with over 10 years of experience in creating engaging sensory experiences for babies and toddlers.",
        qualifications: ["Early Years Development", "Sensory Integration Specialist", "First Aid Certified"],
        contactEmail: "hello@sensoryworld.com",
        contactPhone: "+44 20 1234 5678",
        website: "www.sensoryworld.com",
        rating: 4.8
    ))
}
