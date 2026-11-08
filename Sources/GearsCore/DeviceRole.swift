/// The two devices SwiftGears connects to.
public enum DeviceRole: CaseIterable, Sendable {
    case trainer, ride

    /// Recognises a device from its Bluetooth advertisement, or nil when it is none of ours.
    public init?(manufacturerData: [UInt8]?, name: String?) {
        // Zwift devices advertise company id 0x094A (little endian) followed by a device type.
        // The Ride advertises both halves (0x08 left, 0x07 right), but the left one reports the
        // buttons of both, so connecting to the right one too would count every shift twice.
        if let data = manufacturerData, data.count >= 3, data[0] == 0x4A, data[1] == 0x09 {
            guard data[2] == 0x08 else { return nil }
            self = .ride
            return
        }
        guard name?.hasPrefix("KICKR") == true else { return nil }
        self = .trainer
    }
}
