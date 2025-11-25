import SwiftUI

struct ProviderPaymentSettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddBankAccount = false
    @State private var showingAddPaymentMethod = false
    @State private var showingPayoutHistory = false
    @State private var showingPaymentMethods = false
    @State private var bankAccounts: [BankAccount] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Header with Gradient
                VStack(spacing: 20) {
                    // Top Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Payment Settings")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Manage your earnings and payouts")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#BC6C5C"),
                            Color(hex: "#BC6C5C").opacity(0.9),
                            Color(hex: "#BC6C5C").opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
                
                // Content with Enhanced Styling
                PayoutsTab(
                    showingAddBankAccount: $showingAddBankAccount,
                    showingPayoutHistory: $showingPayoutHistory,
                    showingPaymentMethods: $showingPaymentMethods,
                    bankAccounts: $bankAccounts
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)

            .sheet(isPresented: $showingAddBankAccount) {
                AddBankAccountSheet(bankAccounts: $bankAccounts)
            }
            .sheet(isPresented: $showingPayoutHistory) {
                PayoutHistoryScreen()
            }
            .sheet(isPresented: $showingPaymentMethods) {
                PaymentMethodsScreen()
            }
        }
    }
}

// MARK: - Tab Views

struct PayoutsTab: View {
    @Binding var showingAddBankAccount: Bool
    @Binding var showingPayoutHistory: Bool
    @Binding var showingPaymentMethods: Bool
    @Binding var bankAccounts: [BankAccount]
    @State private var availableBalance: Double = 0.0
    @State private var pendingPayouts: Double = 0.0
    @State private var totalEarnings: Double = 0.0
    @State private var commissionPaid: Double = 0.0
    @State private var nextPayoutDate: Date = Date()
    @State private var showingWithdrawalConfirmation = false
    @State private var showingWithdrawalSuccess = false
    @State private var withdrawalAmount: Double = 0.0
    @State private var heldFunds: Double = 0.0
    @State private var showingEditBankAccount = false
    @State private var bankAccountToEdit: BankAccount?
    @State private var showingDeleteConfirmation = false
    @State private var bankAccountToDelete: BankAccount?
    @State private var selectedBankAccountForWithdrawal: BankAccount?
    @State private var showingBankAccountSelection = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Balance Overview Card
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "banknote.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Earnings Overview")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("After 10% YUGI commission")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.6))
                        }
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            // Available Balance
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Available for Withdrawal")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                
                                Text("£\(String(format: "%.2f", availableBalance))")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Accumulated earnings")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yugiGray.opacity(0.6))
                            }
                            
                            Divider()
                                .frame(height: 40)
                            
                            // Held Funds
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pending")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                
                                Text("£\(String(format: "%.2f", heldFunds))")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                
                                Text("72-hour holding period")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yugiGray.opacity(0.6))
                            }
                            
                            Spacer()
                        }
                        
                        // Commission Breakdown
                        VStack(spacing: 12) {
                            HStack {
                                Text("Total Bookings")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                
                                Spacer()
                                
                                Text("£\(String(format: "%.2f", totalEarnings))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Your Earnings")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text("£\(String(format: "%.2f", availableBalance))")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                    
                                    Text("-10%")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.yugiCream.opacity(0.4))
                        .cornerRadius(12)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
                )
                
                // Bank Accounts Section
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bank Accounts")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("Where your earnings are sent")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Button {
                            showingAddBankAccount = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                    }
                    
                    if bankAccounts.isEmpty {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "building.columns")
                                .font(.system(size: 48))
                                .foregroundColor(.yugiGray.opacity(0.4))
                            
                            VStack(spacing: 8) {
                                Text("No Bank Accounts")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Add your first bank account to receive payouts")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(32)
                        .background(Color.yugiCream.opacity(0.4))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(bankAccounts) { account in
                                BankAccountCard(
                                    account: account,
                                    onSetDefault: { setDefaultAccount(account) },
                                    onEdit: { editAccount(account) },
                                    onDelete: { deleteAccount(account) }
                                )
                            }
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
                )
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quick Actions")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("Manage your payouts and history")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.6))
                        }
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        // Withdrawal Button (available anytime if funds exist)
                        QuickActionRow(
                            title: "Withdraw Funds",
                            subtitle: getWithdrawalSubtitle(),
                            icon: "arrow.down.circle.fill",
                            isEnabled: availableBalance > 0 && !bankAccounts.isEmpty
                        ) {
                            initiateWithdrawal()
                        }
                        
                        QuickActionRow(
                            title: "Payout History",
                            subtitle: "View all your past transfers",
                            icon: "clock.fill",
                            isEnabled: true
                        ) {
                            showingPayoutHistory = true
                        }
                        
                        QuickActionRow(
                            title: "Manage Payment Methods",
                            subtitle: "Add, edit, or remove payment cards",
                            icon: "creditcard.fill",
                            isEnabled: true
                        ) {
                            showingPaymentMethods = true
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.yugiCream,
                    Color.yugiCream.opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            calculateBalances()
        }
        .alert("Confirm Withdrawal", isPresented: $showingWithdrawalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Withdraw £\(String(format: "%.2f", withdrawalAmount))", role: .destructive) {
                processWithdrawal()
            }
        } message: {
            if let selectedAccount = selectedBankAccountForWithdrawal {
                Text("Are you sure you want to withdraw £\(String(format: "%.2f", withdrawalAmount)) to \(selectedAccount.bankName) • ****\(String(selectedAccount.accountNumber.suffix(4)))? This amount will be transferred within 3-5 business days.")
            } else {
                Text("Are you sure you want to withdraw £\(String(format: "%.2f", withdrawalAmount)) to your bank account? This amount will be transferred within 3-5 business days.")
            }
        }
        .alert("Withdrawal Successful", isPresented: $showingWithdrawalSuccess) {
            Button("OK") { }
        } message: {
            if let selectedAccount = selectedBankAccountForWithdrawal {
                Text("Your withdrawal of £\(String(format: "%.2f", withdrawalAmount)) has been processed and will be transferred to \(selectedAccount.bankName) • ****\(String(selectedAccount.accountNumber.suffix(4))) within 3-5 business days.")
            } else {
                Text("Your withdrawal of £\(String(format: "%.2f", withdrawalAmount)) has been processed. Funds will be transferred to your bank account within 3-5 business days.")
            }
        }
        .alert("Delete Bank Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let accountToDelete = bankAccountToDelete {
                    removeBankAccount(accountToDelete)
                }
            }
        } message: {
            Text("Are you sure you want to delete this bank account? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditBankAccount) {
            if let accountToEdit = bankAccountToEdit {
                EditBankAccountSheet(
                    bankAccounts: $bankAccounts,
                    accountToEdit: accountToEdit
                )
            }
        }
        .sheet(isPresented: $showingBankAccountSelection) {
            BankAccountSelectionSheet(
                bankAccounts: bankAccounts,
                selectedAccount: $selectedBankAccountForWithdrawal,
                onConfirm: {
                    showingBankAccountSelection = false
                    withdrawalAmount = availableBalance
                    showingWithdrawalConfirmation = true
                }
            )
        }
    }
    
    private func calculateBalances() {
        // Sample data - in real app, this would come from your booking service
        let sampleBookings = [
            PaymentBooking(
                amount: 25.0, 
                date: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                classCompletedAt: Date().addingTimeInterval(-86400 * 7), // Class completed 7 days ago
                hasDispute: false
            ),
            PaymentBooking(
                amount: 30.0, 
                date: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                classCompletedAt: Date().addingTimeInterval(-86400 * 3), // Class completed 3 days ago
                hasDispute: false
            ),
            PaymentBooking(
                amount: 20.0, 
                date: Date().addingTimeInterval(-86400 * 1), // 1 day ago
                classCompletedAt: Date().addingTimeInterval(-86400 * 1), // Class completed 1 day ago
                hasDispute: false
            ),
            PaymentBooking(
                amount: 35.0, 
                date: Date(), // Today
                classCompletedAt: Date(), // Class completed today
                hasDispute: false
            ),
            // Example of a booking with a dispute
            PaymentBooking(
                amount: 40.0,
                date: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                classCompletedAt: Date().addingTimeInterval(-86400 * 5), // Class completed 5 days ago
                hasDispute: true // This booking has a dispute
            )
        ]
        
        // Calculate total earnings from all bookings
        totalEarnings = sampleBookings.reduce(0) { $0 + $1.amount }
        
        // Calculate commission (10%)
        commissionPaid = totalEarnings * 0.10
        
        // Calculate net earnings after commission
        let netEarnings = totalEarnings - commissionPaid
        
        // Calculate held funds (bookings within 72-hour holding period or with disputes)
        let currentDate = Date()
        let seventyTwoHoursInSeconds: TimeInterval = 72 * 3600 // 72 hours in seconds
        
        heldFunds = sampleBookings.reduce(0) { total, booking in
            let timeSinceCompletion = currentDate.timeIntervalSince(booking.classCompletedAt)
            let isWithinHoldingPeriod = timeSinceCompletion < seventyTwoHoursInSeconds
            let hasDispute = booking.hasDispute
            
            // Funds are held if within 72-hour period OR if there's a dispute
            if isWithinHoldingPeriod || hasDispute {
                return total + (booking.amount * 0.9) // Net amount after 10% commission
            } else {
                return total
            }
        }
        
        // Available balance is net earnings minus held funds
        availableBalance = netEarnings - heldFunds
        
        // Set next payout date
        nextPayoutDate = getNextPayoutDate()
    }
    
    private func getLastWorkingDayOfMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // Get the last day of the current month
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth + 1 // Next month
        components.day = 0 // This gives us the last day of current month
        
        guard let lastDayOfMonth = calendar.date(from: components) else {
            return 28 // Fallback
        }
        
        let lastDay = calendar.component(.day, from: lastDayOfMonth)
        
        // Find the last working day by going backwards from the last day
        for day in stride(from: lastDay, through: 1, by: -1) {
            components.day = day
            if let date = calendar.date(from: components) {
                let weekday = calendar.component(.weekday, from: date)
                // Saturday = 7, Sunday = 1
                if weekday != 1 && weekday != 7 {
                    return day
                }
            }
        }
        
        return 28 // Fallback if no working day found
    }
    
    private func getNextPayoutDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let currentDay = calendar.component(.day, from: now)
        
        // Create components for the payout date
        var components = DateComponents()
        components.year = currentYear
        
        // Determine which month to use for payout
        if currentDay >= getLastWorkingDayOfMonth() {
            // If we're past the last working day, use next month's payout date
            components.month = currentMonth + 1
        } else {
            // Otherwise use current month's payout date
            components.month = currentMonth
        }
        
        // Find the last working day of the target month
        components.day = getLastWorkingDayOfMonth()
        return calendar.date(from: components) ?? now
    }
    
    private func formatNextPayoutDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: nextPayoutDate)
    }
    
    private func isLastWorkingDayOfMonth() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentDay = calendar.component(.day, from: now)
        let lastWorkingDayOfMonth = getLastWorkingDayOfMonth()
        return currentDay >= lastWorkingDayOfMonth
    }
    
    private func processWithdrawal() {
        // In a real app, you would send this amount to your backend
        // and then update the availableBalance
        // For this example, we'll just simulate a successful withdrawal
        print("Withdrawing £\(String(format: "%.2f", withdrawalAmount))")
        
        // Simulate a delay for the withdrawal process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            availableBalance -= withdrawalAmount
            // Funds are withdrawn, so we reduce the available balance
            // The remaining funds stay in the account for future withdrawals
            showingWithdrawalSuccess = true
        }
    }
    
    private func setDefaultAccount(_ account: BankAccount) {
        // Update all accounts to set the selected one as default
        for i in 0..<bankAccounts.count {
            bankAccounts[i] = BankAccount(
                id: bankAccounts[i].id,
                accountName: bankAccounts[i].accountName,
                accountNumber: bankAccounts[i].accountNumber,
                sortCode: bankAccounts[i].sortCode,
                bankName: bankAccounts[i].bankName,
                isDefault: bankAccounts[i].id == account.id
            )
        }
    }
    
    private func editAccount(_ account: BankAccount) {
        bankAccountToEdit = account
        showingEditBankAccount = true
    }
    
    private func deleteAccount(_ account: BankAccount) {
        bankAccountToDelete = account
        showingDeleteConfirmation = true
    }
    
    private func removeBankAccount(_ account: BankAccount) {
        bankAccounts.removeAll { $0.id == account.id }
        bankAccountToDelete = nil
    }
    
    private func getWithdrawalSubtitle() -> String {
        if availableBalance <= 0 {
            return "No funds available for withdrawal"
        } else if bankAccounts.isEmpty {
            return "Add a bank account to withdraw funds"
        } else if bankAccounts.count == 1 {
            return "Withdraw to \(bankAccounts[0].bankName)"
        } else {
            return "Choose account to withdraw to"
        }
    }
    
    private func initiateWithdrawal() {
        if bankAccounts.count == 1 {
            // Only one account, use it directly
            selectedBankAccountForWithdrawal = bankAccounts[0]
            withdrawalAmount = availableBalance
            showingWithdrawalConfirmation = true
        } else {
            // Multiple accounts, show selection sheet
            showingBankAccountSelection = true
        }
    }
}

// MARK: - Supporting Models

struct PaymentBooking {
    let amount: Double
    let date: Date
    let classCompletedAt: Date
    let hasDispute: Bool
}

// MARK: - Supporting Views

struct BankAccount: Identifiable {
    let id: String
    let accountName: String
    let accountNumber: String
    let sortCode: String
    let bankName: String
    let isDefault: Bool
}

struct BankAccountCard: View {
    let account: BankAccount
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Bank Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#BC6C5C").opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "#BC6C5C"))
            }
            
            // Account Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(account.accountName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    
                    if account.isDefault {
                        Text("Default")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#BC6C5C"))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                
                Text("\(account.bankName) • \(account.accountNumber) • \(account.sortCode)")
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.7))
            }
            
            Spacer()
            
            // Actions
            Menu {
                Button("Set as Default") {
                    onSetDefault()
                }
                
                Button("Edit Details") {
                    onEdit()
                }
                
                Button("Remove", role: .destructive) {
                    onDelete()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.yugiGray.opacity(0.6))
            }
        }
        .padding(16)
        .background(Color.yugiCream.opacity(0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
        )
    }
}

struct QuickActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isEnabled ? Color(hex: "#BC6C5C") : .yugiGray.opacity(0.4))
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isEnabled ? .yugiGray : .yugiGray.opacity(0.4))
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(isEnabled ? .yugiGray.opacity(0.7) : .yugiGray.opacity(0.3))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(isEnabled ? .yugiGray.opacity(0.5) : .yugiGray.opacity(0.2))
            }
            .padding(16)
            .background(Color.yugiCream.opacity(0.4))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview {
    ProviderPaymentSettingsScreen()
}

// MARK: - Add Bank Account Sheet

struct AddBankAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bankAccounts: [BankAccount]
    @State private var accountName = ""
    @State private var accountNumber = ""
    @State private var sortCode = ""
    @State private var bankName = ""
    @State private var isDefault = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Add Bank Account")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("Enter your bank account details")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .background(Color.yugiCream.opacity(0.3))
                
                // Form
                ScrollView {
                    VStack(spacing: 24) {
                        // Account Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            TextField("e.g., Main Business Account", text: $accountName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Bank Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bank Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            TextField("e.g., Barclays Bank", text: $bankName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Account Number
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account Number")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            TextField("8 digits", text: $accountNumber)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        
                        // Sort Code
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sort Code")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            TextField("XX-XX-XX", text: $sortCode)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        
                        // Default Account Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Set as Default Account")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("This account will be used for all payouts")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $isDefault)
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                        }
                        .padding(16)
                        .background(Color.yugiCream.opacity(0.4))
                        .cornerRadius(12)
                        
                        // Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                
                                Text("Security Notice")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                            }
                            
                            Text("Your bank details are encrypted and stored securely. We use industry-standard security measures to protect your information.")
                                .font(.system(size: 14))
                                .foregroundColor(.yugiGray.opacity(0.7))
                                .lineLimit(nil)
                        }
                        .padding(16)
                        .background(Color(hex: "#BC6C5C").opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.yugiGray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBankAccount()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .disabled(!isFormValid)
                }
            }
        }
        .alert("Bank Account", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !accountName.isEmpty && 
        !accountNumber.isEmpty && 
        !sortCode.isEmpty && 
        !bankName.isEmpty &&
        accountNumber.count == 8 &&
        sortCode.count == 6
    }
    
    private func saveBankAccount() {
        // Validate form
        guard isFormValid else {
            alertMessage = "Please fill in all fields correctly"
            showingAlert = true
            return
        }
        
        // Create new bank account
        let newAccount = BankAccount(
            id: UUID().uuidString, // Generate a unique ID
            accountName: accountName,
            accountNumber: accountNumber,
            sortCode: sortCode,
            bankName: bankName,
            isDefault: isDefault
        )
        
        // Add to the binding array
        bankAccounts.append(newAccount)
        
        // Here you would typically save to your backend/database
        // For now, we'll just show a success message
        alertMessage = "Bank account added successfully!"
        showingAlert = true
    }
}

// MARK: - Payout History Screen

struct PayoutHistoryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var payoutHistory: [PayoutTransfer] = []
    @State private var isLoading = true
    @State private var selectedFilter: PayoutFilter = .all
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Payout History")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("All your past transfers")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Summary Card
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Transferred")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.7))
                            
                            Text("£\(String(format: "%.2f", totalTransferred))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .background(Color.yugiCream.opacity(0.3))
                
                // Filter and Search
                VStack(spacing: 16) {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(PayoutFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    title: filter.displayName,
                                    isSelected: selectedFilter == filter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.yugiGray.opacity(0.6))
                        
                        TextField("Search transfers...", text: $searchText)
                            .font(.system(size: 16))
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.yugiGray.opacity(0.6))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yugiGray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 16)
                
                // Payout List
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#BC6C5C")))
                    Spacer()
                } else if filteredPayouts.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 64))
                            .foregroundColor(.yugiGray.opacity(0.4))
                        
                        VStack(spacing: 8) {
                            Text("No Transfers Yet")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            Text("Your payout history will appear here once you receive transfers")
                                .font(.system(size: 16))
                                .foregroundColor(.yugiGray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(32)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPayouts) { payout in
                                PayoutTransferCard(payout: payout)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.yugiGray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshPayoutHistory()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                    }
                }
            }
        }
        .onAppear {
            loadPayoutHistory()
        }
    }
    
    private var totalTransferred: Double {
        payoutHistory.reduce(0) { $0 + $1.amount }
    }
    
    private var filteredPayouts: [PayoutTransfer] {
        var filtered = payoutHistory
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .completed:
            filtered = filtered.filter { $0.status == .completed }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { payout in
                payout.referenceNumber.localizedCaseInsensitiveContains(searchText) ||
                payout.bankAccount.localizedCaseInsensitiveContains(searchText) ||
                String(format: "%.2f", payout.amount).contains(searchText)
            }
        }
        
        return filtered.sorted { $0.date > $1.date }
    }
    
    private func loadPayoutHistory() {
        isLoading = true
        
        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Sample data - in real app, this would come from your backend
            self.payoutHistory = [
                PayoutTransfer(
                    id: "1",
                    amount: 245.50,
                    date: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                    status: .completed,
                    referenceNumber: "PAY-2024-001",
                    bankAccount: "Barclays • ****1234",
                    description: "Monthly payout - January 2024"
                ),
                PayoutTransfer(
                    id: "2",
                    amount: 189.75,
                    date: Date().addingTimeInterval(-86400 * 15), // 15 days ago
                    status: .completed,
                    referenceNumber: "PAY-2024-002",
                    bankAccount: "Barclays • ****1234",
                    description: "Monthly payout - December 2023"
                ),
                PayoutTransfer(
                    id: "3",
                    amount: 312.00,
                    date: Date().addingTimeInterval(-86400 * 45), // 45 days ago
                    status: .completed,
                    referenceNumber: "PAY-2024-003",
                    bankAccount: "Barclays • ****1234",
                    description: "Monthly payout - November 2023"
                ),
                PayoutTransfer(
                    id: "4",
                    amount: 156.25,
                    date: Date().addingTimeInterval(-86400 * 75), // 75 days ago
                    status: .completed,
                    referenceNumber: "PAY-2024-004",
                    bankAccount: "Barclays • ****1234",
                    description: "Monthly payout - October 2023"
                )
            ]
            self.isLoading = false
        }
    }
    
    private func refreshPayoutHistory() {
        loadPayoutHistory()
    }
}

// MARK: - Supporting Models

struct PayoutTransfer: Identifiable {
    let id: String
    let amount: Double
    let date: Date
    let status: PayoutStatus
    let referenceNumber: String
    let bankAccount: String
    let description: String
}

enum PayoutStatus: String, CaseIterable {
    case completed = "completed"
    case pending = "pending"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .completed: return "Completed"
        case .pending: return "Pending"
        case .failed: return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .completed: return .green
        case .pending: return Color(hex: "#BC6C5C")
        case .failed: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

enum PayoutFilter: String, CaseIterable {
    case all = "all"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .completed: return "Completed"
        }
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .yugiGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color(hex: "#BC6C5C") : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "#BC6C5C"), lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct PayoutTransferCard: View {
    let payout: PayoutTransfer
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(payout.description)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    
                    Text(payout.referenceNumber)
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("£\(String(format: "%.2f", payout.amount))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.yugiGray)
                    
                    HStack(spacing: 6) {
                        Image(systemName: payout.status.icon)
                            .font(.system(size: 12))
                            .foregroundColor(payout.status.color)
                        
                        Text(payout.status.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(payout.status.color)
                    }
                }
            }
            
            Divider()
            
            // Details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bank Account")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yugiGray.opacity(0.7))
                    
                    Text(payout.bankAccount)
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Date")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yugiGray.opacity(0.7))
                    
                    Text(formatDate(payout.date))
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yugiGray.opacity(0.2), lineWidth: 1)
            )
    }
} 

// MARK: - Edit Bank Account Sheet

struct EditBankAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bankAccounts: [BankAccount]
    let accountToEdit: BankAccount
    @State private var accountName: String
    @State private var accountNumber: String
    @State private var sortCode: String
    @State private var bankName: String
    @State private var isDefault: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(bankAccounts: Binding<[BankAccount]>, accountToEdit: BankAccount) {
        self._bankAccounts = bankAccounts
        self.accountToEdit = accountToEdit
        self._accountName = State(initialValue: accountToEdit.accountName)
        self._accountNumber = State(initialValue: accountToEdit.accountNumber)
        self._sortCode = State(initialValue: accountToEdit.sortCode)
        self._bankName = State(initialValue: accountToEdit.bankName)
        self._isDefault = State(initialValue: accountToEdit.isDefault)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Edit Bank Account")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("Update your bank account details")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .background(Color.yugiCream.opacity(0.3))
                
                // Form
                ScrollView {
                    VStack(spacing: 24) {
                        // Account Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            TextField("e.g., Main Business Account", text: $accountName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Bank Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bank Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            TextField("e.g., Barclays Bank", text: $bankName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Account Number
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account Number")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            TextField("8 digits", text: $accountNumber)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        
                        // Sort Code
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sort Code")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            TextField("XX-XX-XX", text: $sortCode)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        
                        // Default Account Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Set as Default Account")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("This account will be used for all payouts")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $isDefault)
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                        }
                        .padding(16)
                        .background(Color.yugiCream.opacity(0.4))
                        .cornerRadius(12)
                        
                        // Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                
                                Text("Security Notice")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                            }
                            
                            Text("Your bank details are encrypted and stored securely. We use industry-standard security measures to protect your information.")
                                .font(.system(size: 14))
                                .foregroundColor(.yugiGray.opacity(0.7))
                                .lineLimit(nil)
                        }
                        .padding(16)
                        .background(Color(hex: "#BC6C5C").opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.yugiGray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateBankAccount()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .disabled(!isFormValid)
                }
            }
        }
        .alert("Bank Account", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !accountName.isEmpty && 
        !accountNumber.isEmpty && 
        !sortCode.isEmpty && 
        !bankName.isEmpty &&
        accountNumber.count == 8 &&
        sortCode.count == 6
    }
    
    private func updateBankAccount() {
        // Validate form
        guard isFormValid else {
            alertMessage = "Please fill in all fields correctly"
            showingAlert = true
            return
        }
        
        // Update the bank account in the array
        if let index = bankAccounts.firstIndex(where: { $0.id == accountToEdit.id }) {
            // If setting this account as default, remove default from others
            if isDefault {
                for i in 0..<bankAccounts.count {
                    bankAccounts[i] = BankAccount(
                        id: bankAccounts[i].id,
                        accountName: bankAccounts[i].accountName,
                        accountNumber: bankAccounts[i].accountNumber,
                        sortCode: bankAccounts[i].sortCode,
                        bankName: bankAccounts[i].bankName,
                        isDefault: false
                    )
                }
            }
            
            // Update the current account
            bankAccounts[index] = BankAccount(
                id: accountToEdit.id,
                accountName: accountName,
                accountNumber: accountNumber,
                sortCode: sortCode,
                bankName: bankName,
                isDefault: isDefault
            )
            
            alertMessage = "Bank account updated successfully!"
            showingAlert = true
        }
    }
} 

// MARK: - Bank Account Selection Sheet

struct BankAccountSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bankAccounts: [BankAccount]
    @Binding var selectedAccount: BankAccount?
    let onConfirm: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Select Bank Account")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("Choose which account to withdraw to")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .background(Color.yugiCream.opacity(0.3))
                
                // Bank Account List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(bankAccounts) { account in
                            BankAccountSelectionCard(
                                account: account,
                                isSelected: selectedAccount?.id == account.id
                            ) {
                                selectedAccount = account
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.yugiGray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        onConfirm()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(selectedAccount != nil ? Color(hex: "#BC6C5C") : .yugiGray.opacity(0.5))
                    .disabled(selectedAccount == nil)
                }
            }
        }
    }
}

struct BankAccountSelectionCard: View {
    let account: BankAccount
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Bank Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#BC6C5C").opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                
                // Account Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(account.accountName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        if account.isDefault {
                            Text("Default")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#BC6C5C"))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    
                    Text("\(account.bankName) • ****\(String(account.accountNumber.suffix(4)))")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                // Selection Indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#BC6C5C") : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#BC6C5C").opacity(0.1) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "#BC6C5C") : Color.yugiGray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
} 