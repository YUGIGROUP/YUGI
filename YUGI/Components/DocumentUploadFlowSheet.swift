import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Combine

struct DocumentUploadFlowSheet: View {
    let documentType: DocumentType
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
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
