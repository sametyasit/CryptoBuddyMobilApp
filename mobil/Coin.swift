import Foundation

struct Coin: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let price: Double
    let change24h: Double
    let marketCap: Double
    let image: String
    let rank: Int
    
    var formattedPrice: String {
        if price < 1 {
            return String(format: "$%.4f", price)
        } else if price < 10 {
            return String(format: "$%.3f", price)
        } else {
            return String(format: "$%.2f", price)
        }
    }
    
    var formattedMarketCap: String {
        if marketCap >= 1_000_000_000_000 {
            return String(format: "$%.2fT", marketCap / 1_000_000_000_000)
        } else if marketCap >= 1_000_000_000 {
            return String(format: "$%.2fB", marketCap / 1_000_000_000)
        } else if marketCap >= 1_000_000 {
            return String(format: "$%.2fM", marketCap / 1_000_000)
        } else {
            return String(format: "$%.2f", marketCap)
        }
    }
    
    var formattedChange: String {
        return String(format: "%.1f%%", change24h)
    }
} 