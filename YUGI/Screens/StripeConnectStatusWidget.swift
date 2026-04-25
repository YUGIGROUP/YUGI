import SwiftUI
import Combine

struct StripeConnectStatusWidget: View {
    let onTap: () -> Void

    @StateObject private var service = StripeConnectService.shared
    @State private var status: StripeConnectStatus = .notStarted
    @State private var isLoading = true
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Right-side indicator: pill for states needing attention, chevron otherwise
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                } else if let pill = pillLabel {
                    Text(pill)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(pillTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(pillBackground)
                        .cornerRadius(10)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear(perform: loadStatus)
    }

    // MARK: - State-driven content

    private var title: String { "Stripe Connect" }

    private var subtitle: String {
        switch status {
        case .notStarted: return "Set up payouts to accept bookings"
        case .inProgress: return "Finish setting up your payouts"
        case .restricted: return "Action needed — review requirements"
        case .active:     return "Payouts active"
        }
    }

    private var iconName: String {
        switch status {
        case .active:     return "checkmark.circle.fill"
        case .restricted: return "exclamationmark.triangle.fill"
        default:          return "creditcard.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .active:     return .yugiSage
        case .restricted: return .yugiError
        default:          return .white
        }
    }

    private var pillLabel: String? {
        switch status {
        case .notStarted: return "Set up"
        case .inProgress: return "Continue"
        case .restricted: return "Action needed"
        case .active:     return nil
        }
    }

    private var pillBackground: Color {
        switch status {
        case .restricted: return Color.yugiError.opacity(0.25)
        default:          return Color.white.opacity(0.2)
        }
    }

    private var pillTextColor: Color {
        switch status {
        case .restricted: return .white
        default:          return .white
        }
    }

    // MARK: - Load status

    private func loadStatus() {
        service.checkStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in isLoading = false },
                receiveValue: { response in
                    status = StripeConnectStatus(from: response)
                    isLoading = false
                }
            )
            .store(in: &cancellables)
    }
}
