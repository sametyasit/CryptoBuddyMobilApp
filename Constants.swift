import Foundation
import UIKit

struct Constants {
    struct API {
        // API anahtarınızı buraya girin
        static let cryptoCompareAPIKey = "c1086e4db7b5078baef89a7a374128c506a68d2aea26e434640986920610af78"
        
        // API endpoint'leri
        static let newsBaseURL = "https://min-api.cryptocompare.com/data/v2/news/"
        static let turkishNewsURL = "\(newsBaseURL)?lang=TR&api_key=\(cryptoCompareAPIKey)"
        
        // CoinGecko API
        static let coinGeckoBaseURL = "https://api.coingecko.com/api/v3"
        static let coinGeckoMarketsURL = "\(coinGeckoBaseURL)/coins/markets"
        
        // Websocket URLs for real-time data
        static let coinbaseWebSocketURL = "wss://ws-feed.exchange.coinbase.com"
        static let binanceWebSocketURL = "wss://stream.binance.com:9443/ws"
        
        // FTX API 
        static let ftxRestBaseURL = "https://ftx.com/api"
        static let ftxWebSocketURL = "wss://ftx.com/ws/"
        
        // CryptoCompare Websocket
        static let cryptoCompareWSURL = "wss://streamer.cryptocompare.com/v2?api_key=\(cryptoCompareAPIKey)"
    }
    
    struct UI {
        static let primaryColor = UIColor(red: 0.984, green: 0.788, blue: 0.369, alpha: 1.0) // Altın rengi
        static let backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0) // Koyu arka plan
        static let positiveColor = UIColor(red: 0.0, green: 0.8, blue: 0.2, alpha: 1.0) // Yeşil renk
        static let negativeColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0) // Kırmızı renk
        
        static let cellCornerRadius: CGFloat = 10.0
        static let imagePlaceholder = UIImage(systemName: "photo")
    }
    
    struct Time {
        static let refreshInterval: TimeInterval = 300 // 5 dakika
        static let coinRefreshInterval: TimeInterval = 30 // 30 saniye (WebSocket kullanılmazsa yedek olarak)
        static let webSocketReconnectDelay: TimeInterval = 5 // Websocket bağlantı hatası sonrası 5 saniye bekleme
    }
} 