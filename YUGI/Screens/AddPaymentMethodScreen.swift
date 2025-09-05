import SwiftUI

struct AddPaymentMethodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    
    // Form fields
    @State private var cardNumber = ""
    @State private var cardholderName = ""
    @State private var expiryMonth = 1
    @State private var expiryYear = Calendar.current.component(.year, from: Date())
    @State private var cvv = ""
    @State private var isDefault = false
    
    // UI state
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var detectedCardType: CardType?
    
    // Callback
    let onPaymentMethodAdded: (UserPaymentMethod) -> Void
    
    // Available months and years
    private let months = Array(1...12)
    private let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(currentYear...(currentYear + 20))
    }()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Add Payment Method")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Enter your card details securely")
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
                        // Card Preview
                        cardPreviewSection
                        
                        // Form Fields
                        formSection
                        
                        // Default Card Toggle
                        defaultCardSection
                        
                        // Add Card Button
                        addCardButton
                        
                        // Security Notice
                        securityNoticeSection
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: cardNumber) { _, _ in
                detectCardType()
            }
        }
    }
    
    private var cardPreviewSection: some View {
        VStack(spacing: 16) {
            // Card Preview
            VStack(spacing: 0) {
                // Card front
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        
                        if let cardType = detectedCardType {
                            Image(systemName: cardType.iconName)
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cardNumber.isEmpty ? "•••• •••• •••• ••••" : formatCardNumber(cardNumber))
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CARDHOLDER")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(cardholderName.isEmpty ? "YOUR NAME" : cardholderName.uppercased())
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("EXPIRES")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(String(format: "%02d/%d", expiryMonth, expiryYear))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            detectedCardType?.color ?? Color.gray,
                            detectedCardType?.color.opacity(0.8) ?? Color.gray.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                
                // Card type indicator
                HStack {
                    Text(detectedCardType?.displayName ?? "Card")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(detectedCardType?.color ?? Color.gray)
                .cornerRadius(12)
            }
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Card Details")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 16) {
                // Card Number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Number")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray.opacity(0.8))
                    
                    YUGITextField(
                        text: $cardNumber,
                        placeholder: "1234 5678 9012 3456",
                        icon: "creditcard.fill",
                        keyboardType: .numberPad
                    )
                    .onChange(of: cardNumber) { _, newValue in
                        // Format card number with spaces
                        let cleaned = newValue.replacingOccurrences(of: " ", with: "")
                        let formatted = cleaned.enumerated().map { index, char in
                            if index > 0 && index % 4 == 0 {
                                return " \(char)"
                            }
                            return String(char)
                        }.joined()
                        cardNumber = formatted
                    }
                }
                
                // Cardholder Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cardholder Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray.opacity(0.8))
                    
                    YUGITextField(
                        text: $cardholderName,
                        placeholder: "Enter cardholder name",
                        icon: "person.fill"
                    )
                }
                
                // Expiry Date and CVV
                HStack(spacing: 16) {
                    // Expiry Month
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Month")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yugiGray.opacity(0.8))
                        
                        Picker("Month", selection: $expiryMonth) {
                            ForEach(months, id: \.self) { month in
                                Text(String(format: "%02d", month)).tag(month)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    // Expiry Year
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Year")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yugiGray.opacity(0.8))
                        
                        Picker("Year", selection: $expiryYear) {
                            ForEach(years, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    // CVV
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CVV")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yugiGray.opacity(0.8))
                        
                        YUGITextField(
                            text: $cvv,
                            placeholder: "123",
                            icon: "lock.fill",
                            keyboardType: .numberPad
                        )
                        .onChange(of: cvv) { _, newValue in
                            // Limit CVV to 3-4 digits
                            let cleaned = newValue.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                            cvv = String(cleaned.prefix(4))
                        }
                    }
                }
            }
        }
    }
    
    private var defaultCardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default Payment Method")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Set as default")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text("This card will be used for future bookings")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                Toggle("", isOn: $isDefault)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    private var addCardButton: some View {
        Button(action: addCard) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                }
                
                Text("Add Card")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .disabled(isLoading || !isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
    }
    
    private var securityNoticeSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secure Payment")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text("Your card information is encrypted and secure")
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Helper Methods
    
    private var isFormValid: Bool {
        let cleanedCardNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        let cardNumberValid = cleanedCardNumber.count >= 12
        let cardholderValid = !cardholderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let cvvValid = cvv.count >= 3
        let expiryValid = isExpiryDateValid()
        
        // Debug print to see what's failing
        print("Form validation: cardNumber=\(cardNumberValid) (\(cleanedCardNumber.count) digits), cardholder=\(cardholderValid), cvv=\(cvvValid) (\(cvv.count) chars), expiry=\(expiryValid)")
        
        return cardNumberValid && cardholderValid && cvvValid && expiryValid
    }
    
    private func isExpiryDateValid() -> Bool {
        let currentDate = Date()
        let currentYear = Calendar.current.component(.year, from: currentDate)
        let currentMonth = Calendar.current.component(.month, from: currentDate)
        
        if expiryYear < currentYear {
            return false
        }
        
        if expiryYear == currentYear && expiryMonth < currentMonth {
            return false
        }
        
        return true
    }
    
    private func detectCardType() {
        let cleaned = cardNumber.replacingOccurrences(of: " ", with: "")
        
        if cleaned.hasPrefix("4") {
            detectedCardType = .visa
        } else if cleaned.hasPrefix("5") {
            detectedCardType = .mastercard
        } else if cleaned.hasPrefix("34") || cleaned.hasPrefix("37") {
            detectedCardType = .amex
        } else if cleaned.hasPrefix("6") {
            detectedCardType = .discover
        } else {
            detectedCardType = nil
        }
    }
    
    private func formatCardNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        var formatted = ""
        
        for (index, char) in cleaned.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted += String(char)
        }
        
        return formatted
    }
    
    private func addCard() {
        guard isFormValid else {
            let cleanedCardNumber = cardNumber.replacingOccurrences(of: " ", with: "")
            var errorDetails: [String] = []
            
            if cleanedCardNumber.count < 12 {
                errorDetails.append("Card number must be at least 12 digits")
            }
            if cardholderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorDetails.append("Cardholder name is required")
            }
            if cvv.count < 3 {
                errorDetails.append("CVV must be at least 3 digits")
            }
            if !isExpiryDateValid() {
                errorDetails.append("Expiry date must be in the future")
            }
            
            let errorMessage = errorDetails.isEmpty ? "Please fill in all required fields correctly" : errorDetails.joined(separator: "\n")
            showError(errorMessage)
            return
        }
        
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            
            let cleanedCardNumber = cardNumber.replacingOccurrences(of: " ", with: "")
            let lastFourDigits = String(cleanedCardNumber.suffix(4))
            
            let newPaymentMethod = UserPaymentMethod(
                id: UUID().uuidString,
                type: detectedCardType ?? .visa,
                lastFourDigits: lastFourDigits,
                expiryMonth: expiryMonth,
                expiryYear: expiryYear,
                cardholderName: cardholderName.trimmingCharacters(in: .whitespacesAndNewlines),
                isDefault: isDefault
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