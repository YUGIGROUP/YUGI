import SwiftUI

struct BookingView: View {
    let classItem: Class
    let viewModel: ClassDiscoveryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var participants = 1
    @State private var requirements = ""
    @State private var isBooking = false
    @State private var error: Error?
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Class Details")) {
                    DetailRow(icon: "person.2", text: classItem.name)
                    DetailRow(icon: "calendar", text: formatDate(classItem.schedule.startDate))
                    DetailRow(icon: "mappin.circle", text: classItem.location.address.formatted)
                }
                
                Section(header: Text("Booking Details")) {
                    Stepper("Number of Participants: \(participants)", value: $participants, in: 1...4)
                    TextField("Special Requirements", text: $requirements)
                }
                
                Section {
                    Button {
                        Task {
                            await bookClass()
                        }
                    } label: {
                        HStack {
                            Text("Confirm Booking")
                            if isBooking {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isBooking)
                }
            }
            .navigationTitle("Book Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Booking Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error as? BookingService.BookingError {
                    Text(error.message)
                } else {
                    Text("An unexpected error occurred")
                }
            }
            .alert("Booking Confirmed", isPresented: $showingConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your booking has been confirmed for \(formatDate(classItem.schedule.startDate)). A calendar event has been created.")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func bookClass() async {
        isBooking = true
        do {
            _ = try await viewModel.bookClass(classItem, participants: participants, requirements: requirements)
            showingConfirmation = true
        } catch {
            self.error = error
        }
        isBooking = false
    }
}

private struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.primary)
        }
    }
} 