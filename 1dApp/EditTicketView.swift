import SwiftUI

struct EditTicketView: View {
    let ticket: Ticket
    @ObservedObject var viewModel: TicketListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: String
    
    private let statuses = [
        ("Создан", "🆕 Создан", "Тикет отправлен, ожидает назначения"),
        ("Назначен", "👨‍💻 Назначен", "Назначен конкретному агенту"),
        ("В работе", "🔧 В работе", "Агент работает над тикетом"),
        ("Ожидает ответа пользователя", "❓ Ожидает ответа", "Ждём ответа от пользователя"),
        ("Ожидает действий поддержки", "⏳ Ожидает поддержку", "Ждём действий от поддержки"),
        ("Закрыт", "🗃 Закрыт", "Тикет закрыт"),
        ("Отменён", "🚫 Отменён", "Ошибочный тикет или дубль")
    ]
    
    init(ticket: Ticket, viewModel: TicketListViewModel) {
        self.ticket = ticket
        self.viewModel = viewModel
        _selectedStatus = State(initialValue: ticket.status)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Информация о тикете") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ticket.title)
                            .font(.headline)
                        Text(ticket.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let category = ticket.category {
                            Label(category, systemImage: "folder")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Статус") {
                    ForEach(statuses, id: \.0) { status, title, description in
                        HStack {
                            Button(action: { selectedStatus = status }) {
                                HStack {
                                    Text(title)
                                        .font(.system(.body, design: .rounded))
                                    Spacer()
                                    if selectedStatus == status {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .foregroundColor(selectedStatus == status ? .primary : .secondary)
                        }
                        if selectedStatus == status {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .navigationTitle("Изменение статуса")
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
                    .fontWeight(.medium)
                }
            }
        }
    }
} 