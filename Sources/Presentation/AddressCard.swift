//
//  SwiftUIView.swift
//  Ontology
//
//  Created by Jason Jobe on 4/25/25.
//

import SwiftUI

struct AddressCard: View {
    let model: PostalAddress
    
    var body: some View {
        Text("Hello, World!")
    }
}

#if canImport(Contacts)
import Contacts
// Localized AttributedString
#endif

struct PlaceCard: View {
    let model: Place
    
    var body: some View {
        Text("Hello, World!")
    }
}

#Preview {
    AddressCard()
}
