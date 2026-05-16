import SwiftUI
import PhotosUI
import Combine

struct ProviderBusinessProfileScreen: View {
    let businessName: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showingEditMode = false
    @StateObject private var businessService = ProviderBusinessService.shared
    
    // Document management state
    @State private var showingDocumentUploadSheet = false
    @State private var selectedDocumentType: DocumentType = .insurance
    @State private var providerDocuments: [ProviderDocument] = []
    @State private var isLoadingDocuments = false
    @State private var isDeletingDocument = false
    
    // Profile image management state
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var tempProfileImage: UIImage?
    @State private var isUpdatingProfileImage = false
    @State private var cancellables = Set<AnyCancellable>()
    
    private var displayBusinessName: String {
        businessService.businessInfo.name.isEmpty ? businessName : businessService.businessInfo.name
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Slim header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Business Profile")
                            .font(.custom("Raleway-Regular", size: 28))
                            .foregroundColor(.white)

                        Text(displayBusinessName)
                            .font(.custom("Raleway-Regular", size: 14))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    // Edit Button
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            if !showingEditMode {
                                tempProfileImage = profileImage
                            }
                            showingEditMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                            Text("Edit")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .opacity(showingEditMode ? 0 : 1)
                    .disabled(showingEditMode)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
                .background(Color.yugiMocha.ignoresSafeArea())

                // Tab selector below header, on cream background
                HStack(spacing: 0) {
                    BusinessProfileTabButton(
                        title: "Overview",
                        isSelected: selectedTab == 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 0
                        }
                    }

                    BusinessProfileTabButton(
                        title: "Settings",
                        isSelected: selectedTab == 1
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 1
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.yugiOat)
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .background(Color.yugiCream)

                // Content
                TabView(selection: $selectedTab) {
                    // Overview Tab
                    BusinessOverviewTab(
                        businessInfo: $businessService.businessInfo,
                        contactInfo: $businessService.contactInfo,
                        showingEditMode: showingEditMode,
                        providerDocuments: providerDocuments,
                        isLoadingDocuments: isLoadingDocuments,
                        onUpload: { type in
                            selectedDocumentType = type
                            showingDocumentUploadSheet = true
                        },
                        onReplace: { type, documentId in
                            replaceDocument(type: type, documentId: documentId)
                        },
                        profileImage: $profileImage,
                        tempProfileImage: $tempProfileImage,
                        showingImagePicker: $showingImagePicker,
                        selectedPhotoItem: $selectedPhotoItem,
                        isUpdatingProfileImage: $isUpdatingProfileImage,
                        onSave: {
                            print("🔍 ProviderBusinessProfileScreen - Save button pressed")
                            print("🔍 ProviderBusinessProfileScreen - Bio: '\(businessService.businessInfo.description)'")
                            print("🔍 ProviderBusinessProfileScreen - Services: '\(businessService.businessInfo.services)'")
                            
                            // Save the data locally first
                            businessService.saveBusinessData()
                            
                            // Update business info on server
                            businessService.updateBusinessInfoOnServer()
                            
                            // Update profile image if there's a new one
                            if tempProfileImage != nil {
                                updateProfileImage()
                            }
                            
                            // Exit edit mode
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingEditMode = false
                            }
                        }
                    )
                    .tag(0)
                    
                    // Settings Tab
                    BusinessSettingsTab()
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)

            .onAppear {
                // Load business data when screen appears
                businessService.loadBusinessData()
                
                // Load profile image from current user
                loadProfileImage()
            }
            .onReceive(APIService.shared.$currentUser) { user in
                // Reload profile image when user data updates
                if user != nil {
                    loadProfileImage()
                }
            }
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { oldItem, newItem in
                if let item = newItem {
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                tempProfileImage = UIImage(data: data)
                                // Don't call updateProfileImage() here - let user save manually
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(businessService.errorMessage != nil)) {
                Button("OK") {
                    businessService.errorMessage = nil
                }
            } message: {
                if let errorMessage = businessService.errorMessage {
                    Text(errorMessage)
                }
            }
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
        .sheet(isPresented: $showingDocumentUploadSheet) {
            DocumentUploadFlowSheet(
                documentType: selectedDocumentType,
                onSuccess: {
                    showingDocumentUploadSheet = false
                    loadProviderDocuments()
                }
            )
        }
        .onAppear {
            loadProviderDocuments()
        }
    }

    private func document(for type: DocumentType) -> ProviderDocument? {
        providerDocuments.first { $0.documentType == type.rawValue }
    }

    private func loadProviderDocuments() {
        isLoadingDocuments = true
        APIService.shared.fetchMyProviderDocuments()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoadingDocuments = false
                    if case .failure(let error) = completion {
                        print("Failed to load provider documents: \(error)")
                    }
                },
                receiveValue: { documents in
                    providerDocuments = documents
                }
            )
            .store(in: &cancellables)
    }

    private func replaceDocument(type: DocumentType, documentId: String) {
        isDeletingDocument = true
        APIService.shared.deleteProviderDocument(id: documentId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isDeletingDocument = false
                    if case .failure(let error) = completion {
                        print("Failed to delete document: \(error)")
                    }
                },
                receiveValue: { _ in
                    loadProviderDocuments()
                    selectedDocumentType = type
                    showingDocumentUploadSheet = true
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadProfileImage() {
        guard let currentUser = APIService.shared.currentUser,
              let profileImageString = currentUser.profileImage,
              !profileImageString.isEmpty,
              let imageData = Data(base64Encoded: profileImageString),
              let image = UIImage(data: imageData) else {
            profileImage = nil
            return
        }
        profileImage = image
    }
    
    private func updateProfileImage() {
        print("🔍 ProviderBusinessProfileScreen - updateProfileImage called")
        guard let image = tempProfileImage else { 
            print("🔍 ProviderBusinessProfileScreen - No temp profile image, returning")
            return 
        }
        
        print("🔍 ProviderBusinessProfileScreen - Updating profile image...")
        isUpdatingProfileImage = true
        
        // Convert image to base64 string with proper compression
        guard let profileImageString = ImageCompressor.compressProfileImage(image) else {
            print("❌ ProviderBusinessProfileScreen: Failed to compress profile image")
            isUpdatingProfileImage = false
            return
        }
        
        // Update profile via API
        APIService.shared.updateProfile(profileImage: profileImageString)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isUpdatingProfileImage = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to update profile image: \(error)")
                    }
                },
                receiveValue: { response in
                    print("✅ Profile image updated successfully")
                    profileImage = image
                    tempProfileImage = nil
                    
                    // Update the currentUser in APIService so other screens see the change
                    if let currentUser = APIService.shared.currentUser {
                        let updatedUser = User(
                            id: currentUser.id,
                            email: currentUser.email,
                            fullName: currentUser.fullName,
                            phoneNumber: currentUser.phoneNumber ?? "",
                            profileImage: profileImageString,
                            userType: currentUser.userType,
                            businessName: currentUser.businessName,
                            businessAddress: currentUser.businessAddress,
                            children: currentUser.children ?? []
                        )
                        APIService.shared.currentUser = updatedUser
                        print("✅ Updated APIService.currentUser.profileImage")
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Tab Views

struct BusinessOverviewTab: View {
    @Binding var businessInfo: BusinessInfo
    @Binding var contactInfo: ContactInfo
    let showingEditMode: Bool
    let providerDocuments: [ProviderDocument]
    let isLoadingDocuments: Bool
    let onUpload: (DocumentType) -> Void
    let onReplace: (DocumentType, String) -> Void
    @Binding var profileImage: UIImage?
    @Binding var tempProfileImage: UIImage?
    @Binding var showingImagePicker: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isUpdatingProfileImage: Bool
    let onSave: () -> Void

    private let profileDocumentTypes: [DocumentType] = [.insurance, .dbs, .qualifications]

    private func document(for type: DocumentType) -> ProviderDocument? {
        providerDocuments.first { $0.documentType == type.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Profile Image Card
                VStack(alignment: .leading, spacing: 20) {
                    // Enhanced Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.yugiMocha.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color.yugiMocha)
                        }
                        
                        Text("Business Profile Image")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.yugiGray)
                        
                        Spacer()
                    }
                    
                    // Profile Image Display
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            
                            if let image = tempProfileImage ?? profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else {
                                Text(String(businessInfo.name.prefix(1).uppercased()))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(Color.yugiMocha)
                            }
                            
                            if showingEditMode {
                                // Edit overlay
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            showingImagePicker = true
                                        }) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                                .frame(width: 32, height: 32)
                                                .background(Color.yugiMocha)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                                .frame(width: 120, height: 120)
                            }
                            
                            if isUpdatingProfileImage {
                                // Loading overlay
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                        }
                        
                        if showingEditMode {
                            Text("Tap the camera icon to update your profile image")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.yugiGray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Your profile image will be displayed on all your classes")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.yugiGray.opacity(0.7))
                                .multilineTextAlignment(.center)
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
                        .stroke(Color.yugiMocha, lineWidth: 2)
                )
                
                // Business Information Card
                VStack(alignment: .leading, spacing: 20) {
                    // Enhanced Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.yugiMocha.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color.yugiMocha)
                        }
                        
                        Text("Business Information")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.yugiGray)
                        
                        Spacer()
                    }
                    
                    // Enhanced Fields
                    VStack(spacing: 20) {
                        EditableProfileField(
                            title: "Business Name",
                            value: $businessInfo.name,
                            icon: "building.2",
                            isEditable: showingEditMode
                        )
                        
                        EditableProfileField(
                            title: "Bio",
                            value: $businessInfo.description,
                            icon: "person.text.rectangle",
                            isEditable: showingEditMode,
                            isMultiline: true
                        )
                        
                        EditableProfileField(
                            title: "Services",
                            value: $businessInfo.services,
                            icon: "list.bullet.rectangle",
                            isEditable: showingEditMode,
                            isMultiline: true
                        )
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
                        .stroke(Color.yugiMocha, lineWidth: 2)
                )
                
                // Contact Information Card
                VStack(alignment: .leading, spacing: 20) {
                    // Enhanced Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.yugiMocha.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color.yugiMocha)
                        }
                        
                        Text("Contact Information")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.yugiGray)
                        
                        Spacer()
                    }
                    
                    // Enhanced Fields
                    VStack(spacing: 20) {
                        EditableProfileField(
                            title: "Email Address",
                            value: $contactInfo.email,
                            icon: "envelope",
                            isEditable: showingEditMode
                        )
                        
                        EditableProfileField(
                            title: "Phone Number",
                            value: $contactInfo.phone,
                            icon: "phone",
                            isEditable: showingEditMode
                        )
                        
                        EditableProfileField(
                            title: "Website",
                            value: $contactInfo.website,
                            icon: "globe",
                            isEditable: showingEditMode
                        )
                        
                        EditableProfileField(
                            title: "Business Address",
                            value: $contactInfo.address,
                            icon: "location",
                            isEditable: showingEditMode,
                            isMultiline: true
                        )
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
                        .stroke(Color.yugiMocha, lineWidth: 2)
                )
                
                // Documents Section
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.yugiMocha.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color.yugiMocha)
                        }
                        Text("Documents")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.yugiGray)
                        Spacer()
                    }

                    if isLoadingDocuments && providerDocuments.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 16) {
                        ForEach(profileDocumentTypes, id: \.self) { type in
                            ProviderDocumentManagementCard(
                                documentType: type,
                                document: document(for: type),
                                onUpload: { onUpload(type) },
                                onReplace: {
                                    if let doc = document(for: type) {
                                        onReplace(type, doc.id)
                                    }
                                }
                            )
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
                        .stroke(Color.yugiMocha, lineWidth: 2)
                )
                
                // Save Button (only shown in edit mode)
                if showingEditMode {
                    Button(action: onSave) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.yugiMocha)
                                .shadow(color: Color.yugiMocha.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
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
    }
}

struct DocumentPreviewCard: View {
    let title: String
    let image: UIImage?
    @State private var showPreview = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.yugiGray)
            if let image = image {
                Button(action: { showPreview = true }) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showPreview) {
                    VStack {
                        Text(title)
                            .font(.headline)
                            .padding()
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                        Spacer()
                        Button("Close") { showPreview = false }
                            .padding()
                    }
                }
            } else {
                Text("Not uploaded")
                    .font(.system(size: 14))
                    .foregroundColor(Color.yugiGray.opacity(0.5))
                    .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.yugiCream.opacity(0.4))
        .cornerRadius(12)
    }
}

struct BusinessSettingsTab: View {
    @State private var notificationsEnabled = true
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Profile Settings Card
                VStack(alignment: .leading, spacing: 20) {
                    // Enhanced Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.yugiMocha.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "gear")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color.yugiMocha)
                        }
                        
                        Text("Profile Settings")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.yugiGray)
                        
                        Spacer()
                    }
                    
                    // Settings Options
                    VStack(spacing: 16) {
                        // Notifications Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Push Notifications")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.yugiGray)
                                
                                Text("Receive updates about bookings and messages")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.yugiGray.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $notificationsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: Color.yugiMocha))
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // Delete Account Button
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                
                                Text("Delete Account")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.yugiGray.opacity(0.5))
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
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
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Handle account deletion
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
}

// MARK: - Supporting Views

struct BusinessProfileTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Raleway-SemiBold", size: 14))
                .foregroundColor(isSelected ? .white : Color.yugiSoftBlack)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.yugiMocha : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

struct EditableProfileField: View {
    let title: String
    @Binding var value: String
    let icon: String
    let isEditable: Bool
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.yugiGray.opacity(0.6))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.yugiGray.opacity(0.8))
                
                Spacer()
            }
            
            if isEditable {
                if isMultiline {
                    TextEditor(text: $value)
                        .font(.system(size: 16))
                        .foregroundColor(Color.yugiGray)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yugiCream.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.yugiMocha.opacity(0.3), lineWidth: 1)
                                )
                        )
                } else {
                    TextField("Enter \(title.lowercased())", text: $value)
                        .font(.system(size: 16))
                        .foregroundColor(Color.yugiGray)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yugiCream.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.yugiMocha.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            } else {
                Text(value.isEmpty ? "Not provided" : value)
                    .font(.system(size: 16))
                    .foregroundColor(value.isEmpty ? Color.yugiGray.opacity(0.5) : Color.yugiGray)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.yugiCream.opacity(0.3))
                    )
            }
        }
    }
}


// MARK: - Document Management Card

struct ProviderDocumentManagementCard: View {
    let documentType: DocumentType
    let document: ProviderDocument?
    let onUpload: () -> Void
    let onReplace: () -> Void

    private var statusLabel: String {
        guard let document else { return "Not uploaded" }
        return document.typedStatus?.displayName ?? document.status.capitalized
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(documentType.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.yugiGray)

                    if let document {
                        Text(document.originalFileName)
                            .font(.system(size: 13))
                            .foregroundColor(Color.yugiGray.opacity(0.75))

                        Text("Uploaded \(formattedDate(document.uploadedAt))")
                            .font(.system(size: 12))
                            .foregroundColor(Color.yugiGray.opacity(0.65))

                        if documentType == .dbs, let expiry = document.expiryDate {
                            Text("Expires \(formattedDate(expiry))")
                                .font(.system(size: 12))
                                .foregroundColor(Color.yugiGray.opacity(0.65))
                        }
                    }
                }

                Spacer()

                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(document == nil ? Color.yugiGray.opacity(0.7) : Color.yugiSoftBlack)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        document == nil
                            ? Color.yugiCloud
                            : Color.yugiSage.opacity(0.3)
                    )
                    .cornerRadius(8)
            }

            Button(action: document == nil ? onUpload : onReplace) {
                Text(document == nil ? "Upload" : "Replace")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(document == nil ? .white : Color.yugiMocha)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(document == nil ? Color.yugiMocha : Color.yugiDustyBlush.opacity(0.25))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yugiMocha.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ProviderBusinessProfileScreen(businessName: "Little Learners")
}
