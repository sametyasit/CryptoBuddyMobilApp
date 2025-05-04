import SwiftUI
import Foundation
import Combine
import Charts
import UIKit

// Image önbellek sınıfı
class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 50 // 50 MB
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func removeAll() {
        cache.removeAllObjects()
    }
}

// Önbellekli görüntü yükleme görünümü
struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    
    init(url: URL?, scale: CGFloat = 1.0, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }
    
    var body: some View {
        Group {
            if let cachedImage = getCachedImage() {
                content(.success(Image(uiImage: cachedImage)))
            } else if let image = loadedImage {
                content(.success(Image(uiImage: image)))
            } else {
                content(.empty)
                    .onAppear {
                        if !isLoading {
                            loadImage()
                        }
                    }
            }
        }
    }
    
    private func getCachedImage() -> UIImage? {
        guard let url = url else { return nil }
        return ImageCache.shared.get(forKey: url.absoluteString)
    }
    
    private func loadImage() {
        guard let url = url else { return }
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    ImageCache.shared.set(image, forKey: url.absoluteString)
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// UIImage dönüşümü için uzantı
extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        if let view = controller.view {
            let size = view.intrinsicContentSize
            view.bounds = CGRect(origin: .zero, size: size)
            view.backgroundColor = .clear
            
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
        }
        return nil
    }
}

// SearchViewModel modelini ekleyelim
class SearchViewModelLight: ObservableObject {
    @Published var searchText = ""
    @Published var isLoading = false
    
    // Yerleşik demo veriler
    @Published var coins: [String] = [
        "Bitcoin", "Ethereum", "Cardano", "Solana",
        "Ripple", "Polkadot", "Avalanche", "Dogecoin",
        "Shiba Inu", "Litecoin", "Chainlink", "BNB",
        "Uniswap", "Polygon", "Tron", "Cosmos"
    ]
    
    func loadInitialData() {
        // Verileri şu anda direk kodda tanımladık
    }
}

// CryptoSearchAnimation enumunu ekleyelim
enum CryptoSearchAnimation {
    case bouncingLogos
    static func random() -> CryptoSearchAnimation { .bouncingLogos }
}

// MARK: - App Colors Theme
//struct AppColorsTheme {
//    static let gold = Color(red: 0.984, green: 0.788, blue: 0.369)
//    static let darkGray = Color(UIColor.darkGray)
//    static let black = Color.black
//}

// Ana uygulamanın tab view yapısı
struct MainTabView: View {
    @State private var showingLoginView = false
    
    var body: some View {
        TabView {
            MarketView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Markets")
                }
            
            NewsView()
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("News")
                }
            
            SearchView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            PortfolioView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Portfolio")
                }
            
            CommunityView(showingLoginView: $showingLoginView)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Community")
                }
        }
        .accentColor(AppColorsTheme.gold)
        .sheet(isPresented: $showingLoginView) {
            LoginView(isPresented: $showingLoginView)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Market View
struct MarketView: View {
    @Binding var showingLoginView: Bool
    
    var body: some View {
        NavigationView {
            CoinListView()
                .navigationTitle("Markets")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColorsTheme.gold)
                                .imageScale(.large)
                        }
                    }
                }
        }
    }
}

// MARK: - News View
struct NewsViewSimple: View {
    @State private var isLoading = false
    @State private var showingNewsDetail = false
    @State private var selectedCategory: NewsCategory = .all
    @State private var searchText = ""
    
    enum NewsCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case crypto = "Crypto"
        case blockchain = "Blockchain"
        case nft = "NFT"
        case defi = "DeFi"
        
        var id: String { self.rawValue }
    }
    
    init(showDefaultContent: Bool) {
        // Empty initializer to resolve the ambiguity
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(NewsCategory.allCases) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category.rawValue)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? AppColorsTheme.gold : Color.gray.opacity(0.3))
                                    .foregroundColor(selectedCategory == category ? .black : .white)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColorsTheme.gold))
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    // Demo için örnek haberler
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(1...10, id: \.self) { i in
                                NewsCardView(
                                    title: "Kripto Para Haberi \(i)",
                                    description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam eu turpis molestie, dictum est a, mattis tellus.",
                                    source: "Crypto News",
                                    date: Date(),
                                    category: selectedCategory.rawValue
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Crypto News")
            .searchable(text: $searchText, prompt: "Search news...")
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
    }
}

struct NewsCardView: View {
    let title: String
    let description: String
    let source: String
    let date: Date
    let category: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Text(source)
                    .font(.caption)
                    .foregroundColor(AppColorsTheme.gold)
                
                Spacer()
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(AppColorsTheme.darkGray)
        .cornerRadius(10)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Login View
struct LoginViewSimple: View {
    @Binding var isPresented: Bool
    @State private var username = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var isLoggedIn = false
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Giriş Yap")
                        .font(.largeTitle)
                        .padding(.bottom, 30)
                    
                    // Kullanıcı adı
                    TextField("Kullanıcı Adı", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 15)
                    
                    // Şifre
                    SecureField("Şifre", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    
                    Button("Giriş Yap") {
                        // Demo için basit bir kontrol
                        if username.isEmpty || password.isEmpty {
                            showingAlert = true
                        } else {
                            // Giriş başarılı
                            UserDefaults.standard.set(true, forKey: "isLoggedIn")
                            isPresented = false
                        }
                    }
                    .foregroundColor(.black)
                    .padding()
                    .frame(width: 200)
                    .background(AppColorsTheme.gold)
                    .cornerRadius(10)
                    
                    Button("Kapat") {
                        isPresented = false
                    }
                    .foregroundColor(AppColorsTheme.gold)
                    .padding(.top, 20)
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Hata"),
                    message: Text("Lütfen kullanıcı adı ve şifre girin"),
                    dismissButton: .default(Text("Tamam"))
                )
            }
        }
    }
}

// MARK: - Search View
struct SearchView: View {
    @Binding var showingLoginView: Bool
    @StateObject private var viewModel = SearchViewModelLight()
    @State private var searchText = ""
    @State private var animationType: CryptoSearchAnimation = .bouncingLogos
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("Arama Ekranı")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding(.top, 10)
                    
                    TextField("Kripto para ara...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    if searchText.isEmpty {
                        // Animasyonlu coin matrisi
                        CryptoSearchAnimationView(type: animationType, coinNames: viewModel.coins)
                            .padding(.top, 30)
                    } else {
                        // Arama sonuçları burada gösterilecek
                        List {
                            ForEach(viewModel.coins.filter { $0.lowercased().contains(searchText.lowercased()) }, id: \.self) { coin in
                                HStack {
                                    Image(systemName: "bitcoinsign.circle.fill")
                                        .foregroundColor(AppColorsTheme.gold)
                                    Text(coin)
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.black)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingLoginView = true
                    }) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppColorsTheme.gold)
                            .imageScale(.large)
                    }
                }
            }
        }
        .onAppear {
            // Animasyon tipini değiştir ve verileri yükle
            self.animationType = .bouncingLogos
            viewModel.loadInitialData()
        }
    }
}

// MARK: - CryptoSearchAnimationView
struct CryptoSearchAnimationView: View {
    let type: CryptoSearchAnimation
    let coinNames: [String]
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { column in
                        let index = row * 4 + column
                        if index < coinNames.count {
                            CoinLogoCircle(name: coinNames[index])
                        }
                    }
                }
            }
        }
    }
}

// Coin logo dairesi
struct CoinLogoCircle: View {
    let name: String
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColorsTheme.darkGray)
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.2), radius: 5)
            
            VStack(spacing: 2) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(AppColorsTheme.gold)
                    .frame(width: 30, height: 30)
                
                Text(name.prefix(4))
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isAnimating ? 1.1 : 1.0)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Portfolio View
struct PortfolioView: View {
    @Binding var showingLoginView: Bool
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if !isLoggedIn {
                    // Kullanıcı giriş yapmamışsa gösterilecek görünüm
                    VStack(spacing: 20) {
                        Image(systemName: "lock.circle")
                            .font(.system(size: 70))
                            .foregroundColor(AppColorsTheme.gold)
                            .padding(.bottom, 30)
                        
                        Text("Portföyünüzü görüntülemek için \ngiriş yapmalısınız")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                        
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Text("Giriş Yap")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColorsTheme.gold)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 50)
                    }
                } else {
                    // Kullanıcı giriş yapmışsa portföy görünümü
                    Text("Portföy İçeriği")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("Portföy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoggedIn {
                        Button(action: {
                            // Çıkış yap
                            isLoggedIn = false
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(AppColorsTheme.gold)
                        }
                    } else {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColorsTheme.gold)
                                .imageScale(.large)
                        }
                    }
                }
            }
            .onAppear {
                // Kullanıcının giriş durumunu kontrol et
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            }
            .onChange(of: showingLoginView) { _ in
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            }
        }
    }
}

// MARK: - Community View
struct CommunityView: View {
    @Binding var showingLoginView: Bool
    @State private var isLoggedIn = false
    @State private var newPostText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Community View")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                    
                    if !isLoggedIn {
                        // Giriş yapmayan kullanıcılar için bilgi kartı
                        HStack(spacing: 16) {
                            Image(systemName: "lock.circle")
                                .font(.system(size: 24))
                                .foregroundColor(AppColorsTheme.gold)
                            
                            Text("Yorum yapmak için giriş yapmalısınız")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                showingLoginView = true
                            }) {
                                Text("Giriş Yap")
                                    .font(.footnote.bold())
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppColorsTheme.gold)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.darkGray).opacity(0.3))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoggedIn {
                        Button(action: {
                            // Çıkış yap
                            isLoggedIn = false
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(AppColorsTheme.gold)
                        }
                    } else {
                        Button(action: {
                            showingLoginView = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppColorsTheme.gold)
                                .imageScale(.large)
                        }
                    }
                }
            }
            .onAppear {
                // Kullanıcının giriş durumunu kontrol et
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            }
            .onChange(of: showingLoginView) { _ in
                isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            }
        }
    }
}

// MARK: - Geçici Coin Detay Görünümü
struct TemporaryCoinDetailView: View {
    let coinId: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Coin ID: \(coinId)")
                .font(.headline)
                .padding()
            
            Text("Coin detayları yakında burada olacak")
                .foregroundColor(.gray)
                .padding()
            
            Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(AppColorsTheme.gold)
            .foregroundColor(.black)
            .cornerRadius(8)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationTitle("Coin Detayları")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Kapat")
                        .foregroundColor(AppColorsTheme.gold)
                }
            }
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView()
        }
    }
}

