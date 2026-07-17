import Ontology
import Testing

@Suite("Word64")
struct Word64Tests {
    @Test("Every alphabet symbol maps to its direct six-bit index")
    func alphabetIndices() throws {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"

        for (index, character) in alphabet.enumerated() {
            let encoded = try CompactWord64.encode(String(character))

            #expect(UInt64(bitPattern: encoded) & 0x3F == UInt64(index))
            #expect(CompactWord64.decode(encoded) == String(character))
        }
    }

    @Test("Unsupported character still reports character")
    func unsupportedCharacter() {
        #expect(throws: CompactWord64Error.unsupportedCharacter("!")) {
            try CompactWord64.encode("abc!")
        }
    }

    @Test("64-bit layout leaves length tags 11 through 15 unused")
    func unusedLengthTags() {
        for tag in UInt64(11)...15 {
            let rawValue = Int64(bitPattern: tag << 60)
            #expect(CompactWord64.decode(rawValue) == nil)
        }
    }
}
