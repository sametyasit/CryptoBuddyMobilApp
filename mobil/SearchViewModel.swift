import SwiftUI
import Combine

// Burada tanımlanan NewsItem silindi, projede zaten var

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var filteredCoins: [Coin] = []
    @Published var filteredNews: [NewsItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private var allCoins: [Coin] = []
    private var allNews: [NewsItem] = []
    private var coinsLoaded = false
    private var newsLoaded = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }
    
    func loadInitialData() {
        Task {
            await fetchCoins()
            await fetchDemoNews()
        }
    }
    
    @MainActor
    func fetchCoins() async {
        isLoading = true
        do {
            let response = try await APIService.shared.fetchCoins(page: 1, perPage: 100)
            self.allCoins = response.coins
            self.coinsLoaded = true
            self.applyFilters()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    @MainActor
    func fetchDemoNews() async {
        isLoading = true
        
        // Demo haberler oluştur (Date -> String formatında)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        self.allNews = [
            NewsItem(
                id: "1",
                title: "Bitcoin Yeni Bir Rekora İmza Attı",
                description: "Bitcoin, son 24 saatte %5 yükselerek yeni bir rekor kırdı.",
                url: "https://example.com/news/1",
                imageUrl: "https://example.com/images/bitcoin.jpg",
                source: "Crypto News",
                publishedAt: dateFormatter.string(from: Date())
            ),
            NewsItem(
                id: "2",
                title: "Ethereum 2.0 Güncellemesi",
                description: "Ethereum ekosistemi, yeni bir güncelleme ile daha verimli hale geliyor.",
                url: "https://example.com/news/2",
                imageUrl: "https://example.com/images/ethereum.jpg",
                source: "DeFi News", 
                publishedAt: dateFormatter.string(from: Date().addingTimeInterval(-86400))
            )
        ]
        
        self.newsLoaded = true
        self.applyFilters()
        isLoading = false
    }
    
    private func applyFilters() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            filteredCoins = []
            filteredNews = []
            return
        }
        filteredCoins = allCoins.filter { coin in
            coin.name.localizedCaseInsensitiveContains(text) ||
            coin.symbol.localizedCaseInsensitiveContains(text)
        }
        filteredNews = allNews.filter { news in
            news.title.localizedCaseInsensitiveContains(text) ||
            news.description.localizedCaseInsensitiveContains(text)
        }
    }
} 