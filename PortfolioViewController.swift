import UIKit

class PortfolioViewController: UIViewController {
    
    // MARK: - UI Elemanları
    
    private let segmentedControl: UISegmentedControl = {
        let items = ["Yükselenler", "Düşenler"]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = Constants.UI.primaryColor
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        return segmentedControl
    }()
    
    private let timeFrameControl: UISegmentedControl = {
        let items = ["24s", "1h", "7g", "30g"]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = Constants.UI.primaryColor
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        return segmentedControl
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(CoinTableViewCell.self, forCellReuseIdentifier: CoinTableViewCell.identifier)
        tableView.register(LoadMoreButtonCell.self, forCellReuseIdentifier: LoadMoreButtonCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let refreshControl = UIRefreshControl()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = Constants.UI.primaryColor
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let errorView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Tekrar Dene", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = Constants.UI.primaryColor
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    
    private var allCoins: [Coin] = [] // Tüm coinleri tut
    private var displayedCoins: [Coin] = [] // Görüntülenen coinler
    private var refreshTimer: Timer?
    private var timeFrame: TimeFrame = .day
    private var isShowingGainers = true
    
    // Sayfalama ile ilgili değişkenler
    private var currentPage = 1
    private var isLoadingMore = false
    private var totalCoinCount = 0
    private var displayLimit = 30
    private var hasMoreCoins = true // Daha fazla coin var mı?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupRefreshControl()
        setupErrorView()
        setupSegmentedControls()
        loadCoins()
        setupAutoRefresh()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.backgroundColor = Constants.UI.backgroundColor
        title = "Piyasa"
        
        view.addSubview(segmentedControl)
        view.addSubview(timeFrameControl)
        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        view.addSubview(errorView)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            timeFrameControl.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            timeFrameControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timeFrameControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: timeFrameControl.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
        ])
    }
    
    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.boldSystemFont(ofSize: 20)
        ]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = Constants.UI.primaryColor
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    private func setupRefreshControl() {
        refreshControl.tintColor = Constants.UI.primaryColor
        refreshControl.attributedTitle = NSAttributedString(string: "Yenileniyor...", attributes: [.foregroundColor: UIColor.lightGray])
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func setupErrorView() {
        errorView.addSubview(errorLabel)
        errorView.addSubview(retryButton)
        
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: errorView.topAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor),
            
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
            retryButton.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 40),
            retryButton.bottomAnchor.constraint(equalTo: errorView.bottomAnchor)
        ])
        
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
    }
    
    private func setupSegmentedControls() {
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        timeFrameControl.addTarget(self, action: #selector(timeFrameChanged), for: .valueChanged)
    }
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(timeInterval: 60, // 1 dakikalık güncelleme
                                           target: self, 
                                           selector: #selector(autoRefreshCoins), 
                                           userInfo: nil, 
                                           repeats: true)
    }
    
    // MARK: - Actions
    
    @objc private func segmentChanged() {
        isShowingGainers = segmentedControl.selectedSegmentIndex == 0
        filterAndSortCoins()
        resetPagination() // Filtreleme değiştiğinde sayfalamayı sıfırla
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }
    
    @objc private func timeFrameChanged() {
        switch timeFrameControl.selectedSegmentIndex {
        case 0:
            timeFrame = .day
        case 1:
            timeFrame = .hour
        case 2:
            timeFrame = .week
        case 3:
            timeFrame = .month
        default:
            timeFrame = .day
        }
        currentPage = 1 // Zaman aralığı değişti, sayfalama sıfırla
        loadCoins()
    }
    
    @objc private func pullToRefresh() {
        currentPage = 1 // Yenileme yapıldı, sayfalama sıfırla
        loadCoins()
    }
    
    @objc private func retryButtonTapped() {
        errorView.isHidden = true
        loadCoins()
    }
    
    @objc private func autoRefreshCoins() {
        // Kullanıcı tableView'da aktif olarak scroll yapmıyorsa otomatik yenile
        if !tableView.isDragging && !tableView.isDecelerating {
            loadCoins(showLoadingIndicator: false)
        }
    }
    
    // Daha fazla coin yükleme
    func loadMoreCoins() {
        if isLoadingMore || !hasMoreCoins {
            return
        }
        
        isLoadingMore = true
        
        // Yükleme göstergesi için footer'daki cell'i güncelle
        tableView.reloadRows(at: [IndexPath(row: displayedCoins.count, section: 0)], with: .none)
        
        currentPage += 1
        
        CoinNetworkManager.shared.fetchCoins(timeFrame: timeFrame, page: currentPage, perPage: 100) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingMore = false
                
                switch result {
                case .success(let newCoins):
                    if newCoins.isEmpty {
                        self.hasMoreCoins = false
                    } else {
                        // Yeni coinleri ana listeye ekle
                        self.allCoins.append(contentsOf: newCoins)
                        self.filterAndSortCoins()
                    }
                    
                case .failure:
                    // Hata durumunda sessizce devam et, kullanıcı tekrar daha fazla göster diyebilir
                    break
                }
                
                // Yükleme göstergesi için footer'ı güncelle
                if self.tableView.numberOfRows(inSection: 0) > self.displayedCoins.count {
                    self.tableView.reloadRows(at: [IndexPath(row: self.displayedCoins.count, section: 0)], with: .none)
                }
            }
        }
    }
    
    // Sayfalamayı sıfırlama
    private func resetPagination() {
        displayLimit = 30 // İlk sayfada gösterilecek coin sayısı
        updateDisplayedCoins()
    }
    
    // Görüntülenecek coinleri güncelleme
    private func updateDisplayedCoins() {
        let totalCoins = allCoins.count
        let limit = min(displayLimit, totalCoins)
        
        displayedCoins = Array(allCoins.prefix(limit))
        hasMoreCoins = limit < totalCoins || currentPage == 1 // İlk sayfadaysak daha fazla olabileceğini varsay
        
        tableView.reloadData()
    }
    
    // Daha fazla göster butonuna tıklanınca
    @objc private func loadMoreButtonTapped() {
        if displayLimit < allCoins.count {
            // Zaten yüklenen coinler içinde daha gösterilmeyenler varsa
            displayLimit += 30
            updateDisplayedCoins()
        } else {
            // Daha fazla coin yükle
            loadMoreCoins()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadCoins(showLoadingIndicator: Bool = true) {
        if showLoadingIndicator && allCoins.isEmpty {
            activityIndicator.startAnimating()
        }
        
        // Sayfalamayı sıfırla
        if currentPage == 1 {
            allCoins = []
            displayedCoins = []
            displayLimit = 30
            hasMoreCoins = true
        }
        
        CoinNetworkManager.shared.fetchCoins(timeFrame: timeFrame, currency: "usd", perPage: 100, page: currentPage) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                
                switch result {
                case .success(let coinData):
                    if self.currentPage == 1 {
                        self.allCoins = coinData
                    } else {
                        self.allCoins.append(contentsOf: coinData)
                    }
                    
                    self.filterAndSortCoins()
                    self.errorView.isHidden = true
                    
                    // Yanıt boşsa, daha fazla coin yok demektir
                    if coinData.isEmpty && self.currentPage > 1 {
                        self.hasMoreCoins = false
                    }
                    
                case .failure(let error):
                    if self.allCoins.isEmpty {
                        self.showError(error)
                    }
                }
            }
        }
    }
    
    private func filterAndSortCoins() {
        // Filtreleme ve sıralama
        if isShowingGainers {
            // Yükselenler - büyükten küçüğe sırala
            allCoins.sort { $0.priceChangePercentage > $1.priceChangePercentage }
        } else {
            // Düşenler - küçükten büyüğe sırala
            allCoins.sort { $0.priceChangePercentage < $1.priceChangePercentage }
        }
        
        // Görüntülenecek coinleri güncelle
        updateDisplayedCoins()
    }
    
    private func showError(_ error: NetworkError) {
        var errorMessage = "Bir hata oluştu. Lütfen tekrar deneyiniz."
        
        switch error {
        case .invalidURL:
            errorMessage = "Geçersiz URL. Lütfen tekrar deneyiniz."
        case .noData:
            errorMessage = "Veri alınamadı. Lütfen internet bağlantınızı kontrol ediniz."
        case .decodingError:
            errorMessage = "Veri işlenemedi. Lütfen tekrar deneyiniz."
        case .serverError(let message):
            errorMessage = "Sunucu hatası: \(message)"
        }
        
        errorLabel.text = errorMessage
        errorView.isHidden = false
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension PortfolioViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Eğer gösterilecek coin varsa, bir fazla satır (daha fazla göster butonu için)
        return displayedCoins.count + (hasMoreCoins ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Son satır ve daha fazla coin varsa "Daha Fazla Göster" butonu göster
        if indexPath.row == displayedCoins.count && hasMoreCoins {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: LoadMoreButtonCell.identifier, for: indexPath) as? LoadMoreButtonCell else {
                return UITableViewCell()
            }
            
            cell.configure(isLoading: isLoadingMore)
            cell.loadMoreButton.addTarget(self, action: #selector(loadMoreButtonTapped), for: .touchUpInside)
            return cell
        }
        
        // Normal coin hücresi
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CoinTableViewCell.identifier, for: indexPath) as? CoinTableViewCell else {
            return UITableViewCell()
        }
        
        let coin = displayedCoins[indexPath.row]
        cell.configure(with: coin)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Eğer "Daha Fazla" butonuysa işlem yapma
        if indexPath.row == displayedCoins.count {
            return
        }
        
        // Coin detaylarına git
        let coin = displayedCoins[indexPath.row]
        let detailVC = CoinDetailViewController(coin: coin)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // "Daha Fazla Göster" butonu için yükseklik
        if indexPath.row == displayedCoins.count {
            return 60
        }
        return UITableView.automaticDimension
    }
}

// "Daha Fazla Göster" butonu için özel hücre
class LoadMoreButtonCell: UITableViewCell {
    static let identifier = "LoadMoreButtonCell"
    
    let loadMoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Daha Fazla Göster", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.984, green: 0.788, blue: 0.369, alpha: 1.0) // Altın rengi
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(loadMoreButton)
        loadMoreButton.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            loadMoreButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            loadMoreButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            loadMoreButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            loadMoreButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            loadMoreButton.heightAnchor.constraint(equalToConstant: 40),
            
            activityIndicator.centerYAnchor.constraint(equalTo: loadMoreButton.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: loadMoreButton.trailingAnchor, constant: -15)
        ])
    }
    
    func configure(isLoading: Bool) {
        if isLoading {
            loadMoreButton.setTitle("Yükleniyor...", for: .normal)
            activityIndicator.startAnimating()
            loadMoreButton.isEnabled = false
        } else {
            loadMoreButton.setTitle("Daha Fazla Göster", for: .normal)
            activityIndicator.stopAnimating()
            loadMoreButton.isEnabled = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        configure(isLoading: false)
    }
} 