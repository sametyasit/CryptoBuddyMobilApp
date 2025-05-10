import Foundation
import SwiftUI

class CoinListViewModel: ObservableObject {
    @Published var coins: [Coin] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var allPagesLoaded = false
    @Published var errorMessage: String? = nil
    @Published var currentAPI = "Yükleniyor..."
    
    private var currentPage = 1
    private let coinsPerPage = 30
    private let maxCoins = 1000
    
    @MainActor
    func fetchCoins() async {
        isLoading = true
        currentPage = 1  // Sayfa numarasını sıfırla
        
        do {
            // Her sayfada 30 coin çekelim
            let perPage = coinsPerPage
            let fetchResult = try await APIService.shared.fetchCoins(page: currentPage, perPage: perPage)
            
            // Gelen verileri kaydedelim
            coins = fetchResult.coins
            
            // API kaynağını güncelle
            currentAPI = fetchResult.source
            
            // Sadece hiç coin gelmediğinde true yap, aksi takdirde her zaman daha fazla coin yüklenebilir
            allPagesLoaded = fetchResult.coins.isEmpty || coins.count >= maxCoins
            
            print("📱 İlk sayfa yüklendi: \(coins.count) coin")
            
        } catch APIService.APIError.allAPIsFailed {
            errorMessage = "Hiçbir API kaynağından veri alınamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin."
        } catch APIService.APIError.rateLimitExceeded {
            errorMessage = "API hız limiti aşıldı. Lütfen bir süre sonra tekrar deneyin."
        } catch URLError.timedOut {
            errorMessage = "Sunucuya bağlanırken zaman aşımına uğradı. İnternet bağlantınızı kontrol edin."
        } catch URLError.notConnectedToInternet {
            errorMessage = "İnternet bağlantısı bulunamadı. Lütfen ağ ayarlarınızı kontrol edin."
        } catch {
            errorMessage = "Veri yüklenirken bir hata oluştu: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    @MainActor
    func loadMoreCoins() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        currentPage += 1
        
        do {
            let fetchResult = try await APIService.shared.fetchCoins(page: currentPage, perPage: coinsPerPage)
            let newCoins = fetchResult.coins
            
            // Yeni coinleri ekleyelim
            coins.append(contentsOf: newCoins)
            
            // Daha fazla coin olup olmadığını kontrol edelim
            allPagesLoaded = newCoins.count < coinsPerPage || coins.count >= maxCoins
            
        } catch {
            errorMessage = "Daha fazla coin yüklenirken bir hata oluştu: \(error.localizedDescription)"
        }
        
        isLoadingMore = false
    }
    
    @MainActor
    func refresh() async {
        // Sayfa bilgilerini sıfırlayalım
        currentPage = 1
        allPagesLoaded = false
        errorMessage = nil
        
        // Coinleri yeniden yükleyelim
        await fetchCoins()
    }
} 