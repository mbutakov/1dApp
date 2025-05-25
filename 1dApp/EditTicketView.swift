import SwiftUI

struct EditTicketView: View {
    let ticket: Ticket
    @ObservedObject var viewModel: TicketListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: String
    
    init(ticket: Ticket, viewModel: TicketListViewModel) {
        self.ticket = ticket
        self.viewModel = viewModel
        _selectedStatus = State(initialValue: ticket.status)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Информация о тикете") {
                    Text(ticket.title)
                        .font(.headline)
                    Text(ticket.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let category = ticket.category {
                        Text("Категория: \(category)")
                            .font(.subheadline)
                    }
                }
                
                Section("Статус") {
                    Picker("Статус", selection: $selectedStatus) {
                        Text("открыт").tag("открыт")
                        Text("ожидает ответа").tag("ожидает ответа")
                        Text("закрыт").tag("закрыт")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Редактирование тикета")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        viewModel.updateTicketStatus(ticketId: ticket.id, newStatus: selectedStatus)
                        dismiss()
                    }
                }
            }
        }
    }
} 