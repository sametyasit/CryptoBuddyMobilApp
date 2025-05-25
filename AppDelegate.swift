import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Ana Tab Controller'ı Oluştur
        let tabBarController = UITabBarController()
        tabBarController.view.backgroundColor = Constants.UI.backgroundColor
        
        // Piyasa Tab (Portfolio)
        let portfolioVC = PortfolioViewController()
        let portfolioNavController = UINavigationController(rootViewController: portfolioVC)
        portfolioNavController.tabBarItem = UITabBarItem(title: "Piyasa", image: UIImage(systemName: "chart.pie.fill"), tag: 0)
        
        // Haberler Tab
        let newsViewController = NewsViewController()
        let newsNavController = UINavigationController(rootViewController: newsViewController)
        newsNavController.tabBarItem = UITabBarItem(title: "Haberler", image: UIImage(systemName: "newspaper.fill"), tag: 1)
        
        // Tab Controller'a view controller'ları ekle
        tabBarController.viewControllers = [portfolioNavController, newsNavController]
        
        // Tab bar görünümünü ayarla
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        
        tabBarController.tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBarController.tabBar.scrollEdgeAppearance = appearance
        }
        
        tabBarController.tabBar.tintColor = Constants.UI.primaryColor
        tabBarController.tabBar.unselectedItemTintColor = .lightGray
        
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
        
        // Uygulama görünümü için genel ayarlar
        configureAppAppearance()
        
        // Initialize real-time crypto data service
        initializeCryptoDataService()
        
        // Popüler kripto para logolarını arka planda yükle
        CryptoIconsHelper.shared.preloadPopularCoinIcons()
        
        return true
    }
    
    private func configureAppAppearance() {
        // Uygulamanın genel görünümü için ayarlar
        UINavigationBar.appearance().tintColor = Constants.UI.primaryColor
        UINavigationBar.appearance().barTintColor = UIColor(white: 0.1, alpha: 1.0)
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        
        if #available(iOS 15.0, *) {
            // iOS 15 ve üzeri için navigation bar görünümü
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.boldSystemFont(ofSize: 20)
            ]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    private func initializeCryptoDataService() {
        // Start the real-time data service
        CryptoDataService.shared.startService()
        
        // Log connection status
        print("Real-time crypto data service initialized")
    }

    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
} 