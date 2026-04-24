//
//  Word64.swift
//  Ontology
//
//  Created by Jason Jobe on 4/23/26.
//


//
//  CompactWord64.swift
//  GameWorld
//
//  Created by Jason Jobe on 4/20/26.
//


import Foundation

public struct Word64: Hashable, Sendable {
    public let rawValue: Int64
    
    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }
}
public typealias Char10 = Word64

extension Word64: Codable {
    public init(from decoder: any Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        self = .init(stringLiteral: s)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var svc = encoder.singleValueContainer()
        try svc.encode(self.description)
    }
}

extension Word64: CustomStringConvertible {
    public var description: String {
        CompactWord64.decode(rawValue) ?? ""
    }
}

extension Word64: ExpressibleByStringLiteral {
    
    public typealias StringLiteralType = String
        
    public init(stringLiteral value: String) {
        self.rawValue = (try? CompactWord64.encode(value)) ?? 0
    }
}

public enum CompactWord64Error: Error, Equatable, Sendable {
    case tooLong(maxLength: Int)
    case unsupportedCharacter(Character)
}

public enum CompactWord64 {
    // Backward-compatible Int64 capacity.
    public static var maxCompactWordLength: Int {
        maxCompactWordLength(for: Int64.self)
    }

    public static var maxLength: Int {
        maxCompactWordLength
    }

    // 64 symbols for 6-bit packing.
    // a-z, A-Z, 0-9, -, _
    private static let alphabetBytes = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_".utf8)
    private static let lookup: [UInt8: UInt64] = {
        Dictionary(uniqueKeysWithValues: alphabetBytes.enumerated().map { (index, value) in
            (value, UInt64(index))
        })
    }()

    public static func maxCompactWordLength<T: FixedWidthInteger>(for type: T.Type) -> Int {
        layout(forBitWidth: T.bitWidth).maxSymbols
    }

    // Backward-compatible Int64 API.
    public static func encode(
        _ word: String,
        truncatingToFit: Bool = false
    ) throws -> Int64 {
        try encode(word, as: Int64.self, truncatingToFit: truncatingToFit)
    }

    public static func encode<T: FixedWidthInteger>(
        _ word: String,
        as type: T.Type = T.self,
        truncatingToFit: Bool = false
    ) throws -> T {
        var bytes = Array(word.utf8)
        let layout = layout(forBitWidth: T.bitWidth)
        if bytes.count > layout.maxSymbols, truncatingToFit {
            bytes = Array(bytes.prefix(layout.maxSymbols))
        }

        // Validate characters first so callers get deterministic character-level errors.
        for byte in bytes {
            guard lookup[byte] != nil else {
                throw CompactWord64Error.unsupportedCharacter(Character(UnicodeScalar(byte)))
            }
        }

        guard bytes.count <= layout.maxSymbols else {
            throw CompactWord64Error.tooLong(maxLength: layout.maxSymbols)
        }

        var payload: UInt64 = 0
        for (offset, byte) in bytes.enumerated() {
            let code = lookup[byte]!
            payload |= (code << (offset * 6))
        }

        let packed = (UInt64(bytes.count) << layout.payloadBits) | payload
        return fromUInt64BitPattern(packed, as: T.self)
    }

    // Backward-compatible Int64 API.
    public static func decode(_ packed: Int64) -> String? {
        decodeRaw(toUInt64BitPattern(packed, bitWidth: Int64.bitWidth), bitWidth: Int64.bitWidth)
    }

    public static func decode<T: FixedWidthInteger>(_ packed: T) -> String? {
        decodeRaw(toUInt64BitPattern(packed, bitWidth: T.bitWidth), bitWidth: T.bitWidth)
    }

    private struct Layout {
        var maxSymbols: Int
        var lengthBits: Int
        var payloadBits: Int
    }

    private static func layout(forBitWidth bitWidth: Int) -> Layout {
        precondition(bitWidth > 0 && bitWidth <= 64, "CompactWord64 supports integer widths up to 64 bits.")

        for symbols in stride(from: bitWidth / 6, through: 0, by: -1) {
            let payloadBits = symbols * 6
            let lengthBits = bitWidth - payloadBits
            if lengthBits >= bitsRequired(toRepresent: symbols) {
                return Layout(maxSymbols: symbols, lengthBits: lengthBits, payloadBits: payloadBits)
            }
        }

        return Layout(maxSymbols: 0, lengthBits: bitWidth, payloadBits: 0)
    }

    private static func bitsRequired(toRepresent maxValue: Int) -> Int {
        if maxValue <= 1 { return 1 }
        return Int.bitWidth - (maxValue.leadingZeroBitCount)
    }

    private static func decodeRaw(_ raw: UInt64, bitWidth: Int) -> String? {
        let layout = layout(forBitWidth: bitWidth)
        let count = Int(raw >> layout.payloadBits)
        guard count <= layout.maxSymbols else { return nil }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(count)

        for offset in 0..<count {
            let code = Int((raw >> (offset * 6)) & 0x3F)
            guard code < alphabetBytes.count else { return nil }
            bytes.append(alphabetBytes[code])
        }

        return String(decoding: bytes, as: UTF8.self)
    }

    private static func toUInt64BitPattern<T: FixedWidthInteger>(_ value: T, bitWidth: Int) -> UInt64 {
        let full = if T.isSigned {
            UInt64(bitPattern: Int64(truncatingIfNeeded: value))
        } else {
            UInt64(truncatingIfNeeded: value)
        }
        guard bitWidth < 64 else { return full }
        let mask = (UInt64(1) << bitWidth) - 1
        return full & mask
    }

    private static func fromUInt64BitPattern<T: FixedWidthInteger>(_ value: UInt64, as type: T.Type) -> T {
        if T.isSigned {
            return T(truncatingIfNeeded: Int64(bitPattern: value))
        } else {
            return T(truncatingIfNeeded: value)
        }
    }
}
