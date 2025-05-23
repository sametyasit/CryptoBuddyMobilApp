import Foundation

struct ApiKeys {
    // News API from newsapi.org
    static let newsApiKey = "YOUR_NEWS_API_KEY"
    
    // CryptoCompare API key
    static let cryptoCompareApiKey = "YOUR_CRYPTOCOMPARE_API_KEY"
    
    // CoinGecko API (free tier doesn't require API key but we're prepared for future)
    static let coinGeckoApiKey = "YOUR_COINGECKO_API_KEY_IF_NEEDED"
    
    // Add additional crypto news API keys as needed
}

// MARK: - API Endpoints
struct ApiEndpoints {
    // News API endpoints
    static let newsApiCryptoHeadlines = "https://newsapi.org/v2/everything?q=cryptocurrency+bitcoin+ethereum&sortBy=publishedAt&language=en&apiKey=\(ApiKeys.newsApiKey)"
    
    // CryptoCompare endpoints
    static let cryptoCompareNews = "https://min-api.cryptocompare.com/data/v2/news/?lang=EN&api_key=\(ApiKeys.cryptoCompareApiKey)"
    
    // CoinGecko endpoints (free tier)
    static let coinGeckoMarkets = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1"
    
    // Function to create custom news search URL
    static func newsApiCustomSearch(query: String) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "cryptocurrency"
        return "https://newsapi.org/v2/everything?q=\(encodedQuery)&sortBy=publishedAt&language=en&apiKey=\(ApiKeys.newsApiKey)"
    }
} 