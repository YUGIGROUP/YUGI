import SwiftUI

struct ProviderClassCreationScreen: View {
    let businessName: String
    let onClassPublished: ((ClassCreationData) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var classData = ClassCreationData()
    @State private var currentStep = 0
    @State private var isSaving = false
    @State private var showingLocationPicker = false
    @State private var showingSuccessAlert = false
    
    private let steps = [
        "Basic Info & Pricing",
        "Schedule", 
        "Location & Details",
        "Review & Publish"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressSection
                
                // Content based on current step
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case 0:
                            basicInfoSection
                        case 1:
                            scheduleSection
                        case 2:
                            locationDetailsSection
                        case 3:
                            reviewSection
                        default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                
                // Navigation buttons
                navigationButtons
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)

            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerScreen(selectedLocation: $classData.location)
            }
            .overlay(
                Group {
                    if showingSuccessAlert {
                        SuccessPopup(
                            title: "Class Published Successfully!",
                            message: "Your class has been published and is now visible to parents.",
                            onContinue: {
                                onClassPublished?(classData)
                                dismiss()
                            }
                        )
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(1000)
                    }
                    
                    if isSaving {
                        LoadingOverlay()
                            .transition(.opacity)
                            .zIndex(999)
                    }
                }
            )
            .animation(.easeInOut(duration: 0.3), value: showingSuccessAlert)
            .animation(.easeInOut(duration: 0.2), value: isSaving)
        }
        // Terms acceptance is handled during account creation, not here
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color(hex: "#BC6C5C") : Color.yugiGray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#BC6C5C"), lineWidth: index == currentStep ? 2 : 0)
                        )
                }
            }
            
            // Step title
            Text(steps[currentStep])
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            // Progress bar
            ProgressView(value: Double(currentStep + 1), total: Double(steps.count))
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#BC6C5C")))
                .scaleEffect(y: 2)
        }
        .padding()
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var basicInfoSection: some View {
        VStack(spacing: 24) {
            // Business Image Note
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Class Image")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                VStack(spacing: 12) {
                    if let currentUser = APIService.shared.currentUser,
                       currentUser.userType == .provider,
                       let profileImageUrl = currentUser.profileImage,
                       !profileImageUrl.isEmpty,
                       let url = URL(string: profileImageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                )
                        }
                        .onAppear {
                            print("🔍 ProviderClassCreation: AsyncImage appeared for URL: \(url)")
                        }
                        .onDisappear {
                            print("🔍 ProviderClassCreation: AsyncImage disappeared")
                        }
                    } else {
                        Circle()
                            .fill(Color(hex: "#BC6C5C").opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                            )
                    }
                    
                    Text("Your Business Image")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text("Your class will display with your business profile image.")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                )
            }
            .onAppear {
                // Debug logging
                print("🔍 ProviderClassCreation: Current user: \(APIService.shared.currentUser?.fullName ?? "nil")")
                print("🔍 ProviderClassCreation: User type: \(APIService.shared.currentUser?.userType.rawValue ?? "nil")")
                print("🔍 ProviderClassCreation: Profile image URL: \(APIService.shared.currentUser?.profileImage ?? "nil")")
                
                // Additional URL debugging
                if let currentUser = APIService.shared.currentUser,
                   let profileImageUrl = currentUser.profileImage {
                    print("🔍 ProviderClassCreation: Profile image URL exists: \(profileImageUrl)")
                    print("🔍 ProviderClassCreation: URL is empty: \(profileImageUrl.isEmpty)")
                    if let url = URL(string: profileImageUrl) {
                        print("🔍 ProviderClassCreation: URL parsing successful: \(url)")
                    } else {
                        print("🔍 ProviderClassCreation: URL parsing failed for: \(profileImageUrl)")
                    }
                } else {
                    print("🔍 ProviderClassCreation: No profile image URL found")
                }
            }
            
            // Class Name
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "textformat")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Class Name")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                YUGITextField(
                    text: $classData.className,
                    placeholder: "e.g., Baby Sensory Adventure"
                )
            }
            
            // Category
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Category")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                Picker("Category", selection: $classData.category) {
                    ForEach(ClassCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .accentColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                .colorScheme(.light)
                .frame(alignment: .leading)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                )
            }
            
            // Description
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "text.quote")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Description")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                YUGITextEditor(
                    placeholder: "Describe what parents and children can expect from your class...",
                    text: $classData.description,
                    minHeight: 120
                )
            }
            
            // Age Range
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Age Range")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                YUGITextField(
                    text: $classData.ageRange,
                    placeholder: "e.g., 0-12 months, 1-3 years"
                )
            }
            
            // Child Spots Configuration
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Tickets")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    // Individual Child Spots
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Individual Children")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Picker("Individual Children", selection: $classData.individualChildSpots) {
                            ForEach(ChildSpotsOption.allOptions, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .colorScheme(.light)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Sibling Pairs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Siblings (1 ticket for 2 children)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Picker("Sibling Pairs", selection: $classData.siblingPairs) {
                            ForEach(ChildSpotsOption.allOptions, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .colorScheme(.light)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Total Spots Display
                    HStack {
                        Text("Total Child Spots:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Spacer()
                        
                        Text("\(classData.totalChildSpots)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Pricing Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Pricing")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                VStack(spacing: 16) {
                    // Free Class Toggle
                    HStack {
                        Toggle("Free Class", isOn: $classData.isFree)
                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                    )
                    
                    // Price Input (only show if not free)
                    if !classData.isFree {
                        VStack(spacing: 16) {
                            // Base Price
                            HStack {
                                Text("£")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.yugiGray)
                                
                                TextField("0.00", value: $classData.price, format: .number)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.yugiGray)
                                
                                Text("per person")
                                    .font(.system(size: 16))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                            )
                            
                            // Adult Pricing Options
                            VStack(spacing: 12) {
                                // Adults pay the same
                                HStack {
                                    Button(action: {
                                        classData.adultsPaySame = true
                                        classData.adultsFree = false
                                    }) {
                                        HStack {
                                            Image(systemName: classData.adultsPaySame ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(classData.adultsPaySame ? Color(hex: "#BC6C5C") : .gray)
                                            Text("Adults pay the same as children")
                                                .foregroundColor(.yugiGray)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                // Adults pay different price
                                HStack {
                                    Button(action: {
                                        classData.adultsPaySame = false
                                        classData.adultsFree = false
                                    }) {
                                        HStack {
                                            Image(systemName: !classData.adultsPaySame && !classData.adultsFree ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(!classData.adultsPaySame && !classData.adultsFree ? Color(hex: "#BC6C5C") : .gray)
                                            Text("Adults pay different price")
                                                .foregroundColor(.yugiGray)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if !classData.adultsPaySame && !classData.adultsFree {
                                        HStack {
                                            Text("£")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.yugiGray)
                                            
                                            TextField("0.00", value: $classData.adultPrice, format: .number)
                                                .keyboardType(.decimalPad)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.yugiGray)
                                                .frame(width: 60)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                                
                                // Adults are free
                                HStack {
                                    Button(action: {
                                        classData.adultsPaySame = false
                                        classData.adultsFree = true
                                    }) {
                                        HStack {
                                            Image(systemName: classData.adultsFree ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(classData.adultsFree ? Color(hex: "#BC6C5C") : .gray)
                                            Text("Adults are free")
                                                .foregroundColor(.yugiGray)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            
                            // Sibling Pricing (only show if sibling pairs > 0)
                            if classData.siblingPairs.numericValue ?? 0 > 0 {
                                VStack(spacing: 12) {
                                    Text("Sibling Pricing")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.yugiGray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    HStack {
                                        Text("£")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.yugiGray)
                                        
                                        TextField("0.00", value: $classData.siblingPrice, format: .number)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.yugiGray)
                                            .frame(width: 80)
                                        
                                        Text("for siblings (2 children)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.yugiGray.opacity(0.7))
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var scheduleSection: some View {
        VStack(spacing: 24) {
            // Class Dates
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Schedule")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                VStack(spacing: 16) {
                    // Class Dates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Class Dates")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        ForEach(classData.classDates) { classDate in
                            HStack {
                                DatePicker("", selection: Binding(
                                    get: { classDate.date },
                                    set: { newDate in
                                        if let index = classData.classDates.firstIndex(where: { $0.id == classDate.id }) {
                                            classData.classDates[index].date = newDate
                                        }
                                    }
                                ), displayedComponents: .date)
                                    .labelsHidden()
                                    .accentColor(Color(hex: "#BC6C5C"))
                                
                                Spacer()
                                
                                if classData.classDates.count > 1 {
                                    Button(action: {
                                        classData.classDates.removeAll { $0.id == classDate.id }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red)
                                    }
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
                        
                        Button(action: {
                            classData.classDates.append(ClassDate())
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                Text("Add Date")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#BC6C5C"))
                            .padding()
                            .background(Color(hex: "#BC6C5C").opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Time Slots
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Slots")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        ForEach(classData.timeSlots) { timeSlot in
                            TimeSlotRow(
                                timeSlot: Binding(
                                    get: { timeSlot },
                                    set: { newTimeSlot in
                                        if let index = classData.timeSlots.firstIndex(where: { $0.id == timeSlot.id }) {
                                            classData.timeSlots[index] = newTimeSlot
                                        }
                                    }
                                ),
                                onDelete: {
                                    if classData.timeSlots.count > 1 {
                                        classData.timeSlots.removeAll { $0.id == timeSlot.id }
                                    }
                                }
                            )
                        }
                        
                        Button(action: {
                            classData.timeSlots.append(TimeSlot())
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                Text("Add Time Slot")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#BC6C5C"))
                            .padding()
                            .background(Color(hex: "#BC6C5C").opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration (minutes)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        HStack {
                            Stepper("", value: $classData.duration, in: 15...180, step: 15)
                                .labelsHidden()
                            
                            Text("\(classData.duration) minutes")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            Spacer()
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

            

        }
    }
    
    private var locationDetailsSection: some View {
        VStack(spacing: 24) {
            // Location
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Location")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                Button(action: {
                    showingLocationPicker = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(classData.location?.name ?? "Select Location")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            if let location = classData.location {
                                Text(location.address.formatted)
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                            } else {
                                Text("Tap to choose where your class will be held")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                            }
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
                .buttonStyle(PlainButtonStyle())
            }
            
            // What to Bring
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("What to Bring")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                YUGITextEditor(
                    placeholder: "List any items parents should bring for their children...",
                    text: $classData.whatToBring,
                    minHeight: 80
                )
            }
            
            // Special Requirements
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Special Requirements")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                YUGITextEditor(
                    placeholder: "Any special requirements or notes for parents...",
                    text: $classData.specialRequirements,
                    minHeight: 80
                )
            }
        }
    }
    
    private var reviewSection: some View {
        VStack(spacing: 24) {
            // Review Summary
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Review Summary")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "textformat")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        Text("Class Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Spacer()
                        
                        Text(classData.className)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                    }
                    
                    HStack {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        Text("Category")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Spacer()
                        
                        Text(classData.category.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                    }
                    
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        Text("Age Range")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Spacer()
                        
                        Text(classData.ageRange)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                    }
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        Text("Child Spots")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            if classData.individualChildSpots.numericValue ?? 0 > 0 {
                                Text("Individual: \(classData.individualChildSpots.displayName)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray)
                            }
                            if classData.siblingPairs.numericValue ?? 0 > 0 {
                                Text("Sibling Pairs: \(classData.siblingPairs.displayName)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray)
                            }
                            Text("Total: \(classData.totalChildSpots) spots")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yugiGray)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        Text("Schedule")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Spacer()
                        
                        Text("\(classData.classDates.count) dates, \(classData.timeSlots.count) time slots")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                    }
                    
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        Text("Pricing")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Spacer()
                        
                        if classData.isFree {
                            Text("Free")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("£\(classData.price, specifier: "%.2f") per person")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.yugiGray)
                                
                                if classData.siblingPairs.numericValue ?? 0 > 0 {
                                    Text("Siblings: £\(classData.siblingPrice, specifier: "%.2f")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yugiGray.opacity(0.7))
                                }
                                
                                if classData.adultsPaySame {
                                    Text("Adults pay same as children")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yugiGray.opacity(0.7))
                                } else if classData.adultsFree {
                                    Text("Adults are free")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yugiGray.opacity(0.7))
                                } else {
                                    Text("Adults: £\(classData.adultPrice, specifier: "%.2f")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yugiGray.opacity(0.7))
                                }
                            }
                        }
                    }
                    

                }
            }
            
            // Location Details
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Location")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if let location = classData.location {
                        Text("Location: \(location.name)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        Text("Address: \(location.address.formatted)")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    } else {
                        Text("Location: Not specified")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        Text("Address: Not specified")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    }
                }
            }
            
            // What to Bring
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("What to Bring")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if !classData.whatToBring.isEmpty {
                        Text("What to Bring:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        Text(classData.whatToBring)
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    } else {
                        Text("No items specified for parents to bring.")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    }
                }
            }
            
            // Special Requirements
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("Special Requirements")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if !classData.specialRequirements.isEmpty {
                        Text("Special Requirements:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        Text(classData.specialRequirements)
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    } else {
                        Text("No special requirements or notes.")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    }
                }
            }
        }
    }
    

    
    private var navigationButtons: some View {
        VStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: {
                    currentStep -= 1
                }) {
                    Text("Previous")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                )
            }
            
            if currentStep < steps.count - 1 {
                Button(action: {
                    currentStep += 1
                }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                )
            } else {
                Button(action: {
                    isSaving = true
                    Task {
                        do {
                            try await classData.publish()
                            showingSuccessAlert = true
                        } catch {
                            print("Error publishing class: \(error)")
                            // Handle error appropriately
                        }
                        isSaving = false
                    }
                }) {
                    Text("Publish Class")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#BC6C5C"))
                        .cornerRadius(12)
                }
                .padding(.top)
                .disabled(isSaving)
            }
        }
        .padding(.horizontal)
    }
} 

// MARK: - Supporting Models

// MARK: - Child Spots Options
enum ChildSpotsOption: String, CaseIterable {
    case zero = "0"
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case eleven = "11"
    case twelve = "12"
    case thirteen = "13"
    case fourteen = "14"
    case fifteen = "15"
    
    static var allOptions: [ChildSpotsOption] {
        return [.zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .eleven, .twelve, .thirteen, .fourteen, .fifteen]
    }
    
    var displayName: String {
        if rawValue == "0" {
            return "None"
        } else {
            return rawValue
        }
    }
    
    var numericValue: Int? {
        return Int(rawValue)
    }
}

struct ClassCreationData {
    var className = ""
    var category: ClassCategory = .baby
    var description = ""
    var ageRange = ""
    var individualChildSpots: ChildSpotsOption = .one
    var siblingPairs: ChildSpotsOption = .zero
    var siblingPrice: Double = 0.0
    
    var classDates: [ClassDate] = [ClassDate()]
    var timeSlots: [TimeSlot] = [TimeSlot()]
    var duration = 60
    var isFree = false
    var price: Double = 0.0
    var adultsPaySame = true
    var adultPrice: Double = 0.0
    var adultsFree = false
    
    var location: Location?
    var whatToBring = ""
    var specialRequirements = ""
    
    var maxCapacity: Int {
        let individualSpots = individualChildSpots.numericValue ?? 0
        let siblingSpots = siblingPairs.numericValue ?? 0
        return individualSpots + siblingSpots
    }
    
    var totalChildSpots: Int {
        return maxCapacity
    }
    
    var allowSiblings: Bool {
        return siblingPairs.numericValue ?? 0 > 0
    }
    
    func publish() async throws {
        // Simulate API call
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
}

struct ClassDate: Identifiable {
    let id = UUID()
    var date: Date = Date()
}

struct TimeSlot: Identifiable {
    let id = UUID()
    var startTime = Calendar.current.date(from: DateComponents(hour: 10)) ?? Date()
}

struct TimeSlotRow: View {
    @Binding var timeSlot: TimeSlot
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            DatePicker("", selection: $timeSlot.startTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .accentColor(Color(hex: "#BC6C5C"))
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
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

// MARK: - Placeholder Views

struct LocationPickerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: Location?
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Location Picker")
                    .font(.title)
                    .padding()
                
                Button("Select Location") {
                    // Mock location selection
                    selectedLocation = Location(
                        id: UUID(),
                        name: "Community Centre",
                        address: Address(
                            street: "123 Main St",
                            city: "London",
                            state: "England",
                            postalCode: "SW1A 1AA",
                            country: "United Kingdom"
                        ),
                        coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                        accessibilityNotes: nil,
                        parkingInfo: nil,
                        babyChangingFacilities: nil
                    )
                    dismiss()
                }
                .padding()
                .background(Color(hex: "#BC6C5C"))
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Spacer()
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)

        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Publishing...")
                    .foregroundColor(.white)
                    .padding(.top)
            }
        }
    }
}

struct SuccessPopup: View {
    let title: String
    let message: String
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Button("Continue") {
                    onContinue()
                }
                .padding()
                .background(Color(hex: "#BC6C5C"))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(40)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
    }
}



#Preview {
    ProviderClassCreationScreen(
        businessName: "Test Business",
        onClassPublished: { _ in }
    )
} 