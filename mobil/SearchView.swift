import SwiftUI
import SafariServices

struct SearchView: View {
    @Binding var showingLoginView: Bool
    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel = SearchViewModelLight()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Coin, kripto haber veya anahtar kelime ara...", text: $viewModel.searchText)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: viewModel.searchText) { oldValue, newValue in
                                viewModel.isSearching = true
                                viewModel.searchCoins(newValue)
                                viewModel.searchNews(newValue)
                            }
                        
                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.searchText = ""
                                viewModel.isSearching = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6).opacity(0.2))
                    .cornerRadius(10)
                    .padding()
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.984, green: 0.788, blue: 0.369)))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if viewModel.isSearching && viewModel.searchText.isEmpty {
                        // Arama çubuğu boşaltıldığında iptal edilmiş demektir
                        ScrollView {
                            VStack(alignment: .leading) {
                                Text("Popüler Coinler")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    .padding(.top)
                                
                                PopularCoinsView()
                                
                                Text("Son Haberler")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    .padding(.top)
                                
                                RecentNewsView()
                            }
                        }
                    } else if viewModel.isSearching {
                        // Arama sonuçları
                        ScrollView {
                            VStack(alignment: .leading) {
                                if !viewModel.filteredCoins.isEmpty {
                                    Text("Coinler")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                        .padding(.top)
                                    
                                    CoinSearchResultsView(coins: viewModel.filteredCoins)
                                }
                                
                                if !viewModel.filteredNews.isEmpty {
                                    Text("Haberler")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                        .padding(.top)
                                    
                                    NewsSearchResultsView(news: viewModel.filteredNews)
                                }
                                
                                if viewModel.filteredCoins.isEmpty && viewModel.filteredNews.isEmpty {
                                    VStack {
                                        Spacer()
                                        Text("Sonuç bulunamadı.")
                                            .foregroundColor(.gray)
                                            .padding()
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    } else {
                        // Default view (initial state)
                        ScrollView {
                            VStack(alignment: .leading) {
                                Text("Popüler Coinler")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    .padding(.top)
                                
                                PopularCoinsView()
                                
                                Text("Son Haberler")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    .padding(.top)
                                
                                RecentNewsView()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ara")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadInitialData()
            }
        }
    }
}

extension SearchViewModelLight {
    func searchCoins(_ query: String) {
        if query.isEmpty {
            filteredCoins = []
            return
        }
        
        let searchTerms = query.lowercased().components(separatedBy: " ")
        
        filteredCoins = coins.filter { coin in
            searchTerms.allSatisfy { term in
                coin.name.lowercased().contains(term) ||
                coin.symbol.lowercased().contains(term)
            }
        }.sorted { $0.marketCapRank < $1.marketCapRank }
    }
    
    func searchNews(_ query: String) {
        if query.isEmpty {
            filteredNews = []
            return
        }
        
        let searchTerms = query.lowercased().components(separatedBy: " ")
        
        filteredNews = news.filter { newsItem in
            searchTerms.allSatisfy { term in
                newsItem.title.lowercased().contains(term) ||
                newsItem.description.lowercased().contains(term) ||
                newsItem.source.lowercased().contains(term)
            }
        }
    }
}

// Helper views
struct PopularCoinsView: View {
    @EnvironmentObject private var apiService: APIService
    @State private var popularCoins: [Coin] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.984, green: 0.788, blue: 0.369)))
                    .frame(height: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(popularCoins.prefix(10)) { coin in
                            NavigationLink(destination: CoinDetailView(coin: coin)) {
                                PopularCoinCard(coin: coin)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(height: 180)
        .onAppear {
            loadPopularCoins()
        }
    }
    
    private func loadPopularCoins() {
        isLoading = true
        
        Task {
            do {
                let response = try await APIService.shared.fetchCoins(page: 1, perPage: 10)
                DispatchQueue.main.async {
                    popularCoins = response.coins
                    isLoading = false
                }
            } catch {
                print("Error loading popular coins: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }
    }
}

struct PopularCoinCard: View {
    let coin: Coin
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if let url = URL(string: coin.image) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        case .empty, .failure:
                            Image(systemName: "bitcoinsign.circle.fill")
                                .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                                .frame(width: 30, height: 30)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                        .frame(width: 30, height: 30)
                }
                
                Text(coin.symbol.uppercased())
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(coin.name)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Text(coin.formattedPrice)
                .font(.headline)
                .foregroundColor(.white)
            
            Text("\(coin.change24h >= 0 ? "+" : "")\(coin.formattedChange)")
                .font(.caption)
                .foregroundColor(coin.change24h >= 0 ? .green : .red)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(coin.change24h >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .cornerRadius(4)
        }
        .padding()
        .frame(width: 140, height: 150)
        .background(Color(UIColor.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

struct RecentNewsView: View {
    @State private var news: [NewsItem] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.984, green: 0.788, blue: 0.369)))
                    .frame(height: 150)
            } else if news.isEmpty {
                Text("Haber bulunamadı")
                    .foregroundColor(.gray)
                    .frame(height: 150)
            } else {
                VStack(spacing: 15) {
                    ForEach(news.prefix(5)) { item in
                        NewsItemRow(newsItem: item)
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            loadNews()
        }
    }
    
    private func loadNews() {
        isLoading = true
        
        APIService.shared.fetchCryptoNews(page: 1, itemsPerPage: 5) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let newsItems):
                    self.news = newsItems
                case .failure:
                    self.news = []
                }
            }
        }
    }
}

struct NewsItemRow: View {
    let newsItem: NewsItem
    @State private var showSafariView = false
    
    var body: some View {
        Button(action: {
            showSafariView = true
        }) {
            HStack(alignment: .top, spacing: 15) {
                if let url = URL(string: newsItem.imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        case .empty, .failure:
                            Image(systemName: "newspaper.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                                .frame(width: 80, height: 80)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(8)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 80, height: 80)
                } else {
                    Image(systemName: "newspaper.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                        .frame(width: 80, height: 80)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(newsItem.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(newsItem.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(newsItem.source)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                        
                        Spacer()
                        
                        Text(formatDate(newsItem.publishedAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemGray6).opacity(0.1))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showSafariView) {
            Button("Safari'de Aç") {
                if let url = URL(string: newsItem.url) {
                    UIApplication.shared.open(url)
                }
                showSafariView = false
            }
            .padding()
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        guard let date = formatter.date(from: dateString) else {
            return "Bilinmeyen tarih"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

struct CoinSearchResultsView: View {
    let coins: [Coin]
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(coins.prefix(10)) { coin in
                NavigationLink(destination: CoinDetailView(coin: coin)) {
                    CoinSearchResultRow(coin: coin)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct CoinSearchResultRow: View {
    let coin: Coin
    
    var body: some View {
        HStack {
            if let url = URL(string: coin.image) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    case .empty, .failure:
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                            .frame(width: 40, height: 40)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 40, height: 40)
            } else {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading) {
                Text(coin.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(coin.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(coin.formattedPrice)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(coin.change24h >= 0 ? "+" : "")\(coin.formattedChange)")
                    .font(.caption)
                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(coin.change24h >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

struct NewsSearchResultsView: View {
    let news: [NewsItem]
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(news.prefix(5), id: \.id) { item in
                NewsItemRow(newsItem: item)
            }
        }
        .padding(.horizontal)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(showingLoginView: .constant(false))
            .environmentObject(AuthService())
            .environmentObject(APIService.shared)
            .preferredColorScheme(.dark)
    }
} 