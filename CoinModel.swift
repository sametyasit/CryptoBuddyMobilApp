import Foundation

// Zaman aralığı seçenekleri için enum
enum TimeFrame {
    case hour
    case day
    case week
    case month
    
    var parameterValue: String {
        switch self {
        case .hour:
            return "1h"
        case .day:
            return "24h"
        case .week:
            return "7d"
        case .month:
            return "30d"
        }
    }
}

// API'den gelen yanıtın yapısını tanımlama
struct CoinResponse: Codable {
    let data: [Coin]
}

// Coin modeli
struct Coin: Codable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    let currentPrice: Double
    let marketCap: Double?
    let marketCapRank: Int?
    let totalVolume: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChange24h: Double?
    let priceChangePercentage: Double
    let marketCapChange24h: Double?
    let marketCapChangePercentage24h: Double?
    let circulatingSupply: Double?
    let totalSupply: Double?
    let maxSupply: Double?
    let ath: Double?
    let athChangePercentage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChange24h = "price_change_24h"
        case priceChangePercentage = "price_change_percentage_24h"
        case marketCapChange24h = "market_cap_change_24h"
        case marketCapChangePercentage24h = "market_cap_change_percentage_24h"
        case circulatingSupply = "circulating_supply"
        case totalSupply = "total_supply"
        case maxSupply = "max_supply"
        case ath
        case athChangePercentage = "ath_change_percentage"
    }
    
    // Fiyat değişimini formatla (ör: +5.23% veya -2.34%)
    func formattedPriceChange() -> String {
        let prefix = priceChangePercentage >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", priceChangePercentage))%"
    }
    
    // Fiyat değişimi pozitif mi (renklendirme için)
    var isPriceChangePositive: Bool {
        return priceChangePercentage >= 0
    }
    
    // Fiyatı formatla
    func formattedPrice() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencySymbol = "$"
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = currentPrice < 1 ? 6 : 2
        
        if let formattedValue = numberFormatter.string(from: NSNumber(value: currentPrice)) {
            return formattedValue
        }
        
        return "$\(currentPrice)"
    }
    
    // Hacim değerini formatla
    func formattedVolume() -> String {
        guard let volume = totalVolume else { return "N/A" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        
        if volume >= 1_000_000_000 {
            formatter.positiveSuffix = "B"
            return formatter.string(from: NSNumber(value: volume / 1_000_000_000)) ?? "N/A"
        } else if volume >= 1_000_000 {
            formatter.positiveSuffix = "M"
            return formatter.string(from: NSNumber(value: volume / 1_000_000)) ?? "N/A"
        }
        
        return formatter.string(from: NSNumber(value: volume)) ?? "N/A"
    }
    
    // Market Cap değerini formatla
    func formattedMarketCap() -> String {
        guard let marketCap = marketCap else { return "N/A" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        
        if marketCap >= 1_000_000_000 {
            formatter.positiveSuffix = "B"
            return formatter.string(from: NSNumber(value: marketCap / 1_000_000_000)) ?? "N/A"
        } else if marketCap >= 1_000_000 {
            formatter.positiveSuffix = "M"
            return formatter.string(from: NSNumber(value: marketCap / 1_000_000)) ?? "N/A"
        }
        
        return formatter.string(from: NSNumber(value: marketCap)) ?? "N/A"
    }
} 