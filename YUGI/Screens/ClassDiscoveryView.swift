import SwiftUI
import CoreLocation

// MARK: - Shared Components

struct YUGICategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.roboto(size: 14))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.yugiOrange : Color.yugiOrange.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct YUGISearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search classes...", text: $text)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Main View

struct ClassDiscoveryView: View {
    @StateObject private var viewModel: ClassDiscoveryViewModel
    @State private var showingBookingSheet = false
    @State private var selectedClassForBooking: Class?
    
    init(locationService: LocationService, bookingService: BookingService) {
        _viewModel = StateObject(wrappedValue: ClassDiscoveryViewModel(
            locationService: locationService,
            bookingService: bookingService
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            YUGICategoryButton(
                                title: "All",
                                isSelected: viewModel.selectedCategory == nil
                            ) {
                                withAnimation {
                                    viewModel.selectedCategory = nil
                                }
                            }
                            
                            ForEach(ClassCategory.allCases, id: \.self) { category in
                                YUGICategoryButton(
                                    title: category.rawValue,
                                    isSelected: viewModel.selectedCategory == category
                                ) {
                                    withAnimation {
                                        viewModel.selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(UIColor.systemBackground))
                    
                    // Search Bar
                    YUGISearchBar(text: $viewModel.searchText)
                        .padding()
                    
                    // Class List
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredClasses.isEmpty {
                        EmptyStateView()
                    } else {
                        ClassList(
                            classes: viewModel.filteredClasses,
                            onFavorite: { classItem in
                                viewModel.toggleFavorite(for: classItem.id)
                            },
                            onBook: { selectedClass in
                                selectedClassForBooking = selectedClass
                                showingBookingSheet = true
                            }
                        )
                    }
                }
                
                if let error = viewModel.error as? LocationService.LocationError {
                    LocationErrorView(message: error.message) {
                        viewModel.startLocationUpdates()
                    }
                }
            }
            .navigationTitle("Find Classes")
            .sheet(isPresented: $showingBookingSheet) {
                if let class_ = selectedClassForBooking {
                    BookingView(classItem: class_, viewModel: viewModel)
                }
            }
        }
        .onAppear {
            viewModel.startLocationUpdates()
        }
    }
}

// MARK: - Supporting Views

struct ClassList: View {
    let classes: [Class]
    let onFavorite: (Class) -> Void
    let onBook: (Class) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(classes) { classItem in
                    ClassCard(classItem: classItem, onFavorite: onFavorite, onBook: onBook)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct ClassCard: View {
    let classItem: Class
    let onFavorite: (Class) -> Void
    let onBook: (Class) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(classItem.name)
                        .font(.roboto(size: 18))
                        .fontWeight(.medium)
                    Text(classItem.provider.name)
                        .font(.roboto(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    onFavorite(classItem)
                } label: {
                    Image(systemName: classItem.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(classItem.isFavorite ? .red : .gray)
                }
            }
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                ClassDetailRow(icon: "calendar", text: formatSchedule(classItem.schedule))
                ClassDetailRow(icon: "mappin.circle", text: classItem.location.address.formatted)
                ClassDetailRow(icon: "person.2", text: "\(classItem.currentEnrollment)/\(classItem.maxCapacity) enrolled")
                ClassDetailRow(icon: "dollarsign.circle", text: formatPrice(classItem.pricing))
            }
            
            // Rating
            HStack {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(classItem.averageRating) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
                Text(String(format: "%.1f", classItem.averageRating))
                    .font(.roboto(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // Book Button
            Button {
                onBook(classItem)
            } label: {
                Text(classItem.isAvailable ? "Book Now" : "Class Full")
                    .font(.roboto(size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(classItem.isAvailable ? Color.yugiOrange : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!classItem.isAvailable)
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    private func formatSchedule(_ schedule: Schedule) -> String {
        let days = schedule.recurringDays.map { $0.shortName }.joined(separator: ", ")
        let timeSlot = schedule.timeSlots[0]
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(days) at \(formatter.string(from: timeSlot.startTime))"
    }
    
    private func formatPrice(_ pricing: Pricing) -> String {
        return "\(pricing.currency)\(pricing.amount)/\(pricing.type.rawValue)"
    }
}

struct ClassDetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(text)
                .font(.roboto(size: 14))
                .foregroundColor(.primary)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No classes found")
                .font(.roboto(size: 18))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LocationErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .font(.roboto(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Enable Location", action: retry)
                .font(.roboto(size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.yugiOrange)
                .cornerRadius(10)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
    }
} 