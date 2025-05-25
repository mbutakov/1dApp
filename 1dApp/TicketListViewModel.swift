
import Foundation
import Combine
import OSLog

class TicketListViewModel: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastOpenedTicketId: Int?
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "TicketList")
    private let defaults = UserDefaults.standard
    private let lastTicketKey = "lastOpenedTicketId"
    
    init() {
        logger.info("TicketListViewModel initialized")
        lastOpenedTicketId = defaults.object(forKey: lastTicketKey) as? Int
        loadTickets()
    }
    
    func loadTickets() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        logger.info("Starting to load tickets")
        
        TicketAPI.shared.fetchTickets { [weak self] result in
            guard let self = self else {
                print("Self is nil in loadTickets completion")
                return
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let tickets):
                    // Сортируем тикеты так, чтобы последний открытый был первым
                    self.tickets = self.sortTickets(tickets)
                    self.error = nil
                    self.logger.info("Successfully loaded \(tickets.count) tickets")
                case .failure(let err):
                    self.error = err.localizedDescription
                    self.logger.error("Failed to load tickets: \(err.localizedDescription)")
                }
            }
        }
    }
    
    func setLastOpenedTicket(_ ticketId: Int) {
        lastOpenedTicketId = ticketId
        defaults.set(ticketId, forKey: lastTicketKey)
        
        // Пересортировываем текущий список
        tickets = sortTickets(tickets)
    }
    
    private func sortTickets(_ tickets: [Ticket]) -> [Ticket] {
        guard let lastId = lastOpenedTicketId else { return tickets }
        
        return tickets.sorted { ticket1, ticket2 in
            if ticket1.id == lastId { return true }
            if ticket2.id == lastId { return false }
            return ticket1.created_at > ticket2.created_at
        }
    }
    
    func updateTicketStatus(ticketId: Int, newStatus: String) {
        logger.info("Updating ticket \(ticketId) status to \(newStatus)")
        
        // Обновляем статус локально
        if let index = tickets.firstIndex(where: { $0.id == ticketId }) {
            // Создаем новый тикет с обновленным статусом
            var updatedTicket = tickets[index]
            // Используем KeyPath для создания нового экземпляра с измененным полем
            let mirror = Mirror(reflecting: updatedTicket)
            let properties = mirror.children.reduce(into: [String: Any]()) { dict, child in
                if let label = child.label {
                    dict[label] = child.value
                }
            }
            var mutableProperties = properties
            mutableProperties["status"] = newStatus
            
            if let encodedData = try? JSONSerialization.data(withJSONObject: mutableProperties),
               let decodedTicket = try? JSONDecoder().decode(Ticket.self, from: encodedData) {
                tickets[index] = decodedTicket
            }
        }
        
        // Отправляем запрос на сервер для обновления статуса
        Task { @MainActor in
            do {
                try await TicketAPI.shared.updateTicketStatus(ticketId: ticketId, newStatus: newStatus)
                logger.info("Successfully updated ticket status")
                // Обновляем список тикетов после успешного обновления
                loadTickets()
            } catch {
                logger.error("Failed to update ticket status: \(error.localizedDescription)")
                self.error = "Ошибка при обновлении статуса"
            }
        }
    }
} 
