import SwiftUI
import Combine

class MultiCoinViewModel: ObservableObject {
    @Published var allCoins: [Coin] = []
    @Published var isLoaded = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var activeAPIs: [String] = ["CoinGecko"]
    
    private var currentPage = 1
    private let pageSize = 50
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
    func refreshCoins() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        error = nil
        currentPage = 1
        
        apiService.fetchCoins(page: currentPage, pageSize: pageSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isRefreshing = false
                
                switch completion {
                case .finished:
                    self?.isLoaded = true
                case .failure(let error):
                    self?.error = error.localizedDescription
                }
            } receiveValue: { [weak self] coins in
                self?.allCoins = coins
            }
            .store(in: &cancellables)
    }
    
    func loadMoreCoins() {
        guard !isLoadingMore, !isRefreshing else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        apiService.fetchCoins(page: currentPage, pageSize: pageSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingMore = false
                
                if case .failure(let error) = completion {
                    self?.error = error.localizedDescription
                    self?.currentPage -= 1
                }
            } receiveValue: { [weak self] coins in
                self?.allCoins.append(contentsOf: coins)
            }
            .store(in: &cancellables)
    }
} 