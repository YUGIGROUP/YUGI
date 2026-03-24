import SwiftUI

struct ContentView: View {
    @State private var showConsentScreen = false

    var body: some View {
        NavigationStack {
            WelcomeScreen()
        }
        .fullScreenCover(isPresented: $showConsentScreen) {
            ConsentScreen {
                showConsentScreen = false
            }
        }
        .onAppear {
            showConsentScreen = ConsentManager.shared.needsToShowConsent()
        }
    }
}

#Preview {
    ContentView()
}
