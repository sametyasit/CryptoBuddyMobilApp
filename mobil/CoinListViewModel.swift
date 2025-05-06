@MainActor
func fetchCoins() async {
    isLoading = true
    do {
        let fetchResult = try await APIService.shared.fetchCoins(page: currentPage, perPage: coinsPerPage)
        let newCoins = fetchResult.coins
        let apiSource = fetchResult.source
        
        if currentPage == 1 {
            coins = newCoins
        } else {
            coins.append(contentsOf: newCoins)
        }
        
        // API kaynağını güncelle
        currentAPI = apiSource
        
        // Tüm sayfalar yüklendi mi kontrol et
        allPagesLoaded = newCoins.count < coinsPerPage
        
    } catch APIError.allAPIsFailed {
        errorMessage = "Hiçbir API kaynağından veri alınamadı. Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin."
    } catch APIError.rateLimitExceeded {
        errorMessage = "API hız limiti aşıldı. Lütfen bir süre sonra tekrar deneyin."
    } catch URLError.timedOut {
        errorMessage = "Sunucuya bağlanırken zaman aşımı oluştu. İnternet bağlantınızı kontrol edin."
    } catch URLError.notConnectedToInternet {
        errorMessage = "İnternet bağlantısı bulunamadı. Lütfen ağ ayarlarınızı kontrol edin."
    } catch {
        errorMessage = "Veri yüklenirken bir hata oluştu: \(error.localizedDescription)"
    }
    isLoading = false
} 