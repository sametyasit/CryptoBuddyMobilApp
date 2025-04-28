import SwiftUI
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var filteredCoins: [Coin] = []
    @Published var filteredNews: [NewsService.NewsItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private var allCoins: [Coin] = []
    private var allNews: [NewsService.NewsItem] = []
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
            await fetchNews()
        }
    }
    
    @MainActor
    func fetchCoins() async {
        isLoading = true
        do {
            let coins = try await APIService.shared.fetchCoins(page: 1, perPage: 100)
            self.allCoins = coins
            self.coinsLoaded = true
            self.applyFilters()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    @MainActor
    func fetchNews() async {
        isLoading = true
        do {
            let news = try await NewsService.shared.fetchNews(category: .all, page: 1)
            self.allNews = news
            self.newsLoaded = true
            self.applyFilters()
        } catch {
            self.error = error.localizedDescription
        }
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