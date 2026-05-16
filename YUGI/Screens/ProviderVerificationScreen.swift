import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Combine

struct ProviderVerificationScreen: View {
    let businessName: String

    @State private var documents: [ProviderDocument] = []
    @State private var isLoadingDocuments = false
    @State private var documentsLoadError: String?
    @State private var shouldNavigateToDashboard = false
    @State private var showingUploadSheet = false
    @State private var selectedDocumentType: DocumentType?
    @State private var replacingDocumentId: String?
    @State private var isDeleting = false
    @State private var cancellables = Set<AnyCancellable>()

    private let documentTypes: [DocumentType] = [.dbs, .insurance, .qualifications, .businessRegistration]

    var body: some View {
        ZStack {
            Color.yugiCloud.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if isLoadingDocuments && documents.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }

                    if let documentsLoadError {
                        Text(documentsLoadError)
                            .font(.custom("Raleway-Regular", size: 14))
                            .foregroundColor(.red)
                    }

                    VStack(spacing: 12) {
                        ForEach(documentTypes, id: \.self) { type in
                            documentTile(for: type)
                        }
                    }

                    YUGIButton(
                        title: "Continue to Dashboard",
                        style: .primary,
                        action: { shouldNavigateToDashboard = true }
                    )
                    .padding(.top, 8)
                }
                .padding(24)
            }
        }
        .fullScreenCover(isPresented: $shouldNavigateToDashboard) {
            ProviderDashboardScreen(businessName: businessName)
        }
        .sheet(isPresented: $showingUploadSheet) {
            if let selectedDocumentType {
                DocumentUploadFlowSheet(
                    documentType: selectedDocumentType,
                    onSuccess: {
                        showingUploadSheet = false
                        replacingDocumentId = nil
                        loadDocuments()
                    }
                )
            }
        }
        .onAppear {
            loadDocuments()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verify your account")
                .font(.custom("Raleway-SemiBold", size: 28))
                .foregroundColor(Color.yugiSoftBlack)

            Text("Upload your documents so we can verify your account. Once approved, you'll be able to publish classes.")
                .font(.custom("Raleway-Regular", size: 16))
                .foregroundColor(Color.yugiSoftBlack.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Color.yugiSage)
                .frame(width: 48, height: 4)
                .cornerRadius(2)
        }
    }

    @ViewBuilder
    private func documentTile(for type: DocumentType) -> some View {
        let doc = document(for: type)
        let badge = statusBadge(for: doc)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(type.displayName)
                    .font(.custom("Raleway-SemiBold", size: 17))
                    .foregroundColor(Color.yugiSoftBlack)
                Spacer()
                statusBadgeView(badge)
            }

            if type == .dbs, let expiry = doc?.expiryDate {
                Text("Expires \(formattedDate(expiry))")
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundColor(Color.yugiSoftBlack.opacity(0.7))

                if isDBSExpiringSoon(expiry) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.yugiDustyBlush)
                        Text("Your DBS expires within 60 days — please upload a renewed certificate.")
                            .font(.custom("Raleway-Regular", size: 13))
                            .foregroundColor(Color.yugiSoftBlack.opacity(0.85))
                    }
                }
            }

            if let rejection = doc?.rejectionReason, !rejection.isEmpty, doc?.typedStatus == .rejected {
                Text(rejection)
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundColor(.red)
            }

            HStack {
                if doc == nil {
                    uploadButton(for: type)
                } else if doc?.typedStatus == .pending {
                    replaceButton(for: type, documentId: doc!.id)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yugiMocha.opacity(0.15), lineWidth: 1)
        )
    }

    private func uploadButton(for type: DocumentType) -> some View {
        Button {
            selectedDocumentType = type
            showingUploadSheet = true
        } label: {
            Text("Upload")
                .font(.custom("Raleway-SemiBold", size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.yugiMocha)
                .cornerRadius(8)
        }
        .disabled(isDeleting)
    }

    private func replaceButton(for type: DocumentType, documentId: String) -> some View {
        Button {
            deleteAndReupload(type: type, documentId: documentId)
        } label: {
            HStack(spacing: 8) {
                if isDeleting && replacingDocumentId == documentId {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text("Replace")
                    .font(.custom("Raleway-SemiBold", size: 15))
            }
            .foregroundColor(Color.yugiMocha)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.yugiDustyBlush.opacity(0.25))
            .cornerRadius(8)
        }
        .disabled(isDeleting)
    }

    private func document(for type: DocumentType) -> ProviderDocument? {
        documents.first { $0.documentType == type.rawValue }
    }

    private enum TileStatus {
        case notUploaded
        case document(DocumentStatus)
    }

    private func statusBadge(for document: ProviderDocument?) -> TileStatus {
        guard let document else { return .notUploaded }
        if let status = document.typedStatus {
            return .document(status)
        }
        return .notUploaded
    }

    @ViewBuilder
    private func statusBadgeView(_ badge: TileStatus) -> some View {
        switch badge {
        case .notUploaded:
            Text("Not uploaded")
                .font(.custom("Raleway-SemiBold", size: 12))
                .foregroundColor(Color.yugiSoftBlack.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.yugiCloud)
                .cornerRadius(8)
        case .document(let status):
            Text(status.displayName)
                .font(.custom("Raleway-SemiBold", size: 12))
                .foregroundColor(badgeTextColor(for: status))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(badgeBackgroundColor(for: status))
                .cornerRadius(8)
        }
    }

    private func badgeBackgroundColor(for status: DocumentStatus) -> Color {
        switch status {
        case .approved: return Color.yugiSage.opacity(0.35)
        case .pending: return Color.yugiDustyBlush.opacity(0.3)
        case .rejected: return Color.red.opacity(0.15)
        case .expired: return Color.orange.opacity(0.2)
        }
    }

    private func badgeTextColor(for status: DocumentStatus) -> Color {
        switch status {
        case .approved: return Color.yugiSoftBlack
        case .pending: return Color.yugiSoftBlack
        case .rejected: return .red
        case .expired: return .orange
        }
    }

    private func isDBSExpiringSoon(_ date: Date) -> Bool {
        guard let threshold = Calendar.current.date(byAdding: .day, value: 60, to: Date()) else {
            return false
        }
        return date <= threshold
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func loadDocuments() {
        isLoadingDocuments = true
        documentsLoadError = nil

        APIService.shared.fetchMyProviderDocuments()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoadingDocuments = false
                    if case .failure(let error) = completion {
                        documentsLoadError = error.localizedDescription
                    }
                },
                receiveValue: { fetched in
                    documents = fetched
                }
            )
            .store(in: &cancellables)
    }

    private func deleteAndReupload(type: DocumentType, documentId: String) {
        isDeleting = true
        replacingDocumentId = documentId

        APIService.shared.deleteProviderDocument(id: documentId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isDeleting = false
                    replacingDocumentId = nil
                    if case .failure(let error) = completion {
                        documentsLoadError = error.localizedDescription
                    }
                },
                receiveValue: { _ in
                    loadDocuments()
                    selectedDocumentType = type
                    showingUploadSheet = true
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Upload sheet

struct DocumentUploadFlowSheet: View {
    let documentType: DocumentType
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedFileURL: URL?
    @State private var fileData: Data?
    @State private var fileName: String = "document"
    @State private var mimeType: String = "image/jpeg"
    @State private var showingFileImporter = false
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    private var canUpload: Bool {
        guard fileData != nil, !isUploading else { return false }
        if documentType == .dbs {
            return expiryDate > Date()
        }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Upload \(documentType.displayName)")
                    .font(.custom("Raleway-SemiBold", size: 22))
                    .foregroundColor(Color.yugiSoftBlack)

                if documentType == .dbs {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DBS expiry date")
                            .font(.custom("Raleway-SemiBold", size: 15))
                            .foregroundColor(Color.yugiSoftBlack)
                        DatePicker(
                            "Expiry date",
                            selection: $expiryDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(Color.yugiMocha)

                        if expiryDate <= Date() {
                            Text("Expiry date must be in the future.")
                                .font(.custom("Raleway-Regular", size: 13))
                                .foregroundColor(.red)
                        }
                    }
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    uploadOptionRow(
                        icon: "photo.fill",
                        title: "Photo Library",
                        subtitle: "Choose an image from your library"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showingFileImporter = true
                } label: {
                    uploadOptionRow(
                        icon: "folder.fill",
                        title: "Browse Files",
                        subtitle: "PDF or image files"
                    )
                }
                .buttonStyle(.plain)

                if fileData != nil {
                    Text(fileName)
                        .font(.custom("Raleway-Regular", size: 14))
                        .foregroundColor(Color.yugiSoftBlack.opacity(0.8))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.custom("Raleway-Regular", size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button(action: performUpload) {
                    HStack(spacing: 8) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isUploading ? "Uploading…" : "Upload")
                            .font(.custom("Raleway-SemiBold", size: 16))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canUpload ? Color.yugiMocha : Color.yugiGray.opacity(0.4))
                    .cornerRadius(12)
                }
                .disabled(!canUpload)
            }
            .padding(24)
            .background(Color.yugiCloud.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.yugiMocha)
                        .disabled(isUploading)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadFile(from: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        fileData = data
                        fileName = "photo.jpg"
                        mimeType = "image/jpeg"
                        errorMessage = nil
                    }
                }
            }
        }
    }

    private func uploadOptionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.yugiMocha)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Raleway-SemiBold", size: 16))
                    .foregroundColor(Color.yugiSoftBlack)
                Text(subtitle)
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundColor(Color.yugiSoftBlack.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color.yugiSoftBlack.opacity(0.4))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }

    private func loadFile(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            fileData = data
            fileName = url.lastPathComponent
            mimeType = mimeType(for: url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        default: return "application/octet-stream"
        }
    }

    private func performUpload() {
        guard let fileData else { return }
        if documentType == .dbs && expiryDate <= Date() {
            errorMessage = "Please choose a future expiry date for your DBS certificate."
            return
        }

        isUploading = true
        errorMessage = nil

        let expiry: Date? = documentType == .dbs ? expiryDate : nil

        APIService.shared.uploadProviderDocument(
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            documentType: documentType,
            expiryDate: expiry
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isUploading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            },
            receiveValue: { _ in
                dismiss()
                onSuccess()
            }
        )
        .store(in: &cancellables)
    }
}

#Preview {
    ProviderVerificationScreen(businessName: "Little Musicians")
}
