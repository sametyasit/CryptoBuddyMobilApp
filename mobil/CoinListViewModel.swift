@MainActor
func fetchCoins() async {
    isLoading = true
    currentPage = 1  // Sayfa numarasını sıfırla
    
    do {
        // Her sayfada 20 coin çekelim
        let perPage = 20
        let fetchResult = try await APIService.shared.fetchCoins(page: currentPage, perPage: perPage)
        
        // Gelen verileri kaydedelim
        coins = fetchResult.coins
        
        // API kaynağını güncelle
        currentAPI = fetchResult.source
        
        // Sadece hiç coin gelmediğinde true yap, aksi takdirde her zaman daha fazla coin yüklenebilir
        allPagesLoaded = fetchResult.coins.isEmpty
        
        print("📱 İlk sayfa yüklendi: \(coins.count) coin")
        
    } catch APIError.allAPIsFailed {
        errorMessage = "Hiçbir API kaynağından veri alınamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin."
    } catch APIError.rateLimitExceeded {
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