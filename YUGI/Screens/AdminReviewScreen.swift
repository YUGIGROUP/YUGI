import SwiftUI
import Combine
import QuickLook

extension Notification.Name {
    static let openAdminDocument = Notification.Name("openAdminDocument")
}

// MARK: - Admin review queue

struct AdminReviewScreen: View {
    @Binding var pendingDeepLinkDocumentId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var documents: [AdminPendingDocument] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var highlightedDocumentId: String?
    @State private var documentToReject: AdminPendingDocument?
    @State private var documentPendingApproval: AdminPendingDocument?
    @State private var previewItem: AdminDocumentPreviewItem?
    @State private var isLoadingPreview = false
    @State private var previewError: String?
    @State private var cancellables = Set<AnyCancellable>()

    private var groupedDocuments: [(providerName: String, documents: [AdminPendingDocument])] {
        let grouped = Dictionary(grouping: documents) { $0.provider.displayName }
        return grouped.keys.sorted().map { key in
            (providerName: key, documents: grouped[key]!.sorted { $0.uploadedAt < $1.uploadedAt })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.yugiCloud.ignoresSafeArea()

                if isLoading && documents.isEmpty {
                    ProgressView()
                        .tint(Color.yugiMocha)
                } else if let errorMessage, documents.isEmpty {
                    errorState(message: errorMessage)
                } else if documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }

                if isLoadingPreview {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Loading document…")
                        .padding(24)
                        .background(Color.yugiCloud)
                        .cornerRadius(12)
                        .tint(Color.yugiMocha)
                }
            }
            .navigationTitle("Admin Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundColor(Color.yugiMocha)
                }
            }
            .refreshable { await refreshDocuments() }
            .onAppear {
                loadDocuments()
                consumeDeepLinkIfNeeded()
            }
            .onChange(of: pendingDeepLinkDocumentId) { _, _ in
                consumeDeepLinkIfNeeded()
            }
            .onChange(of: documents.count) { _, _ in
                consumeDeepLinkIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAdminDocument)) { notification in
                if let documentId = notification.userInfo?["documentId"] as? String {
                    pendingDeepLinkDocumentId = documentId
                    consumeDeepLinkIfNeeded()
                }
            }
            .alert("Approve this document?", isPresented: Binding(
                get: { documentPendingApproval != nil },
                set: { if !$0 { documentPendingApproval = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    documentPendingApproval = nil
                }
                Button("Approve") {
                    if let doc = documentPendingApproval {
                        approveDocument(doc)
                    }
                    documentPendingApproval = nil
                }
            }
            .alert("Could not open document", isPresented: Binding(
                get: { previewError != nil },
                set: { if !$0 { previewError = nil } }
            )) {
                Button("OK", role: .cancel) { previewError = nil }
            } message: {
                Text(previewError ?? "")
            }
            .sheet(item: $documentToReject) { doc in
                AdminDocumentRejectSheet(document: doc) { reason in
                    rejectDocument(doc, reason: reason)
                    documentToReject = nil
                } onCancel: {
                    documentToReject = nil
                }
            }
            .sheet(item: $previewItem) { item in
                AdminDocumentQuickLookPreview(item: item)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.yugiSage)
            Text("Nothing waiting for review")
                .font(.custom("Raleway-SemiBold", size: 20))
                .foregroundColor(Color.yugiSoftBlack)
            Text("New provider uploads will appear here.")
                .font(.custom("Raleway-Regular", size: 15))
                .foregroundColor(Color.yugiBodyText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.custom("Raleway-Regular", size: 15))
                .foregroundColor(Color.yugiError)
                .multilineTextAlignment(.center)
            Button("Try again") { loadDocuments() }
                .font(.custom("Raleway-SemiBold", size: 16))
                .foregroundColor(Color.yugiMocha)
        }
        .padding(32)
    }

    private var documentList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending documents awaiting your approval")
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(Color.yugiBodyText)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)

                    ForEach(groupedDocuments, id: \.providerName) { group in
                        Text(group.providerName)
                            .font(.custom("Raleway-SemiBold", size: 17))
                            .foregroundColor(Color.yugiSoftBlack)
                            .padding(.top, 12)
                            .padding(.horizontal, 4)

                        ForEach(group.documents) { doc in
                            AdminPendingDocumentCard(
                                document: doc,
                                isHighlighted: highlightedDocumentId == doc.id,
                                onView: { openDocumentPreview(doc) },
                                onApprove: { documentPendingApproval = doc },
                                onReject: { documentToReject = doc }
                            )
                            .id(doc.id)
                        }
                    }
                }
                .padding(20)
            }
            .onChange(of: highlightedDocumentId) { _, newValue in
                guard let id = newValue else { return }
                withAnimation {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func loadDocuments() {
        isLoading = true
        errorMessage = nil
        APIService.shared.fetchPendingAdminDocuments()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { docs in
                documents = docs
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func refreshDocuments() async {
        await withCheckedContinuation { continuation in
            APIService.shared.fetchPendingAdminDocuments()
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                    continuation.resume()
                } receiveValue: { docs in
                    documents = docs
                }
                .store(in: &cancellables)
        }
    }

    private func consumeDeepLinkIfNeeded() {
        guard let targetId = pendingDeepLinkDocumentId, !targetId.isEmpty else { return }
        guard documents.contains(where: { $0.id == targetId }) else { return }
        highlightedDocumentId = targetId
        pendingDeepLinkDocumentId = nil
    }

    private func openDocumentPreview(_ doc: AdminPendingDocument) {
        isLoadingPreview = true
        APIService.shared.fetchAdminDocumentDetail(id: doc.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoadingPreview = false
                if case .failure(let error) = completion {
                    previewError = error.localizedDescription
                }
            } receiveValue: { detail in
                Task {
                    do {
                        let localURL = try await AdminDocumentPreviewLoader.downloadToTemporaryFile(
                            from: detail.viewUrl,
                            suggestedFileName: doc.originalFileName
                        )
                        previewItem = AdminDocumentPreviewItem(
                            id: doc.id,
                            fileURL: localURL,
                            title: doc.originalFileName
                        )
                    } catch {
                        previewError = error.localizedDescription
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func approveDocument(_ doc: AdminPendingDocument) {
        APIService.shared.approveAdminDocument(id: doc.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in
                documents.removeAll { $0.id == doc.id }
                if highlightedDocumentId == doc.id {
                    highlightedDocumentId = nil
                }
            }
            .store(in: &cancellables)
    }

    private func rejectDocument(_ doc: AdminPendingDocument, reason: String) {
        APIService.shared.rejectAdminDocument(id: doc.id, reason: reason)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in
                documents.removeAll { $0.id == doc.id }
                if highlightedDocumentId == doc.id {
                    highlightedDocumentId = nil
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Document card

private struct AdminPendingDocumentCard: View {
    let document: AdminPendingDocument
    let isHighlighted: Bool
    let onView: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    private var typeLabel: String {
        document.typedDocumentType?.displayName ?? document.documentType.capitalized
    }

    private var uploadDateText: String {
        AdminReviewFormatters.displayDate.string(from: document.uploadedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.provider.displayName)
                    .font(.custom("Raleway-SemiBold", size: 16))
                    .foregroundColor(Color.yugiSoftBlack)
                if let subtitle = document.provider.subtitle {
                    Text(subtitle)
                        .font(.custom("Raleway-Regular", size: 14))
                        .foregroundColor(Color.yugiBodyText)
                }
            }

            Text(typeLabel)
                .font(.custom("Raleway-SemiBold", size: 14))
                .foregroundColor(Color.yugiMocha)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.originalFileName)
                    .font(.custom("Raleway-Regular", size: 14))
                    .foregroundColor(Color.yugiSoftBlack)
                Text("Uploaded \(uploadDateText)")
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundColor(Color.yugiBodyText)
                if document.documentType == DocumentType.dbs.rawValue, let expiry = document.expiryDate {
                    Text("DBS expires \(AdminReviewFormatters.displayDate.string(from: expiry))")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(Color.yugiDeepSage)
                }
            }

            HStack(spacing: 10) {
                Button(action: onView) {
                    Text("View")
                        .font(.custom("Raleway-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(Color.yugiMocha)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.yugiMocha, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onApprove) {
                    Text("Approve")
                        .font(.custom("Raleway-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(Color.yugiMocha)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: onReject) {
                    Text("Reject")
                        .font(.custom("Raleway-SemiBold", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(Color.yugiError)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.yugiError, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.yugiOat)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHighlighted ? Color.yugiSage : Color.yugiBorder, lineWidth: isHighlighted ? 2.5 : 1)
        )
        .padding(.bottom, 8)
    }
}

// MARK: - Reject sheet

private struct AdminDocumentRejectSheet: View {
    let document: AdminPendingDocument
    let onReject: (String) -> Void
    let onCancel: () -> Void

    @State private var reason = ""
    @FocusState private var reasonFocused: Bool

    private var canSubmit: Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Reject document")
                    .font(.custom("Raleway-SemiBold", size: 22))
                    .foregroundColor(Color.yugiSoftBlack)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Document")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(Color.yugiBodyText)
                    Text(document.originalFileName)
                        .font(.custom("Raleway-SemiBold", size: 15))
                        .foregroundColor(Color.yugiSoftBlack)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yugiOat)
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason for rejection")
                        .font(.custom("Raleway-SemiBold", size: 14))
                        .foregroundColor(Color.yugiSoftBlack)
                    TextField("Explain what the provider needs to fix…", text: $reason, axis: .vertical)
                        .lineLimit(4...8)
                        .focused($reasonFocused)
                        .padding(12)
                        .background(Color.yugiCloud)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.yugiBorder, lineWidth: 1)
                        )
                    Text("\(reason.trimmingCharacters(in: .whitespacesAndNewlines).count)/10 minimum characters")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundColor(canSubmit ? Color.yugiDeepSage : Color.yugiBodyText)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Cancel", action: onCancel)
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(Color.yugiMocha)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yugiMocha, lineWidth: 1.5)
                        )

                    Button("Reject") {
                        onReject(reason.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .font(.custom("Raleway-SemiBold", size: 16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(canSubmit ? Color.yugiError : Color.yugiError.opacity(0.4))
                    .cornerRadius(12)
                    .disabled(!canSubmit)
                }
            }
            .padding(24)
            .background(Color.yugiCloud.ignoresSafeArea())
            .onAppear { reasonFocused = true }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - QuickLook (download fresh each session, temp file removed on dismiss)

struct AdminDocumentPreviewItem: Identifiable {
    let id: String
    let fileURL: URL
    let title: String
}

enum AdminDocumentPreviewLoader {
    static func downloadToTemporaryFile(from urlString: String, suggestedFileName: String) async throws -> URL {
        guard let remoteURL = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: remoteURL)
        let ext = (suggestedFileName as NSString).pathExtension
        let base = (suggestedFileName as NSString).deletingPathExtension
        let fileName = "\(UUID().uuidString)-\(base).\(ext.isEmpty ? "bin" : ext)"
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: localURL, options: .atomic)
        return localURL
    }
}

struct AdminDocumentQuickLookPreview: UIViewControllerRepresentable {
    let item: AdminDocumentPreviewItem
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: QLPreviewController, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(item: item, onDismiss: dismiss)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let item: AdminDocumentPreviewItem
        let onDismiss: DismissAction

        init(item: AdminDocumentPreviewItem, onDismiss: DismissAction) {
            self.item = item
            self.onDismiss = onDismiss
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            item.fileURL as NSURL
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: item.fileURL)
        }

        deinit {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
    }
}

private enum AdminReviewFormatters {
    static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

#Preview {
    AdminReviewScreen(pendingDeepLinkDocumentId: .constant(nil))
}
