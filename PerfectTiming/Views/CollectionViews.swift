import PerfectTimingCore
import StoreKit
import SwiftUI

struct ShopView: View {
  @EnvironmentObject var app: AppCoordinator
  @State private var selected: CosmeticItem?
  var body: some View {
    ZStack {
      NeonBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          PurchaseStatusView(state: app.store.state)
          if !app.store.products.isEmpty {
            Text("Store Packs").font(.title2.bold()).padding(.horizontal)
            ForEach(app.store.products.filter { $0.id != StoreConfiguration.premium }) { product in
              NeonCard {
                HStack {
                  VStack(alignment: .leading) {
                    Text(product.displayName).font(.headline)
                    Text(product.description).font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Button(product.displayPrice) { Task { await purchase(product) } }
                    .buttonStyle(.borderedProminent)
                }
              }.padding(.horizontal)
            }
          }
          Text("Cosmetics").font(.title2.bold()).padding(.horizontal)
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
            ForEach(CosmeticCatalog.all.filter { !$0.premium }) { item in
              CosmeticTile(item: item, owned: app.save.inventory.owned.contains(item.id))
                .onTapGesture {
                  selected = item
                }
            }
          }.padding(.horizontal)
        }.padding(.vertical)
      }
    }.navigationTitle("Shop").sheet(item: $selected) { CosmeticPreviewView(item: $0) }
  }

  @MainActor private func purchase(_ product: Product) async {
    guard await app.store.purchase(product) else { return }
    if let amount = StoreConfiguration.coinAmounts[product.id],
      let transactionID = app.store.lastVerifiedTransactionID
    {
      _ = app.save.economy.grant(
        amount, reason: "Store coin pack", rewardID: "store-transaction-\(transactionID)")
    }
    app.applyPremiumUnlocksIfNeeded()
    app.haptics.reward()
    app.persist()
  }
}
struct InventoryView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    ZStack {
      NeonBackground()
      ScrollView {
        VStack(alignment: .leading) {
          ForEach(CosmeticCategory.allCases, id: \.self) { category in
            Text(category.rawValue.capitalized).font(.title2.bold()).padding(.top)
            ScrollView(.horizontal, showsIndicators: false) {
              HStack {
                ForEach(
                  CosmeticCatalog.all.filter {
                    $0.category == category && app.save.inventory.owned.contains($0.id)
                  }
                ) { item in
                  CosmeticTile(item: item, owned: true).frame(width: 155).onTapGesture {
                    app.save.inventory.equipped[category] = item.id
                    app.persist()
                  }
                }
              }
            }
          }
        }.padding()
      }
    }.navigationTitle("Inventory")
  }
}
struct CosmeticTile: View {
  let item: CosmeticItem
  let owned: Bool
  var body: some View {
    NeonCard {
      VStack(alignment: .leading, spacing: 9) {
        RoundedRectangle(cornerRadius: 18).fill(Color(hex: item.previewHex).gradient).frame(
          height: 92
        ).overlay(
          Image(systemName: owned ? "checkmark.circle.fill" : "sparkles").font(.title)
            .foregroundStyle(.white))
        Text(item.name).font(.headline).lineLimit(1)
        Text(owned ? "Owned" : "◉ \(item.coinPrice)").font(.caption.bold()).foregroundStyle(
          owned ? .green : .cyan)
      }
    }
  }
}
struct CosmeticPreviewView: View {
  @EnvironmentObject var app: AppCoordinator
  @Environment(\.dismiss) var dismiss
  let item: CosmeticItem
  @State private var confirm = false
  var owned: Bool { app.save.inventory.owned.contains(item.id) }
  var body: some View {
    ZStack {
      NeonBackground()
      VStack(spacing: 24) {
        Capsule().fill(.secondary).frame(width: 40, height: 5)
        RoundedRectangle(cornerRadius: 34).fill(Color(hex: item.previewHex).gradient).frame(
          height: 280
        ).overlay(TargetLogo())
        Text(item.name).font(.largeTitle.weight(.black))
        Text(item.detail).foregroundStyle(.secondary)
        Spacer()
        Button(owned ? "Equip" : "Unlock for \(item.coinPrice.formatted()) Coins") {
          if owned {
            app.save.inventory.equipped[item.category] = item.id
            app.persist()
            dismiss()
          } else {
            confirm = true
          }
        }.buttonStyle(PrimaryButtonStyle()).disabled(
          !owned && app.save.economy.balance < item.coinPrice)
      }.padding(24)
    }.confirmationDialog("Spend Timing Coins?", isPresented: $confirm) {
      Button("Unlock \(item.name)") {
        if app.save.economy.spend(item.coinPrice, reason: "Cosmetic \(item.id)") {
          app.save.inventory.owned.insert(item.id)
          app.save.inventory.equipped[item.category] = item.id
          app.persist()
          app.haptics.reward()
          dismiss()
        }
      }
      Button("Cancel", role: .cancel) {}
    }
  }
}
private struct PurchaseStatusView: View {
  let state: StoreManager.PurchaseState
  @ViewBuilder var body: some View {
    switch state {
    case .loading: ProgressView("Loading purchases…")
    case .purchasing: ProgressView("Processing purchase…")
    case .pending: Label("Purchase pending approval", systemImage: "clock")
    case .failed(let message):
      Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
    case .idle, .success: EmptyView()
    }
  }
}

struct PremiumView: View {
  @EnvironmentObject var app: AppCoordinator
  var body: some View {
    ZStack {
      NeonBackground()
      ScrollView {
        VStack(spacing: 22) {
          Image(systemName: "crown.fill").font(.system(size: 70)).foregroundStyle(.yellow)
          Text("Don’t Tap Yet! Premium").font(.largeTitle.weight(.black)).multilineTextAlignment(
            .center)
          ForEach(
            [
              "No interstitial ads", "Void theme bundle", "Exclusive Apex marker",
              "Royal Wake trail", "Premium badge", "2,500 Timing Coins",
            ], id: \.self
          ) {
            Label($0, systemImage: "checkmark.seal.fill").frame(
              maxWidth: .infinity, alignment: .leading)
          }
          if app.save.premiumEntitlements.contains(StoreConfiguration.premium) {
            Label("Premium owned", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
          } else if let product = app.store.products.first(where: {
            $0.id == StoreConfiguration.premium
          }) {
            Button("Upgrade • \(product.displayPrice)") {
              Task {
                if await app.store.purchase(product) {
                  app.save.premiumEntitlements.insert(product.id)
                  _ = app.save.economy.grant(
                    EconomyConfiguration.premiumCoinBonus, reason: "Premium bonus",
                    rewardID: "premium-bonus")
                  app.save.inventory.owned.formUnion([
                    "theme.void", "marker.premium", "trail.premium", "badge.premium",
                  ])
                  app.persist()
                }
              }
            }.buttonStyle(PrimaryButtonStyle())
          } else {
            ProgressView("Loading purchases…")
          }
          Button("Restore Purchases") { Task { await app.store.restore() } }.buttonStyle(.bordered)
          PurchaseStatusView(state: app.store.state)
          Text("One-time purchase. Rewarded ads remain optional.").font(.footnote).foregroundStyle(
            .secondary)
        }.padding(24)
      }
    }.navigationTitle("Premium")
  }
}
