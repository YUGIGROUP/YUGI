import SwiftUI

struct ProviderClassEditScreen: View {
    let classItem: ProviderClass
    @Environment(\.dismiss) private var dismiss
    @State private var editedClass: ProviderClass
    @State private var isSaving = false
    @State private var showingLocationPicker = false
    @State private var showingSuccessAlert = false
    
    init(classItem: ProviderClass) {
        self.classItem = classItem
        self._editedClass = State(initialValue: classItem)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Basic Information
                    basicInfoSection
                    
                    // Schedule & Pricing
                    schedulePricingSection
                    
                    // Location & Details
                    locationDetailsSection
                    
                    // Save Button
                    saveButton
                }
                .padding()
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerScreen(selectedLocation: Binding(
                    get: { 
                        // Convert string to Location object for the picker
                        Location(
                            id: UUID(),
                            name: editedClass.location,
                            address: Address(
                                street: "",
                                city: "",
                                state: "",
                                postalCode: "",
                                country: ""
                            ),
                            coordinates: Location.Coordinates(latitude: 0, longitude: 0),
                            accessibilityNotes: nil,
                            parkingInfo: nil,
                            babyChangingFacilities: nil
                        )
                    },
                    set: { newLocation in
                        // Update the location string from the Location object
                        editedClass = ProviderClass(
                            id: editedClass.id,
                            name: editedClass.name,
                            description: editedClass.description,
                            category: editedClass.category,
                            price: editedClass.price,
                            isFree: editedClass.isFree,
                            maxCapacity: editedClass.maxCapacity,
                            currentBookings: editedClass.currentBookings,
                            isPublished: editedClass.isPublished,
                            status: editedClass.status,
                            location: newLocation?.name ?? editedClass.location,
                            nextSession: editedClass.nextSession,
                            createdAt: editedClass.createdAt
                        )
                    }
                ))
            }
            .alert("Changes Saved", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your class has been updated successfully.")
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Basic Information", icon: "info.circle.fill")
            
            // Class Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Class Name")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                YUGITextField(
                    text: Binding(
                        get: { editedClass.name },
                        set: { editedClass = ProviderClass(
                            id: editedClass.id,
                            name: $0,
                            description: editedClass.description,
                            category: editedClass.category,
                            price: editedClass.price,
                            isFree: editedClass.isFree,
                            maxCapacity: editedClass.maxCapacity,
                            currentBookings: editedClass.currentBookings,
                            isPublished: editedClass.isPublished,
                            status: editedClass.status,
                            location: editedClass.location,
                            nextSession: editedClass.nextSession,
                            createdAt: editedClass.createdAt
                        )}
                    ),
                    placeholder: "Enter class name"
                )
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Picker("Category", selection: Binding(
                    get: { editedClass.category },
                    set: { editedClass = ProviderClass(
                        id: editedClass.id,
                        name: editedClass.name,
                        description: editedClass.description,
                        category: $0,
                        price: editedClass.price,
                        isFree: editedClass.isFree,
                        maxCapacity: editedClass.maxCapacity,
                        currentBookings: editedClass.currentBookings,
                        isPublished: editedClass.isPublished,
                        status: editedClass.status,
                        location: editedClass.location,
                        nextSession: editedClass.nextSession,
                        createdAt: editedClass.createdAt
                    )}
                )) {
                    ForEach(ClassCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                )
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                YUGITextEditor(
                    placeholder: "Describe your class...",
                    text: Binding(
                        get: { editedClass.description },
                        set: { editedClass = ProviderClass(
                            id: editedClass.id,
                            name: editedClass.name,
                            description: $0,
                            category: editedClass.category,
                            price: editedClass.price,
                            isFree: editedClass.isFree,
                            maxCapacity: editedClass.maxCapacity,
                            currentBookings: editedClass.currentBookings,
                            isPublished: editedClass.isPublished,
                            status: editedClass.status,
                            location: editedClass.location,
                            nextSession: editedClass.nextSession,
                            createdAt: editedClass.createdAt
                        )}
                    ),
                    minHeight: 100
                )
            }
        }
    }
    
    private var schedulePricingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Schedule & Pricing", icon: "calendar.badge.clock")
            
            // Pricing
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle("Free Class", isOn: Binding(
                        get: { editedClass.isFree },
                        set: { editedClass = ProviderClass(
                            id: editedClass.id,
                            name: editedClass.name,
                            description: editedClass.description,
                            category: editedClass.category,
                            price: editedClass.price,
                            isFree: $0,
                            maxCapacity: editedClass.maxCapacity,
                            currentBookings: editedClass.currentBookings,
                            isPublished: editedClass.isPublished,
                            status: editedClass.status,
                            location: editedClass.location,
                            nextSession: editedClass.nextSession,
                            createdAt: editedClass.createdAt
                        )}
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                    
                    Spacer()
                }
                
                if !editedClass.isFree {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price per Session")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        HStack {
                            Text("£")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            TextField("0.00", value: Binding(
                                get: { editedClass.price },
                                set: { editedClass = ProviderClass(
                                    id: editedClass.id,
                                    name: editedClass.name,
                                    description: editedClass.description,
                                    category: editedClass.category,
                                    price: $0,
                                    isFree: editedClass.isFree,
                                    maxCapacity: editedClass.maxCapacity,
                                    currentBookings: editedClass.currentBookings,
                                    isPublished: editedClass.isPublished,
                                    status: editedClass.status,
                                    location: editedClass.location,
                                    nextSession: editedClass.nextSession,
                                    createdAt: editedClass.createdAt
                                )}
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
            }
            
            // Capacity
            VStack(alignment: .leading, spacing: 8) {
                Text("Class Size")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Stepper(value: Binding(
                    get: { editedClass.maxCapacity },
                    set: { editedClass = ProviderClass(
                        id: editedClass.id,
                        name: editedClass.name,
                        description: editedClass.description,
                        category: editedClass.category,
                        price: editedClass.price,
                        isFree: editedClass.isFree,
                        maxCapacity: $0,
                        currentBookings: editedClass.currentBookings,
                        isPublished: editedClass.isPublished,
                        status: editedClass.status,
                        location: editedClass.location,
                        nextSession: editedClass.nextSession,
                        createdAt: editedClass.createdAt
                    )}
                ), in: 1...15) {
                    HStack {
                        Text("\(editedClass.maxCapacity) \(editedClass.maxCapacity == 1 ? "child" : "children")")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        Spacer()
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private var locationDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Location & Details", icon: "location.fill")
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Button {
                    showingLocationPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(editedClass.location)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: saveChanges) {
            HStack {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                }
                
                Text(isSaving ? "Saving..." : "Save Changes")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSaving ? Color.yugiGray.opacity(0.3) : Color(hex: "#BC6C5C"))
            )
        }
        .disabled(isSaving)
        .buttonStyle(.plain)
    }
    
    private func saveChanges() {
        isSaving = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSaving = false
            showingSuccessAlert = true
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            Spacer()
        }
    }
}

#Preview {
    ProviderClassEditScreen(classItem: ProviderClass(
        id: UUID().uuidString,
        name: "Baby Sensory Adventure",
        description: "A journey of discovery through light, sound, and touch.",
        category: ClassCategory.baby,
        price: 15.0,
        isFree: false,
        maxCapacity: 1,
        currentBookings: 0,
        isPublished: true,
        status: ClassStatus.upcoming,
        location: "Sensory World Studio",
        nextSession: Date().addingTimeInterval(86400),
        createdAt: Date()
    ))
} 