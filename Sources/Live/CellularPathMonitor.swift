import Foundation
import Network

final class CellularPathMonitor: CellularPathMonitoring {
    init() {}

    func availability() -> AsyncStream<Bool> {
        let monitor = NWPathMonitor(requiredInterfaceType: .cellular)
        return AsyncStream { continuation in
            let task = Task {
                for await path in monitor {
                    continuation.yield(path.status == .satisfied)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                monitor.cancel()
            }
        }
    }
}
