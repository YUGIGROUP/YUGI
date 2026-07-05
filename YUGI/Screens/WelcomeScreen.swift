import SwiftUI

struct WelcomeScreen: View {
    @State private var shouldNavigate = false

    // Single flag driving the staggered top-down settle on appear
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid Mocha background
                Color(hex: "#A3867A")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Logo
                    Image("YugiLogoMocha")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * 0.55)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -24)
                        .animation(.easeOut(duration: 0.6).delay(0.1), value: appeared)

                    // Divider line
                    Rectangle()
                        .fill(Color(hex: "#E8DDD5"))
                        .frame(width: 30, height: 2)
                        .padding(.top, 24)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -24)
                        .animation(.easeOut(duration: 0.6).delay(0.35), value: appeared)

                    // Tagline
                    Text("This generation of mothers\nhelping the next")
                        .font(.custom("Raleway-Regular", size: 15))
                        .tracking(0.5)
                        .foregroundColor(Color(hex: "#E8DDD5"))
                        .multilineTextAlignment(.center)
                        .padding(.top, 18)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -24)
                        .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)

                    Spacer()

                    // Get Started button block
                    Button(action: {
                        shouldNavigate = true
                    }) {
                        Text("Get Started")
                            .font(.custom("Raleway-Medium", size: 16))
                            .foregroundColor(Color(hex: "#FAF7F4"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "#FAF7F4"), lineWidth: 1.5)
                            )
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -24)
                    .animation(.easeOut(duration: 0.6).delay(0.7), value: appeared)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .ignoresSafeArea(.all, edges: .all)
        .navigationDestination(isPresented: $shouldNavigate) {
            AuthScreen()
        }
        .onAppear {
            appeared = true
        }
    }
}

#Preview("Welcome Flow") {
    WelcomeScreen()
}
