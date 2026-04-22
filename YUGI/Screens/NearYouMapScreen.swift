import SwiftUI
import MapKit

struct NearYouMapScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService.shared

    private var initialPosition: MapCameraPosition {
        .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: locationService.latitude,
                longitude: locationService.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        ))
    }

    var body: some View {
        NavigationStack {
            Map(initialPosition: initialPosition)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Near You")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.yugiMocha, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                            .font(.custom("Raleway-Medium", size: 15))
                            .foregroundColor(.white)
                    }
                }
        }
    }
}
