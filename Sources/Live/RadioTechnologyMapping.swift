import CoreTelephony

public enum RadioTechnologyMapping {
    public nonisolated static func generation(fromRadioAccessTechnology rat: String?) -> RadioGeneration {
        guard let rat else { return .unknown }

        switch rat {
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
            return .fiveG
        case CTRadioAccessTechnologyLTE:
            return .lte
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            return .threeG
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge,
             CTRadioAccessTechnologyCDMA1x:
            return .twoG
        default:
            return .unknown
        }
    }
}
