import SwiftUI
import OSLog

struct TicketListView: View {
    @StateObject private var viewModel = TicketListViewModel()
    @State private var searchText = ""
    @State private var selectedStatus: String?
    @State private var selectedTicket: Ticket?
    @State private var showEditTicket = false
    @State private var supportId: Int64 = 1
    
    private var uniqueStatuses: [String] {
        Array(Set(viewModel.tickets.map { $0.status })).sorted()
    }
    
    private var statusColors: [String: Color] = [
        "открыт": .green,
        "в работе": .orange,
        "закрыт": .red
    ]
    
    private var filteredTickets: [Ticket] {
        viewModel.tickets.filter { ticket in
            let matchesSearch = searchText.isEmpty || 
                ticket.title.localizedCaseInsensitiveContains(searchText) ||
                ticket.description.localizedCaseInsensitiveContains(searchText) ||
                ticket.user_full_name.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = selectedStatus == nil || ticket.status == selectedStatus
            
            return matchesSearch && matchesStatus
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Поиск и фильтры в одном контейнере
                VStack(spacing: 16) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Поиск по тикетам...", text: $searchText)
                            .foregroundColor(.primary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !searchText.isEmpty {
                            Button(action: { withAnimation { searchText = "" } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(12)
                    .background(.thinMaterial)
                    .cornerRadius(16)
                    
                    // Фильтры
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Button(action: { selectedStatus = nil }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Все")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedStatus == nil ? Color.accentColor : Color(.tertiarySystemFill))
                                .foregroundColor(selectedStatus == nil ? .white : .primary)
                                .cornerRadius(20)
                                .shadow(color: selectedStatus == nil ? Color.accentColor.opacity(0.3) : .clear, radius: 5, x: 0, y: 2)
                                .scaleEffect(selectedStatus == nil ? 1.05 : 1.0)
                            }
                            
                            ForEach(uniqueStatuses, id: \.self) { status in
                                Button(action: { selectedStatus = status }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: status == "открыт" ? "checkmark.circle.fill" :
                                                           status == "закрыт" ? "xmark.circle.fill" : "clock.fill")
                                            .font(.system(size: 16, weight: .medium))
                                        Text(status)
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(selectedStatus == status ? statusColors[status]?.opacity(0.9) : Color(.tertiarySystemFill))
                                    .foregroundColor(selectedStatus == status ? .white : statusColors[status])
                                    .cornerRadius(20)
                                    .shadow(color: selectedStatus == status ? (statusColors[status] ?? .clear).opacity(0.3) : .clear, radius: 5, x: 0, y: 2)
                                    .scaleEffect(selectedStatus == status ? 1.05 : 1.0)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Список тикетов
                List(filteredTickets, selection: $selectedTicket) { ticket in
                    NavigationLink(value: ticket) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(ticket.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        if ticket.id == viewModel.lastOpenedTicketId {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                        }
                                    }
                                    
                                    Text(ticket.description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(ticket.status)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(statusColors[ticket.status]?.opacity(0.15))
                                        .foregroundColor(statusColors[ticket.status])
                                        .cornerRadius(12)
                                    
                                    HStack(spacing: 6) {
                                        let shortName = ticket.user_full_name.split(separator: " ").prefix(2).map { 
                                            if $0 == ticket.user_full_name.split(separator: " ")[0] {
                                                return String($0)
                                            } else {
                                                return String($0.prefix(1)) + "."
                                            }
                                        }.joined(separator: " ")
                                        
                                        Text(shortName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            
                            HStack(spacing: 16) {
                                Label {
                                    Text(ticket.created_at.prefix(10))
                                        .font(.caption)
                                } icon: {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                                
                                if let category = ticket.category {
                                    Label {
                                        Text(category)
                                            .font(.caption)
                                    } icon: {
                                        Image(systemName: "folder")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(
                            ticket.id == viewModel.lastOpenedTicketId ?
                            Color.accentColor.opacity(0.05) :
                            Color.clear
                        )
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            selectedTicket = ticket
                            showEditTicket = true
                        } label: {
                            Label("Редактировать", systemImage: "slider.horizontal.3")
                        }
                        .tint(.indigo)
                    }
                    .listRowBackground(Color(.secondarySystemBackground).opacity(0.5))
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .navigationTitle("Тикеты")
                .refreshable { viewModel.loadTickets() }
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                    } else if let error = viewModel.error {
                        VStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            Text(error)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    } else if filteredTickets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "ticket")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Нет тикетов")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } detail: {
            if let ticket = selectedTicket {
                TicketMessagesView(ticket: ticket, supportId: supportId)
                    .onAppear {
                        viewModel.setLastOpenedTicket(ticket.id)
                    }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Выберите тикет для просмотра")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showEditTicket) {
            if let ticket = selectedTicket {
                EditTicketView(ticket: ticket, viewModel: viewModel)
            }
        }
    }
} 