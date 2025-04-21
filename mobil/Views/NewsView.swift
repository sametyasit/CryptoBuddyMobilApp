import SwiftUI
import SafariServices

// MARK: - Error Types
public enum NewsError: Error {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case allAPIsFailed
    case invalidData
    
    public var localizedDescription: String {
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
public final class NewsService {
    public static let shared = NewsService()
    private init() {}
    
    public enum NewsCategory: String, CaseIterable {
        case all = "All"
        case trading = "Trading"
        case technology = "Technology"
        case regulation = "Regulation"
        case mining = "Mining"
        case defi = "DeFi"
        case nft = "NFT"
        case metaverse = "Metaverse"
    }
    
    public struct NewsItem: Identifiable, Hashable {
        public let id: String
        public let title: String
        public let description: String
        public let url: String
        public let imageUrl: String
        public let publishedAt: Date
        public let source: String
        public let category: NewsCategory
        
        public static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
            lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public init(id: String, title: String, description: String, url: String, imageUrl: String, publishedAt: Date, source: String, category: NewsCategory) {
            self.id = id
            self.title = title
            self.description = description
            self.url = url
            self.imageUrl = imageUrl
            self.publishedAt = publishedAt
            self.source = source
            self.category = category
        }
    }
    
    public func fetchNews(category: NewsCategory = .all, page: Int = 1) async throws -> [NewsItem] {
        let apiKey = "YOUR_NEWS_API_KEY"
        let urlString = "https://newsapi.org/v2/top-headlines?category=business&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NewsError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NewsError.invalidResponse
        }
        
        let newsResponse = try JSONDecoder().decode(NewsAPIResponse.self, from: data)
        return newsResponse.articles.map { article in
            NewsItem(
                id: UUID().uuidString,
                title: article.title,
                description: article.description ?? "",
                url: article.url,
                imageUrl: article.urlToImage ?? "",
                publishedAt: ISO8601DateFormatter().date(from: article.publishedAt) ?? Date(),
                source: article.source.name,
                category: category
            )
        }
    }
}

// MARK: - View Model
public final class NewsViewModel: ObservableObject {
    @Published public var allNews: [NewsService.NewsItem] = []
    @Published public var filteredNews: [NewsService.NewsItem] = []
    @Published public var isLoading = false
    @Published public var isLoadingMore = false
    @Published public var error: NewsError?
    @Published public var selectedCategory: NewsService.NewsCategory = .all
    @Published public var activeSources: Set<String> = []
    
    private let newsService = NewsService.shared
    private var currentPage = 1
    
    public init() {}
    
    public func fetchNews() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let news = try await newsService.fetchNews(category: selectedCategory, page: currentPage)
            await MainActor.run {
                self.allNews = news
                self.filteredNews = news
                updateActiveSources()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = error as? NewsError ?? .invalidResponse
            }
        }
    }
    
    public func loadMoreNews() async {
        guard !isLoadingMore else { return }
        
        await MainActor.run {
            isLoadingMore = true
            currentPage += 1
        }
        
        do {
            let news = try await newsService.fetchNews(category: selectedCategory, page: currentPage)
            await MainActor.run {
                self.allNews.append(contentsOf: news)
                self.filteredNews = self.allNews
                updateActiveSources()
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                currentPage -= 1
                isLoadingMore = false
            }
        }
    }
    
    public func filterNews(with searchText: String) {
        if searchText.isEmpty {
            filteredNews = allNews
        } else {
            filteredNews = allNews.filter { news in
                news.title.localizedCaseInsensitiveContains(searchText) ||
                news.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    public func filterNews(by category: NewsService.NewsCategory) {
        if category == .all {
            filteredNews = allNews
        } else {
            filteredNews = allNews.filter { $0.category == category }
        }
    }
    
    private func updateActiveSources() {
        activeSources = Set(filteredNews.map { $0.source.components(separatedBy: ":").first ?? "" })
    }
}

// MARK: - Views
public struct NewsView: View {
    @StateObject private var viewModel = NewsViewModel()
    @State private var showingSafari = false
    @State private var selectedNewsURL: URL?
    @State private var searchText = ""
    @State private var selectedCategory: NewsService.NewsCategory = .all
    @State private var showError = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Kategori seçici
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(NewsService.NewsCategory.allCases, id: \.self) { category in
                                CategoryButton(
                                    title: category.rawValue,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                    Task {
                                        await viewModel.fetchNews()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    // Arama çubuğu
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search news...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: searchText) { _ in
                                viewModel.filterNews(with: searchText)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                viewModel.filterNews(with: "")
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // API kaynakları
                    if !viewModel.filteredNews.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Text("Sources:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(Array(viewModel.activeSources), id: \.self) { source in
                                    Text(source)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Haber listesi
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredNews) { news in
                                NewsCard(newsItem: news)
                                    .onTapGesture {
                                        if let url = URL(string: news.url) {
                                            selectedNewsURL = url
                                            showingSafari = true
                                        }
                                    }
                            }
                            
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.fetchNews()
                    }
                }
                
                // Yükleniyor göstergesi
                if viewModel.isLoading && viewModel.filteredNews.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                }
                
                // Hata mesajı
                if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.fetchNews()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                }
            }
            .navigationTitle("Crypto News")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingSafari) {
            if let url = selectedNewsURL {
                SafariView(url: url)
            }
        }
        .onAppear {
            if viewModel.filteredNews.isEmpty {
                Task {
                    await viewModel.fetchNews()
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
                .cornerRadius(20)
        }
    }
}

struct NewsCard: View {
    let newsItem: NewsService.NewsItem
    
    var body: some View {
        Link(destination: URL(string: newsItem.url)!) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: newsItem.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(height: 200)
                .clipped()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(newsItem.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(newsItem.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack {
                        Text(newsItem.source)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(newsItem.publishedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NewsView()
} 