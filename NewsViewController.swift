import SwiftUI
import SafariServices

struct NewsItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageUrl: String
    let source: String
    let date: Date
    let url: String
}

class NewsViewModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    @Published var isLoading = false
    
    func loadNews() {
        isLoading = true
        
        // Örnek veriler
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.newsItems = [
                NewsItem(
                    title: "Bitcoin 50,000 Doları Aştı",
                    description: "Bitcoin fiyatı son 6 ayın en yüksek seviyesine ulaşarak 50,000 doları aştı.",
                    imageUrl: "https://example.com/images/1.jpg",
                    source: "Kripto Haber",
                    date: Date(),
                    url: "https://example.com/news/1"
                ),
                NewsItem(
                    title: "Ethereum 2.0 Güncellemesi Ertelendi",
                    description: "Ethereum 2.0 güncellemesi teknik sorunlar nedeniyle 3 ay ertelendi.",
                    imageUrl: "https://example.com/images/2.jpg",
                    source: "Blockchain Dünyası",
                    date: Date().addingTimeInterval(-86400),
                    url: "https://example.com/news/2"
                )
            ]
            self.isLoading = false
        }
    }
}

struct NewsViewController: View {
    @StateObject private var viewModel = NewsViewModel()
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    private let darkBackgroundColor = Color(red: 0.11, green: 0.11, blue: 0.118)
    
    var body: some View {
        NavigationView {
            ZStack {
                darkBackgroundColor.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                        .scaleEffect(1.5)
                } else if viewModel.newsItems.isEmpty {
                    VStack {
                        Text("Henüz haber bulunamadı")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button("Yenile") {
                            viewModel.loadNews()
                        }
                        .padding()
                        .foregroundColor(.black)
                        .background(goldColor)
                        .cornerRadius(8)
                        .padding(.top, 20)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.newsItems) { item in
                                NewsCard(newsItem: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Haberler")
            .onAppear {
                viewModel.loadNews()
            }
        }
    }
}

struct NewsCard: View {
    let newsItem: NewsItem
    private let goldColor = Color(red: 0.984, green: 0.788, blue: 0.369)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(newsItem.title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(newsItem.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(3)
            
            HStack {
                Text(newsItem.source)
                    .font(.caption)
                    .foregroundColor(goldColor)
                
                Spacer()
                
                Text(formattedDate(newsItem.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NewsViewController_Previews: PreviewProvider {
    static var previews: some View {
        NewsViewController()
    }
} 