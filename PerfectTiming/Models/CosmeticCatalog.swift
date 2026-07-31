import PerfectTimingCore

enum CosmeticCatalog {
  static let all: [CosmeticItem] = {
    func item(
      _ id: String, _ name: String, _ category: CosmeticCategory, _ rarity: CosmeticRarity,
      _ price: Int, _ hex: String, _ premium: Bool = false, _ level: Int = 1
    ) -> CosmeticItem {
      .init(
        id: id, name: name, detail: "A \(rarity.rawValue) \(category.rawValue) style.",
        category: category, rarity: rarity, coinPrice: price, premium: premium, unlockLevel: level,
        previewHex: hex)
    }
    return [
      item("theme.neonBlue", "Neon Blue", .theme, .common, 0, "00C8FF"),
      item("theme.sunset", "Sunset", .theme, .rare, 900, "FF5B78"),
      item("theme.cyberPurple", "Cyber Purple", .theme, .rare, 1200, "A66CFF"),
      item("theme.toxicGreen", "Toxic Green", .theme, .rare, 1400, "63FF78"),
      item("theme.goldRush", "Gold Rush", .theme, .epic, 2200, "FFD45B"),
      item("theme.ice", "Ice", .theme, .rare, 1600, "9BE7FF"),
      item("theme.lava", "Lava", .theme, .epic, 2300, "FF4B2B"),
      item("theme.monochrome", "Monochrome", .theme, .common, 700, "FFFFFF"),
      item("theme.candy", "Candy", .theme, .epic, 2600, "FF8DE1"),
      item("theme.void", "Void", .theme, .premium, 0, "6C4DFF", true),
      item("marker.orb", "Pulse Orb", .marker, .common, 0, "FFFFFF"),
      item("marker.diamond", "Diamond", .marker, .common, 450, "00E5FF"),
      item("marker.comet", "Comet", .marker, .rare, 800, "FFB45C"),
      item("marker.prism", "Prism", .marker, .rare, 1000, "D9A0FF"),
      item("marker.core", "Core", .marker, .epic, 1700, "FF4D9A"),
      item("marker.pixel", "Pixel", .marker, .common, 500, "55FF99"),
      item("marker.star", "Nova Star", .marker, .legendary, 3200, "FFD76A"),
      item("marker.premium", "Apex", .marker, .premium, 0, "FFFFFF", true),
      item("trail.spark", "Spark", .trail, .common, 0, "00C8FF"),
      item("trail.ribbon", "Ribbon", .trail, .common, 500, "FF7CB8"),
      item("trail.echo", "Echo", .trail, .rare, 900, "B786FF"),
      item("trail.dust", "Stardust", .trail, .rare, 1100, "FFFFFF"),
      item("trail.flame", "Flame", .trail, .epic, 1800, "FF5B30"),
      item("trail.ice", "Frost", .trail, .epic, 1800, "A5ECFF"),
      item("trail.matrix", "Matrix", .trail, .legendary, 2800, "50FF75"),
      item("trail.premium", "Royal Wake", .trail, .premium, 0, "FFD65A", true),
      item("tap.ripple", "Ripple", .tapEffect, .common, 300, "00C8FF"),
      item("tap.burst", "Burst", .tapEffect, .rare, 750, "FFFFFF"),
      item("tap.heart", "Heart", .tapEffect, .rare, 900, "FF5A9E"),
      item("tap.shock", "Shockwave", .tapEffect, .epic, 1500, "A56CFF"),
      item("tap.portal", "Portal", .tapEffect, .epic, 1800, "55FFD5"),
      item("tap.crown", "Crown", .tapEffect, .legendary, 2800, "FFD65A"),
      item("particle.dots", "Neon Dots", .particle, .common, 250, "00C8FF"),
      item("particle.squares", "Pixels", .particle, .common, 400, "7AFF9D"),
      item("particle.stars", "Stars", .particle, .rare, 850, "FFFFFF"),
      item("particle.shards", "Shards", .particle, .epic, 1400, "B078FF"),
      item("particle.fire", "Embers", .particle, .epic, 1600, "FF6038"),
      item("particle.confetti", "Confetti", .particle, .legendary, 2400, "FF7EDB"),
      item("badge.rookie", "Rookie", .badge, .common, 0, "8FA8C0"),
      item("badge.focused", "Focused", .badge, .common, 300, "00C8FF"),
      item("badge.precise", "Precise", .badge, .rare, 600, "62F5C9"),
      item("badge.rusher", "Rusher", .badge, .rare, 700, "FF8D5B"),
      item("badge.combo", "Combo Pro", .badge, .rare, 900, "B56CFF"),
      item("badge.chaos", "Chaos Tamer", .badge, .epic, 1400, "FF4C94"),
      item("badge.daily", "Daily Ace", .badge, .epic, 1500, "FFD55B"),
      item("badge.legend", "Legend", .badge, .legendary, 3000, "FFFFFF"),
      item("badge.premium", "Premium", .badge, .premium, 0, "FFD768", true),
      item("badge.perfect", "Perfection", .badge, .legendary, 4000, "00FFFF"),
      item("gameover.fade", "Neon Fade", .gameOver, .common, 400, "00C8FF"),
      item("gameover.shatter", "Shatter", .gameOver, .epic, 1800, "FFFFFF"),
    ]
  }()
}
