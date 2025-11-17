import Foundation
import Network
import Combine

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected: Bool = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive: Bool = false

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.omnitak.networkmonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown

        var description: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wired: return "Wired"
            case .unknown: return "Unknown"
            }
        }

        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wired: return "cable.connector"
            case .unknown: return "network.slash"
            }
        }
    }

    init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateStatus(path: path)
            }
        }

        monitor.start(queue: queue)
        print("Network monitoring started")
    }

    func stopMonitoring() {
        monitor.cancel()
        print("Network monitoring stopped")
    }

    private func updateStatus(path: NWPath) {
        // Update connection status
        isConnected = path.status == .satisfied

        // Update connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wired
        } else {
            connectionType = .unknown
        }

        // Check if expensive
        isExpensive = path.isExpensive

        // Log status changes
        print("Network status: \(isConnected ? "Connected" : "Disconnected") via \(connectionType.description)")
        if isExpensive {
            print("Warning: Connection is expensive (likely cellular)")
        }
    }

    // MARK: - Helper Methods

    var canDownloadMaps: Bool {
        // Allow downloads only on Wi-Fi or if user explicitly allows expensive connections
        return isConnected && !isExpensive
    }

    var statusDescription: String {
        if !isConnected {
            return "No Connection"
        }

        var description = connectionType.description
        if isExpensive {
            description += " (Expensive)"
        }
        return description
    }
}

// MARK: - Network Status View Model

class NetworkStatusViewModel: ObservableObject {
    @Published var showWarning: Bool = false
    @Published var warningMessage: String = ""

    private var cancellables = Set<AnyCancellable>()
    private let monitor = NetworkMonitor.shared

    init() {
        setupObservers()
    }

    private func setupObservers() {
        // Monitor connection changes
        monitor.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.showWarning = true
                    self?.warningMessage = "No internet connection. Using offline maps only."
                } else {
                    self?.showWarning = false
                }
            }
            .store(in: &cancellables)

        // Monitor expensive connection
        monitor.$isExpensive
            .sink { [weak self] isExpensive in
                if isExpensive && (self?.monitor.isConnected ?? false) {
                    self?.showWarning = true
                    self?.warningMessage = "Using cellular data. Map downloads may incur charges."
                }
            }
            .store(in: &cancellables)
    }

    func dismissWarning() {
        showWarning = false
    }
}
