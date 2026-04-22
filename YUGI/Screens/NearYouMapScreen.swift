import SwiftUI
import MapKit

// MARK: - Models

private struct NearbyClass: Identifiable, Decodable {
    let id: String
    let title: String
    let venueName: String
    let latitude: Double
    let longitude: Double
    let nextSessionStart: Date?
    let price: Double
    let categoryName: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, venueName, latitude, longitude, nextSessionStart, price, categoryName
    }

    init(from decoder: Decoder) throws {
        let c     = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        title         = try c.decode(String.self, forKey: .title)
        venueName     = try c.decode(String.self, forKey: .venueName)
        latitude      = try c.decode(Double.self,  forKey: .latitude)
        longitude     = try c.decode(Double.self,  forKey: .longitude)
        price         = try c.decode(Double.self,  forKey: .price)
        categoryName  = try c.decode(String.self,  forKey: .categoryName)
        if let s = try c.decodeIfPresent(String.self, forKey: .nextSessionStart) {
            nextSessionStart = ISO8601DateFormatter().date(from: s)
        } else {
            nextSessionStart = nil
        }
    }
}

private struct NearbyClassesResponse: Decodable {
    let success: Bool
    let data: [NearbyClass]
}

// MARK: - Screen

struct NearYouMapScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationService = LocationService.shared

    @State private var nearbyClasses: [NearbyClass] = []
    @State private var hasLoaded = false
    @State private var selectedClass: NearbyClass? = nil
    @State private var showingClassSearch = false

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
            ZStack(alignment: .bottom) {
                Map(initialPosition: initialPosition) {
                    ForEach(nearbyClasses) { cls in
                        Annotation(cls.title, coordinate: cls.coordinate, anchor: .bottom) {
                            Button {
                                withAnimation(.easeOut(duration: 0.25)) { selectedClass = cls }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.yugiMocha)
                                        .frame(width: 32, height: 32)
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    Image(systemName: "figure.2.and.child.holdinghands")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                bottomOverlay
            }
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
            .sheet(isPresented: $showingClassSearch) { ClassSearchView() }
            .task { await loadNearbyClasses() }
        }
    }

    // MARK: - Bottom overlay

    @ViewBuilder
    private var bottomOverlay: some View {
        if let cls = selectedClass {
            classPreviewCard(cls)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if hasLoaded && nearbyClasses.isEmpty {
            emptyStateCard
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .transition(.opacity)
        }
    }

    // MARK: - Class preview card

    private func classPreviewCard(_ cls: NearbyClass) -> some View {
        ZStack(alignment: .topTrailing) {
            Button { showingClassSearch = true } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cls.title)
                            .font(.custom("Raleway-SemiBold", size: 16))
                            .foregroundColor(Color.yugiSoftBlack)
                            .lineLimit(1)
                        if !cls.venueName.isEmpty {
                            Text(cls.venueName)
                                .font(.custom("Raleway-Regular", size: 13))
                                .foregroundColor(Color.yugiBodyText)
                                .lineLimit(1)
                        }
                        if let session = cls.nextSessionStart {
                            Text(formatSession(session))
                                .font(.custom("Raleway-Regular", size: 12))
                                .foregroundColor(Color.yugiBodyText)
                        }
                    }
                    Spacer()
                    Text("£\(Int(cls.price))")
                        .font(.custom("Raleway-SemiBold", size: 11))
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.yugiSage)
                        .clipShape(Capsule())
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yugiCloud)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeOut(duration: 0.25)) { selectedClass = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.yugiBodyText)
                    .padding(6)
                    .background(Color.yugiOat)
                    .clipShape(Circle())
            }
            .offset(x: 8, y: -8)
        }
    }

    // MARK: - Empty state card

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Text("No classes here yet. We're just getting started — be the first to discover one nearby.")
                .font(.custom("Raleway-Regular", size: 14))
                .foregroundColor(Color.yugiSoftBlack)
                .multilineTextAlignment(.center)
            Button { showingClassSearch = true } label: {
                Text("Browse all classes")
                    .font(.custom("Raleway-SemiBold", size: 14))
                    .foregroundColor(Color.yugiMocha)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.yugiCloud)
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private func formatSession(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM, HH:mm"
        return f.string(from: date)
    }

    private func loadNearbyClasses() async {
        let lat    = locationService.latitude
        let lng    = locationService.longitude
        let urlStr = "\(APIConfig.baseURL)/classes/nearby?lat=\(lat)&lng=\(lng)&radiusMiles=5"
        guard let url = URL(string: urlStr) else {
            await MainActor.run { hasLoaded = true }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response  = try JSONDecoder().decode(NearbyClassesResponse.self, from: data)
            await MainActor.run {
                nearbyClasses = response.data
                hasLoaded = true
            }
        } catch {
            print("NearYouMapScreen: fetch error — \(error)")
            await MainActor.run { hasLoaded = true }
        }
    }
}
