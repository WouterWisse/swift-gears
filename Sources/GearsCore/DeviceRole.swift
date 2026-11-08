/// The three devices SwiftGears connects to.
public enum DeviceRole: CaseIterable, Sendable {
    case trainer, leftShifter, rightShifter

    /// Recognises a device from its Bluetooth advertisement, or nil when it is none of ours.
    public init?(manufacturerData: [UInt8]?, name: String?) {
        // Zwift devices advertise company id 0x094A (little endian) followed by a device type.
        if let data = manufacturerData, data.count >= 3, data[0] == 0x4A, data[1] == 0x09 {
            switch data[2] {
            case 0x07: self = .rightShifter; return
            case 0x08: self = .leftShifter; return
            default: break
            }
        }
        guard name?.hasPrefix("KICKR") == true else { return nil }
        self = .trainer
    }
}
