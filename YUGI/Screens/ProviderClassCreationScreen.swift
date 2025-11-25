import SwiftUI
import Combine

struct ProviderClassCreationScreen: View {
    let businessName: String
    let onClassPublished: ((ClassCreationData) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var classData = ClassCreationData()
    @State private var currentStep = 0
    @State private var isSaving = false
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
                       let profileImageString = currentUser.profileImage,
                       !profileImageString.isEmpty,
                       let imageData = Data(base64Encoded: profileImageString),
                       let profileImage = UIImage(data: imageData) {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .onAppear {
                                print("🔍 ProviderClassCreation: Profile image displayed successfully")
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
                
                // Additional profile image debugging
                if let currentUser = APIService.shared.currentUser,
                   let profileImageString = currentUser.profileImage {
                    print("🔍 ProviderClassCreation: Profile image string exists: \(profileImageString.prefix(50))...")
                    print("🔍 ProviderClassCreation: String is empty: \(profileImageString.isEmpty)")
                    if let imageData = Data(base64Encoded: profileImageString),
                       let _ = UIImage(data: imageData) {
                        print("🔍 ProviderClassCreation: Base64 image parsing successful")
                    } else {
                        print("🔍 ProviderClassCreation: Base64 image parsing failed")
                    }
                } else {
                    print("🔍 ProviderClassCreation: No profile image string found")
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
                        HStack {
                            Text("Individual Children")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            InfoButton(
                                title: "Individual Tickets",
                                message: "Individual tickets are for single children. Each child needs their own ticket to attend the class. This is the standard ticket type for most bookings."
                            )
                        }
                        
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
                        HStack {
                            Text("Siblings")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            InfoButton(
                                title: "Sibling Tickets",
                                message: "Sibling tickets allow siblings to attend together. You can set a different price for sibling tickets - this could be a discount, the same price, or any pricing that works for your class. Perfect for families with multiple children who want to participate together."
                            )
                        }
                        
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
                    
                    // Twin Pairs
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Twins")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            InfoButton(
                                title: "Twin Tickets",
                                message: "Twin tickets are specifically for families with twins who want to attend together. You can set a different price for twin tickets - this could be a discount, the same price, or any pricing that works for your class. Perfect for families with twins who want to participate together."
                            )
                        }
                        
                        Picker("Twin Pairs", selection: $classData.twinPairs) {
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
                    VStack(spacing: 8) {
                        HStack {
                            Text("Total Child Spots:")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            Spacer()
                            
                            Text("\(classData.totalChildSpots)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            HStack {
                                Text("Expected Adults:")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.yugiGray)
                                
                                InfoButton(
                                    title: "Expected Adults",
                                    message: "We assume 1 adult will attend with each ticket sold. So 1 individual child ticket = 1 adult, 1 sibling pair ticket = 1 adult, 1 twin pair ticket = 1 adult. This helps you plan for the total number of people in your class."
                                )
                            }
                            
                            Spacer()
                            
                            Text("\(classData.expectedAdults)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
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
                                
                                Text("per ticket")
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
                                // Adults are free
                                HStack {
                                    Button(action: {
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
                                
                                // Adults pay different price
                                HStack {
                                    Button(action: {
                                        classData.adultsFree = false
                                    }) {
                                        HStack {
                                            Image(systemName: !classData.adultsFree ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(!classData.adultsFree ? Color(hex: "#BC6C5C") : .gray)
                                            Text("Adults pay different price")
                                                .foregroundColor(.yugiGray)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if !classData.adultsFree {
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
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            
                            // Sibling Pricing (only show if sibling pairs > 0)
                            if classData.siblingPairs.numericValue ?? 0 > 0 {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Sibling Pricing")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.yugiGray)
                                        
                                        InfoButton(
                                            title: "Sibling Pricing",
                                            message: "Set the price for sibling tickets. This is the total price for both siblings together. You can choose any pricing strategy - a discount to encourage family bookings, the same price as individual tickets, or any amount that works for your class."
                                        )
                                        
                                        Spacer()
                                    }
                                    
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
                            
                            // Twin Pricing (only show if twin pairs > 0)
                            if classData.twinPairs.numericValue ?? 0 > 0 {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Twin Pricing")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.yugiGray)
                                        
                                        InfoButton(
                                            title: "Twin Pricing",
                                            message: "Set the price for twin tickets. This is the total price for both twins together. You can choose any pricing strategy - a discount to encourage twin bookings, the same price as individual tickets, or any amount that works for your class."
                                        )
                                        
                                        Spacer()
                                    }
                                    
                                    HStack {
                                        Text("£")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.yugiGray)
                                        
                                        TextField("0.00", value: $classData.twinPrice, format: .number)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.yugiGray)
                                            .frame(width: 80)
                                        
                                        Text("for twins (2 children)")
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
                
                VStack(spacing: 16) {
                    // Venue Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Venue Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        YUGITextField(
                            text: $classData.venueName,
                            placeholder: "e.g., Community Centre, Library, Park"
                        )
                    }
                    
                    // Street Address
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Street Address")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        YUGITextField(
                            text: $classData.streetAddress,
                            placeholder: "e.g., 123 Main Street"
                        )
                    }
                    
                    // City
                    VStack(alignment: .leading, spacing: 8) {
                        Text("City")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        YUGITextField(
                            text: $classData.city,
                            placeholder: "e.g., London"
                        )
                    }
                    
                    // Postal Code
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Postal Code")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        YUGITextField(
                            text: $classData.postalCode,
                            placeholder: "e.g., SW1A 1AA"
                        )
                    }
                    
                    // Coordinates (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coordinates (Optional)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Latitude")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                
                                TextField("0.0", value: $classData.latitude, format: .number)
                                    .keyboardType(.decimalPad)
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Longitude")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                
                                TextField("0.0", value: $classData.longitude, format: .number)
                                    .keyboardType(.decimalPad)
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        
                        Text("Tip: You can find coordinates by searching your venue on Google Maps")
                            .font(.system(size: 12))
                            .foregroundColor(.yugiGray.opacity(0.6))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
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
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Total: \(classData.totalChildSpots) child spots")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Expected: \(classData.expectedAdults) adults")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                            }
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
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            // Show actual dates
                            if !classData.classDates.isEmpty {
                                Text("Dates: \(classData.formatDates(classData.classDates))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray)
                            }
                            
                            // Show actual times
                            if !classData.timeSlots.isEmpty {
                                Text("Times: \(classData.formatTimes(classData.timeSlots))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.yugiGray)
                            }
                        }
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
                                Text("£\(classData.price, specifier: "%.2f") per ticket")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.yugiGray)
                                
                                if classData.siblingPairs.numericValue ?? 0 > 0 {
                                    Text("Siblings: £\(classData.siblingPrice, specifier: "%.2f")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yugiGray.opacity(0.7))
                                }
                                
                                
                                // Pricing breakdown with service fees
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Total Cost Breakdown:")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.yugiGray)
                                    
                                    if classData.individualChildSpots.numericValue ?? 0 > 0 {
                                        let individualSpots = classData.individualChildSpots.numericValue ?? 0
                                        let individualCost = Double(individualSpots) * classData.price
                                        Text("\(individualSpots) individual: £\(individualCost, specifier: "%.2f")")
                                            .font(.system(size: 10))
                                            .foregroundColor(.yugiGray.opacity(0.7))
                                    }
                                    
                                    if classData.siblingPairs.numericValue ?? 0 > 0 {
                                        let siblingPairs = classData.siblingPairs.numericValue ?? 0
                                        let siblingCost = Double(siblingPairs) * classData.siblingPrice
                                        Text("\(siblingPairs) sibling pair(s): £\(siblingCost, specifier: "%.2f")")
                                            .font(.system(size: 10))
                                            .foregroundColor(.yugiGray.opacity(0.7))
                                    }
                                    
                                    if classData.twinPairs.numericValue ?? 0 > 0 {
                                        let twinPairs = classData.twinPairs.numericValue ?? 0
                                        let twinCost = Double(twinPairs) * classData.twinPrice
                                        Text("\(twinPairs) twin pair(s): £\(twinCost, specifier: "%.2f")")
                                            .font(.system(size: 10))
                                            .foregroundColor(.yugiGray.opacity(0.7))
                                    }
                                    
                                    // Adult pricing breakdown
                                    if !classData.adultsFree {
                                        let totalTickets = (classData.individualChildSpots.numericValue ?? 0) + (classData.siblingPairs.numericValue ?? 0) + (classData.twinPairs.numericValue ?? 0)
                                        let adultCost = Double(totalTickets) * classData.adultPrice
                                        Text("\(totalTickets) adult(s): £\(adultCost, specifier: "%.2f")")
                                            .font(.system(size: 10))
                                            .foregroundColor(.yugiGray.opacity(0.7))
                                    }
                                    
                                    Text("Total: £\(classData.totalCost, specifier: "%.2f")")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                }
                                
                                if classData.adultsFree {
                                    Text("Adults are free")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yugiGray.opacity(0.7))
                                } else {
                                    Text("Adults: £\(classData.adultPrice, specifier: "%.2f") per adult")
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
                    if !classData.venueName.isEmpty {
                        Text("Venue: \(classData.venueName)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                    }
                    
                    if !classData.streetAddress.isEmpty || !classData.city.isEmpty {
                        let address = [classData.streetAddress, classData.city, classData.postalCode].filter { !$0.isEmpty }.joined(separator: ", ")
                        Text("Address: \(address)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                    }
                    
                    if classData.latitude != 0.0 && classData.longitude != 0.0 {
                        Text("Coordinates: \(classData.latitude, specifier: "%.6f"), \(classData.longitude, specifier: "%.6f")")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    }
                    
                    if classData.venueName.isEmpty && classData.streetAddress.isEmpty && classData.city.isEmpty {
                        Text("Location: Not specified")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
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
    var twinPairs: ChildSpotsOption = .zero
    var twinPrice: Double = 0.0
    
    var classDates: [ClassDate] = [ClassDate()]
    var timeSlots: [TimeSlot] = [TimeSlot()]
    var duration = 60
    var isFree = false
    var price: Double = 0.0
    var adultsPaySame = false
    var adultPrice: Double = 0.0
    var adultsFree = false
    
    var location: String = ""
    var venueName: String = ""
    var streetAddress: String = ""
    var city: String = ""
    var postalCode: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var whatToBring = ""
    var specialRequirements = ""
    
    var maxCapacity: Int {
        let individualSpots = individualChildSpots.numericValue ?? 0
        let siblingSpots = siblingPairs.numericValue ?? 0
        let twinSpots = twinPairs.numericValue ?? 0
        // Each sibling pair = 2 children, each twin pair = 2 children
        return individualSpots + (siblingSpots * 2) + (twinSpots * 2)
    }
    
    var totalChildSpots: Int {
        return maxCapacity
    }
    
    // Calculate expected adults (1 adult per ticket)
    var expectedAdults: Int {
        let individualTickets = individualChildSpots.numericValue ?? 0
        let siblingTickets = siblingPairs.numericValue ?? 0
        let twinTickets = twinPairs.numericValue ?? 0
        // 1 adult per ticket (individual, sibling pair, or twin pair)
        return individualTickets + siblingTickets + twinTickets
    }
    
    var allowSiblings: Bool {
        return siblingPairs.numericValue ?? 0 > 0
    }
    
    // Service fee constant
    static let serviceFee: Double = 1.99
    
    // Calculate total cost for individual tickets
    var individualTicketTotal: Double {
        let individualSpots = individualChildSpots.numericValue ?? 0
        return (Double(individualSpots) * price) + (Double(individualSpots) * Self.serviceFee)
    }
    
    // Calculate total cost for sibling tickets
    var siblingTicketTotal: Double {
        let siblingPairCount = siblingPairs.numericValue ?? 0
        return (Double(siblingPairCount) * siblingPrice) + (Double(siblingPairCount) * Self.serviceFee)
    }
    
    // Calculate total cost for twin tickets
    var twinTicketTotal: Double {
        let twinPairCount = twinPairs.numericValue ?? 0
        return (Double(twinPairCount) * twinPrice) + (Double(twinPairCount) * Self.serviceFee)
    }
    
    // Calculate total cost for adults
    var adultTicketTotal: Double {
        if adultsFree {
            return 0.0
        } else {
            let totalTickets = (individualChildSpots.numericValue ?? 0) + (siblingPairs.numericValue ?? 0) + (twinPairs.numericValue ?? 0)
            return Double(totalTickets) * adultPrice
        }
    }
    
    // Calculate total cost for all tickets (provider view - no service fees)
    var totalCost: Double {
        let individualCost = Double(individualChildSpots.numericValue ?? 0) * price
        let siblingCost = Double(siblingPairs.numericValue ?? 0) * siblingPrice
        let twinCost = Double(twinPairs.numericValue ?? 0) * twinPrice
        let adultCost = adultTicketTotal
        return individualCost + siblingCost + twinCost + adultCost
    }
    
    // Format dates for display
    func formatDates(_ dates: [ClassDate]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let dateStrings = dates.map { formatter.string(from: $0.date) }
        return dateStrings.joined(separator: ", ")
    }
    
    // Format times for display
    func formatTimes(_ timeSlots: [TimeSlot]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        let timeStrings = timeSlots.map { formatter.string(from: $0.startTime) }
        return timeStrings.joined(separator: ", ")
    }
    
    func publish() async throws {
        // First, create the class
        let createResponse = try await APIService.shared.createClass(classData: self)
            .receive(on: DispatchQueue.main)
            .async()
        
        print("✅ Class created successfully: \(createResponse.data.name)")
        
        // Then, publish the class
        let publishResponse = try await APIService.shared.publishClass(id: createResponse.data.id)
            .receive(on: DispatchQueue.main)
            .async()
        
        print("✅ Class published successfully: \(publishResponse.data.name)")
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

// MARK: - Extensions
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}

#Preview {
    ProviderClassCreationScreen(
        businessName: "Test Business",
        onClassPublished: { _ in }
    )
} 