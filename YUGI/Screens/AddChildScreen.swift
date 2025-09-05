import SwiftUI

struct AddChildScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var childName = ""
    @State private var dateOfBirth = Date()
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    
    let childToEdit: Child?
    let onSave: (Child) -> Void
    let onDelete: ((String) -> Void)?
    
    init(childToEdit: Child? = nil, onSave: @escaping (Child) -> Void, onDelete: ((String) -> Void)? = nil) {
        self.childToEdit = childToEdit
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.yugiCream.ignoresSafeArea()
                
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text(childToEdit == nil ? "Add Child" : "Edit Child")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(childToEdit == nil ? "Tell us about your child" : "Update your child's information")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Form
                ScrollView {
                    VStack(spacing: 24) {
                            // Debug info
                            if let child = childToEdit {
                                Text("Editing child: \(child.name)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                    .padding()
                                    .background(Color(hex: "#BC6C5C").opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                        // Child's Name
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Child's Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            YUGITextField(
                                text: $childName,
                                placeholder: "Enter your child's first name",
                                icon: "person.fill"
                            )
                        }
                        
                        // Date of Birth
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Date of Birth")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    // Month Picker
                                    Picker("Month", selection: $selectedMonth) {
                                        ForEach(1...12, id: \.self) { month in
                                            Text(monthName(for: month)).tag(month)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(maxWidth: .infinity)
                                    
                                    // Year Picker
                                    Picker("Year", selection: $selectedYear) {
                                        ForEach(2008...2024, id: \.self) { year in
                                            Text("\(year)").tag(year)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Save Button
                        Button(action: saveChild) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                Text(childToEdit == nil ? "Add Child" : "Save Changes")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .disabled(childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        
                        // Delete Button (only shown when editing)
                        if childToEdit != nil {
                            VStack(spacing: 16) {
                                Divider()
                                    .background(Color.yugiGray.opacity(0.2))
                                
                                Button(action: {
                                    showingDeleteConfirmation = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 16))
                                        Text("Delete Child")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.red)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(20)
                    }
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Child", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteChild()
                }
            } message: {
                Text("Are you sure you want to delete \(childToEdit?.name ?? "this child")? This action cannot be undone.")
            }
            .onAppear {
                print("👶 AddChildScreen: onAppear called")
                print("👶 AddChildScreen: childToEdit = \(childToEdit?.name ?? "nil")")
                
                if let child = childToEdit {
                    print("👶 AddChildScreen: Loading child data: \(child.name), age: \(child.age)")
                    childName = child.name
                    if let dob = child.dateOfBirth {
                        dateOfBirth = dob
                        let calendar = Calendar.current
                        selectedMonth = calendar.component(.month, from: dob)
                        selectedYear = calendar.component(.year, from: dob)
                        print("👶 AddChildScreen: Set dateOfBirth to: \(dob)")
                    }
                    print("👶 AddChildScreen: childName set to: \(childName)")
                } else {
                    print("👶 AddChildScreen: No child to edit, this is add mode")
                }
            }
            .onChange(of: selectedMonth) { _, _ in
                updateDateOfBirth()
            }
            .onChange(of: selectedYear) { _, _ in
                updateDateOfBirth()
            }
        }
    }
    
    private func calculateAge() -> Int {
        let calendar = Calendar.current
        let currentDate = Date()
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        var age = currentYear - selectedYear
        if currentMonth < selectedMonth {
            age -= 1
        }
        return age
    }
    
    private func monthName(for month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter.monthSymbols[month - 1]
    }
    
    private func updateDateOfBirth() {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1 // Default to first day of month
        dateOfBirth = Calendar.current.date(from: components) ?? Date()
    }
    
    private func saveChild() {
        // Validation
        guard !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Please enter your child's name")
            return
        }
        
        let age = calculateAge()
        guard age >= 0 && age <= 16 else {
            showError("Please enter a valid date of birth")
            return
        }
        
        // Create or update child with a unique ID
        let child = Child(
            id: childToEdit?.id ?? UUID().uuidString,
            name: childName.trimmingCharacters(in: .whitespacesAndNewlines),
            age: age,
            dateOfBirth: dateOfBirth
        )
        
        // Save and dismiss
        onSave(child)
        dismiss()
    }
    
    private func deleteChild() {
        // Implementation of deleteChild function
        // This function should be implemented to actually delete the child from the data source
        // For now, we'll just call the onDelete closure with the child's ID
        if let id = childToEdit?.id {
            onDelete?(id)
        }
        dismiss()
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

#Preview {
    AddChildScreen { child in
        print("Added child: \(child.name)")
    } onDelete: { childId in
        print("Deleted child with ID: \(childId)")
    }
} 