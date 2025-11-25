import SwiftUI
import Combine

// MARK: - Shared Storage for New Classes
class NewClassStorage: ObservableObject {
    static let shared = NewClassStorage()
    @Published var newClasses: [ProviderClass] = []
    
    private init() {}
    
    func addNewClass(_ classData: ClassCreationData) {
        let newClass = ProviderClass(
            id: UUID().uuidString,
            name: classData.className,
            description: classData.description,
            category: classData.category,
            price: classData.price,
            isFree: classData.isFree,
            maxCapacity: classData.maxCapacity,
            currentBookings: 0,
            isPublished: true,
            status: ClassStatus.upcoming,
            location: classData.location.isEmpty ? "Location TBD" : classData.location,
            nextSession: classData.classDates.first?.date,
            createdAt: Date()
        )
        
        newClasses.insert(newClass, at: 0)
        print("💾 NewClassStorage: Added new class '\(classData.className)'. Total new classes: \(newClasses.count)")
    }
    
    func clearNewClasses() {
        newClasses.removeAll()
    }
}

// MARK: - Provider Children Service
class ProviderChildrenService: ObservableObject {
    static let shared = ProviderChildrenService()
    
    @Published var children: [Child] = []
    
    private init() {}
    
    func addChild(_ child: Child) {
        children.append(child)
        print("👶 ProviderChildrenService: Added child: \(child.name)")
    }
    
    func updateChild(_ child: Child) {
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = child
            print("👶 ProviderChildrenService: Updated child: \(child.name)")
        }
    }
    
    func removeChild(withId id: String) {
        children.removeAll { $0.id == id }
        print("👶 ProviderChildrenService: Removed child with ID: \(id)")
    }
    
    func clearChildren() {
        children.removeAll()
        print("👶 ProviderChildrenService: Cleared all children")
    }
}

// MARK: - ProviderClass Model (for shared storage)
struct ProviderClass: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: ClassCategory
    let price: Double
    let isFree: Bool
    let maxCapacity: Int
    let currentBookings: Int
    var isPublished: Bool
    var status: ClassStatus
    let location: String
    let nextSession: Date?
    let createdAt: Date
}

struct ProviderDashboardScreen: View {
    let businessName: String
    @State private var verificationStatus: ProviderVerificationStatus = .approved
    @State private var shouldNavigateToClassDiscovery = false
    @State private var shouldNavigateToProfileCompletion = false
    @State private var shouldNavigateToClassCreation = false
    @State private var shouldNavigateToBookings = false
    @State private var shouldNavigateToTermsPrivacy = false
    @State private var shouldNavigateToAcceptedTerms = false
    @State private var shouldNavigateToGuidelines = false
    @State private var shouldNavigateToBusinessProfile = false
    @State private var hasAcceptedTerms = false
    @State private var shouldNavigateToPaymentSettings = false
    @State private var shouldNavigateToMyClasses = false
    @State private var shouldNavigateToClassSearch = false
    @State private var shouldNavigateToChildrenBookings = false

    @State private var showingHelpSupport = false
    @State private var showingAddChild = false
    @State private var showingEditChild = false
    @State private var childToEdit: Child? = nil
    @State private var children: [Child] = []
    @State private var shouldSignOut = false
    @StateObject private var businessService = ProviderBusinessService.shared
    @StateObject private var providerChildrenService = ProviderChildrenService.shared
    
    private var displayBusinessName: String {
        // Prioritize current user's business name, then businessService, then fallback
        if let currentUser = APIService.shared.currentUser,
           let userBusinessName = currentUser.businessName,
           !userBusinessName.isEmpty {
            return userBusinessName
        } else if !businessService.businessInfo.name.isEmpty {
            return businessService.businessInfo.name
        } else {
            return businessName
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Provider Dashboard")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Welcome back, \(displayBusinessName)")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.top)
                    
                    // Terms & Conditions Required - Show immediately if not accepted
                    if !hasAcceptedTerms {
                        TermsRequiredCard {
                            shouldNavigateToTermsPrivacy = true
                        }
                    } else {
                        // Verification Status Card
                        VerificationStatusCard(status: verificationStatus)
                        
                        // Quick Actions
                        if verificationStatus == .approved {
                            // Quick Actions Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Quick Actions")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ProviderQuickActionButton(
                                        title: "Create Class",
                                        icon: "plus.circle",
                                        color: .white
                                    ) {
                                        shouldNavigateToClassCreation = true
                                    }
                                    
                                    ProviderQuickActionButton(
                                        title: "My Classes",
                                        icon: "list.bullet",
                                        color: .white
                                    ) {
                                        shouldNavigateToMyClasses = true
                                    }
                                    
                                    ProviderQuickActionButton(
                                        title: "Bookings",
                                        icon: "calendar",
                                        color: .white
                                    ) {
                                        shouldNavigateToBookings = true
                                    }
                                    
                                    ProviderQuickActionButton(
                                        title: "Discover",
                                        icon: "magnifyingglass",
                                        color: .white
                                    ) {
                                        shouldNavigateToClassSearch = true
                                    }
                                }
                            }
                        } else {
                            // Pending Actions for non-approved providers
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Next Steps")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 12) {
                                    PendingActionButton(
                                        title: "Complete Profile",
                                        subtitle: "Add your business information",
                                        icon: "person.crop.circle.plus",
                                        color: .white
                                    ) {
                                        shouldNavigateToProfileCompletion = true
                                    }
                                    
                                    PendingActionButton(
                                        title: "Read Guidelines",
                                        subtitle: "Learn about our policies",
                                        icon: "book",
                                        color: .white
                                    ) {
                                        shouldNavigateToGuidelines = true
                                    }
                                }
                            }
                        }
                        
                        // Account Management
                        AccountManagementSection(
                            hasAcceptedTerms: hasAcceptedTerms,
                            onViewTerms: {
                                shouldNavigateToAcceptedTerms = true
                            },
                            onBusinessProfile: {
                                shouldNavigateToBusinessProfile = true
                            },
                            onPaymentSettings: {
                                shouldNavigateToPaymentSettings = true
                            },
                            onSupport: {
                                showingHelpSupport = true
                            },
                            shouldNavigateToChildrenBookings: $shouldNavigateToChildrenBookings,
                            children: providerChildrenService.children,
                            showingAddChild: $showingAddChild,
                            showingEditChild: $showingEditChild,
                            childToEdit: $childToEdit,
                            shouldNavigateToClassCreation: $shouldNavigateToClassCreation,
                            shouldNavigateToAcceptedTerms: $shouldNavigateToAcceptedTerms,

                        )
                        
                        // Log Out Button
                        VStack(spacing: 16) {
                            Button(action: {
                                // Clear user data (but keep terms acceptance)
                                ProviderChildrenService.shared.clearChildren()
                                NewClassStorage.shared.clearNewClasses()
                                
                                // Trigger logout
                                shouldSignOut = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Text("Log Out")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 20)
                    }
                }
                .padding()
            }
            .background(Color(hex: "#BC6C5C").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showingHelpSupport) {
                HelpSupportScreen()
            }
            .sheet(isPresented: $shouldNavigateToTermsPrivacy) {
                TermsPrivacyScreen(onTermsAccepted: {
                    // Update the state when terms are accepted
                    hasAcceptedTerms = true
                    // Save to UserDefaults so it persists across app launches
                    UserDefaults.standard.set(true, forKey: "providerTermsAccepted")
                }, userType: .provider)
            }
            .sheet(isPresented: $showingAddChild) {
                AddChildScreen { newChild in
                    providerChildrenService.addChild(newChild)
                    print("👶 ProviderDashboard: Added child: \(newChild.name)")
                }
            }
            .sheet(isPresented: $showingEditChild) {
                if let childToEdit = childToEdit {
                    AddChildScreen(childToEdit: childToEdit) { updatedChild in
                        providerChildrenService.updateChild(updatedChild)
                        print("👶 ProviderDashboard: Updated child: \(updatedChild.name)")
                    } onDelete: { childId in
                        providerChildrenService.removeChild(withId: childId)
                        print("👶 ProviderDashboard: Deleted child with ID: \(childId)")
                    }
                } else {
                    Text("Error: No child selected for editing")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .onChange(of: showingEditChild) { oldValue, newValue in
                if newValue, let childToEdit = childToEdit {
                    print("👶 ProviderDashboard: Presenting edit sheet for child: \(childToEdit.name)")
                } else if newValue {
                    print("👶 ProviderDashboard: No child to edit, this shouldn't happen")
                }
            }

            .navigationDestination(isPresented: $shouldNavigateToProfileCompletion) {
                ProviderProfileCompletionScreen()
            }
            .sheet(isPresented: $shouldNavigateToClassCreation) {
                ProviderClassCreationScreen(
                    businessName: displayBusinessName,
                    onClassPublished: { classData in
                        print("🏠 ProviderDashboard: Class published callback triggered")
                        print("🏠 ProviderDashboard: Class name: \(classData.className)")
                        
                        // Add to shared storage so it appears in My Classes
                        NewClassStorage.shared.addNewClass(classData)
                        
                        shouldNavigateToClassCreation = false // Dismiss the class creation screen
                        shouldNavigateToMyClasses = true // Navigate to My Classes
                    }
                )
            }
            .sheet(isPresented: $shouldNavigateToBookings) {
                ProviderBookingsScreen(businessName: displayBusinessName)
            }
            .sheet(isPresented: $shouldNavigateToAcceptedTerms) {
                TermsPrivacyScreen(isReadOnly: true, onTermsAccepted: {
                    hasAcceptedTerms = true
                }, userType: .provider)
            }
            .sheet(isPresented: $shouldNavigateToGuidelines) {
                ProviderGuidelinesScreen()
            }
            .sheet(isPresented: $shouldNavigateToBusinessProfile) {
                ProviderBusinessProfileScreen(businessName: displayBusinessName)
            }
            .sheet(isPresented: $shouldNavigateToPaymentSettings) {
                ProviderPaymentSettingsScreen()
            }
            .sheet(isPresented: $shouldNavigateToMyClasses) {
                ProviderMyClassesScreen(businessName: displayBusinessName)
            }
            .sheet(isPresented: $shouldNavigateToClassSearch) {
                ClassSearchView()
            }
            .sheet(isPresented: $shouldNavigateToChildrenBookings) {
                ProviderChildrenBookingsScreen(businessName: displayBusinessName)
            }

            .fullScreenCover(isPresented: $shouldSignOut) {
                // This will show the welcome screen when user logs out
                NavigationStack {
                    WelcomeScreen()
                }
            }
        }
        .onAppear {
            print("🏢 ProviderDashboardScreen: onAppear called")
            print("🏢 ProviderDashboardScreen: businessName = \(businessName)")
            print("🏢 ProviderDashboardScreen: verificationStatus = \(verificationStatus)")
            print("🏢 ProviderDashboardScreen: APIService.isAuthenticated = \(APIService.shared.isAuthenticated)")
            print("🏢 ProviderDashboardScreen: APIService.currentUser = \(APIService.shared.currentUser?.fullName ?? "nil")")
            print("🏢 ProviderDashboardScreen: APIService.currentUser.userType = \(APIService.shared.currentUser?.userType.rawValue ?? "nil")")
            print("🏢 ProviderDashboardScreen: APIService.currentUser.profileImage = \(APIService.shared.currentUser?.profileImage ?? "nil")")
            
            // Force authentication for testing if no user is authenticated
            if !APIService.shared.isAuthenticated {
                print("🏢 ProviderDashboardScreen: No user authenticated, forcing authentication for testing...")
                APIService.shared.forceAuthenticateForTesting(userType: .provider)
            }
            
            // Check if terms have been accepted
            hasAcceptedTerms = UserDefaults.standard.bool(forKey: "providerTermsAccepted")
            
            // Load business data
            businessService.loadBusinessData()
            
            // Handle children data based on user type
            #if DEBUG
            // Check if this is a test user (existing user with mock data) or a new user
            let isTestUser = APIService.shared.currentUser?.email.contains("test") == true
            if isTestUser && providerChildrenService.children.isEmpty {
                loadMockChildren()
            } else if !isTestUser {
                // Clear mock children for new users
                clearMockChildrenForNewUser()
            }
            #else
            // In production, always clear mock children for new users
            clearMockChildrenForNewUser()
            #endif
        }
        .onDisappear {
            print("🏢 ProviderDashboardScreen: onDisappear called")
        }

    }
    
    private func loadMockChildren() {
        // Mock data for demonstration - using consistent IDs for testing
        let mockChildren = [
            Child(childId: "provider_child_1", childName: "Emma", childAge: 2, childDateOfBirth: Date().addingTimeInterval(-365 * 2 * 24 * 60 * 60)), // 2 years ago
            Child(childId: "provider_child_2", childName: "Liam", childAge: 3, childDateOfBirth: Date().addingTimeInterval(-365 * 3 * 24 * 60 * 60)), // 3 years ago
            Child(childId: "provider_child_3", childName: "Ava", childAge: 2, childDateOfBirth: Date().addingTimeInterval(-365 * 2 * 24 * 60 * 60)), // 2 years ago
            Child(childId: UUID().uuidString, childName: "Johnson", childAge: 4, childDateOfBirth: Date().addingTimeInterval(-365 * 4 * 24 * 60 * 60)), // 4 years ago
            Child(childId: UUID().uuidString, childName: "Smith", childAge: 5, childDateOfBirth: Date().addingTimeInterval(-365 * 5 * 24 * 60 * 60)), // 5 years ago
            Child(childId: UUID().uuidString, childName: "Wilson", childAge: 4, childDateOfBirth: Date().addingTimeInterval(-365 * 4 * 24 * 60 * 60)), // 4 years ago
        ]
        
        // Add to shared service
        for child in mockChildren {
            providerChildrenService.addChild(child)
        }
        
        // Sync local array
        children = providerChildrenService.children
    }
    
    private func clearMockChildrenForNewUser() {
        // Clear any existing mock children for new users
        providerChildrenService.clearChildren()
        children = providerChildrenService.children
        print("👶 ProviderDashboard: Cleared mock children for new user")
    }
} 

// MARK: - Supporting Components

struct VerificationStatusCard: View {
    let status: ProviderVerificationStatus
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with enhanced styling
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: status.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(status.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(status.description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct TermsAcceptedCard: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Terms Accepted")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("You have accepted the terms and conditions")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.green.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct TermsAndConditionsCard: View {
    let onViewTerms: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Terms & Conditions")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Please review and accept our terms")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
            }
            
            Button(action: onViewTerms) {
                Text("View Terms")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

struct QuickActionsSection: View {
    @Binding var shouldNavigateToClassCreation: Bool
    @Binding var shouldNavigateToBookings: Bool
    @Binding var shouldNavigateToMyClasses: Bool
    @Binding var shouldNavigateToClassSearch: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ProviderQuickActionButton(
                    title: "Create Class",
                    icon: "plus.circle",
                    color: .white
                ) {
                    shouldNavigateToClassCreation = true
                }
                
                ProviderQuickActionButton(
                    title: "View Bookings",
                    icon: "calendar.badge.clock",
                    color: .white
                ) {
                    shouldNavigateToBookings = true
                }
                
                ProviderQuickActionButton(
                    title: "My Classes",
                    icon: "list.bullet",
                    color: .white
                ) {
                    shouldNavigateToMyClasses = true
                }
                
                ProviderQuickActionButton(
                    title: "Search Classes",
                    icon: "magnifyingglass",
                    color: .white
                ) {
                    print("🔍 ProviderDashboard: Search Classes button tapped")
                    print("🔍 ProviderDashboard: Setting shouldNavigateToClassSearch = true")
                    shouldNavigateToClassSearch = true
                    print("�� ProviderDashboard: shouldNavigateToClassSearch is now: \(shouldNavigateToClassSearch)")
                }
            }
        }
    }
}

struct PendingActionsSection: View {
    @Binding var shouldNavigateToClassDiscovery: Bool
    @Binding var shouldNavigateToProfileCompletion: Bool
    @Binding var shouldNavigateToGuidelines: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Get Started")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                PendingActionButton(
                    title: "Complete Profile",
                    subtitle: "Add your business information",
                    icon: "person.circle",
                    color: .white
                ) {
                    shouldNavigateToProfileCompletion = true
                }
                
                PendingActionButton(
                    title: "View Guidelines",
                    subtitle: "Learn about our policies",
                    icon: "book",
                    color: .white
                ) {
                    shouldNavigateToGuidelines = true
                }
                
                PendingActionButton(
                    title: "Browse Classes",
                    subtitle: "See what other providers offer",
                    icon: "magnifyingglass",
                    color: .white
                ) {
                    shouldNavigateToClassDiscovery = true
                }
            }
        }
    }
}

struct AccountManagementSection: View {
    let hasAcceptedTerms: Bool
    let onViewTerms: () -> Void
    let onBusinessProfile: () -> Void
    let onPaymentSettings: () -> Void
    let onSupport: () -> Void
    @Binding var shouldNavigateToChildrenBookings: Bool
    let children: [Child]
    @Binding var showingAddChild: Bool
    @Binding var showingEditChild: Bool
    @Binding var childToEdit: Child?
    @Binding var shouldNavigateToClassCreation: Bool
    @Binding var shouldNavigateToAcceptedTerms: Bool

    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Management")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                AccountActionButton(
                    title: "Business Profile",
                    subtitle: "Manage your business information",
                    icon: "building.2",
                    color: .white
                ) {
                    onBusinessProfile()
                }
                
                AccountActionButton(
                    title: "Payment Settings",
                    subtitle: "Manage your payment methods",
                    icon: "creditcard",
                    color: .white
                ) {
                    onPaymentSettings()
                }
                

                
                AccountActionButton(
                    title: "Help & Support",
                    subtitle: "Get help and contact support",
                    icon: "questionmark.circle",
                    color: .white
                ) {
                    onSupport()
                }
                
                AccountActionButton(
                    title: hasAcceptedTerms ? "Terms Accepted" : "Terms Required",
                    subtitle: hasAcceptedTerms ? "You have accepted the terms" : "Accept terms to create classes",
                    icon: "doc.text",
                    color: hasAcceptedTerms ? .green : .yellow
                ) {
                    if hasAcceptedTerms {
                        // Show read-only terms view
                        shouldNavigateToAcceptedTerms = true
                    } else {
                        // Direct to class creation to accept terms
                        shouldNavigateToClassCreation = true
                    }
                }
                
                AccountActionButton(
                    title: "Children Bookings",
                    subtitle: "Manage your children's classes",
                    icon: "person.2",
                    color: .white
                ) {
                    shouldNavigateToChildrenBookings = true
                }
            }
        }
    }
}

struct ProviderQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PendingActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AccountActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Screens

struct ProviderProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogoutConfirmation = false
    @State private var shouldSignOut = false
    let businessName: String
    let onLogout: () -> Void
    
    // Get actual user data from APIService
    private var currentUser: User? {
        APIService.shared.currentUser
    }
    
    private var userEmail: String {
        currentUser?.email ?? "No email available"
    }
    
    private var userPhone: String {
        currentUser?.phoneNumber ?? "No phone available"
    }
    
    private var userLocation: String {
        currentUser?.businessAddress ?? "No location available"
    }
    
    private var memberSince: String {
        guard let createdAt = currentUser?.createdAt else {
            return "Unknown"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: createdAt)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Avatar
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        
                        VStack(spacing: 8) {
                            Text(businessName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.yugiGray)
                            
                            Text("Provider Account")
                                .font(.system(size: 16))
                                .foregroundColor(.yugiGray.opacity(0.7))
                        }
                    }
                    .padding(.top, 20)
                    
                    // Account Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Account Information")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        VStack(spacing: 12) {
                            ProviderProfileInfoRow(
                                icon: "envelope",
                                title: "Email",
                                value: userEmail
                            )
                            
                            ProviderProfileInfoRow(
                                icon: "phone",
                                title: "Phone",
                                value: userPhone
                            )
                            
                            ProviderProfileInfoRow(
                                icon: "location",
                                title: "Location",
                                value: userLocation
                            )
                            
                            ProviderProfileInfoRow(
                                icon: "calendar",
                                title: "Member Since",
                                value: memberSince
                            )
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    // Logout Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Account")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        Button(action: {
                            showingLogoutConfirmation = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sign Out")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.red)
                                    
                                    Text("Sign out of your account")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .padding()
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    // App Version
                    VStack(spacing: 8) {
                        Text("YUGI")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray.opacity(0.7))
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.5))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
            .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    // Handle logout
                    print("🚪 ProviderProfileSheet: User signed out")
                    
                    // Clear user data (but keep terms acceptance)
                    ProviderChildrenService.shared.clearChildren()
                    NewClassStorage.shared.clearNewClasses()
                    
                    // Call the logout callback
                    onLogout()
                    
                    // Dismiss the profile sheet
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your account.")
            }
        }
    }
}

// MARK: - Supporting Views

struct ProviderProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray.opacity(0.7))
                
                Text(value)
                    .font(.system(size: 16))
                    .foregroundColor(.yugiGray)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct AcceptedTermsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Accepted Terms")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.yugiGray)
                
                Text("Terms and conditions accepted...")
                    .font(.system(size: 16))
                    .foregroundColor(.yugiGray.opacity(0.7))
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
        }
    }
}

struct ProviderGuidelinesScreen: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Provider Guidelines")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.yugiGray)
                
                Text("Guidelines and policies...")
                    .font(.system(size: 16))
                    .foregroundColor(.yugiGray.opacity(0.7))
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct TermsRequiredCard: View {
    let onAcceptTerms: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Title and Description
            VStack(spacing: 12) {
                Text("Terms & Conditions Required")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Before you can create classes or use YUGI's provider features, you must read and accept our Terms & Conditions and Privacy Policy.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Action Button
            Button(action: onAcceptTerms) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    
                    Text("Read & Accept Terms")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    ProviderDashboardScreen(businessName: "Sensory World")
} 
