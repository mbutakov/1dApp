import Foundation

struct Ticket: Identifiable, Codable, Hashable {
    let id: Int
    let user_id: Int64
    let title: String
    let description: String
    let status: String
    let category: String?
    let created_at: String
    let closed_at: String?
    let user_full_name: String
    
    // Вспомогательные свойства для отображения статуса
    var statusIcon: String {
        switch status {
        case "создан": return "🆕"
        case "назначен": return "👨‍💻"
        case "в работе": return "🔧"
        case "ожидает ответа пользователя": return "❓"
        case "ожидает действий поддержки": return "⏳"
        case "закрыт": return "🗃"
        case "отменён": return "🚫"
        default: return ""
        }
    }
    
    var statusColor: String {
        switch status {
        case "создан": return "blue"
        case "назначен": return "purple"
        case "в работе": return "orange"
        case "ожидает ответа пользователя": return "yellow"
        case "ожидает действий поддержки": return "red"
        case "закрыт": return "gray"
        case "отменён": return "secondary"
        default: return "gray"
        }
    }
    
    var statusDisplayName: String {
        return "\(statusIcon) \(status.capitalized)"
    }
}

struct TicketMessage: Identifiable, Codable, Equatable {
    let id: Int
    let ticket_id: Int
    let sender_type: String // "user" или "support"
    let sender_id: Int64
    let message: String
    let created_at: String
    
    static func == (lhs: TicketMessage, rhs: TicketMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.ticket_id == rhs.ticket_id &&
        lhs.sender_type == rhs.sender_type &&
        lhs.sender_id == rhs.sender_id &&
        lhs.message == rhs.message &&
        lhs.created_at == rhs.created_at
    }
}

struct TicketPhoto: Identifiable, Codable {
    let id: Int
    let ticket_id: Int
    let sender_type: String
    let sender_id: Int64
    let file_path: String
    let file_id: String
    let message_id: Int?
    let created_at: String
}

struct User: Identifiable, Codable {
    let id: Int64
    let full_name: String?
    let phone: String?
    let location_lat: Double?
    let location_lng: Double?
    let birth_date: String?
    let is_registered: Bool
    let registered_at: String?
} 