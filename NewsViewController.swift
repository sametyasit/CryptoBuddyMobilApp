import SwiftUI
import SafariServices
import Combine

// NewsAPI.org response model
struct NewsResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [Article]
}

struct Article: Codable {
    let source: Source
    let author: String?
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let content: String?
}

struct Source: Codable {
    let id: String?
    let name: String
}

// CryptoCompare API response model
struct CryptoCompareNewsResponse: Codable {
    let Type: Int
    let Message: String
    let Data: [CryptoCompareNewsItem]
}

struct CryptoCompareNewsItem: Codable {
    let id: String
    let guid: String
    let published_on: Int
    let imageurl: String
    let title: String
    let url: String
    let source: String
    let body: String
    let tags: String
    let categories: String
    let upvotes: String
    let downvotes: String
}

// CoinDesk API response model
struct CoinDeskNewsResponse: Codable {
    let data: [CoinDeskNewsItem]
}

struct CoinDeskNewsItem: Codable {
    let id: String
    let title: String
    let description: String?
    let url: String
    let thumbnail: CoinDeskThumbnail?
    let createdAt: String
    let tags: [String]?
    let source: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, url, thumbnail
        case createdAt = "created_at"
        case tags, source
    }
}

struct CoinDeskThumbnail: Codable {
    let url: String?
}

struct NewsItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageUrl: String?
    let source: String
    let publishedAt: Date
    let url: String
    let tags: [String]
}

class NewsViewModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var selectedTags: Set<String> = []
    @Published var availableTags: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    var filteredNewsItems: [NewsItem] {
        var filtered = newsItems
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) || 
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.source.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        
        // Filter by selected tags
        if !selectedTags.isEmpty {
            filtered = filtered.filter { newsItem in
                newsItem.tags.contains(where: selectedTags.contains)
            }
        }
        
        return filtered
    }
    
    init() {
        setupRefreshTimer()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    func setupRefreshTimer() {
        // Auto-refresh every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.loadAllNews()
        }
    }
    
    func loadAllNews() {
        isLoading = true
        errorMessage = nil
        
        // Load news from multiple sources
        loadNewsAPI()
        loadCryptoCompareNews()
        loadCoinDeskNews()
    }
    
    private func loadNewsAPI() {
        guard let url = URL(string: ApiEndpoints.newsApiCryptoHeadlines) else {
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: NewsResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("NewsAPI error: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] response in
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime]
                
                let newsAPIItems = response.articles.compactMap { article in
                    guard let publishedDate = dateFormatter.date(from: article.publishedAt) else {
                        return nil
                    }
                    
                    // Extract tags from content if available
                    var tags: [String] = []
                    if let content = article.content {
                        // Extract potential cryptocurrency names and tags
                        let cryptoKeywords = ["Bitcoin", "Ethereum", "BTC", "ETH", "Blockchain", 
                                           "Cryptocurrency", "Altcoin", "DeFi", "NFT", "Token"]
                        
                        tags = cryptoKeywords.filter { content.localizedCaseInsensitiveContains($0) }
                    }
                    
                    return NewsItem(
                        title: article.title,
                        description: article.description ?? "No description available",
                        imageUrl: article.urlToImage,
                        source: article.source.name,
                        publishedAt: publishedDate,
                        url: article.url,
                        tags: tags
                    )
                }
                
                self?.updateNewsItems(with: newsAPIItems)
            }
            .store(in: &cancellables)
    }
    
    private func loadCryptoCompareNews() {
        guard let url = URL(string: ApiEndpoints.cryptoCompareNews) else {
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: CryptoCompareNewsResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    print("CryptoCompare error: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] response in
                let cryptoCompareItems = response.Data.map { item in
                    // Extract tags from categories string
                    let tags = item.categories.components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    return NewsItem(
                        title: item.title,
                        description: item.body,
                        imageUrl: item.imageurl,
                        source: item.source,
                        publishedAt: Date(timeIntervalSince1970: TimeInterval(item.published_on)),
                        url: item.url,
                        tags: tags
                    )
                }
                
                self?.updateNewsItems(with: cryptoCompareItems)
            }
            .store(in: &cancellables)
    }
    
    private func loadCoinDeskNews() {
        // CoinDesk API URL (public API)
        let urlString = "https://api.coindesk.com/v1/content/fetch/all-stories?limit=20"
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: CoinDeskNewsResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    print("CoinDesk API error: \(error.localizedDescription)")
                    
                    // If all APIs fail, only then show fallback news
                    if self?.newsItems.isEmpty == true {
                        self?.errorMessage = "Failed to load news"
                        self?.loadFallbackNews()
                    }
                }
            } receiveValue: { [weak self] response in
                let dateFormatter = ISO8601DateFormatter()
                
                let coinDeskItems = response.data.compactMap { item -> NewsItem? in
                    guard let date = dateFormatter.date(from: item.createdAt) else {
                        return nil
                    }
                    
                    return NewsItem(
                        title: item.title,
                        description: item.description ?? "No description available",
                        imageUrl: item.thumbnail?.url,
                        source: item.source ?? "CoinDesk",
                        publishedAt: date,
                        url: "https://www.coindesk.com" + item.url, // Add base URL
                        tags: item.tags ?? []
                    )
                }
                
                self?.updateNewsItems(with: coinDeskItems)
            }
            .store(in: &cancellables)
    }
    
    private func updateNewsItems(with newItems: [NewsItem]) {
        // Merge with existing items, avoiding duplicates based on URL
        let existingUrls = Set(newsItems.map { $0.url })
        let uniqueNewItems = newItems.filter { !existingUrls.contains($0.url) }
        
        // Add new items
        newsItems.append(contentsOf: uniqueNewItems)
        
        // Sort by date (newest first)
        newsItems.sort { $0.publishedAt > $1.publishedAt }
        
        // Collect all available tags for filtering
        var allTags = Set<String>()
        for item in newsItems {
            for tag in item.tags {
                allTags.insert(tag)
            }
        }
        availableTags = allTags
        
        // Cap the number of news items to avoid excessive memory usage
        if newsItems.count > 100 {
            newsItems = Array(newsItems.prefix(100))
        }
        
        isLoading = false
    }
    
    // Fallback when API is unavailable or for testing
    private func loadFallbackNews() {
        self.newsItems = [
            NewsItem(
                title: "Memecoin Moo Deng, MEW Surges After Robinhood Listing",
                description: "Both tokens jumped on the news, adding to their already large gains this month.",
                imageUrl: nil,
                source: "CoinDesk",
                publishedAt: Date(),
                url: "https://example.com/news/1",
                tags: ["Memecoin", "Robinhood", "Trading"]
            ),
            NewsItem(
                title: "BlockTrust IRA Brings Quant Trading Tools to Crypto Retirement Accounts",
                description: "The new tools allow retirement investors to use algorithmic trading for crypto assets.",
                imageUrl: nil,
                source: "Crypto Insider",
                publishedAt: Date().addingTimeInterval(-3600),
                url: "https://example.com/news/2",
                tags: ["IRA", "Trading", "Investment"]
            ),
            NewsItem(
                title: "Bitcoin Surpasses $67,000 as Institutional Buyers Return",
                description: "Bitcoin's price rally continues as institutional buyers show renewed interest following recent ETF approvals.",
                imageUrl: nil,
                source: "CryptoNews",
                publishedAt: Date().addingTimeInterval(-7200),
                url: "https://example.com/news/3",
                tags: ["Bitcoin", "BTC", "Investment", "ETF"]
            )
        ]
    }
    
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}

struct NewsViewController: View {
    @StateObject private var viewModel = NewsViewModel()
    @State private var isRefreshing = false
    @State private var showingTagFilters = false
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    private let darkBackgroundColor = Color(red: 0.11, green: 0.11, blue: 0.118)
    
    var body: some View {
        NavigationView {
            ZStack {
                darkBackgroundColor.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading && viewModel.newsItems.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                        .scaleEffect(1.5)
                } else if !viewModel.isLoading && viewModel.newsItems.isEmpty {
                    VStack {
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.headline)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                        } else {
                            Text("Henüz haber bulunamadı")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Button("Yenile") {
                            viewModel.loadAllNews()
                        }
                        .padding()
                        .foregroundColor(.black)
                        .background(goldColor)
                        .cornerRadius(8)
                        .padding(.top, 20)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            TextField("Haberlerde ara...", text: $viewModel.searchText)
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .overlay(
                                    HStack {
                                        Spacer()
                                        
                                        if !viewModel.searchText.isEmpty {
                                            Button(action: {
                                                viewModel.searchText = ""
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.trailing, 8)
                                        }
                                        
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.gray)
                                            .padding(.trailing)
                                    }
                                )
                            
                            Button(action: {
                                showingTagFilters.toggle()
                            }) {
                                Image(systemName: "tag")
                                    .foregroundColor(viewModel.selectedTags.isEmpty ? .gray : goldColor)
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                                    .scaleEffect(0.8)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Selected tags bar
                        if !viewModel.selectedTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(Array(viewModel.selectedTags), id: \.self) { tag in
                                        Button(action: {
                                            viewModel.toggleTag(tag)
                                        }) {
                                            HStack {
                                                Text(tag)
                                                    .font(.caption)
                                                    .foregroundColor(.black)
                                                
                                                Image(systemName: "xmark")
                                                    .font(.caption)
                                                    .foregroundColor(.black.opacity(0.7))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(goldColor)
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        if viewModel.filteredNewsItems.isEmpty {
                            VStack {
                                Spacer()
                                Text("Bu arama için sonuç bulunamadı")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(viewModel.filteredNewsItems) { item in
                                    NewsCard(newsItem: item)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            }
                            .listStyle(.plain)
                            .background(darkBackgroundColor)
                            .refreshable {
                                isRefreshing = true
                                await refreshNews()
                                isRefreshing = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Haberler")
            .onAppear {
                viewModel.loadAllNews()
            }
            .sheet(isPresented: $showingTagFilters) {
                TagFilterView(
                    availableTags: Array(viewModel.availableTags).sorted(),
                    selectedTags: viewModel.selectedTags,
                    toggleTag: viewModel.toggleTag
                )
                .preferredColorScheme(.dark)
            }
        }
    }
    
    func refreshNews() async {
        await MainActor.run {
            viewModel.loadAllNews()
        }
    }
}

struct TagFilterView: View {
    let availableTags: [String]
    let selectedTags: Set<String>
    let toggleTag: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    private let darkBackgroundColor = Color(red: 0.11, green: 0.11, blue: 0.118)
    
    var body: some View {
        NavigationView {
            ZStack {
                darkBackgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Haberleri Etiketlere Göre Filtrele")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                    
                    if availableTags.isEmpty {
                        Text("Henüz etiket bulunamadı")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                                ForEach(availableTags, id: \.self) { tag in
                                    Button(action: {
                                        toggleTag(tag)
                                    }) {
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .frame(minWidth: 60)
                                            .background(selectedTags.contains(tag) ? goldColor : Color.gray.opacity(0.2))
                                            .foregroundColor(selectedTags.contains(tag) ? .black : .white)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    
                    Button("Tamam") {
                        dismiss()
                    }
                    .padding()
                    .foregroundColor(.black)
                    .background(goldColor)
                    .cornerRadius(8)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(goldColor)
                }
            }
        }
    }
}

struct NewsCard: View {
    let newsItem: NewsItem
    @State private var showSafari = false
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        Button(action: {
            showSafari = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                if let imageUrl = newsItem.imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                        }
                    }
                    .cornerRadius(8)
                }
                
                Text(newsItem.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(3)
                
                Text(newsItem.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(3)
                
                if !newsItem.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(newsItem.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(goldColor.opacity(0.2))
                                    .foregroundColor(goldColor)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                HStack {
                    Text(newsItem.source)
                        .font(.caption)
                        .foregroundColor(goldColor)
                    
                    Spacer()
                    
                    Text(timeAgoString(from: newsItem.publishedAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: newsItem.url) ?? URL(string: "https://google.com")!)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfMonth, .month, .year], from: date, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1 yıl önce" : "\(year) yıl önce"
        }
        
        if let month = components.month, month > 0 {
            return month == 1 ? "1 ay önce" : "\(month) ay önce"
        }
        
        if let week = components.weekOfMonth, week > 0 {
            return week == 1 ? "1 hafta önce" : "\(week) hafta önce"
        }
        
        if let day = components.day, day > 0 {
            return day == 1 ? "1 gün önce" : "\(day) gün önce"
        }
        
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 saat önce" : "\(hour) saat önce"
        }
        
        if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 dakika önce" : "\(minute) dakika önce"
        }
        
        return "Az önce"
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}

struct NewsViewController_Previews: PreviewProvider {
    static var previews: some View {
        NewsViewController()
    }
} 