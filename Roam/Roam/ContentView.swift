//
//  ContentView.swift
//  Roam
//
//  Created by Joshua Johnson on 2/27/25.
//
import SwiftUI
import GooglePlaces

struct ContentView: View {
    @State private var goToHomeView = true
    @State private var goToMemoryView = false
    @State private var goToAddView = false
    
    var body: some View {
        VStack {
            if goToHomeView {
                HomeView(goToAddView: $goToAddView, goToMemoryView: $goToMemoryView, goToHomeView: $goToHomeView)
            } else if goToAddView {
                AddView(goToAddView: $goToAddView, goToMemoryView: $goToMemoryView, goToHomeView: $goToHomeView)
            } else if goToMemoryView {
                MemoryView(goToAddView: $goToAddView, goToMemoryView: $goToMemoryView, goToHomeView: $goToHomeView)
            }
        }
    }
}
