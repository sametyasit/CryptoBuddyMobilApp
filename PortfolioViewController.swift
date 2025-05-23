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
    
    private var coins: [Coin] = []
    private var refreshTimer: Timer?
    private var timeFrame: TimeFrame = .day
    private var isShowingGainers = true
    
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
        loadCoins()
    }
    
    @objc private func pullToRefresh() {
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
    
    // MARK: - Data Loading
    
    private func loadCoins(showLoadingIndicator: Bool = true) {
        if showLoadingIndicator && coins.isEmpty {
            activityIndicator.startAnimating()
        }
        
        CoinNetworkManager.shared.fetchCoins(timeFrame: timeFrame) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                
                switch result {
                case .success(let coinData):
                    self.coins = coinData
                    self.filterAndSortCoins()
                    self.errorView.isHidden = true
                    
                case .failure(let error):
                    if self.coins.isEmpty {
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
            coins.sort { $0.priceChangePercentage > $1.priceChangePercentage }
        } else {
            // Düşenler - küçükten büyüğe sırala
            coins.sort { $0.priceChangePercentage < $1.priceChangePercentage }
        }
        
        tableView.reloadData()
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
        return coins.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CoinTableViewCell.identifier, for: indexPath) as? CoinTableViewCell else {
            return UITableViewCell()
        }
        
        let coin = coins[indexPath.row]
        cell.configure(with: coin)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Coin detaylarına git
        let coin = coins[indexPath.row]
        let detailVC = CoinDetailViewController(coin: coin)
        navigationController?.pushViewController(detailVC, animated: true)
    }
} 