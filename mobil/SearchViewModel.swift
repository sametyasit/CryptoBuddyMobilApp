import Foundation
import SwiftUI
import Combine

// Burada tanımlanan NewsItem silindi, projede zaten var

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var topCoins: [Coin] = []
    @Published var filteredCoins: [Coin] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String? = nil
    
    private var allCoins: [Coin] = []
    private var allNews: [NewsItem] = []
    private var coinsLoaded = false
    private var newsLoaded = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce ile arama özelliği
        $searchText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.filterCoins()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadInitialData() {
        Task {
            await loadTopCoins()
            await fetchDemoNews()
        }
    }
    
    @MainActor
    func loadTopCoins() async {
        guard topCoins.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // En popüler 100 coini getir
            let response = try await APIService.shared.fetchCoins(page: 1, perPage: 100)
            self.topCoins = response.coins
            
            // Tüm yüklenen coinleri sakla (arama için)
            self.allCoins = response.coins
            
            isLoading = false
        } catch {
            isLoading = false
            handleError(error)
        }
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
    
    @MainActor
    func filterCoins() async {
        guard !searchText.isEmpty else {
            filteredCoins = []
            isSearching = false
            return
        }
        
        // Arama yapılırken yükleme durumunu göster
        if !isSearching {
            isSearching = true
        }
        
        // Önce yerel verilerle eşleşmeyi dene
        let localResults = performLocalSearch()
        
        if !localResults.isEmpty {
            // Yerel sonuçlar varsa onları kullan
            self.filteredCoins = localResults
            self.isSearching = false
            return
        }
        
        // Yerel sonuç bulunamadıysa API'den ara
        do {
            // Yeni sayfa yükle ve üzerinde arama yap
            let response = try await APIService.shared.fetchCoins(page: 1, perPage: 200)
            
            // Yeni verileri sakla
            self.allCoins.append(contentsOf: response.coins.filter { coin in
                !self.allCoins.contains(where: { $0.id == coin.id })
            })
            
            // Arama yap
            self.filteredCoins = performLocalSearch()
            self.isSearching = false
        } catch {
            self.isSearching = false
            // Arama sırasındaki hatalar için kullanıcıya bildirim gösterme
            print("Arama hatası: \(error)")
        }
    }
    
    private func performLocalSearch() -> [Coin] {
        let searchTermLowercased = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return allCoins.filter { coin in
            coin.name.lowercased().contains(searchTermLowercased) ||
            coin.symbol.lowercased().contains(searchTermLowercased)
        }.sorted { $0.marketCap > $1.marketCap }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = checkErrorType(error)
    }
    
    private func checkErrorType(_ error: Error) -> String {
        // APIService'ten APIError kullanımı
        if let apiError = error as? APIService.APIError {
            switch apiError {
            case .invalidURL:
                return "Geçersiz URL"
            case .invalidResponse:
                return "Sunucu yanıtı geçersiz"
            case .decodingError:
                return "Veri çözümlenirken hata oluştu"
            case .allAPIsFailed:
                return "Tüm API servisleri başarısız oldu"
            case .coinNotFound:
                return "Coin bulunamadı"
            case .rateLimitExceeded:
                return "API kullanım limiti aşıldı"
            case .invalidData:
                return "Veri geçersiz"
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "İnternet bağlantısı bulunamadı"
            case .timedOut:
                return "Bağlantı zaman aşımına uğradı"
            default:
                return "Ağ hatası: \(urlError.localizedDescription)"
            }
        } else {
            return error.localizedDescription
        }
    }
    
    private func applyFilters() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            filteredCoins = []
            return
        }
        filteredCoins = allCoins.filter { coin in
            coin.name.localizedCaseInsensitiveContains(text) ||
            coin.symbol.localizedCaseInsensitiveContains(text)
        }
    }
} 
