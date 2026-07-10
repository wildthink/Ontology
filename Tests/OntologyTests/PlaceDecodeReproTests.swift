import Foundation
import Testing

@testable import Ontology
import OntologyOKF

/// Regression: a `Place` with a nested `address`/`geo` and an *unquoted numeric*
/// `postalCode` (the natural way a human or tool writes one) must decode fully.
/// Previously the bare `94016` parsed as a number and failed the strict `String`
/// decode of `postalCode`, collapsing the whole `Place` decode — which made
/// Surfboard render the "Can't display Place" fallback instead of the card.
@Suite
struct PlaceDecodeReproTests {

    // Mirrors the on-disk demo Place item exactly.
    let markdown = """
    ---
    type: Place
    title: The Rusty Flagon
    description: A centuries-old inn and tavern at the heart of Evermore.
    icon: mappin.and.ellipse
    color: orange
    address:
      streetAddress: 42 Market Street
      addressLocality: Evermore
      addressRegion: CA
      postalCode: 94016
      addressCountry: USA
    geo:
      latitude: 37.7793
      longitude: -122.4193
    telephone: +1 555-0142
    resource: https://rustyflagon.example
    ---
    The Rusty Flagon has poured ale for travelers since the founding of Evermore.
    """

    @Test("OKFReader.decode of a Place with an unquoted numeric postalCode keeps all fields")
    func directReader() throws {
        let place = try OKFReader.decode(Place.self, from: markdown)
        #expect(place.name == "The Rusty Flagon")
        #expect(place.address?.streetAddress == "42 Market Street")
        #expect(place.address?.postalCode == "94016")
        #expect(place.geo?.latitude == 37.7793)
        #expect(place.telephone == "+1 555-0142")
    }

    @Test("Surfboard path: OKFConcept parse → decode keeps all Place fields")
    func conceptPath() throws {
        let concept = try #require(OKFConcept(id: "items/x.md", markdown: markdown))
        let place = try concept.decode(Place.self)
        #expect(place.name == "The Rusty Flagon")
        #expect(place.address?.streetAddress == "42 Market Street")
        #expect(place.address?.postalCode == "94016")
        #expect(place.geo?.latitude == 37.7793)
        #expect(place.telephone == "+1 555-0142")
    }
}
