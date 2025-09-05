import SwiftUI

struct PaymentMethodsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddPaymentMethod = false
    @StateObject private var sharedPaymentService = SharedPaymentService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Payment Methods")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Manage your payment options")
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
                        // Payment Methods List
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Your Payment Methods")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingAddPaymentMethod = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16))
                                        Text("Add New")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                }
                            }
                            
                            if sharedPaymentService.paymentMethods.isEmpty {
                                // Empty State
                                VStack(spacing: 16) {
                                    Image(systemName: "creditcard")
                                        .font(.system(size: 48))
                                        .foregroundColor(.yugiGray.opacity(0.3))
                                    
                                    VStack(spacing: 8) {
                                        Text("No Payment Methods")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.yugiGray)
                                        
                                        Text("Add a payment method to make bookings")
                                            .font(.system(size: 14))
                                            .foregroundColor(.yugiGray.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                    }
                                    
                                    Button(action: {
                                        showingAddPaymentMethod = true
                                    }) {
                                        Text("Add Payment Method")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Color(hex: "#BC6C5C"))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(32)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#BC6C5C"), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(sharedPaymentService.paymentMethods) { paymentMethod in
                                        UserPaymentMethodRow(
                                            paymentMethod: paymentMethod,
                                            onSetDefault: {
                                                setDefaultPaymentMethod(paymentMethod)
                                            },
                                            onDelete: {
                                                deletePaymentMethod(paymentMethod)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Security Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Security & Privacy")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                        .frame(width: 16)
                                    
                                    Text("All payment information is encrypted and secure")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yugiGray.opacity(0.8))
                                }
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                        .frame(width: 16)
                                    
                                    Text("We never store your full card details")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yugiGray.opacity(0.8))
                                }
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                        .frame(width: 16)
                                    
                                    Text("PCI DSS compliant payment processing")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yugiGray.opacity(0.8))
                                }
                            }
                        }
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#BC6C5C"), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddPaymentMethod) {
                AddPaymentMethodScreen { newPaymentMethod in
                    addNewPaymentMethod(newPaymentMethod)
                }
            }
        }
    }
    
    private func setDefaultPaymentMethod(_ paymentMethod: UserPaymentMethod) {
        // Create a new payment method with default set to true
        let updatedPaymentMethod = UserPaymentMethod(
            id: paymentMethod.id,
            type: paymentMethod.type,
            lastFourDigits: paymentMethod.lastFourDigits,
            expiryMonth: paymentMethod.expiryMonth,
            expiryYear: paymentMethod.expiryYear,
            cardholderName: paymentMethod.cardholderName,
            isDefault: true
        )
        
        // Remove the old payment method and add the updated one
        sharedPaymentService.deletePaymentMethod(paymentMethod)
        sharedPaymentService.addPaymentMethod(updatedPaymentMethod)
    }
    
    private func deletePaymentMethod(_ paymentMethod: UserPaymentMethod) {
        sharedPaymentService.deletePaymentMethod(paymentMethod)
    }
    
    private func addNewPaymentMethod(_ newPaymentMethod: UserPaymentMethod) {
        sharedPaymentService.addPaymentMethod(newPaymentMethod)
    }
}

struct UserPaymentMethodRow: View {
    let paymentMethod: UserPaymentMethod
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Card Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(paymentMethod.type.color.opacity(0.1))
                    .frame(width: 50, height: 32)
                
                Image(systemName: paymentMethod.type.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(paymentMethod.type.color)
            }
            
            // Card Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(paymentMethod.type.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    if paymentMethod.isDefault {
                        Text("Default")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#BC6C5C"))
                            .cornerRadius(4)
                    }
                }
                
                Text("•••• •••• •••• \(paymentMethod.lastFourDigits)")
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.7))
                
                Text("Expires \(String(format: "%02d/%d", paymentMethod.expiryMonth, paymentMethod.expiryYear))")
                    .font(.system(size: 12))
                    .foregroundColor(.yugiGray.opacity(0.6))
            }
            
            Spacer()
            
            // Actions Menu
            Menu {
                if !paymentMethod.isDefault {
                    Button("Set as Default") {
                        onSetDefault()
                    }
                }
                
                Button("Delete", role: .destructive) {
                    showingDeleteAlert = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.yugiGray.opacity(0.6))
                    .frame(width: 24)
            }
        }
        .padding()
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#BC6C5C"), lineWidth: 1)
        )
        .cornerRadius(12)
        .alert("Delete Payment Method", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this payment method? This action cannot be undone.")
        }
    }
}

#Preview {
    PaymentMethodsScreen()
} 