import Foundation

struct AccessibilitySummaryInput {
    let downloadMbps: Double
    let uploadMbps: Double
    let generation: RadioGeneration
    let quality: SignalQuality
    let downloadBytes: Int64
    let uploadBytes: Int64
}

enum AccessibilitySummary {
    // swiftlint:disable:next function_parameter_count
    nonisolated static func value(
        downloadMbps: Double,
        uploadMbps: Double,
        generation: RadioGeneration,
        quality: SignalQuality,
        downloadBytes: Int64,
        uploadBytes: Int64
    ) -> String {
        let input = AccessibilitySummaryInput(
            downloadMbps: downloadMbps,
            uploadMbps: uploadMbps,
            generation: generation,
            quality: quality,
            downloadBytes: downloadBytes,
            uploadBytes: uploadBytes
        )
        return buildValue(input)
    }

    private nonisolated static func buildValue(_ input: AccessibilitySummaryInput) -> String {
        let downloadPart = formatDownload(input.downloadMbps)
        let uploadPart = formatUpload(input.uploadMbps)
        let generationPart = formatGeneration(input.generation)
        let qualityPart = formatQuality(input.quality)
        let dataPart = formatSessionData(input.downloadBytes, input.uploadBytes)

        var components: [String] = [downloadPart, uploadPart]
        if !generationPart.isEmpty {
            components.append(generationPart)
        }
        components.append(qualityPart)
        components.append(dataPart)

        return components.joined(separator: ", ")
    }

    private nonisolated static func formatDownload(_ mbps: Double) -> String {
        if mbps >= ScoutMeter.downloadCapMbps {
            return "more than 10 megabits per second down"
        }
        let rounded = Int(mbps.rounded())
        return "\(rounded) megabits per second down"
    }

    private nonisolated static func formatUpload(_ mbps: Double) -> String {
        if mbps >= ScoutMeter.uploadCapMbps {
            return "more than 5 megabits per second up"
        }
        let rounded = Int(mbps.rounded())
        return "\(rounded) megabits per second up"
    }

    private nonisolated static func formatGeneration(_ generation: RadioGeneration) -> String {
        switch generation {
        case .unknown:
            ""
        default:
            generation.rawValue
        }
    }

    private nonisolated static func formatQuality(_ quality: SignalQuality) -> String {
        switch quality {
        case .great:
            "Great signal"
        case .usable:
            "Usable signal"
        case .poor:
            "Poor signal"
        }
    }

    private nonisolated static func formatSessionData(
        _ downloadBytes: Int64,
        _ uploadBytes: Int64
    ) -> String {
        let downloadMbStr = simplifyMbDisplay(
            ScoutMeter.megabytesDisplay(bytes: downloadBytes)
        )
        let uploadMbStr = simplifyMbDisplay(
            ScoutMeter.megabytesDisplay(bytes: uploadBytes)
        )
        return "\(downloadMbStr) megabytes down and \(uploadMbStr) megabytes up used this session"
    }

    private nonisolated static func simplifyMbDisplay(_ display: String) -> String {
        var result = display.replacingOccurrences(of: " MB", with: "")
        if result != "0.0", result.hasSuffix(".0") {
            result.removeLast(2)
        }
        return result
    }
}
