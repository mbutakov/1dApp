//
//  ContentView.swift
//  1dApp
//
//  Created by user on 25.05.2025.
//

import SwiftUI
import SwiftData
import OSLog

struct ContentView: View {
    var body: some View {
        TabView {
            TicketListView()
                .tabItem {
                    Label("Тикеты", systemImage: "ticket")
                }
            
            UsersView()
                .tabItem {
                    Label("Пользователи", systemImage: "person.2")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
