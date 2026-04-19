import SwiftUI

struct PaymentMethodsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddPaymentMethod = false
    @StateObject private var sharedPaymentService = SharedPaymentService.shared

    @State private var showHeader  = false
    @State private var showContent = false
    @State private var showFooter  = false

    var body: some View {
        ZStack {
            Color.yugiCloud.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Nav header
                HStack(spacing: 6) {
                    Button(action: { dismiss() }) {
                        Text("‹")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text("Payment methods")
                        .font(.custom("Raleway-Medium", size: 18))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color.yugiMocha.ignoresSafeArea(edges: .top))
                .opacity(showHeader ? 1 : 0)
                .offset(y: showHeader ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showHeader)

                // MARK: Body
                Group {
                    if sharedPaymentService.paymentMethods.isEmpty {
                        emptyState
                    } else {
                        populatedState
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showContent)

                // MARK: Footer
                Text("🔒 Encrypted & PCI-DSS compliant")
                    .font(.custom("Raleway-Regular", size: 12))
                    .foregroundColor(Color.yugiBodyText)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                    .padding(.bottom, 32)
                    .opacity(showFooter ? 1 : 0)
                    .offset(y: showFooter ? 0 : 12)
                    .animation(.easeOut(duration: 0.6), value: showFooter)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showHeader  = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { showContent = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { showFooter  = true }
        }
        .sheet(isPresented: $showingAddPaymentMethod) {
            AddPaymentMethodScreen { newPaymentMethod in
                addNewPaymentMethod(newPaymentMethod)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.yugiOat)
                        .frame(width: 72, height: 72)
                    Image(systemName: "creditcard")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(Color.yugiMocha)
                }
                Spacer().frame(height: 28)
                Text("No cards added yet")
                    .font(.custom("Raleway-Medium", size: 22))
                    .foregroundColor(Color.yugiSoftBlack)
                    .tracking(-0.3)
                Spacer().frame(height: 8)
                Text("Add a card to make bookings quick and secure.")
                    .font(.custom("Raleway-Regular", size: 14))
                    .foregroundColor(Color.yugiBodyText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(7)
                    .frame(maxWidth: 260)
                Spacer().frame(height: 28)
                Button(action: { showingAddPaymentMethod = true }) {
                    Text("Add a card")
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 40)
                        .background(Color.yugiMocha)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Populated State

    private var populatedState: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(sharedPaymentService.paymentMethods) { paymentMethod in
                    UserPaymentMethodRow(
                        paymentMethod: paymentMethod,
                        onSetDefault: { setDefaultPaymentMethod(paymentMethod) },
                        onDelete: { deletePaymentMethod(paymentMethod) }
                    )
                }
                Button(action: { showingAddPaymentMethod = true }) {
                    Text("+ Add another card")
                        .font(.custom("Raleway-Medium", size: 14))
                        .foregroundColor(Color.yugiMocha)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundColor(Color.yugiBorder)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Logic (preserved)

    private func setDefaultPaymentMethod(_ paymentMethod: UserPaymentMethod) {
        let updatedPaymentMethod = UserPaymentMethod(
            id: paymentMethod.id,
            type: paymentMethod.type,
            lastFourDigits: paymentMethod.lastFourDigits,
            expiryMonth: paymentMethod.expiryMonth,
            expiryYear: paymentMethod.expiryYear,
            cardholderName: paymentMethod.cardholderName,
            isDefault: true
        )
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

// MARK: - UserPaymentMethodRow

struct UserPaymentMethodRow: View {
    let paymentMethod: UserPaymentMethod
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "F5F1ED"))
                    .frame(width: 40, height: 40)
                Image(systemName: "creditcard")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(Color.yugiMocha)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(paymentMethod.type.displayName) ••\(paymentMethod.lastFourDigits)")
                    .font(.custom("Raleway-Medium", size: 15))
                    .foregroundColor(Color.yugiSoftBlack)
                Text("Expires \(String(format: "%02d/%02d", paymentMethod.expiryMonth, paymentMethod.expiryYear % 100))")
                    .font(.custom("Raleway-Regular", size: 12))
                    .foregroundColor(Color.yugiBodyText)
            }

            Spacer()

            if paymentMethod.isDefault {
                Text("DEFAULT")
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundColor(Color.yugiDeepSage)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color.yugiSage)
                    .clipShape(Capsule())
            }

            Menu {
                if !paymentMethod.isDefault {
                    Button("Set as Default") { onSetDefault() }
                }
                Button("Delete", role: .destructive) { showingDeleteAlert = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundColor(Color.yugiBodyText)
                    .frame(width: 24)
            }
        }
        .padding(18)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yugiOat, lineWidth: 1)
        )
        .cornerRadius(16)
        .alert("Delete Payment Method", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete this payment method? This action cannot be undone.")
        }
    }
}

#Preview {
    PaymentMethodsScreen()
}
