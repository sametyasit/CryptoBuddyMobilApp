import Foundation
import SwiftUI

struct Coin: Identifiable, Codable {
    let id: String
    let name: String
    let symbol: String
    var price: Double
    var change24h: Double
    var marketCap: Double
    let image: String
    var rank: Int
    
    // Farklı zaman aralıkları için değişim değerleri
    var changeHour: Double = 0
    var changeWeek: Double = 0
    var changeMonth: Double = 0
    
    // Ek veri alanları
    var totalVolume: Double = 0
    var high24h: Double = 0
    var low24h: Double = 0
    var priceChange24h: Double = 0
    var ath: Double = 0
    var athChangePercentage: Double = 0
    var graphData: [GraphPoint] = []
    var description: String = ""
    var website: String = ""
    var twitter: String = ""
    var reddit: String = ""
    var github: String = ""
    
    // CodingKeys for backward compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, symbol, price, change24h, marketCap, image, rank
        case totalVolume, high24h, low24h, priceChange24h, ath, athChangePercentage
        case changeHour, changeWeek, changeMonth
    }
    
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
        if marketCap <= 0 {
            return "Bilinmiyor"
        } else if marketCap >= 1_000_000_000_000 {
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
    
    // Zaman aralığına göre değişim değerini formatla
    func formattedChangeForTimeFrame(timeFrame: String) -> String {
        let value: Double
        switch timeFrame {
        case "1s":
            value = changeHour
        case "7g":
            value = changeWeek
        case "30g":
            value = changeMonth
        default:
            value = change24h
        }
        return String(format: "%.1f%%", value)
    }
    
    var formattedVolume: String {
        if totalVolume <= 0 {
            return "Bilinmiyor"
        } else if totalVolume >= 1_000_000_000 {
            return String(format: "$%.2fB", totalVolume / 1_000_000_000)
        } else if totalVolume >= 1_000_000 {
            return String(format: "$%.2fM", totalVolume / 1_000_000)
        } else {
            return String(format: "$%.2f", totalVolume)
        }
    }
    
    var formattedHigh24h: String {
        if high24h <= 0 {
            return formattedPrice // Veri yoksa mevcut fiyatı göster
        }
        
        if high24h < 1 {
            return String(format: "$%.4f", high24h)
        } else if high24h < 10 {
            return String(format: "$%.3f", high24h)
        } else {
            return String(format: "$%.2f", high24h)
        }
    }
    
    var formattedLow24h: String {
        if low24h <= 0 {
            return formattedPrice // Veri yoksa mevcut fiyatı göster
        }
        
        if low24h < 1 {
            return String(format: "$%.4f", low24h)
        } else if low24h < 10 {
            return String(format: "$%.3f", low24h)
        } else {
            return String(format: "$%.2f", low24h)
        }
    }
    
    var formattedAth: String {
        if ath <= 0 {
            return "Bilinmiyor"
        } else if ath >= 1_000_000 {
            return String(format: "$%.2fM", ath / 1_000_000)
        } else if ath >= 1_000 {
            return String(format: "$%.2fK", ath / 1_000)
        } else if ath < 1 {
            return String(format: "$%.4f", ath)
        } else if ath < 10 {
            return String(format: "$%.3f", ath)
        } else {
            return String(format: "$%.2f", ath)
        }
    }
    
    var changeColor: Color {
        return change24h >= 0 ? .green : .red
    }
}

// Graph nokta modeli
struct GraphPoint: Codable, Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let price: Double
    
    var date: Date {
        return Date(timeIntervalSince1970: timestamp)
    }
    
    // APIGraphPoint'ten dönüştürme için initializer
    init(from apiPoint: APIService.APIGraphPoint) {
        self.timestamp = apiPoint.timestamp
        self.price = apiPoint.price
    }
    
    // Normal initializer
    init(timestamp: TimeInterval, price: Double) {
        self.timestamp = timestamp
        self.price = price
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp, price
    }
}

// Detaylı coin bilgisi modeli
struct CoinDetail: Codable {
    let id: String
    let description: [String: String]
    let links: Links
    
    struct Links: Codable {
        let homepage: [String]
        let twitterScreenName: String?
        let subredditURL: String?
        let reposURL: ReposURL?
        
        enum CodingKeys: String, CodingKey {
            case homepage
            case twitterScreenName = "twitter_screen_name"
            case subredditURL = "subreddit_url"
            case reposURL = "repos_url"
        }
    }
    
    struct ReposURL: Codable {
        let github: [String]?
    }
} 