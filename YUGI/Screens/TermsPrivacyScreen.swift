import SwiftUI

struct TermsPrivacyScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    let isReadOnly: Bool
    let onTermsAccepted: (() -> Void)?
    let userType: UserType
    
    init(isReadOnly: Bool = false, onTermsAccepted: (() -> Void)? = nil, userType: UserType = .parent) {
        self.isReadOnly = isReadOnly
        self.onTermsAccepted = onTermsAccepted
        self.userType = userType
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Terms & Conditions")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Read our terms of service and privacy policy")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Tab Selector
                HStack(spacing: 0) {
                    TermsPrivacyTabButton(
                        title: "Terms of Service",
                        isSelected: selectedTab == 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 0
                        }
                    }
                    
                    TermsPrivacyTabButton(
                        title: "Privacy Policy",
                        isSelected: selectedTab == 1
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 1
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(hex: "#BC6C5C"))
                
                // Content
                TabView(selection: $selectedTab) {
                    TermsOfServiceView(isReadOnly: isReadOnly, onTermsAccepted: onTermsAccepted, userType: userType)
                        .tag(0)
                    
                    PrivacyPolicyView()
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)

        }
    }
}

struct TermsPrivacyTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white.opacity(0.3) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

struct TermsOfServiceView: View {
    @State private var hasAcceptedTerms = false
    @Environment(\.dismiss) private var dismiss
    let isReadOnly: Bool
    let onTermsAccepted: (() -> Void)?
    let userType: UserType
    
    init(isReadOnly: Bool = false, onTermsAccepted: (() -> Void)? = nil, userType: UserType = .parent) {
        self.isReadOnly = isReadOnly
        self.onTermsAccepted = onTermsAccepted
        self.userType = userType
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Last Updated
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Updated: \(userType == .provider ? "October 15, 2025" : "October 15, 2025")")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                    
                    Text(userType == .provider ? "Provider Terms & Conditions" : "Parent/Guardian Terms & Conditions")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yugiGray)
                }
                
                if userType == .provider {
                    // Provider Terms & Conditions
                    TermsLegalSection(
                        title: "YUGI Group Limited - Provider Terms & Conditions",
                        content: "Effective Date: 15 October 2025\n\nCompany Name: YUGI Group Limited\nRegistered in England and Wales, Company No. 16318935\nRegistered Address: 167 Sandbanks Road, BH14 8EJ\nContact Email: info@yugiapp.ai"
                    )
                    
                    TermsLegalSection(
                        title: "1. Purpose of the Agreement",
                        content: "YUGI Group Limited (\"YUGI\", \"we\", \"our\", or \"us\") operates a digital platform that connects parents and guardians with baby, toddler, child, and wellness-focused classes. You (\"Provider\") are responsible for the delivery of your classes, while YUGI facilitates access, visibility, scheduling, and secure bookings."
                    )
                    
                    TermsLegalSection(
                        title: "2. Payments, Pricing and Platform Integrity",
                        content: "2.1 YUGI deducts a service fee of 10% from each completed and paid booking.\n\n2.2 Payments for completed classes enter a 3-day holding phase after the class takes place. You may withdraw funds once available after this holding phase, provided the class was delivered and is not subject to dispute.\n\n2.3 You are solely responsible for setting your own pricing.\n\n2.4 You agree to promote YUGI as your primary booking channel and not encourage users to book off-platform."
                    )
                    
                    TermsLegalSection(
                        title: "2A. Refunds and Disputes",
                        content: "2A.1 Parents or guardians may cancel a booking and receive a full refund if cancelled 24 hours or more before the class.\n\n2A.2 Payments enter a 3-day holding phase after each class. Funds are released after this period unless a dispute is raised.\n\n2A.3 If a dispute is raised, funds remain on hold until resolved.\n\n2A.4 YUGI may issue full or partial refunds at its discretion.\n\n2A.5 YUGI's decision on disputes and refunds is final."
                    )
                    
                    TermsLegalSection(
                        title: "3. Class Listings and Responsibilities",
                        content: "You must provide accurate class information and ensure listings remain up to date. You are solely responsible for class delivery, attendance, and participant safety. YUGI is not liable for downtime or interruptions."
                    )
                    
                    TermsLegalSection(
                        title: "4. Health, Safety and Safeguarding",
                        content: "You must comply with all UK health and safety laws, hold valid Public Liability Insurance (minimum £2 million), and conduct regular risk assessments. If working with children, you must hold an Enhanced DBS certificate and comply with all safeguarding requirements."
                    )
                    
                    TermsLegalSection(
                        title: "5. Cancellations and Non-Delivery",
                        content: "If you cancel a class, notify YUGI and all users immediately. Parents or guardians will receive a full refund of the amount paid for that class. Frequent cancellations may result in account suspension or removal."
                    )
                    
                    TermsLegalSection(
                        title: "6. Insurance and Liability",
                        content: "You operate as an independent provider, not as an employee or agent of YUGI. YUGI accepts no liability for injury, loss, or damage arising from your classes. Total liability is limited to the total amount paid by a user in the 12 months before the claim. You indemnify YUGI against all claims or losses arising from your actions or omissions."
                    )
                    
                    TermsLegalSection(
                        title: "7. Brand and Community Expectations",
                        content: "You must uphold YUGI's values of trust, wellbeing, simplicity, and inclusion. Unsafe, discriminatory, or unprofessional behaviour will result in immediate removal."
                    )
                    
                    TermsLegalSection(
                        title: "8. Content Standards",
                        content: "You may only upload appropriate content suitable for families. Explicit, offensive, or misleading material is prohibited. YUGI may remove or edit content at its discretion."
                    )
                    
                    TermsLegalSection(
                        title: "9. Data and Privacy",
                        content: "You must handle all personal data in compliance with the UK GDPR and the Data Protection Act 2018. You may not use user data for marketing without explicit consent."
                    )
                    
                    TermsLegalSection(
                        title: "9A. Children's Data",
                        content: "Providers may receive a child's first name and month/year of birth only. This data is for class delivery and safety purposes and must be deleted once no longer needed."
                    )
                    
                    TermsLegalSection(
                        title: "10. Termination and Enforcement",
                        content: "Either party may terminate with 14 days' notice. YUGI may suspend or remove your account for safeguarding breaches, inappropriate conduct, or off-platform booking diversion."
                    )
                    
                    TermsLegalSection(
                        title: "11. Governing Law and Jurisdiction",
                        content: "These terms are governed by the laws of England and Wales, with exclusive jurisdiction in the courts of England and Wales."
                    )
                    
                    TermsLegalSection(
                        title: "12. Force Majeure",
                        content: "YUGI is not liable for delays or failures caused by events beyond its control, including natural disasters, outages, or regulatory changes."
                    )
                    
                    TermsLegalSection(
                        title: "13. AI Usage",
                        content: "YUGI uses artificial intelligence to enhance recommendations, detect fraud, and improve user experience. Data is anonymised where possible."
                    )
                    
                    TermsLegalSection(
                        title: "14. Survival and Severability",
                        content: "Clauses on liability, indemnity, and data privacy survive termination. Invalid clauses do not affect the remainder."
                    )
                    
                    TermsLegalSection(
                        title: "15. Marketing Consent",
                        content: "Marketing emails are sent only with your opt-in consent and may be withdrawn at any time."
                    )
                    
                    TermsLegalSection(
                        title: "16. Providers Booking Classes for Their Own Children",
                        content: "Providers may book classes for their own children and are bound by the same rules as parents regarding booking, payments, and cancellations."
                    )
                    
                    TermsLegalSection(
                        title: "17. Agreement and Acceptance",
                        content: "By listing your classes on YUGI, you confirm that you have read, understood, and agree to these Terms and Conditions. For questions, contact info@yugiapp.ai."
                    )
                    
                } else {
                    // Parent Terms & Conditions
                    TermsLegalSection(
                        title: "YUGI Group Limited - Parent / Guardian Terms & Conditions",
                        content: "Effective Date: 15 October 2025\n\nCompany Name: YUGI Group Limited\nRegistered in England and Wales, Company No. 16318935\nRegistered Address: 167 Sandbanks Road, BH14 8EJ\nContact Email: info@yugiapp.ai"
                    )
                    
                    TermsLegalSection(
                        title: "1. About YUGI",
                        content: "YUGI Group Limited (\"YUGI\", \"we\", \"our\", or \"us\") connects parents and guardians with classes offered by independent providers. YUGI facilitates bookings and payments but does not deliver classes directly."
                    )
                    
                    TermsLegalSection(
                        title: "2. Booking and Payments",
                        content: "A non-refundable £1.99 service fee applies to every booking. Payment is taken at the time of booking."
                    )
                    
                    TermsLegalSection(
                        title: "3. Cancellations and Refunds",
                        content: "3.1 Cancel 24+ hours before a class -> full refund minus the £1.99 service fee.\n\n3.2 Cancel within 24 hours -> no refund.\n\n3.3 If a provider cancels -> full refund minus the £1.99 service fee.\n\n3.4 The £1.99 service fee is non-refundable in all cases.\n\n3.5 Refunds are processed only through the YUGI platform. YUGI's decision on disputes is final."
                    )
                    
                    TermsLegalSection(
                        title: "4. Disputes",
                        content: "If you are unhappy with a class, raise a dispute within 48 hours. Payments are held for 3 days after the class and will only be released to the provider once confirmed or any dispute is resolved."
                    )
                    
                    TermsLegalSection(
                        title: "5. Responsibilities",
                        content: "You must provide accurate information for yourself and your child. Supervision during applicable classes remains your responsibility. You must not upload or post offensive content."
                    )
                    
                    TermsLegalSection(
                        title: "6. Health, Safety and Safeguarding",
                        content: "YUGI requires all providers to maintain valid DBS checks and insurance. Participation is at your own risk."
                    )
                    
                    TermsLegalSection(
                        title: "7. Liability",
                        content: "YUGI is not liable for accidents, injuries, or losses arising from classes booked via the platform. Total liability is limited to the total amount paid by you in the 12 months prior to the claim."
                    )
                    
                    TermsLegalSection(
                        title: "8. Data and Privacy",
                        content: "By booking a class, you consent to YUGI sharing your name, email, and your child's first name and month/year of birth with the provider for class delivery. Data is handled according to our Privacy Policy."
                    )
                    
                    TermsLegalSection(
                        title: "9. AI Usage",
                        content: "YUGI uses AI to recommend classes, detect fraud, and improve your experience."
                    )
                    
                    TermsLegalSection(
                        title: "10. Governing Law and Jurisdiction",
                        content: "These terms are governed by the laws of England and Wales, with exclusive jurisdiction in the courts of England and Wales."
                    )
                    
                    TermsLegalSection(
                        title: "11. Contact",
                        content: "For any questions, contact info@yugiapp.ai."
                    )
                    
                    TermsLegalSection(
                        title: "12. Agreement and Acceptance",
                        content: "By registering on YUGI, you confirm that you have read, understood, and agree to these Terms and Conditions."
                    )
                }
                
                // Only show acceptance section if not read-only
                if !isReadOnly {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Button(action: {
                                hasAcceptedTerms.toggle()
                            }) {
                                Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 24))
                                    .foregroundColor(hasAcceptedTerms ? Color(hex: "#BC6C5C") : .yugiGray.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I acknowledge and agree")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("I have read, understood, and agree to the Parent/Guardian Terms & Conditions above. I understand that I must accept these terms before I can start booking classes on the YUGI platform.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        
                        // Accept Button
                        Button(action: {
                            if hasAcceptedTerms {
                                // Save acceptance status based on user type
                                let key = userType == .provider ? "providerTermsAccepted" : "parentTermsAccepted"
                                UserDefaults.standard.set(true, forKey: key)
                                dismiss()
                                onTermsAccepted?()
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                Text("Accept Terms & Conditions")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(hasAcceptedTerms ? Color(hex: "#BC6C5C") : Color.yugiGray.opacity(0.3))
                            )
                        }
                        .disabled(!hasAcceptedTerms)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("YUGI Group Limited - Privacy Policy")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yugiGray)
                }
                
                TermsLegalSection(
                    title: "Effective Date and Company Details",
                    content: "Effective Date: 15 October 2025\n\nCompany Name: YUGI Group Limited\nRegistered in England and Wales, Company No. 16318935\nRegistered Address: 167 Sandbanks Road, BH14 8EJ\nContact Email: info@yugiapp.ai"
                )
                
                TermsLegalSection(
                    title: "1. Introduction",
                    content: "YUGI Group Limited (\"YUGI\", \"we\", \"our\", or \"us\") complies with the United Kingdom General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018. This Privacy Policy applies to all users of the YUGI platform, including parents, guardians, and providers."
                )
                
                TermsLegalSection(
                    title: "2. Data We Collect",
                    content: "We may collect:\n- Name and contact details.\n- Booking and payment information.\n- Child's first name and month/year of birth.\n- Provider details (class descriptions, DBS verification).\n- Technical data such as IP address, device type, and usage."
                )
                
                TermsLegalSection(
                    title: "3. How We Use Your Data",
                    content: "We use data to:\n- Facilitate bookings, payments, and communication.\n- Share necessary data with providers for class delivery.\n- Ensure safety and safeguarding.\n- Improve recommendations using AI.\n- Detect and prevent fraud."
                )
                
                TermsLegalSection(
                    title: "4. Third-Party Services",
                    content: "- AWS and MongoDB Atlas host and store data securely within the UK/EEA.\n- Firebase (by Google) provides authentication and analytics.\n- Stripe processes all payments; YUGI does not store card details.\n\nStripe Privacy Policy: https://stripe.com/gb/privacy"
                )
                
                TermsLegalSection(
                    title: "5. AI Usage",
                    content: "YUGI uses AI for recommendations, venue intelligence, and fraud detection. Data is anonymised or pseudonymised where possible."
                )
                
                TermsLegalSection(
                    title: "6. Data Retention",
                    content: "- Child data is deleted within 30 days after a class or dispute resolution.\n- Account data is retained for 6 years for legal compliance."
                )
                
                TermsLegalSection(
                    title: "7. Data Security",
                    content: "Encryption and access controls protect all personal data. Only authorised staff and verified service providers have access."
                )
                
                TermsLegalSection(
                    title: "8. Your Rights",
                    content: "Under UK GDPR, you can:\n- Access your data.\n- Request correction or deletion.\n- Withdraw consent.\n- Request data portability.\n\nContact info@yugiapp.ai to exercise these rights."
                )
                
                TermsLegalSection(
                    title: "9. Events Outside Our Control",
                    content: "YUGI is not responsible for delays or data issues caused by events beyond reasonable control."
                )
                
                TermsLegalSection(
                    title: "10. Enforcement",
                    content: "Misuse of data may lead to account suspension or removal. YUGI will report serious breaches to the ICO as required."
                )
                
                TermsLegalSection(
                    title: "11. Governing Law",
                    content: "This policy is governed by the laws of England and Wales, with exclusive jurisdiction in the courts of England and Wales."
                )
                
                TermsLegalSection(
                    title: "12. Updates",
                    content: "We may update this policy. Continued use of YUGI indicates acceptance of the latest version."
                )
                
                TermsLegalSection(
                    title: "13. Contact",
                    content: "For privacy questions or data rights, contact:\nYUGI Group Limited\nEmail: info@yugiapp.ai\nAddress: 167 Sandbanks Road, BH14 8EJ"
                )
            }
            .padding(20)
        }
    }
}

struct TermsLegalSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            Text(content)
                .font(.system(size: 16))
                .foregroundColor(.yugiGray.opacity(0.8))
                .lineSpacing(4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    TermsPrivacyScreen()
}

// MARK: - Terms Agreement Screen for Onboarding

struct TermsAgreementScreen: View {
    let parentName: String
    @Environment(\.dismiss) private var dismiss
    @State private var hasAcceptedTerms = false
    @State private var shouldNavigateToOnboarding = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Terms & Conditions")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Read our terms of service and privacy policy")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Tab Selector
                HStack(spacing: 0) {
                    TermsPrivacyTabButton(
                        title: "Terms of Service",
                        isSelected: selectedTab == 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 0
                        }
                    }
                    
                    TermsPrivacyTabButton(
                        title: "Privacy Policy",
                        isSelected: selectedTab == 1
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 1
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(hex: "#BC6C5C"))
                
                // Content
                TabView(selection: $selectedTab) {
                    // Terms of Service Tab
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                // Last Updated
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Updated: October 15, 2025")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yugiGray.opacity(0.7))
                                    
                                    Text("Parent/Guardian Terms & Conditions")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.yugiGray)
                                }
                            
                            // About YUGI
                            TermsLegalSection(
                                title: "1. About YUGI",
                                content: "YUGI is a digital platform that connects parents and guardians with classes run by independent providers. YUGI does not operate or deliver classes directly. All classes are organised and run by the providers listed on the platform."
                            )
                            
                            // Booking and Payments
                            TermsLegalSection(
                                title: "2. Booking and Payments",
                                content: "2.1 All bookings must be completed through the YUGI platform.\n\n2.2 A non-refundable service fee of £1.99 is charged for each booking. This fee covers administration, app operation, and transaction costs.\n\n2.3 Payment is taken at the time of booking.\n\n2.4 YUGI does not guarantee uninterrupted access to the platform and shall not be liable for any downtime, service interruptions, or technical issues."
                            )
                            
                            // Cancellations, Refunds and Fees
                            TermsLegalSection(
                                title: "3. Cancellations, Refunds and Fees",
                                content: "3.1 The £1.99 service fee is non-refundable in all circumstances.\n\n3.2 If you cancel a booking less than 24 hours before the scheduled start time, you will not receive any refund.\n\n3.3 If you cancel a booking 24 hours or more before the scheduled start time, you will receive a refund of the booking price minus the £1.99 service fee.\n\n3.4 If a provider cancels the class, you will receive a refund of the booking price minus the £1.99 service fee.\n\n3.5 If you wish to raise a dispute, you must do so within 48 hours after the scheduled class. YUGI's decision on refunds or disputes is final."
                            )
                            
                            // Responsibilities and Conduct
                            TermsLegalSection(
                                title: "4. Responsibilities and Conduct",
                                content: "4.1 You are responsible for ensuring the accuracy of the information you provide during booking, including your contact details and your child's details.\n\n4.2 You must supervise your child at all times during classes where parental supervision is required.\n\n4.3 You must not post offensive, misleading, or inappropriate content on the platform.\n\n4.4 YUGI reserves the right to remove any content, restrict account access, or withhold services if you breach these terms or engage in conduct detrimental to the platform or its users."
                            )
                            
                            // Health, Safety and Safeguarding
                            TermsLegalSection(
                                title: "5. Health, Safety and Safeguarding",
                                content: "5.1 YUGI requires all providers to hold valid Enhanced Disclosure and Barring Service (DBS) certificates and public liability insurance.\n\n5.2 YUGI cannot guarantee the suitability of all venues or activities for every child. Participation in any class is at your own risk."
                            )
                            
                            // Liability
                            TermsLegalSection(
                                title: "6. Liability",
                                content: "6.1 YUGI is not liable for any accident, injury, loss, or damage arising from participation in a class booked through the platform.\n\n6.2 To the maximum extent permitted by law, YUGI's total liability to any user shall be limited to the total amount paid by that user in the 12 months prior to the event giving rise to the claim.\n\n6.3 You agree to indemnify YUGI against any claims arising from your participation or your child's participation in a booked class."
                            )
                            
                            // Intellectual Property
                            TermsLegalSection(
                                title: "7. Intellectual Property",
                                content: "7.1 All content on the platform is owned by or licensed to YUGI or the providers.\n\n7.2 You may not copy, reproduce, or distribute any content without prior written consent."
                            )
                            
                            // Data and Privacy
                            TermsLegalSection(
                                title: "8. Data and Privacy",
                                content: "8.1 YUGI handles all personal data in accordance with the United Kingdom General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018.\n\n8.2 By booking a class, you consent to YUGI sharing your name, email address, and your child's first name, month/year of birth, and any relevant health information with the booked provider for class delivery and safety purposes."
                            )
                            
                            // Children's Personal Data
                            TermsLegalSection(
                                title: "8A. Children's Personal Data",
                                content: "8A.1 You confirm you are the parent or legal guardian of the child whose data you provide.\n\n8A.2 You consent to YUGI collecting, storing, and sharing your child's first name, month/year of birth, and any relevant health information solely for the purpose of class delivery, attendance, and safety.\n\n8A.3 This data will be securely stored, shared only with the booked provider, and deleted within 30 days after the class or resolution of any disputes.\n\n8A.4 This data will never be used for marketing without your explicit consent."
                            )
                            
                            // AI Usage
                            TermsLegalSection(
                                title: "9. AI Usage",
                                content: "9.1 YUGI uses artificial intelligence to recommend classes, prevent fraud, and improve platform services.\n\n9.2 AI-related data may include your booking history, ratings, and app usage patterns.\n\n9.3 Where possible, this data is anonymised or pseudonymised."
                            )
                            
                            // Termination and Enforcement
                            TermsLegalSection(
                                title: "10. Termination and Enforcement",
                                content: "10.1 YUGI may suspend or terminate your account for breaches of these terms, inappropriate behaviour, or misuse of the platform.\n\n10.2 YUGI reserves the right to remove any content, restrict account access, or withhold services if you breach these terms or engage in conduct detrimental to the platform or its users."
                            )
                            
                            // Governing Law and Jurisdiction
                            TermsLegalSection(
                                title: "11. Governing Law and Jurisdiction",
                                content: "This agreement is governed by the laws of England and Wales, and all disputes shall be resolved exclusively in the courts of England and Wales, regardless of the country from which the platform is accessed."
                            )
                            
                            // Force Majeure
                            TermsLegalSection(
                                title: "12. Force Majeure",
                                content: "YUGI shall not be liable for any delay or failure to perform its obligations under these terms if such delay or failure results from events or circumstances beyond YUGI's reasonable control, including but not limited to acts of God, strikes, lockouts, accidents, war, fire, breakdown of plant or machinery, and shortage or unavailability of raw materials."
                            )
                            
                            // Survival of Terms
                            TermsLegalSection(
                                title: "13. Survival of Terms",
                                content: "Clauses on liability, indemnity, confidentiality, intellectual property rights, and governing law survive termination."
                            )
                            
                            // Severability
                            TermsLegalSection(
                                title: "14. Severability",
                                content: "If any clause of this agreement is found invalid, the remainder will continue in full force."
                            )
                            
                            // Marketing Consent
                            TermsLegalSection(
                                title: "15. Marketing Consent",
                                content: "YUGI will only send marketing communications if you have explicitly opted in, and you may withdraw this consent at any time."
                            )
                            
                            // Agreement and Acceptance
                            TermsLegalSection(
                                title: "16. Agreement and Acceptance",
                                content: "By registering and booking on YUGI, you confirm that you have read, understood, and agree to these Terms and Conditions and our Privacy Policy. You confirm that you are the parent or legal guardian of the child whose data you provide and consent to its use in accordance with clause 8A. Continued use of the YUGI platform confirms ongoing acceptance."
                            )
                            
                            // Acceptance Section
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        hasAcceptedTerms.toggle()
                                    }) {
                                        Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 24))
                                            .foregroundColor(hasAcceptedTerms ? Color(hex: "#BC6C5C") : .yugiGray.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("I acknowledge and agree")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.yugiGray)
                                        
                                        Text("I have read, understood, and agree to the Terms & Conditions and Privacy Policy above. I understand that I must accept these terms before I can start booking classes on the YUGI platform.")
                                            .font(.system(size: 14))
                                            .foregroundColor(.yugiGray.opacity(0.8))
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                
                                // Continue Button
                                Button(action: {
                                    if hasAcceptedTerms {
                                        if userType == .provider {
                                            // Save acceptance status for provider
                                            UserDefaults.standard.set(true, forKey: "providerTermsAccepted")
                                            // Call the callback to proceed to verification screen
                                            onTermsAccepted?()
                                        } else {
                                            // Save acceptance status for parent onboarding
                                            UserDefaults.standard.set(true, forKey: "parentTermsAccepted")
                                            shouldNavigateToOnboarding = true
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                        Text("Accept Terms & Privacy & Continue")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(hasAcceptedTerms ? Color(hex: "#BC6C5C") : Color.yugiGray.opacity(0.3))
                                    )
                                }
                                .disabled(!hasAcceptedTerms)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                    }
                    .background(Color.yugiCream)
                    .tag(0)
                    
                    // Privacy Policy Tab
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                // Title
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("YUGI Group Limited - Privacy Policy")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.yugiGray)
                                }
                                
                                TermsLegalSection(
                                    title: "Effective Date and Company Details",
                                    content: "Effective Date: 15 October 2025\n\nCompany Name: YUGI Group Limited\nRegistered in England and Wales, Company No. 16318935\nRegistered Address: 167 Sandbanks Road, BH14 8EJ\nContact Email: info@yugiapp.ai"
                                )
                                
                                TermsLegalSection(
                                    title: "1. Introduction",
                                    content: "YUGI Group Limited (\"YUGI\", \"we\", \"our\", or \"us\") complies with the United Kingdom General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018. This Privacy Policy applies to all users of the YUGI platform, including parents, guardians, and providers."
                                )
                                
                                TermsLegalSection(
                                    title: "2. Data We Collect",
                                    content: "We may collect:\n- Name and contact details.\n- Booking and payment information.\n- Child's first name and month/year of birth.\n- Provider details (class descriptions, DBS verification).\n- Technical data such as IP address, device type, and usage."
                                )
                                
                                TermsLegalSection(
                                    title: "3. How We Use Your Data",
                                    content: "We use data to:\n- Facilitate bookings, payments, and communication.\n- Share necessary data with providers for class delivery.\n- Ensure safety and safeguarding.\n- Improve recommendations using AI.\n- Detect and prevent fraud."
                                )
                                
                                TermsLegalSection(
                                    title: "4. Third-Party Services",
                                    content: "- AWS and MongoDB Atlas host and store data securely within the UK/EEA.\n- Firebase (by Google) provides authentication and analytics.\n- Stripe processes all payments; YUGI does not store card details.\n\nStripe Privacy Policy: https://stripe.com/gb/privacy"
                                )
                                
                                TermsLegalSection(
                                    title: "5. AI Usage",
                                    content: "YUGI uses AI for recommendations, venue intelligence, and fraud detection. Data is anonymised or pseudonymised where possible."
                                )
                                
                                TermsLegalSection(
                                    title: "6. Data Retention",
                                    content: "- Child data is deleted within 30 days after a class or dispute resolution.\n- Account data is retained for 6 years for legal compliance."
                                )
                                
                                TermsLegalSection(
                                    title: "7. Data Security",
                                    content: "Encryption and access controls protect all personal data. Only authorised staff and verified service providers have access."
                                )
                                
                                TermsLegalSection(
                                    title: "8. Your Rights",
                                    content: "Under UK GDPR, you can:\n- Access your data.\n- Request correction or deletion.\n- Withdraw consent.\n- Request data portability.\n\nContact info@yugiapp.ai to exercise these rights."
                                )
                                
                                TermsLegalSection(
                                    title: "9. Events Outside Our Control",
                                    content: "YUGI is not responsible for delays or data issues caused by events beyond reasonable control."
                                )
                                
                                TermsLegalSection(
                                    title: "10. Enforcement",
                                    content: "Misuse of data may lead to account suspension or removal. YUGI will report serious breaches to the ICO as required."
                                )
                                
                                TermsLegalSection(
                                    title: "11. Governing Law",
                                    content: "This policy is governed by the laws of England and Wales, with exclusive jurisdiction in the courts of England and Wales."
                                )
                                
                                TermsLegalSection(
                                    title: "12. Updates",
                                    content: "We may update this policy. Continued use of YUGI indicates acceptance of the latest version."
                                )
                                
                                TermsLegalSection(
                                    title: "13. Contact",
                                    content: "For privacy questions or data rights, contact:\nYUGI Group Limited\nEmail: info@yugiapp.ai\nAddress: 167 Sandbanks Road, BH14 8EJ"
                                )
                            }
                            .padding(20)
                        }
                    }
                    .background(Color.yugiCream)
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $shouldNavigateToOnboarding) {
                ParentOnboardingScreen(parentName: parentName)
                    .navigationBarBackButtonHidden()
            }
        }
    }
}

#Preview {
    TermsAgreementScreen(parentName: "Sarah Johnson")
} 