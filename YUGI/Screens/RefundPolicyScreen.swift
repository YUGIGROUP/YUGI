import SwiftUI

struct RefundPolicyScreen: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Refund Policy")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Understanding your cancellation and refund options")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Service Fee
                        PolicySection(
                            title: "1. Service Fee",
                            icon: "poundsign.circle"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Each booking includes a £1.99 non-refundable service fee.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                
                                Text("This covers admin, platform running costs, and secure payment processing.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                            }
                        }
                        
                        // If You Cancel a Booking
                        PolicySection(
                            title: "2. If You Cancel a Booking",
                            icon: "xmark.circle"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                PolicyPoint(
                                    icon: "checkmark.circle.fill",
                                    color: .green,
                                    title: "More than 24 hours before the class",
                                    description: "You will receive a full refund of the class price, minus the £1.99 service fee."
                                )
                                
                                PolicyPoint(
                                    icon: "xmark.circle.fill",
                                    color: .red,
                                    title: "Less than 24 hours before the class",
                                    description: "No refund will be given."
                                )
                            }
                        }
                        
                        // If the Provider Cancels a Class
                        PolicySection(
                            title: "3. If the Provider Cancels a Class",
                            icon: "exclamationmark.triangle"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("If a provider cancels for any reason, you will receive a full refund of the class price, minus the £1.99 service fee.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                            }
                        }
                        
                        // Disputes and Problems with a Class
                        PolicySection(
                            title: "4. Disputes and Problems with a Class",
                            icon: "questionmark.circle"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("If you are unhappy with a class, you must raise a dispute with YUGI within 48 hours after the class ends.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Payments are held for 3 days after each class to allow time for disputes.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                
                                Text("If a dispute is raised, funds will remain on hold until the issue is investigated and resolved.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                
                                Text("YUGI may decide to issue a full or partial refund, or release payment to the provider.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                
                                Text("YUGI's decision is final and binding.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                            }
                        }
                        
                        // When Providers Get Paid
                        PolicySection(
                            title: "5. When Providers Get Paid",
                            icon: "creditcard"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Providers receive payments for completed classes 3 days after the class has taken place, provided there are no disputes.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                
                                Text("If a dispute is raised, payment will be delayed until the issue is resolved.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                            }
                        }
                        
                        // No Refund in Certain Circumstances
                        PolicySection(
                            title: "6. No Refund in Certain Circumstances",
                            icon: "xmark.shield"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("The £1.99 service fee is always non-refundable.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Refunds are not available for missed classes, late arrivals, or changes in personal circumstances unless covered under Section 2 or 3.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                            }
                        }
                        
                        // Contact Information
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Need Help?")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            VStack(spacing: 12) {
                                ContactRow(
                                    icon: "envelope",
                                    title: "Email Support",
                                    subtitle: "support@yugi.com",
                                    action: {
                                        // Open email
                                    }
                                )
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Supporting Views

struct PolicySection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.yugiGray)
            }
            
            content
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct PolicyPoint: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

struct FeePoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .padding(.top, 6)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.yugiGray.opacity(0.8))
            
            Spacer()
        }
    }
}

struct ProcessStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#BC6C5C"))
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

struct ImportantNote: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.yugiGray)
            
            Spacer()
        }
    }
}

struct ContactRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.5))
            }
            .padding()
            .background(Color.yugiCream)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    RefundPolicyScreen()
} 