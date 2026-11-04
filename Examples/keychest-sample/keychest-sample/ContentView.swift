//
//  ContentView.swift
//  keychest-sample
//
//  Created by Coda on 04/11/26.
//

import SwiftUI
import KeychestKeys

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Text(Secrets.Debug().apiKey)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
