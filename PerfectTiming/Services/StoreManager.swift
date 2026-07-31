import PerfectTimingCore
import StoreKit
import SwiftUI

@MainActor final class StoreManager: ObservableObject {
  enum PurchaseState: Equatable {
    case idle, loading, purchasing, pending, success
    case failed(String)
  }
  @Published private(set) var products: [Product] = []
  @Published var state: PurchaseState = .idle
  @Published private(set) var lastVerifiedTransactionID: UInt64?
  private var listener: Task<Void, Never>?
  private var entitlementHandler: ((Set<String>) -> Void)?
  func start(onEntitlements: @escaping (Set<String>) -> Void) async {
    entitlementHandler = onEntitlements
    listener = observeTransactions()
    await loadProducts()
    await refreshEntitlements()
  }
  func loadProducts() async {
    state = .loading
    do {
      products = try await Product.products(for: StoreConfiguration.productIDs).sorted {
        $0.price < $1.price
      }
      state = .idle
    } catch { state = .failed(error.localizedDescription) }
  }
  func purchase(_ product: Product) async -> Bool {
    state = .purchasing
    do {
      switch try await product.purchase() {
      case .success(let verification):
        let transaction = try verified(verification)
        lastVerifiedTransactionID = transaction.id
        await transaction.finish()
        state = .success
        await refreshEntitlements()
        return true
      case .pending:
        state = .pending
        return false
      case .userCancelled:
        state = .idle
        return false
      @unknown default:
        state = .failed("Unknown purchase result")
        return false
      }
    } catch {
      state = .failed(error.localizedDescription)
      return false
    }
  }
  func restore() async {
    do {
      try await AppStore.sync()
      await refreshEntitlements()
      state = .success
    } catch { state = .failed(error.localizedDescription) }
  }
  func refreshEntitlements() async {
    var owned = Set<String>()
    for await result in Transaction.currentEntitlements {
      if let t = try? verified(result), t.revocationDate == nil { owned.insert(t.productID) }
    }
    entitlementHandler?(owned)
  }
  private func observeTransactions() -> Task<Void, Never> {
    Task.detached { [weak self] in
      for await result in Transaction.updates {
        guard let self else { return }
        if let transaction = try? self.verified(result) {
          await transaction.finish()
          await self.refreshEntitlements()
        }
      }
    }
  }
  nonisolated private func verified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .verified(let value): return value
    case .unverified: throw StoreError.unverified
    }
  }
  enum StoreError: Error { case unverified }
}
