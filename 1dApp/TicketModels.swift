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
}

struct TicketMessage: Identifiable, Codable {
    let id: Int
    let ticket_id: Int
    let sender_type: String // "user" или "support"
    let sender_id: Int64
    let message: String
    let created_at: String
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