import UIKit
import SafariServices

class CoinDetailViewController: UIViewController {
    
    // MARK: - UI Elemanları
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.layer.cornerRadius = Constants.UI.cellCornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let coinImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let symbolLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let changeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statsView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.layer.cornerRadius = Constants.UI.cellCornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let marketCapTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Market Cap"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let volumeTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Hacim (24s)"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let highTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "24s En Yüksek"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let lowTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "24s En Düşük"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let marketCapValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let volumeValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let highValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let lowValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .white
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Coin Hakkında"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionTextView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        textView.textColor = .white
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.dataDetectorTypes = .link
        textView.layer.cornerRadius = Constants.UI.cellCornerRadius
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let visitWebsiteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("CoinGecko Sayfasını Ziyaret Et", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = Constants.UI.primaryColor
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = Constants.UI.primaryColor
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Properties
    
    private let coin: Coin
    private var coinDetail: CoinDetail?
    
    // MARK: - Initialization
    
    init(coin: Coin) {
        self.coin = coin
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBasicInfo()
        loadCoinDetail()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.backgroundColor = Constants.UI.backgroundColor
        title = coin.name
        
        // Add navigation bar button
        let favoriteButton = UIBarButtonItem(image: UIImage(systemName: "star"), style: .plain, target: self, action: #selector(favoriteButtonTapped))
        navigationItem.rightBarButtonItem = favoriteButton
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add views to content view
        contentView.addSubview(headerView)
        contentView.addSubview(statsView)
        contentView.addSubview(descriptionTitleLabel)
        contentView.addSubview(descriptionTextView)
        contentView.addSubview(visitWebsiteButton)
        
        // Add subviews to header view
        headerView.addSubview(coinImageView)
        headerView.addSubview(nameLabel)
        headerView.addSubview(symbolLabel)
        headerView.addSubview(priceLabel)
        headerView.addSubview(changeLabel)
        
        // Add subviews to stats view
        statsView.addSubview(marketCapTitleLabel)
        statsView.addSubview(volumeTitleLabel)
        statsView.addSubview(highTitleLabel)
        statsView.addSubview(lowTitleLabel)
        statsView.addSubview(marketCapValueLabel)
        statsView.addSubview(volumeValueLabel)
        statsView.addSubview(highValueLabel)
        statsView.addSubview(lowValueLabel)
        
        // Add activity indicator
        view.addSubview(activityIndicator)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header view
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Coin image view
            coinImageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            coinImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            coinImageView.widthAnchor.constraint(equalToConstant: 64),
            coinImageView.heightAnchor.constraint(equalToConstant: 64),
            coinImageView.bottomAnchor.constraint(lessThanOrEqualTo: headerView.bottomAnchor, constant: -16),
            
            // Name label
            nameLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: coinImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -16),
            
            // Symbol label
            symbolLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            symbolLabel.leadingAnchor.constraint(equalTo: coinImageView.trailingAnchor, constant: 12),
            
            // Price label
            priceLabel.topAnchor.constraint(equalTo: symbolLabel.bottomAnchor, constant: 12),
            priceLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            // Change label
            changeLabel.centerYAnchor.constraint(equalTo: priceLabel.centerYAnchor),
            changeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: priceLabel.trailingAnchor, constant: 12),
            changeLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            changeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            changeLabel.heightAnchor.constraint(equalToConstant: 28),
            changeLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            
            // Stats view
            statsView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            statsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Market cap title
            marketCapTitleLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 16),
            marketCapTitleLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 16),
            
            // Market cap value
            marketCapValueLabel.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 16),
            marketCapValueLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -16),
            marketCapValueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: marketCapTitleLabel.trailingAnchor, constant: 8),
            
            // Volume title
            volumeTitleLabel.topAnchor.constraint(equalTo: marketCapTitleLabel.bottomAnchor, constant: 12),
            volumeTitleLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 16),
            
            // Volume value
            volumeValueLabel.topAnchor.constraint(equalTo: marketCapValueLabel.bottomAnchor, constant: 12),
            volumeValueLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -16),
            volumeValueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: volumeTitleLabel.trailingAnchor, constant: 8),
            
            // High title
            highTitleLabel.topAnchor.constraint(equalTo: volumeTitleLabel.bottomAnchor, constant: 12),
            highTitleLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 16),
            
            // High value
            highValueLabel.topAnchor.constraint(equalTo: volumeValueLabel.bottomAnchor, constant: 12),
            highValueLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -16),
            highValueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: highTitleLabel.trailingAnchor, constant: 8),
            
            // Low title
            lowTitleLabel.topAnchor.constraint(equalTo: highTitleLabel.bottomAnchor, constant: 12),
            lowTitleLabel.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 16),
            lowTitleLabel.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -16),
            
            // Low value
            lowValueLabel.topAnchor.constraint(equalTo: highValueLabel.bottomAnchor, constant: 12),
            lowValueLabel.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -16),
            lowValueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: lowTitleLabel.trailingAnchor, constant: 8),
            lowValueLabel.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -16),
            
            // Description title
            descriptionTitleLabel.topAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 24),
            descriptionTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            descriptionTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Description text view
            descriptionTextView.topAnchor.constraint(equalTo: descriptionTitleLabel.bottomAnchor, constant: 8),
            descriptionTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            descriptionTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Visit website button
            visitWebsiteButton.topAnchor.constraint(equalTo: descriptionTextView.bottomAnchor, constant: 24),
            visitWebsiteButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            visitWebsiteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            visitWebsiteButton.heightAnchor.constraint(equalToConstant: 50),
            visitWebsiteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Add action to visit website button
        visitWebsiteButton.addTarget(self, action: #selector(visitWebsiteButtonTapped), for: .touchUpInside)
    }
    
    private func setupBasicInfo() {
        // Set up the basic info from the coin model
        nameLabel.text = coin.name
        symbolLabel.text = coin.symbol.uppercased()
        priceLabel.text = coin.formattedPrice()
        
        // Set up change label
        let priceChangeText = coin.formattedPriceChange()
        changeLabel.text = priceChangeText
        
        if coin.isPriceChangePositive {
            changeLabel.backgroundColor = UIColor.green.withAlphaComponent(0.2)
            changeLabel.textColor = UIColor.green
        } else {
            changeLabel.backgroundColor = UIColor.red.withAlphaComponent(0.2)
            changeLabel.textColor = UIColor.red
        }
        
        // Set up stats view with available data
        marketCapValueLabel.text = coin.formattedMarketCap()
        volumeValueLabel.text = coin.formattedVolume()
        
        if let high = coin.high24h {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = high < 1 ? 6 : 2
            highValueLabel.text = formatter.string(from: NSNumber(value: high))
        } else {
            highValueLabel.text = "N/A"
        }
        
        if let low = coin.low24h {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = low < 1 ? 6 : 2
            lowValueLabel.text = formatter.string(from: NSNumber(value: low))
        } else {
            lowValueLabel.text = "N/A"
        }
        
        // Load coin image
        CoinNetworkManager.shared.downloadImage(from: coin.image) { [weak self] image in
            DispatchQueue.main.async {
                if let image = image {
                    self?.coinImageView.image = image
                } else {
                    self?.coinImageView.image = UIImage(systemName: "questionmark.circle")
                    self?.coinImageView.tintColor = .lightGray
                }
            }
        }
    }
    
    private func loadCoinDetail() {
        activityIndicator.startAnimating()
        descriptionTextView.isHidden = true
        
        CoinNetworkManager.shared.fetchCoinDetail(id: coin.id) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.descriptionTextView.isHidden = false
                
                switch result {
                case .success(let coinDetail):
                    self.coinDetail = coinDetail
                    self.updateUI(with: coinDetail)
                case .failure:
                    self.descriptionTextView.text = "Coin hakkında detaylı bilgi alınamadı."
                }
            }
        }
    }
    
    private func updateUI(with coinDetail: CoinDetail) {
        // Update description
        let description = coinDetail.description["tr"] ?? coinDetail.description["en"] ?? "Açıklama bulunamadı."
        
        // Convert HTML to attributed string
        if let attributedString = try? NSAttributedString(
            data: description.data(using: .utf8) ?? Data(),
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil) {
            
            descriptionTextView.attributedText = attributedString
        } else {
            descriptionTextView.text = description
        }
    }
    
    // MARK: - Actions
    
    @objc private func favoriteButtonTapped() {
        // Toggle favorite status
        let isFavorited = !UserDefaults.standard.bool(forKey: "favorite_\(coin.id)")
        UserDefaults.standard.set(isFavorited, forKey: "favorite_\(coin.id)")
        
        // Update button image
        let imageName = isFavorited ? "star.fill" : "star"
        navigationItem.rightBarButtonItem?.image = UIImage(systemName: imageName)
        
        // Show feedback
        let message = isFavorited ? "Favorilere eklendi" : "Favorilerden çıkarıldı"
        let feedbackView = UIView()
        feedbackView.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        feedbackView.layer.cornerRadius = 10
        feedbackView.translatesAutoresizingMaskIntoConstraints = false
        
        let feedbackLabel = UILabel()
        feedbackLabel.text = message
        feedbackLabel.textColor = .white
        feedbackLabel.font = UIFont.systemFont(ofSize: 14)
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        
        feedbackView.addSubview(feedbackLabel)
        view.addSubview(feedbackView)
        
        NSLayoutConstraint.activate([
            feedbackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            feedbackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            feedbackView.heightAnchor.constraint(equalToConstant: 40),
            
            feedbackLabel.centerXAnchor.constraint(equalTo: feedbackView.centerXAnchor),
            feedbackLabel.centerYAnchor.constraint(equalTo: feedbackView.centerYAnchor),
            feedbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: feedbackView.leadingAnchor, constant: 16),
            feedbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: feedbackView.trailingAnchor, constant: -16)
        ])
        
        UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
            feedbackView.alpha = 0
        }) { _ in
            feedbackView.removeFromSuperview()
        }
    }
    
    @objc private func visitWebsiteButtonTapped() {
        // Open CoinGecko page for this coin
        if let url = URL(string: "https://www.coingecko.com/en/coins/\(coin.id)") {
            let safariVC = SFSafariViewController(url: url)
            present(safariVC, animated: true)
        }
    }
} 