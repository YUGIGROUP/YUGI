import SwiftUI

struct ClassSearchView: View {
    @State private var location = ""
    @State private var selectedCategory: ClassCategory?
    @State private var selectedDays: Set<WeekDay> = []
    @State private var showResults = false

    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "#BC6C5C")
                    .ignoresSafeArea()
                
                if showResults {
                    searchResultsView
                } else {
                    searchFormView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showResults {
                        Button("Back") {
                            showResults = false
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Search Form View
    private var searchFormView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("Find Your Perfect Class")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Discover amazing activities for your child")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Location Input
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("LOCATION")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1.5)
                        
                        Text("Where are you looking?")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 4)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 20)
                        
                        ZStack(alignment: .leading) {
                            if location.isEmpty {
                                Text("Enter your location")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 16))
                            }
                            
                            TextField("", text: $location)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        if !location.isEmpty {
                            Button(action: {
                                location = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                
                // Category Picker
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CATEGORY")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1.5)
                        
                        Text("What type of activity?")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 4)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ClassCategory.allCases, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = selectedCategory == category ? nil : category
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: category.iconName)
                                            .font(.system(size: 24))
                                            .foregroundColor(selectedCategory == category ? Color(hex: "#BC6C5C") : .white)
                                        
                                        Text(category.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(selectedCategory == category ? Color(hex: "#BC6C5C") : .white)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(width: 80, height: 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedCategory == category ? Color.white : Color.white.opacity(0.15))
                                    )
                                }
                                .accessibilityLabel(category.displayName)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                // Days Picker
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AVAILABLE DAYS")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1.5)
                        
                        Text("Select all that apply")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 4)
                    }
                    
                    HStack(spacing: 12) {
                        ForEach([WeekDay.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday], id: \.self) { day in
                            Button(action: {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(day.shortName.prefix(1))
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(width: 32, height: 32)
                                        .foregroundColor(selectedDays.contains(day) ? Color(hex: "#BC6C5C") : .white)
                                        .background(
                                            Circle()
                                                .fill(selectedDays.contains(day) ? Color.white : Color.white.opacity(0.15))
                                        )
                                }
                            }
                            .accessibilityLabel(day.shortName)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if selectedDays.isEmpty {
                        Text("Any day")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 4)
                    } else {
                        Text(selectedDays.map { $0.shortName }.joined(separator: ", "))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 4)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                
                // Search Button
                Button {
                    print("🔍 ClassSearchView: Search button tapped - setting showResults = true")
                    showResults = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                        Text("DISCOVER CLASSES")
                            .tracking(1)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(location.isEmpty)
                .opacity(location.isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        VStack {
            Text("Search Results")
                .font(.largeTitle)
                .foregroundColor(.white)
            
            Text("Location: \(location)")
                .foregroundColor(.white)
            
            if let category = selectedCategory {
                Text("Category: \(category.displayName)")
                    .foregroundColor(.white)
            }
            
            if !selectedDays.isEmpty {
                Text("Days: \(selectedDays.map { $0.shortName }.joined(separator: ", "))")
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ClassSearchView()
} 