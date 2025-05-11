import SwiftUI
import SafariServices

// MARK: - Error Types
enum NewsError: Error {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case allAPIsFailed
    case invalidData
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Error parsing data"
        case .allAPIsFailed:
            return "Unable to fetch news from any source"
        case .invalidData:
            return "Invalid data received from server"
        }
    }
}

// MARK: - Model
enum NewsCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case crypto = "Crypto"
    case trading = "Trading"
    case technology = "Technology"
    case regulation = "Regulation"
    case mining = "Mining"
    case defi = "DeFi"
    case nft = "NFT"
    case metaverse = "Metaverse"
    
    var id: String { self.rawValue }
}

// MARK: - News Service
final class NewsServiceImpl: ObservableObject {
    static let shared = NewsServiceImpl()
    @Published var newsItems: [NewsItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var currentPage = 1
    @Published var hasMorePages = true
    @Published var isLoadingMore = false
    
    private init() {
        loadNews()
    }
    
    private let apiKey = "c1086e4db7b5078baef89a7a374128c506a68d2aea26e434640986920610af78" // Replace with your CryptoCompare API key
    private let baseURL = "https://min-api.cryptocompare.com/data/v2/news/"
    
    struct NewsItem: Identifiable {
        let id: String
        let title: String
        let description: String
        let url: String
        let imageUrl: String
        let source: String
        let publishedAt: Date
        
        // Kategorileri etiketlere dayalı kontrol etmek için yardımcı işlev
        func matchesCategory(_ category: NewsCategory) -> Bool {
            if category == .all {
                return true
            }
            let content = title.lowercased() + " " + description.lowercased()
            return content.contains(category.rawValue.lowercased())
        }
    }
    
    func fetchNews(category: NewsCategory = .all, page: Int = 1) async throws -> [NewsItem] {
        var urlComponents = URLComponents(string: "\(baseURL)")!
        let queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "lang", value: "EN")
        ]
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NewsError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NewsError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            let newsResponse = try decoder.decode(CryptoCompareResponse.self, from: data)
            
            // API'den gelen verileri NewsItem'a dönüştür
            return newsResponse.Data.map { news in
                NewsItem(
                    id: news.id,
                    title: news.title,
                    description: news.body,
                    url: news.url,
                    imageUrl: news.imageurl,
                    source: news.source,
                    publishedAt: Date(timeIntervalSince1970: TimeInterval(news.published_on))
                )
            }
        } catch {
            print("Decoding error: \(error)")
            throw NewsError.decodingError
        }
    }
    
    private func determineCategory(from categories: String) -> NewsCategory {
        let lowercasedCategories = categories.lowercased()
        
        if lowercasedCategories.contains("trading") {
            return .trading
        } else if lowercasedCategories.contains("technology") {
            return .technology
        } else if lowercasedCategories.contains("regulation") {
            return .regulation
        } else if lowercasedCategories.contains("mining") {
            return .mining
        } else if lowercasedCategories.contains("defi") {
            return .defi
        } else if lowercasedCategories.contains("nft") {
            return .nft
        } else if lowercasedCategories.contains("metaverse") {
            return .metaverse
        }
        
        return .all
    }
    
    private func loadNews() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let apiItems = try await APIService.shared.fetchNews()
                DispatchQueue.main.async {
                    // Convert API model to our model
                    self.newsItems = apiItems.map { apiItem in
                        // Parse date
                        let formatter = ISO8601DateFormatter()
                        let date = formatter.date(from: apiItem.publishedAt) ?? Date()
                        
                        return NewsItem(
                            id: apiItem.id,
                            title: apiItem.title,
                            description: apiItem.description,
                            url: apiItem.url,
                            imageUrl: apiItem.imageUrl,
                            source: apiItem.source,
                            publishedAt: date
                        )
                    }
                    self.isLoading = false
                    self.currentPage = 1
                    self.hasMorePages = self.newsItems.count >= 20
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Haber verilerini yüklerken bir hata oluştu: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadMoreNews() {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        
        Task {
            do {
                let apiItems = try await APIService.shared.fetchNews()
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.isLoadingMore = false
                    
                    // Filter out duplicates
                    let existingIds = Set(self.newsItems.map { $0.id })
                    
                    // Convert API model to our model
                    let newItems = apiItems
                        .filter { !existingIds.contains($0.id) }
                        .map { apiItem in
                            let formatter = ISO8601DateFormatter()
                            let date = formatter.date(from: apiItem.publishedAt) ?? Date()
                            
                            return NewsItem(
                                id: apiItem.id,
                                title: apiItem.title,
                                description: apiItem.description,
                                url: apiItem.url,
                                imageUrl: apiItem.imageUrl,
                                source: apiItem.source,
                                publishedAt: date
                            )
                        }
                    
                    if !newItems.isEmpty {
                        self.newsItems.append(contentsOf: newItems)
                        self.currentPage += 1
                    }
                    
                    self.hasMorePages = newItems.count >= 10
                }
                
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoadingMore = false
                    self?.hasMorePages = false
                }
            }
        }
    }
    
    func refreshNews() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let apiItems = try await APIService.shared.fetchNews()
                
                // Convert API model to our model
                let newsItems = apiItems.map { apiItem in
                    // Parse date
                    let formatter = ISO8601DateFormatter()
                    let date = formatter.date(from: apiItem.publishedAt) ?? Date()
                    
                    return NewsItem(
                        id: apiItem.id,
                        title: apiItem.title,
                        description: apiItem.description,
                        url: apiItem.url,
                        imageUrl: apiItem.imageUrl,
                        source: apiItem.source,
                        publishedAt: date
                    )
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.newsItems = newsItems
                    self?.isLoading = false
                    self?.currentPage = 1
                    self?.hasMorePages = newsItems.count >= 20
                    self?.errorMessage = nil
                }
                
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    self?.errorMessage = "Haberler yenilenirken bir hata oluştu: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func getFormattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - CryptoCompare Model
struct CryptoCompareResponse: Codable {
    let Data: [CryptoCompareNewsItem]
}

struct CryptoCompareNewsItem: Codable {
    let id: String
    let title: String
    let body: String
    let url: String
    let imageurl: String
    let source: String
    let published_on: Int
}

// MARK: - SafariView
struct CustomSafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Views
struct NewsView: View {
    @StateObject private var viewModel = NewsServiceImpl.shared
    @State private var searchText = ""
    @State private var selectedCategory: NewsCategory = .all
    @State private var showSafariView = false
    @State private var selectedURL = URL(string: "https://www.example.com")!
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    private let darkBackgroundColor = Color(red: 0.11, green: 0.11, blue: 0.118)
    
    var filteredNews: [NewsServiceImpl.NewsItem] {
        if !searchText.isEmpty {
            return viewModel.newsItems.filter { news in
                news.title.lowercased().contains(searchText.lowercased()) ||
                news.description.lowercased().contains(searchText.lowercased())
            }
        } else if selectedCategory != .all {
            return viewModel.newsItems.filter { $0.matchesCategory(selectedCategory) }
        } else {
            return viewModel.newsItems
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                darkBackgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack {
                    if viewModel.isLoading && viewModel.newsItems.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if let error = viewModel.errorMessage, viewModel.newsItems.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(goldColor)
                            
                            Text(error)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                viewModel.refreshNews()
                            }) {
                                Text("Tekrar Dene")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding()
                                    .background(goldColor)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        Spacer()
                    } else {
                        // Category Tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(NewsCategory.allCases) { category in
                                    CategoryTab(category: category, selectedCategory: $selectedCategory)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 5)
                        
                        // News List
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredNews) { newsItem in
                                    NewsItemView(item: newsItem)
                                        .padding(.horizontal)
                                        .padding(.vertical, 5)
                                        .onTapGesture {
                                            selectedURL = URL(string: newsItem.url) ?? URL(string: "https://www.example.com")!
                                            showSafariView = true
                                        }
                                    
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                        .padding(.horizontal)
                                }
                                
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                                        .frame(width: 50, height: 50)
                                        .padding()
                                } else if viewModel.hasMorePages {
                                    Button(action: {
                                        viewModel.loadMoreNews()
                                    }) {
                                        Text("Daha Fazla Yükle")
                                            .foregroundColor(goldColor)
                                            .padding()
                                    }
                                }
                            }
                        }
                        .refreshable {
                            await refreshData()
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Ara")
                .onChange(of: searchText) { _ in
                    // Auto-filter happens via computed property
                }
            }
            .navigationTitle("Haberler")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if viewModel.newsItems.isEmpty {
                    viewModel.refreshNews()
                }
            }
            .sheet(isPresented: $showSafariView) {
                CustomSafariView(url: selectedURL)
            }
        }
    }
    
    private func refreshData() async {
        viewModel.refreshNews()
    }
}

struct CategoryTab: View {
    let category: NewsCategory
    @Binding var selectedCategory: NewsCategory
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        Button(action: {
            selectedCategory = category
        }) {
            Text(category.rawValue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedCategory == category ? goldColor : Color.gray.opacity(0.2))
                )
                .foregroundColor(selectedCategory == category ? .black : .white)
        }
    }
}

struct NewsItemView: View {
    let item: NewsServiceImpl.NewsItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and source
            HStack {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Spacer()
            }
            
            HStack {
                // Description
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                Spacer()
            }
            
            HStack {
                // Source & Time
                Text(item.source)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("•")
                    .foregroundColor(.gray)
                
                Text(NewsServiceImpl.shared.getFormattedDate(item.publishedAt))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Read More
                Text("Daha Fazla")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
            }
        }
        .padding(.vertical, 8)
    }
}

struct NewsView_Previews: PreviewProvider {
    static var previews: some View {
        NewsView()
    }
} 






