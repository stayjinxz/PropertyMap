import SwiftUI
import StoreKit

private struct SubscriptionTier: Identifiable {
    let name: String
    let monthly: String
    let yearly: String
    let summary: String
    let productStem: String
    var id: String { productStem }
}

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var activeProductIDs: Set<String> = []
    @Published var message: String?
    @Published var busy = false

    // Create matching auto-renewable subscriptions in App Store Connect.
    private let ids = ["com.stayjinxz.propertymap.starter.monthly", "com.stayjinxz.propertymap.starter.yearly",
                       "com.stayjinxz.propertymap.investor.monthly", "com.stayjinxz.propertymap.investor.yearly",
                       "com.stayjinxz.propertymap.investorplus.monthly", "com.stayjinxz.propertymap.investorplus.yearly",
                       "com.stayjinxz.propertymap.professional.monthly", "com.stayjinxz.propertymap.professional.yearly"]

    func refresh() async {
        do {
            products = try await Product.products(for: ids)
            await refreshEntitlements()
        } catch {
            message = "Subscription plans aren't available yet. Please try again later."
        }
    }

    func refreshEntitlements() async {
        var valid: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                valid.insert(transaction.productID)
            }
        }
        activeProductIDs = valid
    }

    func purchase(_ product: Product) async {
        busy = true
        defer { busy = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    message = "Subscription activated on this device."
                case .unverified:
                    message = "Purchase could not be verified."
                }
            case .userCancelled: break
            case .pending: message = "Purchase is pending approval."
            @unknown default: message = "Unable to complete purchase."
            }
        } catch {
            message = "Purchase failed. Please try again."
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = activeProductIDs.isEmpty ? "No active subscriptions found." : "Purchases restored."
        } catch {
            message = "Could not restore purchases."
        }
    }
}

struct SubscriptionView: View {
    @StateObject private var store = SubscriptionStore()
    @State private var yearly = false

    private let tiers: [SubscriptionTier] = [
        .init(name: "Starter", monthly: "$9.99", yearly: "$99.99", summary: "More searches and saved properties", productStem: "starter"),
        .init(name: "Investor", monthly: "$29.99", yearly: "$299.99", summary: "Valuations and advanced filters", productStem: "investor"),
        .init(name: "Investor Plus", monthly: "$69.99", yearly: "$699.99", summary: "Expanded research and higher limits", productStem: "investorplus"),
        .init(name: "Professional", monthly: "$149", yearly: "$1,490", summary: "Professional tools and high-volume research", productStem: "professional")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Find the plan that fits you.")
                        .font(.title2.bold())
                    Picker("Billing period", selection: $yearly) {
                        Text("Monthly").tag(false)
                        Text("Yearly").tag(true)
                    }.pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Free").font(.headline)
                        Text("$0 forever").font(.title2.bold())
                        Text("Basic map browsing and limited searches")
                            .foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                    ForEach(tiers) { tier in
                        let id = "com.stayjinxz.propertymap.\(tier.productStem).\(yearly ? "yearly" : "monthly")"
                        let product = store.products.first(where: { $0.id == id })
                        VStack(alignment: .leading, spacing: 8) {
                            Text(tier.name).font(.headline)
                            HStack(alignment: .firstTextBaseline) {
                                Text(product?.displayPrice ?? (yearly ? tier.yearly : tier.monthly))
                                    .font(.title.bold())
                                Text(yearly ? "/year" : "/month").foregroundStyle(.secondary)
                            }
                            Text(tier.summary).font(.subheadline).foregroundStyle(.secondary)
                            if store.activeProductIDs.contains(id) {
                                Label("Current subscription", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if let product {
                                Button("Subscribe") { Task { await store.purchase(product) } }
                                    .buttonStyle(.borderedProminent).disabled(store.busy)
                            } else {
                                Text("Purchases available after App Store setup")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button("Restore purchases") { Task { await store.restore() } }
                        .disabled(store.busy)
                    Text("Prices shown are proposed until configured in App Store Connect. Paid features and usage limits are not yet enabled. Subscriptions renew automatically unless cancelled in Apple account settings.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationTitle("Plans")
            .task { await store.refresh() }
            .alert("Subscriptions", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK", role: .cancel) { store.message = nil }
            } message: { Text(store.message ?? "") }
        }
    }
}
