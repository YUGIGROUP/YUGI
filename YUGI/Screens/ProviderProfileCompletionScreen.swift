import SwiftUI

struct ProviderProfileCompletionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var businessDescription = ""
    @State private var specialties: [String] = []
    @State private var yearsOfExperience = ""
    @State private var ageGroups = Set<String>()
    @State private var businessHours = BusinessHours()
    @State private var socialMediaLinks = SocialMediaLinks()
    @State private var showingSpecialtyPicker = false
    @State private var newSpecialty = ""
    @State private var isSaving = false
    @State private var animateCards = false
    
    private let availableSpecialties = [
        "Early Years Development",
        "Music Education",
        "Physical Development",
        "Creative Arts",
        "Language Development",
        "Sensory Play",
        "Parent & Baby Classes",
        "Special Educational Needs",
        "First Aid Certified",
        "Safeguarding Trained",
        "Forest School",
        "Montessori",
        "Baby Massage",
        "Baby Yoga",
        "Swimming Lessons",
        "Dance & Movement"
    ]
    
    private let availableAgeGroups = [
        "0-6 months",
        "6-12 months", 
        "1-2 years",
        "2-3 years",
        "3-4 years",
        "4-5 years"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Complete Your Profile")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.yugiGray)
                        
                        Text("Add more details to help parents discover your classes")
                            .font(.system(size: 16))
                            .foregroundColor(.yugiGray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#BC6C5C").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                            )
                    )
                    .offset(y: animateCards ? 0 : -50)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.1), value: animateCards)
                    
                    // Business Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            Text("About Your Business")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yugiGray)
                        }
                        
                        YUGITextEditor(
                            placeholder: "Tell parents about your business, your approach, and what makes your classes special...",
                            text: $businessDescription,
                            minHeight: 120
                        )
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .offset(y: animateCards ? 0 : -50)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: animateCards)
                    
                    // Specialties
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                
                                Text("Specialties & Qualifications")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                            }
                            
                            Spacer()
                            
                            Button {
                                showingSpecialtyPicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Add")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color(hex: "#BC6C5C"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#BC6C5C").opacity(0.1))
                                .cornerRadius(20)
                            }
                        }
                        
                        if specialties.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                
                                Text("Add your qualifications and areas of expertise")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.8))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#BC6C5C").opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#BC6C5C").opacity(0.2), lineWidth: 1)
                            )
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(specialties, id: \.self) { specialty in
                                    SpecialtyChip(
                                        text: specialty,
                                        onRemove: {
                                            specialties.removeAll { $0 == specialty }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .offset(y: animateCards ? 0 : -50)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: animateCards)
                    
                    // Experience
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            Text("Years of Experience")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yugiGray)
                        }
                        
                        Picker("Years of Experience", selection: $yearsOfExperience) {
                            Text("Select experience").tag("")
                            ForEach(1...20, id: \.self) { year in
                                Text("\(year) year\(year == 1 ? "" : "s")").tag("\(year)")
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
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .offset(y: animateCards ? 0 : -50)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: animateCards)
                    
                    // Age Groups
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            Text("Age Groups You Work With")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yugiGray)
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(availableAgeGroups, id: \.self) { ageGroup in
                                AgeGroupToggle(
                                    ageGroup: ageGroup,
                                    isSelected: ageGroups.contains(ageGroup),
                                    onToggle: {
                                        if ageGroups.contains(ageGroup) {
                                            ageGroups.remove(ageGroup)
                                        } else {
                                            ageGroups.insert(ageGroup)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .offset(y: animateCards ? 0 : -50)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: animateCards)
                    
                    // Business Hours
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock.badge")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            Text("Business Hours")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yugiGray)
                        }
                        
                        BusinessHoursView(businessHours: $businessHours)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .offset(y: animateCards ? 0 : -50)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: animateCards)
                    
                    // Social Media
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "network")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            Text("Social Media & Website")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yugiGray)
                        }
                        
                        SocialMediaView(socialMediaLinks: $socialMediaLinks)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .offset(y: animateCards ? 0 : -50)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.7), value: animateCards)
                    
                    // Save Button
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("Save Profile")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: Color(hex: "#BC6C5C").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSaving)
                    .padding(.top, 8)
                    .offset(y: animateCards ? 0 : -50)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: animateCards)
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
            }
            .sheet(isPresented: $showingSpecialtyPicker) {
                SpecialtyPickerSheet(
                    availableSpecialties: availableSpecialties,
                    selectedSpecialties: $specialties
                )
            }
            .onAppear {
                withAnimation {
                    animateCards = true
                }
            }
        }
    }
    
    private func saveProfile() {
        isSaving = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSaving = false
            dismiss()
        }
    }
}

struct SpecialtyChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.yugiGray)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yugiGray.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: "#BC6C5C").opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
        )
    }
}

struct AgeGroupToggle: View {
    let ageGroup: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                
                Text(ageGroup)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .yugiGray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? 
                AnyShapeStyle(LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )) : AnyShapeStyle(Color.white)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color(hex: "#BC6C5C").opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct BusinessHours: Codable {
    var monday = DayHours()
    var tuesday = DayHours()
    var wednesday = DayHours()
    var thursday = DayHours()
    var friday = DayHours()
    var saturday = DayHours()
    var sunday = DayHours()
    
    struct DayHours: Codable {
        var isOpen = false
        var openTime = Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()
        var closeTime = Calendar.current.date(from: DateComponents(hour: 17)) ?? Date()
    }
}

struct BusinessHoursView: View {
    @Binding var businessHours: BusinessHours
    
    private let daysOfWeek = [
        ("Monday", \BusinessHours.monday),
        ("Tuesday", \BusinessHours.tuesday),
        ("Wednesday", \BusinessHours.wednesday),
        ("Thursday", \BusinessHours.thursday),
        ("Friday", \BusinessHours.friday),
        ("Saturday", \BusinessHours.saturday),
        ("Sunday", \BusinessHours.sunday)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(daysOfWeek, id: \.0) { day, keyPath in
                DayHoursRow(
                    dayName: day,
                    dayHours: binding(for: keyPath)
                )
            }
        }
    }
    
    private func binding(for keyPath: WritableKeyPath<BusinessHours, BusinessHours.DayHours>) -> Binding<BusinessHours.DayHours> {
        Binding(
            get: { businessHours[keyPath: keyPath] },
            set: { businessHours[keyPath: keyPath] = $0 }
        )
    }
}

struct DayHoursRow: View {
    let dayName: String
    @Binding var dayHours: BusinessHours.DayHours
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(dayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Spacer()
                
                Toggle("", isOn: $dayHours.isOpen)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
            }
            
            if dayHours.isOpen {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        DatePicker("", selection: $dayHours.openTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accentColor(Color(hex: "#BC6C5C"))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Close")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        DatePicker("", selection: $dayHours.closeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accentColor(Color(hex: "#BC6C5C"))
                    }
                    
                    Spacer()
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
}

struct SocialMediaLinks: Codable {
    var website = ""
    var instagram = ""
    var facebook = ""
    var tiktok = ""
    var x = ""
}

struct SocialMediaView: View {
    @Binding var socialMediaLinks: SocialMediaLinks
    
    var body: some View {
        VStack(spacing: 12) {
            SocialMediaField(
                title: "Website",
                icon: "globe",
                text: $socialMediaLinks.website,
                placeholder: "https://yourwebsite.com"
            )
            
            SocialMediaField(
                title: "Instagram",
                icon: "camera",
                text: $socialMediaLinks.instagram,
                placeholder: "@yourbusiness"
            )
            
            SocialMediaField(
                title: "Facebook",
                icon: "person.2",
                text: $socialMediaLinks.facebook,
                placeholder: "Your Business Page"
            )
            
            SocialMediaField(
                title: "TikTok",
                icon: "music.note",
                text: $socialMediaLinks.tiktok,
                placeholder: "@yourbusiness"
            )
            
            SocialMediaField(
                title: "X (Twitter)",
                icon: "bird",
                text: $socialMediaLinks.x,
                placeholder: "@yourbusiness"
            )
        }
    }
}

struct SocialMediaField: View {
    let title: String
    let icon: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
            }
            
            YUGITextField(
                text: $text,
                placeholder: placeholder
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct SpecialtyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let availableSpecialties: [String]
    @Binding var selectedSpecialties: [String]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Select Specialties")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yugiGray)
                    
                    Text("Choose your qualifications and areas of expertise")
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#BC6C5C").opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                        )
                )
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(availableSpecialties, id: \.self) { specialty in
                            SpecialtyToggle(
                                specialty: specialty,
                                isSelected: selectedSpecialties.contains(specialty),
                                onToggle: {
                                    if selectedSpecialties.contains(specialty) {
                                        selectedSpecialties.removeAll { $0 == specialty }
                                    } else {
                                        selectedSpecialties.append(specialty)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
        }
    }
}

struct SpecialtyToggle: View {
    let specialty: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                
                Text(specialty)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .yugiGray)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? 
                AnyShapeStyle(LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )) : AnyShapeStyle(Color.white)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color(hex: "#BC6C5C").opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProviderProfileCompletionScreen()
} 