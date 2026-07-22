// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
// MARK: - UUID v7 Extension

public extension UUID {
    init(date: Date, tag: UInt16? = nil) {
        self = .v7(date: date, tag: tag)
    }
}

extension UUID {

    public typealias uuid_t = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    /// Generates a new random UUID.
    ///
    /// - Parameter generator: The random number generator to use when creating the new random value.
    /// - Returns: A random UUID.
    public static func random(
        using generator: inout some RandomNumberGenerator
    ) -> UUID {
        let first = UInt64.random(in: .min ... .max, using: &generator)
        let second = UInt64.random(in: .min ... .max, using: &generator)
        
        var firstBits = first
        var secondBits = second
        
        // Set the version to 4 (0100 in binary)
        firstBits &= 0b11111111_11111111_11111111_11111111_11111111_11111111_00001111_11111111 // Clear bits 48 through 51
        firstBits |= 0b00000000_00000000_00000000_00000000_00000000_00000000_01000000_00000000 // Set the version bits to '0100' at the correct position
        
        // Set the variant to '10' (RFC9562 variant)
        secondBits &= 0b00111111_11111111_11111111_11111111_11111111_11111111_11111111_11111111 // Clear the 2 most significant bits
        secondBits |= 0b10000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000 // Set the two MSB to '10'
        
        let uuidBytes = (
            UInt8(truncatingIfNeeded: firstBits >> 56),
            UInt8(truncatingIfNeeded: firstBits >> 48),
            UInt8(truncatingIfNeeded: firstBits >> 40),
            UInt8(truncatingIfNeeded: firstBits >> 32),
            UInt8(truncatingIfNeeded: firstBits >> 24),
            UInt8(truncatingIfNeeded: firstBits >> 16),
            UInt8(truncatingIfNeeded: firstBits >> 8),
            UInt8(truncatingIfNeeded: firstBits),
            UInt8(truncatingIfNeeded: secondBits >> 56),
            UInt8(truncatingIfNeeded: secondBits >> 48),
            UInt8(truncatingIfNeeded: secondBits >> 40),
            UInt8(truncatingIfNeeded: secondBits >> 32),
            UInt8(truncatingIfNeeded: secondBits >> 24),
            UInt8(truncatingIfNeeded: secondBits >> 16),
            UInt8(truncatingIfNeeded: secondBits >> 8),
            UInt8(truncatingIfNeeded: secondBits)
        )
        
        return UUID(uuid: uuidBytes)
    }
    
    @available(*, deprecated, message: "Use UUID.v7(tag:) instead.")
    /// Generates a new UUID version 7 using the current timestamp in milliseconds.
    /// The first 48 bits encode the timestamp (in big-endian),
    /// while the remaining bits are derived from a random UUID.
    /// Bits 6 and 8 are patched to indicate version 7 and RFC 4122 variant.
    @_disfavoredOverload static func v7() -> UUID {
        v7(date: Date())
    }

    /// Generates a new UUID version 7 using the current timestamp in milliseconds.
    /// You can optionally embed a 16-bit tag into the 16 free bits following the version nibble.
    /// - Parameter tag: An optional 16-bit value to embed in the UUID's free bits. Defaults to `nil`.
    /// - Returns: A UUIDv7 value.
    @inlinable
    static func v7(tag: UInt16? = nil) -> UUID {
        return v7(date: Date(), tag: tag)
    }

    /// Generates a new UUID version 7 for a given date using the date's timestamp in milliseconds.
    /// You can optionally embed a 16-bit tag into the 16 free bits following the version nibble.
    /// - Parameters:
    ///   - date: The date whose timestamp (ms since 1970) will be embedded in the first 48 bits.
    ///   - tag: An optional 16-bit value to embed in the UUID's free bits.
    /// - Returns: A UUIDv7 value.
    @inlinable
    static func v7(date: Date, tag: UInt16? = nil) -> UUID {
        // Build a UUIDv7 per RFC 9562 directly, without using a pre-existing UUID as entropy.
        // Layout (big-endian):
        // - bytes 0..5: 48-bit timestamp (ms since Unix epoch)
        // - byte 6: high 4 bits = version (0x7), low 4 bits = high nibble of 12-bit rand_a
        // - byte 7: low 8 bits of 12-bit rand_a
        // - byte 8: high 2 bits = variant (10), low 6 bits = high 6 bits of 62-bit rand_b
        // - bytes 9..15: remaining 56 bits of rand_b
        // We additionally allow embedding a 16-bit `tag` into the 16 free bits after the version nibble.

        // 1) Timestamp (48-bit, big-endian)
        let ms: UInt64 = date.epochTime // milliseconds
        let ts48 = ms & 0x0000_FFFF_FFFF_FFFF // keep lower 48 bits

        // 2) Random parts
        var rng = SystemRandomNumberGenerator()
        // 12-bit rand_a
//        let randA: UInt16 = UInt16.random(in: 0..<(1 << 12), using: &rng)
        // 62-bit rand_b
        let randB: UInt64 = UInt64.random(in: 0..<(1 << 62), using: &rng)

        // Optional 16-bit tag to occupy the 16 free bits after version
        let tagValue: UInt16 = tag ?? 0

        // Prepare bytes buffer
        var bytes = [UInt8](repeating: 0, count: 16)

        // Write timestamp (big-endian) into bytes[0..5]
        bytes[0] = UInt8((ts48 >> 40) & 0xFF)
        bytes[1] = UInt8((ts48 >> 32) & 0xFF)
        bytes[2] = UInt8((ts48 >> 24) & 0xFF)
        bytes[3] = UInt8((ts48 >> 16) & 0xFF)
        bytes[4] = UInt8((ts48 >> 8) & 0xFF)
        bytes[5] = UInt8(ts48 & 0xFF)

        // Compose byte 6 and 7:
        // version in high nibble of byte 6 (0x7x), and embed the high 4 bits of the 16-bit tag in low nibble of byte 6.
        // byte 7 holds the low 8 bits of the tag.
        // If tag is nil, these bits will be zero.
        let tagHighNibble = UInt8((tagValue >> 12) & 0x0F)
        let tagLowByte = UInt8(tagValue & 0xFF)
        bytes[6] = (0x70 /* version 7 */) | tagHighNibble
        bytes[7] = tagLowByte

        // Variant (10) in the two MSBs of byte 8, remaining 6 bits are the top 6 bits of rand_b
        let randBTop6 = UInt8((randB >> 56) & 0x3F) // top 6 of 62-bit value align as if randB were 64-bit
        bytes[8] = 0x80 | randBTop6 // 0b10xxxxxx

        // Remaining 56 bits of rand_b into bytes[9..15]
        let remainder = randB & 0x00FF_FFFF_FFFF_FFFF
        bytes[9]  = UInt8((remainder >> 48) & 0xFF)
        bytes[10] = UInt8((remainder >> 40) & 0xFF)
        bytes[11] = UInt8((remainder >> 32) & 0xFF)
        bytes[12] = UInt8((remainder >> 24) & 0xFF)
        bytes[13] = UInt8((remainder >> 16) & 0xFF)
        bytes[14] = UInt8((remainder >> 8) & 0xFF)
        bytes[15] = UInt8(remainder & 0xFF)

        // Construct UUID from bytes tuple
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }

    /// Converts this UUID into a version 7 UUID using the provided timestamp.
    /// The original UUID provides entropy for the non-timestamp bits.
    /// Note: Direct v7 constructors are available that do not rely on an existing UUID.
    /// - Parameter date: The timestamp to embed in the UUID.
    /// - Returns: A UUIDv7 instance representing the given timestamp and the original entropy.
    func convertedToV7(using date: Date) -> UUID {
        /// The underlying 16-byte representation of this UUID instance.
        var data = self.data
        // Encode date timestamp (UInt64 in milliseconds since 1970)
        // Take only the lower 6 bytes and reverse to big-endian
        data[0..<6] = .init(date.epochTime.littleEndian.data.subdata(in: 0..<6).reversed())
        // Set version (UUIDv7 = 0x7) in byte 6 (upper 4 bits)
        data[6] = (data[6] & 0x0F) | 0x70
        // Set variant (RFC 4122) in byte 8 (upper 2 bits = 10)
        data[8] = (data[8] & 0x3F) | 0x80
        // returns the final uuid object
        return data.object()

    }
    /// The 16-byte `Data` representation of this UUID.
    public var data: Data { .init(self) }

    /// The 16-byte array of bytes representing this UUID.
    @usableFromInline
    var bytes: [UInt8] { .init(self) }

    /// Attempts to extract the `Date` encoded in a UUID v7 timestamp.
    /// Returns `nil` if the UUID is not version 7.
    @inlinable
    public var date: Date? {
        let data = self.data
        // Check if UUID is version 7
        guard (data[6] >> 4) == 0x7 else { return nil }
        // Convert first 6 bytes to UInt64 (pad with 2 leading zero bytes)
        let timestamp: UInt64 = .init(([0, 0] + data[0..<6]).reversed())
        // Convert milliseconds to seconds
        return .init(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }

    /// Returns the 16-bit tag embedded in a UUIDv7, if present.
    /// - Returns: The tag value if this UUID is version 7, otherwise `nil`.
    @inlinable
    public var v7Tag: UInt16? {
        let data = self.data
        // Ensure version 7
        guard (data[6] >> 4) == 0x7 else { return nil }
        // Tag occupies: low nibble of byte 6 (high 4 bits of tag) and all of byte 7 (low 8 bits)
        let highNibble = UInt16(data[6] & 0x0F)
        let lowByte = UInt16(data[7])
        return (highNibble << 12) | lowByte
    }

    /// Returns a copy of this UUID with the provided 16-bit tag set (only applicable to UUIDv7).
    /// If this UUID is not version 7, it is returned unchanged.
    /// - Parameter tag: The 16-bit tag to embed.
    /// - Returns: A new UUID with the tag updated if version 7; otherwise returns `self`.
    @inlinable
    public func settingV7Tag(_ tag: UInt16) -> UUID {
        var data = self.data
        // Ensure version 7
        guard (data[6] >> 4) == 0x7 else { return self }
        // Place the high 4 bits of the tag in the low nibble of byte 6, preserving the version nibble (0x7)
        let highNibble = UInt8((tag >> 12) & 0x0F)
        data[6] = (0x70) | highNibble
        // Place the low 8 bits into byte 7
        data[7] = UInt8(tag & 0x00FF)
        return data.object()
    }

    /// Returns a copy of this UUID with its UUIDv7 tag cleared to 0.
    /// If this UUID is not version 7, it is returned unchanged.
    @inlinable
    public func clearingV7Tag() -> UUID {
        settingV7Tag(0)
    }
}

// MARK: - Data Initialization Helpers

fileprivate extension DataProtocol where Self: RangeReplaceableCollection {

    /// Converts any value into its raw byte representation using its memory layout.
    /// Useful for initializing a collection of bytes (e.g., `Data`, `[UInt8]`, etc.) from any type.
    /// - Parameter object: The value to convert into a sequence of bytes.
    init<T>(_ object: T) {
        self = Swift.withUnsafeBytes(of: object, Self.init)
    }
}

public extension Numeric {

    /// Converts numeric value to Data
    var data: Data { .init(self) }

    /// Initializes numeric value from a Data buffer
    init<D: DataProtocol>(_ data: D) {
        var value: Self = .zero
        let _ = withUnsafeMutableBytes(of: &value, data.copyBytes)
        self = value
    }
}

extension ContiguousBytes {

    @usableFromInline
    /// Converts the contiguous bytes into a value of type `T`.
    /// Assumes `Self` has at least `MemoryLayout<T>.size` bytes.
    func object<T>() -> T {
        withUnsafeBytes { $0.load(as: T.self) }
    }
}

// MARK: - Date Extensions

extension Date {

    /// Current timestamp in milliseconds (as Double)
    static var nowEpochTimeMilliseconds: Double {
        Date().timeIntervalSince1970 * 1000
    }

    /// Current timestamp in milliseconds as UInt64
    static var nowEpochTime: UInt64 {
        .init(nowEpochTimeMilliseconds)
    }

    /// timestamp in milliseconds (as Double)
    var epochTimeMilliseconds: Double {
        timeIntervalSince1970 * 1000
    }

    @usableFromInline
    /// timestamp in milliseconds as UInt64
    var epochTime: UInt64 {
        .init(epochTimeMilliseconds)
    }
}
