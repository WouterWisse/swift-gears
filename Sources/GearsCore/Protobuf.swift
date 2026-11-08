/// The small part of protobuf that Zwift's messages use: varint and length-delimited fields.
enum Protobuf {
    struct Field {
        let number: Int
        /// The value of a varint field.
        let value: UInt64
        /// The bytes of a length-delimited field.
        let bytes: ArraySlice<UInt8>
    }

    /// Nil when the bytes are not a well-formed message. They come from a radio, so never trust them.
    static func parse(_ bytes: ArraySlice<UInt8>) -> [Field]? {
        var index = bytes.startIndex
        var fields: [Field] = []
        while index < bytes.endIndex {
            guard let (key, next) = readVarint(bytes, at: index) else { return nil }
            index = next
            switch key & 7 {
            case 0:
                guard let (value, next) = readVarint(bytes, at: index) else { return nil }
                fields.append(Field(number: Int(key >> 3), value: value, bytes: []))
                index = next
            case 2:
                guard let (length, start) = readVarint(bytes, at: index), length <= UInt64(bytes.endIndex - start) else { return nil }
                let end = start + Int(length)
                fields.append(Field(number: Int(key >> 3), value: 0, bytes: bytes[start..<end]))
                index = end
            default:
                return nil
            }
        }
        return fields
    }

    static func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes: [UInt8] = []
        repeat {
            bytes.append(UInt8(value & 0x7F) | (value > 0x7F ? 0x80 : 0))
            value >>= 7
        } while value != 0
        return bytes
    }

    static func field(_ number: Int, varint value: UInt64) -> [UInt8] {
        [UInt8(number << 3)] + varint(value)
    }

    static func field(_ number: Int, message: [UInt8]) -> [UInt8] {
        [UInt8(number << 3 | 2)] + varint(UInt64(message.count)) + message
    }

    /// Decodes a zigzag-encoded sint32/sint64.
    static func signed(_ value: UInt64) -> Int64 {
        Int64(bitPattern: value >> 1) ^ -Int64(bitPattern: value & 1)
    }

    private static func readVarint(_ bytes: ArraySlice<UInt8>, at start: Int) -> (UInt64, Int)? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var index = start
        while index < bytes.endIndex, shift < 64 {
            let byte = bytes[index]
            value |= UInt64(byte & 0x7F) << shift
            index += 1
            if byte & 0x80 == 0 { return (value, index) }
            shift += 7
        }
        return nil
    }
}

extension [Protobuf.Field] {
    /// The value of the first varint field with this number.
    func value(_ number: Int) -> UInt64? {
        first { $0.number == number }?.value
    }
}
