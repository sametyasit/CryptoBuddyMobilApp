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
struct Coin: Codable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    var currentPrice: Double
    var marketCap: Double?
    let marketCapRank: Int?
    var totalVolume: Double?
    var high24h: Double?
    var low24h: Double?
    var priceChange24h: Double?
    var priceChangePercentage: Double
    var marketCapChange24h: Double?
    var marketCapChangePercentage24h: Double?
    let circulatingSupply: Double?
    let totalSupply: Double?
    let maxSupply: Double?
    let ath: Double?
    let athChangePercentage: Double?
    var lastUpdated: Date?
    
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
        case lastUpdated = "last_updated"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        image = try container.decode(String.self, forKey: .image)
        currentPrice = try container.decode(Double.self, forKey: .currentPrice)
        marketCap = try container.decodeIfPresent(Double.self, forKey: .marketCap)
        marketCapRank = try container.decodeIfPresent(Int.self, forKey: .marketCapRank)
        totalVolume = try container.decodeIfPresent(Double.self, forKey: .totalVolume)
        high24h = try container.decodeIfPresent(Double.self, forKey: .high24h)
        low24h = try container.decodeIfPresent(Double.self, forKey: .low24h)
        priceChange24h = try container.decodeIfPresent(Double.self, forKey: .priceChange24h)
        priceChangePercentage = try container.decode(Double.self, forKey: .priceChangePercentage)
        marketCapChange24h = try container.decodeIfPresent(Double.self, forKey: .marketCapChange24h)
        marketCapChangePercentage24h = try container.decodeIfPresent(Double.self, forKey: .marketCapChangePercentage24h)
        circulatingSupply = try container.decodeIfPresent(Double.self, forKey: .circulatingSupply)
        totalSupply = try container.decodeIfPresent(Double.self, forKey: .totalSupply)
        maxSupply = try container.decodeIfPresent(Double.self, forKey: .maxSupply)
        ath = try container.decodeIfPresent(Double.self, forKey: .ath)
        athChangePercentage = try container.decodeIfPresent(Double.self, forKey: .athChangePercentage)
        
        if let lastUpdatedString = try container.decodeIfPresent(String.self, forKey: .lastUpdated) {
            let formatter = ISO8601DateFormatter()
            lastUpdated = formatter.date(from: lastUpdatedString)
        } else {
            lastUpdated = nil
        }
    }
    
    // For WebSocket real-time coin creation
    init(id: String, symbol: String, name: String, image: String, currentPrice: Double, priceChangePercentage: Double) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.image = image
        self.currentPrice = currentPrice
        self.priceChangePercentage = priceChangePercentage
        self.marketCapRank = nil
        self.marketCap = nil
        self.totalVolume = nil
        self.high24h = nil
        self.low24h = nil
        self.priceChange24h = nil
        self.marketCapChange24h = nil
        self.marketCapChangePercentage24h = nil
        self.circulatingSupply = nil
        self.totalSupply = nil
        self.maxSupply = nil
        self.ath = nil
        self.athChangePercentage = nil
        self.lastUpdated = Date()
    }
    
    // Equatable implementation for comparison
    static func == (lhs: Coin, rhs: Coin) -> Bool {
        return lhs.id == rhs.id
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