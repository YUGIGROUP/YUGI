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
                    Text("Last Updated: January 15, 2024")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                    
                    Text(userType == .provider ? "Provider Terms & Conditions" : "Parent/Guardian Terms & Conditions")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yugiGray)
                }
                
                if userType == .provider {
                    // Provider Terms & Conditions
                    
                    // Purpose of the Agreement
                    TermsLegalSection(
                        title: "1. Purpose of the Agreement",
                        content: "YUGI is a digital platform that connects parents and guardians with baby, toddler, child, and wellness-focused classes. You, as a provider, are responsible for the delivery of all listed classes. YUGI facilitates platform access, visibility, scheduling, and secure bookings."
                    )
                    
                    // Payments, Pricing and Platform Integrity
                    TermsLegalSection(
                        title: "2. Payments, Pricing and Platform Integrity",
                        content: "2.1 YUGI deducts a service fee of 10% from each completed and paid booking.\n\n2.2 Payments for completed classes will enter a 3-day holding phase after the class has taken place. You will be able to withdraw funds as soon as they are available in your account after the 3-day holding phase, provided the class was delivered and is not subject to a dispute.\n\n2.3 You are solely responsible for determining the pricing of your classes listed on the YUGI platform.\n\n2.4 You agree to promote YUGI as the primary booking channel for any classes you advertise through the app and must not encourage YUGI users to bypass the platform."
                    )
                    
                    // Refunds and Disputes
                    TermsLegalSection(
                        title: "2A. Refunds and Disputes",
                        content: "2A.1 Parents, guardians, or users may cancel a booking and receive a full refund if the cancellation is made 24 hours or more before the scheduled start time of the class.\n\n2A.2 When a class is booked, the user's payment will enter a 3-day holding phase after the class has occurred. The funds will be released to you after this holding period, provided there is no cancellation or dispute.\n\n2A.3 If a user raises a dispute, the payment will remain on hold until the issue is investigated and resolved.\n\n2A.4 YUGI may issue full or partial refunds to users based on the outcome of a dispute, at its sole discretion.\n\n2A.5 YUGI's decision on refunds or payment release in the context of a dispute is final and binding."
                    )
                    
                    // Class Listings and Responsibilities
                    TermsLegalSection(
                        title: "3. Class Listings and Responsibilities",
                        content: "3.1 You must provide accurate, up-to-date, and complete information when listing your class.\n\n3.2 You must keep class details, such as time, location, pricing, and age suitability, accurate at all times.\n\n3.3 You are solely responsible for the delivery and management of the class, including attendance, communication, and any follow-up.\n\n3.4 YUGI does not guarantee uninterrupted access to the platform and shall not be liable for any downtime, service interruptions, or technical issues."
                    )
                    
                    // Health, Safety and Safeguarding
                    TermsLegalSection(
                        title: "4. Health, Safety and Safeguarding",
                        content: "4.1 You must comply with all applicable United Kingdom health and safety regulations, perform regular risk assessments, and maintain public liability insurance with a minimum cover of £2,000,000.\n\n4.2 If your classes involve children, you must:\n• Hold a current enhanced Disclosure and Barring Service (DBS) certificate.\n• Comply with the Children Act 1989 and 2004, and Working Together to Safeguard Children 2018.\n• Ensure that all staff or assistants working with children are DBS-cleared and appropriately trained.\n\n4.3 You must provide supporting documentation to YUGI upon request."
                    )
                    
                    // Cancellations and Non-Delivery
                    TermsLegalSection(
                        title: "5. Cancellations and Non-Delivery",
                        content: "5.1 If you cancel a class, you must notify YUGI and all affected users immediately.\n\n5.2 If you cancel a class for any reason, the parent or guardian who booked will receive a full refund of the amount they paid for that class.\n\n5.3 Excessive cancellations, misrepresentation, or failure to deliver classes may result in suspension or removal of your account."
                    )
                    
                    // Insurance and Liability
                    TermsLegalSection(
                        title: "6. Insurance and Liability",
                        content: "6.1 You must maintain valid public liability insurance throughout your use of the YUGI platform.\n\n6.2 You operate as an independent provider and not as an employee, agent, or representative of YUGI.\n\n6.3 YUGI shall not be held liable for any accident, injury, loss, damage, or claim arising out of or in connection with any class, event, venue, or service provided by you.\n\n6.4 To the maximum extent permitted by law, YUGI's total liability to any user shall be limited to the total amount paid by that user in the 12 months prior to the event giving rise to the claim.\n\n6.5 You fully indemnify YUGI against any and all legal actions, claims, losses, damages, or costs resulting from your actions, omissions, or failure to comply with applicable law or these terms."
                    )
                    
                    // Brand and Community Expectations
                    TermsLegalSection(
                        title: "7. Brand and Community Expectations",
                        content: "7.1 You must uphold YUGI's values of trust, wellbeing, simplicity, and inclusion.\n\n7.2 Harassment, discrimination, or behaviour that endangers participants will result in immediate removal."
                    )
                    
                    // Content Standards and Platform Safety
                    TermsLegalSection(
                        title: "7A. Content Standards and Platform Safety",
                        content: "7A.1 All content you upload must be suitable for a general audience, including children.\n\n7A.2 Prohibited content includes explicit, violent, discriminatory, offensive, misleading, or infringing material.\n\n7A.3 YUGI may remove, hide, or edit content at its sole discretion."
                    )
                    
                    // Intellectual Property
                    TermsLegalSection(
                        title: "8. Intellectual Property",
                        content: "8.1 You retain ownership of your class content and materials.\n\n8.2 By listing on YUGI, you grant YUGI a royalty-free, non-exclusive licence to use your content for marketing and promotional purposes."
                    )
                    
                    // Data Use and Privacy
                    TermsLegalSection(
                        title: "9. Data Use and Privacy",
                        content: "9.1 You must handle all personal data in compliance with the United Kingdom General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018.\n\n9.2 You may not use user information for marketing unless they have explicitly opted in."
                    )
                    
                    // Handling of Children's Personal Data
                    TermsLegalSection(
                        title: "9A. Handling of Children's Personal Data",
                        content: "9A.1 You may receive children's personal data, including first name and month/year of birth and any relevant health information, from a parent or guardian when they book a class.\n\n9A.2 You must use this data only for class delivery, attendance, and safety purposes.\n\n9A.3 You must not copy, store, or share this data outside of the YUGI platform unless essential for delivering the booked class.\n\n9A.4 You must securely delete or anonymise this data when it is no longer required."
                    )
                    
                    // Termination and Enforcement
                    TermsLegalSection(
                        title: "10. Termination and Enforcement",
                        content: "10.1 Either party may terminate this agreement with 14 days' written notice.\n\n10.2 YUGI may suspend or remove your account immediately for safeguarding breaches, inappropriate content, non-delivery, or off-platform booking diversion.\n\n10.3 YUGI reserves the right to remove any content, restrict account access, or withhold payments if you breach these terms or engage in conduct detrimental to the platform or its users."
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
                    
                    // AI Usage, Data Collection and Storage
                    TermsLegalSection(
                        title: "13. AI Usage, Data Collection and Storage",
                        content: "13.1 YUGI uses artificial intelligence to improve recommendations, scheduling, and fraud detection.\n\n13.2 AI-related data may include booking patterns, ratings, and usage behaviour.\n\n13.3 Where possible, this data is anonymised or pseudonymised."
                    )
                    
                    // Survival of Terms
                    TermsLegalSection(
                        title: "14. Survival of Terms",
                        content: "Clauses on liability, indemnity, confidentiality, intellectual property rights, and governing law survive termination."
                    )
                    
                    // Severability
                    TermsLegalSection(
                        title: "15. Severability",
                        content: "If any clause of this agreement is invalid, the remainder will continue in effect."
                    )
                    
                    // Marketing Consent
                    TermsLegalSection(
                        title: "16. Marketing Consent",
                        content: "YUGI will only send marketing communications if you have explicitly opted in, and you may withdraw this consent at any time."
                    )
                    
                    // Agreement and Acceptance
                    TermsLegalSection(
                        title: "17. Agreement and Acceptance",
                        content: "By listing your classes on YUGI, you confirm that you have read, understood, and agree to these Terms and Conditions and our Privacy Policy. You acknowledge your obligations under UK GDPR, including handling children's data as outlined in clause 9A. Continued use of the YUGI platform confirms ongoing acceptance."
                    )
                    
                    // Providers Booking Classes for Their Own Children
                    TermsLegalSection(
                        title: "18. Providers Booking Classes for Their Own Children",
                        content: "18.1 As a provider, you may also book classes for your own children through the YUGI platform.\n\n18.2 When booking for your own child, you are subject to the same booking, payment, cancellation, refund, and conduct rules set out in the Parent/Guardian Terms and Conditions, including:\n• A non-refundable service fee of £1.99 per booking.\n• No refund if you cancel less than 24 hours before the scheduled start time.\n• Refund minus the £1.99 service fee if you cancel 24 hours or more before the scheduled start time.\n• If the provider of the class cancels, you will receive a refund minus the £1.99 service fee.\n• The requirement to provide accurate child details and comply with supervision and safety requirements.\n\n18.3 All data and privacy rules for parents and guardians, including the handling of children's personal data, also apply when you book a class for your own child."
                    )
                    
                } else {
                    // Parent Terms & Conditions
                    
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
                                // Save acceptance status
                                UserDefaults.standard.set(true, forKey: "parentTermsAccepted")
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
                    Text("YUGI PRIVACY POLICY")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yugiGray)
                }
                
                // Introduction
                TermsLegalSection(
                    title: "1. Introduction",
                    content: "YUGI Ltd. (\"YUGI\", \"we\", \"our\", or \"us\") is committed to protecting your privacy and complying with the United Kingdom General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018. This Privacy Policy explains how we collect, use, store, and share your personal data when you use our platform.\n\nBy using the YUGI app or website, you consent to the practices described in this policy."
                )
                
                // Data We Collect
                TermsLegalSection(
                    title: "2. Data We Collect",
                    content: "We may collect the following personal data:\n• Name and contact information (email address, phone number).\n• Payment details for processing bookings.\n• Booking history and preferences.\n• Child's first name, month/year of birth, and relevant health information for class delivery and safety purposes.\n• Technical data such as IP address, device type, browser type, and usage patterns."
                )
                
                // How We Use Your Data
                TermsLegalSection(
                    title: "3. How We Use Your Data",
                    content: "We process your personal data to:\n• Facilitate bookings and class delivery.\n• Manage payments, refunds, and disputes.\n• Communicate with you about bookings and platform updates.\n• Share necessary details with providers so they can deliver the booked class.\n• Ensure safety, age suitability, and safeguarding compliance.\n• Improve our services, including using AI to recommend classes and detect fraudulent activity."
                )
                
                // AI Data Usage
                TermsLegalSection(
                    title: "4. AI Data Usage",
                    content: "4.1 We use artificial intelligence to personalise recommendations, detect fraudulent behaviour, and improve platform performance.\n\n4.2 AI-related data may include booking patterns, reviews, and app usage behaviour.\n\n4.3 Where possible, AI data is anonymised or pseudonymised."
                )
                
                // Sharing Your Data
                TermsLegalSection(
                    title: "5. Sharing Your Data",
                    content: "We may share your data with:\n• Class providers (name, email address, and your child's first name, month/year of birth, and relevant health information) for the purpose of delivering the booked class.\n• Payment processors to facilitate secure transactions.\n• IT service providers that support platform operation.\n• Regulatory bodies or authorities where required by law."
                )
                
                // Data Retention
                TermsLegalSection(
                    title: "6. Data Retention",
                    content: "We only keep your personal data for as long as necessary to fulfil the purposes we collected it for, including any legal, accounting, or reporting requirements.\n• Child data (first name and month/year of birth) will be deleted within 30 days after the class or resolution of any disputes."
                )
                
                // Data Security
                TermsLegalSection(
                    title: "7. Data Security",
                    content: "We implement technical and organisational measures to protect your data against unauthorised access, loss, or misuse. However, no internet-based service can be guaranteed to be 100% secure."
                )
                
                // Your Rights
                TermsLegalSection(
                    title: "8. Your Rights",
                    content: "You have the right to:\n• Request access to your personal data.\n• Request correction or deletion of your data.\n• Withdraw consent at any time.\n• Object to processing based on legitimate interests.\n• Request restriction of processing in certain circumstances.\n\nYou can exercise these rights by contacting us at customer@yugi.uk"
                )
                
                // Events Outside Our Control (Force Majeure)
                TermsLegalSection(
                    title: "9. Events Outside Our Control (Force Majeure)",
                    content: "We are not responsible for any delay or failure to comply with our obligations under this Privacy Policy if such delay or failure is caused by events or circumstances beyond our reasonable control, including but not limited to technical outages, cyberattacks, natural disasters, or legal/regulatory changes."
                )
                
                // Enforcement and Breaches
                TermsLegalSection(
                    title: "10. Enforcement and Breaches",
                    content: "We reserve the right to suspend or terminate platform access, remove content, or take legal action if a user breaches our Terms & Conditions or misuses personal data obtained through YUGI."
                )
                
                // Governing Law and Jurisdiction
                TermsLegalSection(
                    title: "11. Governing Law and Jurisdiction",
                    content: "This Privacy Policy and any disputes relating to it are governed by the laws of England and Wales, and all disputes shall be resolved exclusively in the courts of England and Wales, regardless of the country from which the platform is accessed."
                )
                
                // Updates to This Policy
                TermsLegalSection(
                    title: "12. Updates to This Policy",
                    content: "We may update this Privacy Policy from time to time. Changes will be posted on the platform, and continued use of the platform after such changes will be deemed acceptance of the updated policy."
                )
                
                // Consent
                TermsLegalSection(
                    title: "13. Consent",
                    content: "By registering for a YUGI account and using the platform, you confirm that you have read and understood this Privacy Policy and consent to the collection, use, storage, and sharing of your personal data in accordance with it."
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
                                    Text("Last Updated: January 15, 2024")
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
                                        // Save acceptance status
                                        UserDefaults.standard.set(true, forKey: "parentTermsAccepted")
                                        shouldNavigateToOnboarding = true
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
                                    Text("YUGI PRIVACY POLICY")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.yugiGray)
                                }
                                
                                // Introduction
                                TermsLegalSection(
                                    title: "1. Introduction",
                                    content: "YUGI Ltd. (\"YUGI\", \"we\", \"our\", or \"us\") is committed to protecting your privacy and complying with the United Kingdom General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018. This Privacy Policy explains how we collect, use, store, and share your personal data when you use our platform.\n\nBy using the YUGI app or website, you consent to the practices described in this policy."
                                )
                                
                                // Data We Collect
                                TermsLegalSection(
                                    title: "2. Data We Collect",
                                    content: "We may collect the following personal data:\n• Name and contact information (email address, phone number).\n• Payment details for processing bookings.\n• Booking history and preferences.\n• Child's first name, month/year of birth, and relevant health information for class delivery and safety purposes.\n• Technical data such as IP address, device type, browser type, and usage patterns."
                                )
                                
                                // How We Use Your Data
                                TermsLegalSection(
                                    title: "3. How We Use Your Data",
                                    content: "We process your personal data to:\n• Facilitate bookings and class delivery.\n• Manage payments, refunds, and disputes.\n• Communicate with you about bookings and platform updates.\n• Share necessary details with providers so they can deliver the booked class.\n• Ensure safety, age suitability, and safeguarding compliance.\n• Improve our services, including using AI to recommend classes and detect fraudulent activity."
                                )
                                
                                // AI Data Usage
                                TermsLegalSection(
                                    title: "4. AI Data Usage",
                                    content: "4.1 We use artificial intelligence to personalise recommendations, detect fraudulent behaviour, and improve platform performance.\n\n4.2 AI-related data may include booking patterns, reviews, and app usage behaviour.\n\n4.3 Where possible, AI data is anonymised or pseudonymised."
                                )
                                
                                // Sharing Your Data
                                TermsLegalSection(
                                    title: "5. Sharing Your Data",
                                    content: "We may share your data with:\n• Class providers (name, email address, and your child's first name, month/year of birth, and relevant health information) for the purpose of delivering the booked class.\n• Payment processors to facilitate secure transactions.\n• IT service providers that support platform operation.\n• Regulatory bodies or authorities where required by law."
                                )
                                
                                // Data Retention
                                TermsLegalSection(
                                    title: "6. Data Retention",
                                    content: "We only keep your personal data for as long as necessary to fulfil the purposes we collected it for, including any legal, accounting, or reporting requirements.\n• Child data (first name and month/year of birth) will be deleted within 30 days after the class or resolution of any disputes."
                                )
                                
                                // Data Security
                                TermsLegalSection(
                                    title: "7. Data Security",
                                    content: "We implement technical and organisational measures to protect your data against unauthorised access, loss, or misuse. However, no internet-based service can be guaranteed to be 100% secure."
                                )
                                
                                // Your Rights
                                TermsLegalSection(
                                    title: "8. Your Rights",
                                    content: "You have the right to:\n• Request access to your personal data.\n• Request correction or deletion of your data.\n• Withdraw consent at any time.\n• Object to processing based on legitimate interests.\n• Request restriction of processing in certain circumstances.\n\nYou can exercise these rights by contacting us at customer@yugi.uk"
                                )
                                
                                // Events Outside Our Control (Force Majeure)
                                TermsLegalSection(
                                    title: "9. Events Outside Our Control (Force Majeure)",
                                    content: "We are not responsible for any delay or failure to comply with our obligations under this Privacy Policy if such delay or failure is caused by events or circumstances beyond our reasonable control, including but not limited to technical outages, cyberattacks, natural disasters, or legal/regulatory changes."
                                )
                                
                                // Enforcement and Breaches
                                TermsLegalSection(
                                    title: "10. Enforcement and Breaches",
                                    content: "We reserve the right to suspend or terminate platform access, remove content, or take legal action if a user breaches our Terms & Conditions or misuses personal data obtained through YUGI."
                                )
                                
                                // Governing Law and Jurisdiction
                                TermsLegalSection(
                                    title: "11. Governing Law and Jurisdiction",
                                    content: "This Privacy Policy and any disputes relating to it are governed by the laws of England and Wales, and all disputes shall be resolved exclusively in the courts of England and Wales, regardless of the country from which the platform is accessed."
                                )
                                
                                // Updates to This Policy
                                TermsLegalSection(
                                    title: "12. Updates to This Policy",
                                    content: "We may update this Privacy Policy from time to time. Changes will be posted on the platform, and continued use of the platform after such changes will be deemed acceptance of the updated policy."
                                )
                                
                                // Consent
                                TermsLegalSection(
                                    title: "13. Consent",
                                    content: "By registering for a YUGI account and using the platform, you confirm that you have read and understood this Privacy Policy and consent to the collection, use, storage, and sharing of your personal data in accordance with it."
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