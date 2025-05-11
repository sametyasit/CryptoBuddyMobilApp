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

// MARK: - News Service
final class NewsServiceImpl {
    static let shared = NewsServiceImpl()
    private init() {}
    
    private let apiKey = "c1086e4db7b5078baef89a7a374128c506a68d2aea26e434640986920610af78" // Replace with your CryptoCompare API key
    private let baseURL = "https://min-api.cryptocompare.com/data/v2/news/"
    
    enum NewsCategory: String, CaseIterable {
        case all = "All"
        case trading = "Trading"
        case technology = "Technology"
        case regulation = "Regulation"
        case mining = "Mining"
        case defi = "DeFi"
        case nft = "NFT"
        case metaverse = "Metaverse"
    }
    
    struct NewsItem: Identifiable, Hashable {
        let id: String
        let title: String
        let description: String
        let url: String
        let imageUrl: String
        let publishedAt: Date
        let source: String
        let category: NewsCategory
        
        static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
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
                    publishedAt: Date(timeIntervalSince1970: TimeInterval(news.published_on)),
                    source: news.source,
                    category: determineCategory(from: news.categories)
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
}

// CryptoCompare API Response Models
private struct CryptoCompareResponse: Codable {
    let Data: [CryptoCompareNews]
}

private struct CryptoCompareNews: Codable {
    let id: String
    let title: String
    let body: String
    let url: String
    let imageurl: String
    let published_on: Int
    let source: String
    let categories: String
}

// MARK: - View Model
final class NewsViewModel: ObservableObject {
    @Published var allNews: [NewsServiceImpl.NewsItem] = []
    @Published var filteredNews: [NewsServiceImpl.NewsItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: NewsError?
    @Published var selectedCategory: NewsServiceImpl.NewsCategory = .all
    @Published var activeSources: Set<String> = []
    @Published var searchText: String = ""
    
    private let newsService = NewsServiceImpl.shared
    private var currentPage = 1
    private var timer: Timer?
    
    func startAutoRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.fetchNews(force: true) }
        }
    }
    
    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchNews(force: Bool = false) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        do {
            let news = try await newsService.fetchNews(category: .all, page: 1)
            await MainActor.run {
                self.allNews = news
                self.applyFilters()
                updateActiveSources()
                isLoading = false
                currentPage = 1
            }
        } catch let error as NewsError {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = .networkError
                self.isLoading = false
            }
        }
    }
    
    func loadMoreNews() async {
        guard !isLoadingMore else { return }
        await MainActor.run {
            isLoadingMore = true
            currentPage += 1
        }
        do {
            let news = try await newsService.fetchNews(category: .all, page: currentPage)
            await MainActor.run {
                self.allNews.append(contentsOf: news)
                self.applyFilters()
                updateActiveSources()
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                currentPage -= 1
                isLoadingMore = false
                self.error = error as? NewsError ?? .networkError
            }
        }
    }
    
    func selectCategory(_ category: NewsServiceImpl.NewsCategory) {
        selectedCategory = category
        applyFilters()
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
        applyFilters()
    }
    
    private func applyFilters() {
        if !searchText.isEmpty {
            filteredNews = allNews.filter { news in
                news.title.localizedCaseInsensitiveContains(searchText) ||
                news.description.localizedCaseInsensitiveContains(searchText)
            }
        } else if selectedCategory != .all {
            filteredNews = allNews.filter { $0.category == selectedCategory }
        } else {
            filteredNews = allNews
        }
    }
    
    private func updateActiveSources() {
        activeSources = Set(filteredNews.map { $0.source.components(separatedBy: ":").first ?? "" })
    }
}

// MARK: - Views
struct NewsView: View {
    @State private var newsItems: [NewsServiceImpl.NewsItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var currentPage = 1
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    if isLoading && newsItems.isEmpty {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if let error = errorMessage, newsItems.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "newspaper.fill")
                                .font(.system(size: 60))
                                .foregroundColor(goldColor)
                            
                            Text("Haberler yüklenemedi")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(error)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                loadNews()
                            }) {
                                Text("Yeniden Dene")
                                    .fontWeight(.medium)
                                    .padding()
                                    .frame(width: 150)
                                    .background(goldColor)
                                    .foregroundColor(.black)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(newsItems) { newsItem in
                                    NewsItemView(item: newsItem)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                }
                                
                                if isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                                        Spacer()
                                    }
                                    .padding()
                                } else if hasMorePages {
                                    Button(action: {
                                        loadMoreNews()
                                    }) {
                                        Text("Daha Fazla Göster")
                                            .foregroundColor(goldColor)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color(UIColor.systemGray6).opacity(0.2))
                                            .cornerRadius(10)
                                    }
                                    .padding()
                                }
                            }
                        }
                        .refreshable {
                            await refreshNews()
                        }
                    }
                }
            }
            .navigationTitle("Haberler")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if newsItems.isEmpty {
                    loadNews()
                }
            }
        }
    }
    
    private func loadNews() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let items = try await APIService.shared.fetchNews()
                DispatchQueue.main.async {
                    self.newsItems = items
                    self.isLoading = false
                    self.currentPage = 1
                    self.hasMorePages = items.count >= 20
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
                let items = try await APIService.shared.fetchNews()
                
                DispatchQueue.main.async {
                    isLoadingMore = false
                    
                    // Filter out duplicates
                    let existingIds = Set(newsItems.map { $0.id })
                    let newItems = items.filter { !existingIds.contains($0.id) }
                    
                    if !newItems.isEmpty {
                        newsItems.append(contentsOf: newItems)
                        currentPage += 1
                    }
                    
                    hasMorePages = newItems.count >= 10
                }
            } catch {
                DispatchQueue.main.async {
                    isLoadingMore = false
                    hasMorePages = false
                }
            }
        }
    }
    
    private func refreshNews() async {
        do {
            let items = try await APIService.shared.fetchNews()
            
            DispatchQueue.main.async {
                newsItems = items
                currentPage = 1
                hasMorePages = items.count >= 20
                errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "Haberler yenilenirken bir hata oluştu: \(error.localizedDescription)"
            }
        }
    }
}

struct NewsItemView: View {
    let item: NewsServiceImpl.NewsItem
    @State private var showSafariView = false
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        Button(action: {
            showSafariView = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Resim ve kaynak
                ZStack(alignment: .bottomLeading) {
                    if let url = URL(string: item.imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 180)
                                    .clipped()
                            case .empty, .failure:
                                Rectangle()
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(height: 180)
                                    .overlay(
                                        Image(systemName: "newspaper.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(goldColor)
                                            .frame(width: 40, height: 40)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "newspaper.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(goldColor)
                                    .frame(width: 40, height: 40)
                            )
                    }
                    
                    // Kaynak etiketi
                    Text(item.source)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(goldColor)
                        .cornerRadius(4)
                        .padding(8)
                }
                .cornerRadius(10)
                
                // Başlık ve açıklama
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                    
                    // Tarih
                    HStack {
                        Spacer()
                        Text(formatDate(item.publishedAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6).opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSafariView) {
            if let url = URL(string: item.url) {
                CustomSafariView(url: url)
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        guard let date = formatter.date(from: dateString) else {
            return "Bilinmeyen tarih"
        }
        
        // Yayınlanma zamanını göster
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale(identifier: "tr_TR")
        return displayFormatter.string(from: date)
    }
}

struct NewsView_Previews: PreviewProvider {
    static var previews: some View {
        NewsView()
            .preferredColorScheme(.dark)
    }
}

struct CustomSafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NewsView()
} 






