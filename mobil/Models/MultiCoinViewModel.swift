import SwiftUI

class MultiCoinViewModel: ObservableObject {
    @Published var allCoins: [Coin] = []
    @Published var isLoaded = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var activeAPIs: [String] = ["CoinGecko"]
    
    private var currentPage = 1
    private let pageSize = 50
    
    func refreshCoins() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        error = nil
        currentPage = 1
        
        Task {
            await fetchCoinsPage(page: currentPage)
        }
    }
    
    func loadMoreCoins() {
        guard !isLoadingMore, !isRefreshing else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            await fetchCoinsPage(page: currentPage)
        }
    }
    
    @MainActor
    private func fetchCoinsPage(page: Int) async {
        do {
            let response = try await APIService.shared.fetchCoins(page: page, perPage: pageSize)
            
            if page == 1 {
                self.allCoins = response.coins
            } else {
                self.allCoins.append(contentsOf: response.coins)
            }
            
            self.activeAPIs = [response.source]
            self.isLoaded = true
            
            // Update coins
            if page == 1 {
                // İlk yükleme veya yenileme - tüm listeyi sıfırlayıp yeni coinleri yükle
                allCoins = response.coins
                print("📊 Liste yenilendi: \(allCoins.count) coin")
                
                // İlk coin'i kontrol et
                if let firstCoin = response.coins.first {
                    print("🔍 İlk coin: \(firstCoin.name) (\(firstCoin.symbol)) - $\(firstCoin.price)")
                }
                
                // Coin logolarını önbelleğe al
                logoPreloader.preloadLogos(for: response.coins)
            }
        } catch {
            self.error = error.localizedDescription
            if page > 1 {
                self.currentPage -= 1 // Geri al
            }
        }
        
        self.isRefreshing = false
        self.isLoadingMore = false
    }
} 