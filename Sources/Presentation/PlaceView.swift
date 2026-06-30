//
//  PlaceView.swift
//  Ontology
//
//  Created by Jason Jobe on 4/24/25.
//

import SwiftUI
import MapKit
import OntologyApple

// TODO: Map Lookaround

public struct PlaceView: View {
    var place: Place
    var showUser: Bool
    
    public init(place: Place, showUser: Bool = true) {
        self.place = place
        self.showUser = showUser
    }
    
    public var body: some View {
        if let cord = place.clCoordinate {
            let name = place.name ?? "?"
            VStack {
                Map {
                    Marker(name, coordinate: cord)
                        .tint(.orange)
                    if showUser {
                        UserAnnotation()
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapZoomStepper()
                    MapScaleView()
                    MapCompass()
                }
            }
//            .mapScope(mapScope)
        } else {
            ContentUnavailableView("No coordinates", image: "mappin.and.ellipse.circle.fill")
        }
    }
}

extension Place {
    //     var placeID: String = "I63802885C8189B2B"

    static let oaklandMD: Place = Place(
        identifier: UUID().uuidString,
        name: "Oakland MD",
        geo: GeoCoordinates(
            latitude: 39.40982,
            longitude: -79.40598
        ))
    
    static let applePark: Place = Place(
        identifier: "2",
        name: "Apple Park",
        geo: GeoCoordinates(
            latitude: 37.3349,
            longitude: -122.0094
        ))
}

#Preview {
    PlaceView(place: .oaklandMD)
        .preferredColorScheme(.light)
        .padding()
}
