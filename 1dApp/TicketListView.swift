import SwiftUI
import OSLog

struct TicketListView: View {
    @StateObject private var viewModel = TicketListViewModel()
    @State private var searchText = ""
    @State private var selectedStatus: String?
    @State private var selectedTicket: Ticket?
    @State private var showEditTicket = false
    @State private var supportId: Int64 = 1
    @State private var showFilters = false
    
    private var uniqueStatuses: [String] {
        Array(Set(viewModel.tickets.map { $0.status })).sorted()
    }
    
    private var statusColors: [String: Color] = [
        "Создан": .blue,
        "Назначен": .purple,
        "В работе": .orange,
        "Ожидает ответа пользователя": .yellow,
        "Ожидает действий поддержки": .red,
        "Закрыт": .gray,
        "Отменён": .secondary
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
                VStack(spacing: 12) {
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
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // Фильтры
                    VStack(spacing: 8) {
                        HStack {
                            Button(action: { selectedStatus = nil }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                    Text("Все")
                                }
                                .font(.system(.subheadline, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedStatus == nil ? Color.accentColor : Color(.tertiarySystemFill))
                                .foregroundColor(selectedStatus == nil ? .white : .primary)
                                .cornerRadius(8)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(uniqueStatuses, id: \.self) { status in
                                        Button(action: { selectedStatus = status }) {
                                            Text(Ticket(id: 0, user_id: 0, title: "", description: "", status: status, category: nil, created_at: "", closed_at: nil, user_full_name: "").statusDisplayName)
                                                .font(.system(.subheadline, design: .rounded))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedStatus == status ? statusColors[status, default: .gray] : Color(.tertiarySystemFill))
                                                .foregroundColor(selectedStatus == status ? .white : statusColors[status, default: .gray])
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showFilters.toggle()
                                }
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(showFilters ? .blue : .secondary)
                                    .padding(8)
                                    .background(showFilters ? Color.blue.opacity(0.1) : Color(.tertiarySystemFill))
                                    .clipShape(Circle())
                            }
                        }
                        
                        if showFilters {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Статистика по статусам")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                ForEach(uniqueStatuses, id: \.self) { status in
                                    let count = viewModel.tickets.filter { $0.status == status }.count
                                    HStack {
                                        Circle()
                                            .fill(statusColors[status, default: .gray])
                                            .frame(width: 12, height: 12)
                                        
                                        Text(status.capitalized)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text("\(count)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Список тикетов
                List(filteredTickets, selection: $selectedTicket) { ticket in
                    NavigationLink(value: ticket) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ticket.title)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.medium)
                                    
                                    Text(ticket.description)
                                        .font(.system(.subheadline))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Text(ticket.statusDisplayName)
                                    .font(.system(.caption, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColors[ticket.status]?.opacity(0.15))
                                    .foregroundColor(statusColors[ticket.status])
                                    .cornerRadius(6)
                            }
                            
                            HStack(spacing: 12) {
                                Label {
                                    Text(ticket.created_at.prefix(10))
                                        .font(.caption2)
                                } icon: {
                                    Image(systemName: "calendar")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                                
                                Label {
                                    Text(ticket.user_full_name)
                                        .font(.caption2)
                                } icon: {
                                    Image(systemName: "person")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            selectedTicket = ticket
                            showEditTicket = true
                        } label: {
                            Label("Изменить", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color(.systemBackground))
                }
                .listStyle(.plain)
                .refreshable { viewModel.loadTickets() }
            }
            .navigationTitle("Тикеты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
            }
        } detail: {
            if let ticket = selectedTicket {
                TicketMessagesView(ticket: ticket, supportId: supportId)
                    .onAppear {
                        viewModel.setLastOpenedTicket(ticket.id)
                    }
            } else {
                ContentUnavailableView("Выберите тикет", systemImage: "ticket")
            }
        }
        .sheet(isPresented: $showEditTicket) {
            if let ticket = selectedTicket {
                EditTicketView(ticket: ticket, viewModel: viewModel)
            }
        }
    }
} 