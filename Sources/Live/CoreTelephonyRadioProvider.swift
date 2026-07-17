import CoreTelephony
import Foundation

@preconcurrency import ObjectiveC

final class CoreTelephonyRadioProvider: RadioInfoProviding {
    private let info: CTTelephonyNetworkInfo

    init() {
        info = CTTelephonyNetworkInfo()
    }

    func generations() -> AsyncStream<RadioGeneration> {
        let info = info
        return AsyncStream { continuation in
            let currentGeneration = Self.currentGeneration(from: info)
            continuation.yield(currentGeneration)

            let observer = NotificationCenter.default.addObserver(
                forName: .CTServiceRadioAccessTechnologyDidChange,
                object: nil,
                queue: nil
            ) { _ in
                let newGeneration = Self.currentGeneration(from: info)
                continuation.yield(newGeneration)
            }

            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private nonisolated static func currentGeneration(from info: CTTelephonyNetworkInfo) -> RadioGeneration {
        let dataServiceIdentifier = info.dataServiceIdentifier ?? ""
        guard let radioAccessTech = info.serviceCurrentRadioAccessTechnology?[dataServiceIdentifier] else {
            return .unknown
        }
        return RadioTechnologyMapping.generation(fromRadioAccessTechnology: radioAccessTech)
    }
}
