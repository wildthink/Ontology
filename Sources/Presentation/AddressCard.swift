//
//  SwiftUIView.swift
//  Ontology
//
//  Created by Jason Jobe on 4/25/25.
//

import SwiftUI
import Ontology

struct AddressCard: View {
    let model: PostalAddress

    var body: some View {
        Text("Hello, World!")
    }
}

struct PlaceCard: View {
    let model: Place

    var body: some View {
        Text("Hello, World!")
    }
}

#Preview {
    AddressCard(model: PostalAddress())
}
