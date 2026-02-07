import UIKit
import StableRadioCore

class MainViewController: UIViewController {
    // MARK: - Properties

    private var viewModel = MainViewViewModel()

    // UI Elements
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let statusLabel = UILabel()
    private let bufferSizeSlider = UISlider()
    private let bufferSizeLabel = UILabel()
    private let bufferFillProgressView = UIProgressView(progressViewStyle: .default)
    private let formatLabel = UILabel()
    private let bandwidthLabel = UILabel()
    private let latencyLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "StableRadio Receiver"
        view.backgroundColor = .white

        setupUI()
        setupViewModel()
        viewModel.startDiscovery()
    }

    deinit {
        viewModel.stopReceiving()
    }

    // MARK: - Setup

    private func setupUI() {
        // Table view for senders
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SenderCell.self, forCellReuseIdentifier: "SenderCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Status section
        let statusStack = createStatusSection()
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusStack)

        // Layout
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: statusStack.topAnchor),

            statusStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func createStatusSection() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.layer.cornerRadius = 8
        stack.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.isLayoutMarginsRelativeArrangement = true

        // Status label
        statusLabel.text = "Not connected"
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textAlignment = .center
        stack.addArrangedSubview(statusLabel)

        // Buffer size control
        let bufferStack = UIStackView()
        bufferStack.axis = .horizontal
        bufferStack.spacing = 8

        bufferSizeLabel.text = "Buffer: 10s"
        bufferSizeLabel.font = .systemFont(ofSize: 14)
        bufferStack.addArrangedSubview(bufferSizeLabel)

        bufferSizeSlider.minimumValue = 1
        bufferSizeSlider.maximumValue = 60
        bufferSizeSlider.value = 10
        bufferSizeSlider.addTarget(self, action: #selector(bufferSizeChanged), for: .valueChanged)
        bufferStack.addArrangedSubview(bufferSizeSlider)

        stack.addArrangedSubview(bufferStack)

        // Buffer fill progress
        let progressLabel = UILabel()
        progressLabel.text = "Buffer Fill:"
        progressLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(progressLabel)

        bufferFillProgressView.progress = 0
        stack.addArrangedSubview(bufferFillProgressView)

        // Format label
        formatLabel.text = "Format: --"
        formatLabel.font = .systemFont(ofSize: 12)
        formatLabel.textColor = .gray
        stack.addArrangedSubview(formatLabel)

        // Bandwidth label
        bandwidthLabel.text = "Bandwidth: -- kbps"
        bandwidthLabel.font = .systemFont(ofSize: 12)
        bandwidthLabel.textColor = .gray
        stack.addArrangedSubview(bandwidthLabel)

        // Latency label
        latencyLabel.text = "Latency: -- ms"
        latencyLabel.font = .systemFont(ofSize: 12)
        latencyLabel.textColor = .gray
        stack.addArrangedSubview(latencyLabel)

        return stack
    }

    private func setupViewModel() {
        viewModel.onSendersChanged = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }

        viewModel.onStatusChanged = { [weak self] status in
            DispatchQueue.main.async {
                self?.statusLabel.text = status
            }
        }

        viewModel.onBufferFillChanged = { [weak self] fillLevel in
            DispatchQueue.main.async {
                self?.bufferFillProgressView.progress = fillLevel
            }
        }

        viewModel.onFormatChanged = { [weak self] format in
            DispatchQueue.main.async {
                self?.formatLabel.text = "Format: \(format.description)"
                self?.bandwidthLabel.text = "Bandwidth: \(format.estimatedBandwidthKbps) kbps"
            }
        }

        // Start periodic UI updates
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateUI()
        }
    }

    private func updateUI() {
        if let stats = viewModel.currentStats {
            latencyLabel.text = String(format: "Latency: %.0f ms", stats.currentLatencyMs)
        }
    }

    // MARK: - Actions

    @objc private func bufferSizeChanged() {
        let bufferSize = Int(bufferSizeSlider.value)
        bufferSizeLabel.text = "Buffer: \(bufferSize)s"
        viewModel.setBufferSize(TimeInterval(bufferSize))
    }
}

// MARK: - UITableViewDataSource

extension MainViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.discoveredSenders.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SenderCell", for: indexPath) as! SenderCell
        let sender = viewModel.discoveredSenders[indexPath.row]
        cell.configure(with: sender)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Available Senders"
    }
}

// MARK: - UITableViewDelegate

extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let sender = viewModel.discoveredSenders[indexPath.row]

        if viewModel.isConnected {
            // Disconnect
            viewModel.stopReceiving()
        } else {
            // Connect
            viewModel.connectToSender(sender)
        }
    }
}
