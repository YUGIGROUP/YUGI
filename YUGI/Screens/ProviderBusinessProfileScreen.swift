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
    @State private var showingDocumentViewer = false
    @State private var selectedDocumentType: DocumentType = .dbs
    @State private var selectedDocumentData: Data?
    @State private var documentUpdateTrigger = false // Add this to trigger UI updates
    
    // Profile image management state
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var tempProfileImage: UIImage?
    @State private var isUpdatingProfileImage = false
    @State private var cancellables = Set<AnyCancellable>()
    
    enum DocumentType: String, CaseIterable {
        case dbs = "DBS Certificate"
        case qualifications = "Qualifications"
        
        var icon: String {
            switch self {
            case .dbs:
                return "shield.checkered"
            case .qualifications:
                return "graduationcap.fill"
            }
        }
        
        var description: String {
            switch self {
            case .dbs:
                return "Enhanced DBS check certificate"
            case .qualifications:
                return "Professional qualifications and training certificates"
            }
        }
    }
    
    private var displayBusinessName: String {
        businessService.businessInfo.name.isEmpty ? businessName : businessService.businessInfo.name
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Header with Gradient
                VStack(spacing: 20) {
                    // Top Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Business Profile")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(displayBusinessName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        // Edit Button (no save functionality)
                        Button {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if !showingEditMode {
                                    // Entering edit mode - initialize tempProfileImage with current profileImage
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
                    
                    // Enhanced Tab Selector
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
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
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
                TabView(selection: $selectedTab) {
                    // Overview Tab
                    BusinessOverviewTab(
                        businessInfo: $businessService.businessInfo,
                        contactInfo: $businessService.contactInfo,
                        showingEditMode: showingEditMode,
                        selectedDocumentType: $selectedDocumentType,
                        showingDocumentUploadSheet: $showingDocumentUploadSheet,
                        showingDocumentViewer: $showingDocumentViewer,
                        selectedDocumentData: $selectedDocumentData,
                        isDocumentUploaded: isDocumentUploaded,
                        getDocumentData: getDocumentData,
                        deleteDocument: deleteDocument,
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
            DocumentUploadSheet(documentType: selectedDocumentType)
        }
        .sheet(isPresented: $showingDocumentViewer) {
            DocumentViewerSheet(
                documentType: selectedDocumentType,
                documentData: selectedDocumentData
            )
        }
    }
    
    // MARK: - Document Management Helper Functions
    
    private func isDocumentUploaded(_ type: DocumentType) -> Bool {
        _ = documentUpdateTrigger // Use the trigger to ensure this function is called
        switch type {
        case .dbs:
            return UserDefaults.standard.bool(forKey: "providerDBSUploaded") || 
                   UserDefaults.standard.data(forKey: "providerDBSCertificate") != nil
        case .qualifications:
            return UserDefaults.standard.bool(forKey: "providerQualificationsUploaded") || 
                   UserDefaults.standard.data(forKey: "providerQualifications") != nil
        }
    }
    
    private func getDocumentData(_ type: DocumentType) -> Data? {
        _ = documentUpdateTrigger // Use the trigger to ensure this function is called
        switch type {
        case .dbs:
            return UserDefaults.standard.data(forKey: "providerDBSCertificate")
        case .qualifications:
            return UserDefaults.standard.data(forKey: "providerQualifications")
        }
    }

    private func deleteDocument(_ type: DocumentType) {
        switch type {
        case .dbs:
            UserDefaults.standard.removeObject(forKey: "providerDBSCertificate")
            UserDefaults.standard.set(false, forKey: "providerDBSUploaded")
        case .qualifications:
            UserDefaults.standard.removeObject(forKey: "providerQualifications")
            UserDefaults.standard.set(false, forKey: "providerQualificationsUploaded")
        }
        documentUpdateTrigger.toggle() // Trigger UI update
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
    @Binding var selectedDocumentType: ProviderBusinessProfileScreen.DocumentType
    @Binding var showingDocumentUploadSheet: Bool
    @Binding var showingDocumentViewer: Bool
    @Binding var selectedDocumentData: Data?
    let isDocumentUploaded: (ProviderBusinessProfileScreen.DocumentType) -> Bool
    let getDocumentData: (ProviderBusinessProfileScreen.DocumentType) -> Data?
    let deleteDocument: (ProviderBusinessProfileScreen.DocumentType) -> Void
    @Binding var profileImage: UIImage?
    @Binding var tempProfileImage: UIImage?
    @Binding var showingImagePicker: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isUpdatingProfileImage: Bool
    let onSave: () -> Void
    @ObservedObject private var businessService = ProviderBusinessService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Profile Image Card
                VStack(alignment: .leading, spacing: 20) {
                    // Enhanced Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Business Profile Image")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("This image will appear on your classes")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.6))
                        }
                        
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
                                    .foregroundColor(Color(hex: "#BC6C5C"))
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
                                                .background(Color(hex: "#BC6C5C"))
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
                                .foregroundColor(.yugiGray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Your profile image will be displayed on all your classes")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.7))
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
                        .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
                )
                
                // Business Information Card
                VStack(alignment: .leading, spacing: 20) {
                    // Enhanced Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Business Information")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("Core details about your business")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.6))
                        }
                        
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
                        .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
                )
                
                // Contact Information Card
                VStack(alignment: .leading, spacing: 20) {
                    // Enhanced Header
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Contact Information")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("How customers can reach you")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.6))
                        }
                        
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
                        .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
                )
                
                // Documents Section
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Documents")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            Text("Your uploaded certificates")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.6))
                        }
                        Spacer()
                        
                        // Add document button (only shown in edit mode)
                        if showingEditMode {
                            Button {
                                selectedDocumentType = .dbs
                                showingDocumentUploadSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                            }
                        }
                    }
                    
                    VStack(spacing: 16) {
                        // DBS Certificate
                        VStack(spacing: 8) {
                            DocumentManagementCard(
                                title: "DBS Certificate",
                                description: "Enhanced DBS check certificate",
                                icon: "shield.checkered",
                                image: businessService.dbsCertificateImage,
                                isUploaded: isDocumentUploaded(.dbs),
                                isEditMode: showingEditMode,
                                onUpload: {
                                    selectedDocumentType = .dbs
                                    showingDocumentUploadSheet = true
                                },
                                onView: {
                                    selectedDocumentType = .dbs
                                    selectedDocumentData = getDocumentData(.dbs)
                                    showingDocumentViewer = true
                                }
                            )
                            
                            // Delete button (only shown in edit mode when document is uploaded)
                            if showingEditMode && isDocumentUploaded(.dbs) {
                                Button(action: {
                                    deleteDocument(.dbs)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 14))
                                        Text("Delete DBS Certificate")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.red)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Qualifications
                        VStack(spacing: 8) {
                            DocumentManagementCard(
                                title: "Qualifications",
                                description: "Professional qualifications and training certificates",
                                icon: "graduationcap.fill",
                                image: businessService.qualificationsImage,
                                isUploaded: isDocumentUploaded(.qualifications),
                                isEditMode: showingEditMode,
                                onUpload: {
                                    selectedDocumentType = .qualifications
                                    showingDocumentUploadSheet = true
                                },
                                onView: {
                                    selectedDocumentType = .qualifications
                                    selectedDocumentData = getDocumentData(.qualifications)
                                    showingDocumentViewer = true
                                }
                            )
                            
                            // Delete button (only shown in edit mode when document is uploaded)
                            if showingEditMode && isDocumentUploaded(.qualifications) {
                                Button(action: {
                                    deleteDocument(.qualifications)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 14))
                                        Text("Delete Qualifications")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.red)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
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
                                .fill(Color(hex: "#BC6C5C"))
                                .shadow(color: Color(hex: "#BC6C5C").opacity(0.3), radius: 8, x: 0, y: 4)
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
                .foregroundColor(.yugiGray)
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
                    .foregroundColor(.yugiGray.opacity(0.5))
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
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "gear")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile Settings")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.yugiGray)
                            
                            Text("Manage your account preferences")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray.opacity(0.6))
                        }
                        
                        Spacer()
                    }
                    
                    // Settings Options
                    VStack(spacing: 16) {
                        // Notifications Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Push Notifications")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Receive updates about bookings and messages")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $notificationsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
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
                                    .foregroundColor(.yugiGray.opacity(0.5))
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
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
                    .foregroundColor(.yugiGray.opacity(0.6))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.yugiGray.opacity(0.8))
                
                Spacer()
            }
            
            if isEditable {
                if isMultiline {
                    TextEditor(text: $value)
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yugiCream.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                                )
                        )
                } else {
                    TextField("Enter \(title.lowercased())", text: $value)
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yugiCream.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            } else {
                Text(value.isEmpty ? "Not provided" : value)
                    .font(.system(size: 16))
                    .foregroundColor(value.isEmpty ? .yugiGray.opacity(0.5) : .yugiGray)
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

// MARK: - Document Upload Sheet

struct DocumentUploadSheet: View {
    let documentType: ProviderBusinessProfileScreen.DocumentType
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: UIImage?
    @State private var selectedDocument: URL?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingDocumentPicker = false
    @State private var isUploading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: documentType.icon)
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Upload \(documentType.rawValue)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yugiGray)
                    
                    Text("Please upload a clear image or PDF of your \(documentType.rawValue.lowercased())")
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // Upload Options
                VStack(spacing: 16) {
                    // Document Upload Button
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Upload Picture from Photo Library")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Select an image from your photo library")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.yugiGray.opacity(0.5))
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    
                    // File Picker Button (for PDFs and other documents)
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Browse Files")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Select PDF or other document files")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.yugiGray.opacity(0.5))
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                
                // Preview
                if let image = selectedImage {
                    VStack(spacing: 12) {
                        Text("Preview")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                } else if let document = selectedDocument {
                    VStack(spacing: 12) {
                        Text("Selected File")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        HStack {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            Text(document.lastPathComponent)
                                .font(.system(size: 14))
                                .foregroundColor(.yugiGray)
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Upload Button
                Button {
                    uploadDocument()
                } label: {
                    HStack(spacing: 8) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18))
                        }
                        
                        Text(isUploading ? "Uploading..." : "Upload Document")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        (selectedImage != nil || selectedDocument != nil) && !isUploading ? Color(hex: "#BC6C5C") : Color.yugiGray.opacity(0.3)
                    )
                    .cornerRadius(12)
                }
                .disabled(selectedImage == nil && selectedDocument == nil || isUploading)
            }
            .padding(24)
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedDocument = urls.first
            case .failure(let error):
                print("Document picker error: \(error)")
            }
        }
        .onChange(of: selectedPhotoItem) { oldItem, newItem in
            if let item = newItem {
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        selectedImage = UIImage(data: data)
                    }
                }
            }
        }
    }
    
    private func uploadDocument() {
        isUploading = true
        
        // Save the uploaded document to UserDefaults
        if let image = selectedImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            switch documentType {
            case .dbs:
                UserDefaults.standard.set(imageData, forKey: "providerDBSCertificate")
                UserDefaults.standard.set(true, forKey: "providerDBSUploaded")
            case .qualifications:
                UserDefaults.standard.set(imageData, forKey: "providerQualifications")
                UserDefaults.standard.set(true, forKey: "providerQualificationsUploaded")
            }
        } else if let document = selectedDocument {
            // Handle PDF or other document types
            do {
                let documentData = try Data(contentsOf: document)
                switch documentType {
                case .dbs:
                    UserDefaults.standard.set(documentData, forKey: "providerDBSCertificate")
                    UserDefaults.standard.set(true, forKey: "providerDBSUploaded")
                case .qualifications:
                    UserDefaults.standard.set(documentData, forKey: "providerQualifications")
                    UserDefaults.standard.set(true, forKey: "providerQualificationsUploaded")
                }
            } catch {
                print("Error reading document: \(error)")
            }
        }
        
        // Simulate upload delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isUploading = false
            dismiss()
        }
    }
}

// MARK: - Document Viewer Sheet

struct DocumentViewerSheet: View {
    let documentType: ProviderBusinessProfileScreen.DocumentType
    let documentData: Data?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: documentType.icon)
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text(documentType.rawValue)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yugiGray)
                    
                    Text("Document Preview")
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // Document Preview
                if let data = documentData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yugiGray.opacity(0.5))
                        
                        Text("Document not available")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    }
                    .frame(maxHeight: 400)
                }
                
                Spacer()
                
                // Close Button
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#BC6C5C"))
                        .cornerRadius(12)
                }
            }
            .padding(24)
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
        }
    }
}

// MARK: - Document Management Card

struct DocumentManagementCard: View {
    let title: String
    let description: String
    let icon: String
    let image: UIImage?
    let isUploaded: Bool
    let isEditMode: Bool
    let onUpload: () -> Void
    let onView: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#BC6C5C").opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "#BC6C5C"))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yugiGray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isUploaded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                    }
                }
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Action Buttons
            if isEditMode {
                if isUploaded {
                    // Show view button
                    Button(action: onView) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Show upload button
                    Button(action: onUpload) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                    }
                    .buttonStyle(.plain)
                }
            } else if isUploaded {
                // Show only view button in non-edit mode
                Button(action: onView) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#BC6C5C").opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ProviderBusinessProfileScreen(businessName: "Little Learners")
} 