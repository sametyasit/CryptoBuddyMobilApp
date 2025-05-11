import SwiftUI

class SearchViewModelLight: ObservableObject {
    @Published var coins: [Coin] = []
    @Published var news: [NewsItem] = []
    @Published var filteredCoins: [Coin] = []
    @Published var filteredNews: [NewsItem] = []
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var isLoading: Bool = false
    
    func loadInitialData() {
        isLoading = true
        
        // Coinleri yükle
        Task {
            do {
                let response = try await APIService.shared.fetchCoins(page: 1, perPage: 100)
                DispatchQueue.main.async {
                    self.coins = response.coins
                    self.isLoading = false
                }
            } catch {
                print("Error loading coins: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
        
        // Haberleri yükle
        APIService.shared.fetchCryptoNews(page: 1, itemsPerPage: 20) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self.news = items
                case .failure(let error):
                    print("Error loading news: \(error.localizedDescription)")
                }
            }
        }
    }
} 