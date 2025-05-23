import UIKit
import SafariServices

class NewsTableViewCell: UITableViewCell {
    
    static let identifier = "NewsTableViewCell"
    
    // UI Elemanları
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        view.layer.cornerRadius = Constants.UI.cellCornerRadius
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let newsImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .darkGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let sourceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = Constants.UI.primaryColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .lightGray
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let readButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Haberi Oku", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = Constants.UI.primaryColor
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.layer.cornerRadius = 15
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Yükleme indikatörü
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var newsURL: String?
    
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
        
        contentView.addSubview(containerView)
        containerView.addSubview(newsImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(sourceLabel)
        containerView.addSubview(timeLabel)
        containerView.addSubview(readButton)
        newsImageView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            containerView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 15),
            containerView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -15),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            // News image view
            newsImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            newsImageView.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            newsImageView.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            newsImageView.heightAnchor.constraint(equalToConstant: 200),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: newsImageView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: newsImageView.centerYAnchor),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: newsImageView.bottomAnchor, constant: 10),
            titleLabel.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 10),
            titleLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -10),
            
            // Source label
            sourceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            sourceLabel.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 10),
            
            // Time label
            timeLabel.centerYAnchor.constraint(equalTo: sourceLabel.centerYAnchor),
            timeLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -10),
            
            // Read button
            readButton.topAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 15),
            readButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            readButton.widthAnchor.constraint(equalToConstant: 120),
            readButton.heightAnchor.constraint(equalToConstant: 35),
            readButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
        ])
        
        readButton.addTarget(self, action: #selector(readButtonTapped), for: .touchUpInside)
    }
    
    func configure(with news: News) {
        titleLabel.text = news.title
        sourceLabel.text = news.source
        timeLabel.text = news.timeAgoString()
        newsURL = news.url
        
        activityIndicator.startAnimating()
        
        // Resmi yükle
        NetworkManager.shared.downloadImage(from: news.imageurl) { [weak self] image in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if let image = image {
                    self?.newsImageView.image = image
                } else {
                    // Resim yüklenemezse placeholder göster
                    self?.newsImageView.image = Constants.UI.imagePlaceholder
                }
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        newsImageView.image = nil
        titleLabel.text = nil
        sourceLabel.text = nil
        timeLabel.text = nil
        newsURL = nil
    }
    
    @objc private func readButtonTapped() {
        guard let urlString = newsURL, let url = URL(string: urlString) else { return }
        
        let viewController = UIApplication.shared.windows.first?.rootViewController
        let safariViewController = SFSafariViewController(url: url)
        viewController?.present(safariViewController, animated: true)
    }
} 