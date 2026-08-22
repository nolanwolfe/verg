import SwiftUI
import RevenueCat

/// Paywall screen — always uses native UI so both monthly and yearly show correctly
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseService: PurchaseService
    @StateObject private var viewModel = PaywallViewModel()

    var onSubscribed: (() -> Void)?

    var body: some View {
        NativePaywallView(viewModel: viewModel)
            .onAppear {
                viewModel.purchaseService = purchaseService
                viewModel.onDismiss = { dismiss() }
                viewModel.onSubscribed = {
                    onSubscribed?()
                    dismiss()
                }
            }
    }
}

/// Native paywall view
struct NativePaywallView: View {
    @ObservedObject var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(.purple)

                            Text("The Ascent")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Your full archive. Your stats. Your pace.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 20)

                        // Features
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.features) { feature in
                                HStack(spacing: 12) {
                                    Image(systemName: feature.icon)
                                        .foregroundStyle(.purple)
                                        .font(.title3)

                                    Text(feature.text)
                                        .font(.body)
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Plan Selection
                        VStack(spacing: 12) {
                            PlanCard(
                                title: "Yearly",
                                price: viewModel.yearlyPrice,
                                period: "/year",
                                badge: "Best Value",
                                subtitle: viewModel.yearlyTrialDisclosure,
                                isSelected: viewModel.selectedPlan == .yearly,
                                onTap: { viewModel.selectPlan(.yearly) }
                            )

                            PlanCard(
                                title: "Monthly",
                                price: viewModel.monthlyPrice,
                                period: "/month",
                                badge: nil,
                                subtitle: viewModel.monthlyTrialDisclosure,
                                isSelected: viewModel.selectedPlan == .monthly,
                                onTap: { viewModel.selectPlan(.monthly) }
                            )
                        }
                        .padding(.horizontal, 24)

                        // CTA Button
                        VStack(spacing: 8) {
                            Button {
                                viewModel.startTrial()
                            } label: {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text(viewModel.selectedPlanHasFreeTrial ? "Start Free Trial" : "Continue")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(.purple)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .disabled(viewModel.isLoading)

                            Text(viewModel.selectedPlanHasFreeTrial
                                ? "Free trial auto-renews at \(viewModel.selectedPlan == .yearly ? viewModel.yearlyPrice + "/year" : viewModel.monthlyPrice + "/month") unless cancelled."
                                : "Subscription auto-renews unless cancelled.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)

                        // Restore & Legal
                        VStack(spacing: 8) {
                            Button("Restore Purchases") {
                                viewModel.restorePurchases()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Link("Terms", destination: URL(string: "https://nolanwolfe.github.io/verg/terms")!)
                                Text("•").foregroundColor(.secondary)
                                Link("Privacy", destination: URL(string: "https://nolanwolfe.github.io/verg/privacy")!)
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong")
            }
        }
    }
}

/// Individual plan selection card
struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)

                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.purple.opacity(0.2))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    PaywallView()
        .environmentObject(PurchaseService.shared)
}
