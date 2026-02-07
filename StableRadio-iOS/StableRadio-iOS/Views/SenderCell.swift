import UIKit
import StableRadioCore

class SenderCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let formatLabel = UILabel()
    private let iconView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Icon
        iconView.image = UIImage(systemName: "desktopcomputer")
        iconView.tintColor = .systemBlue
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        // Name label
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        // Address label
        addressLabel.font = .systemFont(ofSize: 12)
        addressLabel.textColor = .secondaryLabel
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addressLabel)

        // Format label
        formatLabel.font = .systemFont(ofSize: 12)
        formatLabel.textColor = .systemGreen
        formatLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(formatLabel)

        // Layout
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: formatLabel.leadingAnchor, constant: -8),

            addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            addressLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            addressLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            formatLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            formatLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with sender: DeviceInfo) {
        nameLabel.text = sender.name
        addressLabel.text = "\(sender.ipAddress):\(sender.port)"

        if let format = sender.currentFormat {
            formatLabel.text = "\(format.estimatedBandwidthKbps) kbps"
        } else {
            formatLabel.text = ""
        }
    }
}
