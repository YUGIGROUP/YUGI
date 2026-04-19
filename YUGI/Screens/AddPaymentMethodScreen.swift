import SwiftUI

struct AddPaymentMethodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared

    // Form fields
    @State private var cardNumber     = ""
    @State private var cardholderName = ""
    @State private var expiryMonth    = 1
    @State private var expiryYear     = Calendar.current.component(.year, from: Date())
    @State private var expiryText     = ""
    @State private var cvv            = ""
    @State private var isDefault      = false

    // UI state
    @State private var isLoading      = false
    @State private var showingError   = false
    @State private var errorMessage   = ""
    @State private var detectedCardType: CardType?

    // Animation
    @State private var showHeader = false
    @State private var showForm   = false
    @State private var showSave   = false

    let onPaymentMethodAdded: (UserPaymentMethod) -> Void

    var body: some View {
        ZStack {
            Color.yugiCloud.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header
                HStack(spacing: 6) {
                    Button(action: { dismiss() }) {
                        Text("‹")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text("Add a card")
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

                // MARK: Form
                ScrollView {
                    VStack(spacing: 22) {
                        // Card Number
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CARD NUMBER")
                                .font(.custom("Raleway-Medium", size: 12))
                                .foregroundColor(Color.yugiBodyText)
                                .kerning(0.4)
                            inputField(text: $cardNumber, placeholder: "1234 5678 9012 3456", keyboardType: .numberPad)
                                .onChange(of: cardNumber) { _, newValue in
                                    let digits = newValue.filter { $0.isNumber }
                                    let formatted = formatCardNumberString(String(digits.prefix(16)))
                                    if formatted != newValue { cardNumber = formatted }
                                    detectCardType()
                                }
                        }

                        // Cardholder Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CARDHOLDER NAME")
                                .font(.custom("Raleway-Medium", size: 12))
                                .foregroundColor(Color.yugiBodyText)
                                .kerning(0.4)
                            inputField(text: $cardholderName, placeholder: "Name on card")
                        }

                        // Expiry + CVV
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EXPIRY")
                                    .font(.custom("Raleway-Medium", size: 12))
                                    .foregroundColor(Color.yugiBodyText)
                                    .kerning(0.4)
                                inputField(text: $expiryText, placeholder: "MM / YY", keyboardType: .numberPad)
                                    .onChange(of: expiryText) { _, newValue in
                                        let digits = newValue.filter { $0.isNumber }
                                        let capped = String(digits.prefix(4))
                                        var formatted = ""
                                        for (i, d) in capped.enumerated() {
                                            if i == 2 { formatted += " / " }
                                            formatted.append(d)
                                        }
                                        if formatted != newValue { expiryText = formatted }
                                        parseExpiry(formatted)
                                    }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("CVV")
                                    .font(.custom("Raleway-Medium", size: 12))
                                    .foregroundColor(Color.yugiBodyText)
                                    .kerning(0.4)
                                secureInputField(text: $cvv, placeholder: "123", keyboardType: .numberPad)
                                    .onChange(of: cvv) { _, newValue in
                                        let cleaned = newValue.filter { $0.isNumber }
                                        let capped = String(cleaned.prefix(4))
                                        if capped != newValue { cvv = capped }
                                    }
                            }
                        }

                        // Default toggle
                        HStack {
                            Text("Use for future bookings")
                                .font(.custom("Raleway-Regular", size: 14))
                                .foregroundColor(Color.yugiSoftBlack)
                            Spacer()
                            Toggle("", isOn: $isDefault)
                                .toggleStyle(SwitchToggleStyle(tint: Color.yugiMocha))
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                }
                .opacity(showForm ? 1 : 0)
                .offset(y: showForm ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showForm)

                // MARK: Save (sticky)
                VStack(spacing: 10) {
                    Button(action: addCard) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Save card")
                                    .font(.custom("Raleway-Medium", size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.yugiMocha)
                        .clipShape(Capsule())
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.55)

                    Text("🔒 Encrypted & PCI-DSS compliant")
                        .font(.custom("Raleway-Regular", size: 11))
                        .foregroundColor(Color.yugiBodyText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .opacity(showSave ? 1 : 0)
                .offset(y: showSave ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showSave)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showHeader = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { showForm   = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { showSave   = true }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Field Builders

    @ViewBuilder
    private func inputField(text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundColor(Color.yugiBodyText.opacity(0.7))
            }
            TextField("", text: text)
                .font(.custom("Raleway-Regular", size: 15))
                .foregroundColor(Color.yugiSoftBlack)
                .keyboardType(keyboardType)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yugiBorder, lineWidth: 1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func secureInputField(text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundColor(Color.yugiBodyText.opacity(0.7))
            }
            SecureField("", text: text)
                .font(.custom("Raleway-Regular", size: 15))
                .foregroundColor(Color.yugiSoftBlack)
                .keyboardType(keyboardType)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yugiBorder, lineWidth: 1))
        .cornerRadius(12)
    }

    // MARK: - Helper Methods (preserved)

    private func parseExpiry(_ text: String) {
        let digits = text.filter { $0.isNumber }
        guard digits.count >= 2 else { return }
        let monthStr = String(digits.prefix(2))
        guard let month = Int(monthStr), month >= 1 && month <= 12 else { return }
        expiryMonth = month
        if digits.count == 4 {
            let yearStr = String(digits.suffix(2))
            if let year2 = Int(yearStr) {
                let century = (Calendar.current.component(.year, from: Date()) / 100) * 100
                expiryYear = century + year2
            }
        }
    }

    private func formatCardNumberString(_ digits: String) -> String {
        var result = ""
        for (i, d) in digits.enumerated() {
            if i > 0 && i % 4 == 0 { result += " " }
            result.append(d)
        }
        return result
    }

    private var isFormValid: Bool {
        let cleanedCardNumber = cardNumber.filter { $0.isNumber }
        let cardNumberValid   = cleanedCardNumber.count >= 12
        let cardholderValid   = !cardholderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let cvvValid          = cvv.count >= 3
        let expiryValid       = isExpiryDateValid()
        return cardNumberValid && cardholderValid && cvvValid && expiryValid
    }

    private func isExpiryDateValid() -> Bool {
        let currentDate  = Date()
        let currentYear  = Calendar.current.component(.year,  from: currentDate)
        let currentMonth = Calendar.current.component(.month, from: currentDate)
        if expiryYear < currentYear  { return false }
        if expiryYear == currentYear && expiryMonth < currentMonth { return false }
        return true
    }

    private func detectCardType() {
        let cleaned = cardNumber.filter { $0.isNumber }
        if      cleaned.hasPrefix("4")                              { detectedCardType = .visa }
        else if cleaned.hasPrefix("5")                              { detectedCardType = .mastercard }
        else if cleaned.hasPrefix("34") || cleaned.hasPrefix("37") { detectedCardType = .amex }
        else if cleaned.hasPrefix("6")                              { detectedCardType = .discover }
        else                                                        { detectedCardType = nil }
    }

    private func addCard() {
        guard isFormValid else {
            let cleanedCardNumber = cardNumber.filter { $0.isNumber }
            var errorDetails: [String] = []
            if cleanedCardNumber.count < 12                                           { errorDetails.append("Card number must be at least 12 digits") }
            if cardholderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errorDetails.append("Cardholder name is required") }
            if cvv.count < 3                                                          { errorDetails.append("CVV must be at least 3 digits") }
            if !isExpiryDateValid()                                                   { errorDetails.append("Expiry date must be in the future") }
            showError(errorDetails.isEmpty ? "Please fill in all required fields correctly" : errorDetails.joined(separator: "\n"))
            return
        }

        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            let cleanedCardNumber = cardNumber.filter { $0.isNumber }
            let lastFourDigits    = String(cleanedCardNumber.suffix(4))
            let newPaymentMethod  = UserPaymentMethod(
                id:              UUID().uuidString,
                type:            detectedCardType ?? .visa,
                lastFourDigits:  lastFourDigits,
                expiryMonth:     expiryMonth,
                expiryYear:      expiryYear,
                cardholderName:  cardholderName.trimmingCharacters(in: .whitespacesAndNewlines),
                isDefault:       isDefault
            )
            onPaymentMethodAdded(newPaymentMethod)
            dismiss()
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

#Preview {
    AddPaymentMethodScreen { _ in }
}
