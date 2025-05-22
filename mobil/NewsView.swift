import SwiftUI

struct NewsView: View {
    @State private var news: [APIService.NewsItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showingSafari = false
    @State private var selectedNewsURL: URL? = nil
    @State private var searchText = ""
    
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Arama çubuğu
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                        
                        TextField("Haberlerde ara...", text: $searchText)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(UIColor.systemGray6).opacity(0.3))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                        Text("Haberler yükleniyor...")
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(goldColor)
                        Text("Haberler yüklenemedi")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.top, 10)
                        Text(error)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 5)
                        Button(action: {
                            loadNews()
                        }) {
                            Text("Tekrar Dene")
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(goldColor)
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                        Spacer()
                    } else {
                        // Haberleri göster
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(filteredNews) { item in
                                    NewsCard(newsItem: item, onTap: {
                                        selectedNewsURL = URL(string: item.url)
                                        showingSafari = true
                                    })
                                }
                                
                                if filteredNews.isEmpty {
                                    VStack(spacing: 15) {
                                        Image(systemName: "newspaper")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                        Text(searchText.isEmpty ? "Haber bulunamadı" : "Aramanızla eşleşen haber bulunamadı")
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 50)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Haberler")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadNews()
            }
            .sheet(isPresented: $showingSafari) {
                Button("Safari'de Aç") {
                    if let url = selectedNewsURL {
                        UIApplication.shared.open(url)
                    }
                    showingSafari = false
                }
                .padding()
            }
        }
    }
    
    private var filteredNews: [APIService.NewsItem] {
        if searchText.isEmpty {
            return news
        } else {
            let lowercasedQuery = searchText.lowercased()
            return news.filter { item in
                item.title.lowercased().contains(lowercasedQuery) ||
                item.description.lowercased().contains(lowercasedQuery) ||
                item.source.lowercased().contains(lowercasedQuery)
            }
        }
    }
    
    private func loadNews() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Çoklu API kaynaklarını deneyen yeni metodu kullan
                let fetchedNews = try await APIService.shared.fetchCryptoNews()
                
                await MainActor.run {
                    if fetchedNews.isEmpty {
                        self.errorMessage = "Haberlere erişilemedi. Lütfen daha sonra tekrar deneyin."
                    } else {
                        self.news = fetchedNews
                    }
                    self.isLoading = false
                }
            } catch {
                print("Haber yükleme hatası: \(error.localizedDescription)")
                
                // API hatası durumunda log ekle
                let errorMsg = "Haber API hatası: \(error.localizedDescription)"
                print("⚠️ \(errorMsg)")
                
                await MainActor.run {
                    self.errorMessage = errorMsg
                    self.isLoading = false
                }
            }
        }
    }
}

struct NewsCard: View {
    let newsItem: APIService.NewsItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Haber resmi
                if let url = URL(string: newsItem.imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        case .empty, .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                                .background(Color(UIColor.systemGray5).opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Haber bilgileri
                VStack(alignment: .leading, spacing: 8) {
                    Text(newsItem.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(newsItem.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                    
                    HStack {
                        Text(newsItem.source)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.984, green: 0.788, blue: 0.369))
                        
                        Spacer()
                        
                        if let date = ISO8601DateFormatter().date(from: newsItem.publishedAt) {
                            Text(formattedDate(date))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
            .padding()
            .background(Color(UIColor.systemGray6).opacity(0.2))
            .cornerRadius(15)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
} 