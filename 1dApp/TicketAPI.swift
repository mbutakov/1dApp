import Foundation
import OSLog
import UIKit
import CommonCrypto

struct TicketsResponse: Codable {
    let tickets: [Ticket]
    let limit: Int
    let page: Int
    let total: Int
}

struct TicketMessagesResponse: Codable {
    let messages: [TicketMessage]
}

struct MessageResponse: Codable {
    let message: TicketMessage
}

// Новая структура для ответа при отправке сообщения
struct SendMessageResponse: Codable {
    let message: String
    let message_id: Int
}

struct TicketPhotosResponse: Codable {
    let photos: [TicketPhoto]
}

// Обновленная структура для полного ответа тикета
struct TicketFullResponse: Codable {
    let messages: [TicketMessage]
    let photos: [TicketPhoto]?
    let ticket: Ticket
}

struct UsersResponse: Codable {
    let users: [User]
    let total: Int
}

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "ImageCache")
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    enum CacheCategory: String, CaseIterable {
        case images = "Images"
    }
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB
        
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")
        
        // Создаем директорию для кэша
        let imagesPath = cacheDirectory.appendingPathComponent(CacheCategory.images.rawValue)
        try? fileManager.createDirectory(at: imagesPath, withIntermediateDirectories: true)
        
        logger.debug("Cache directory: \(self.cacheDirectory.path)")
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
        
        let imagesPath = cacheDirectory.appendingPathComponent(CacheCategory.images.rawValue)
        let fileURL = imagesPath.appendingPathComponent(key.md5)
        
        try? image.jpegData(compressionQuality: 0.8)?.write(to: fileURL)
        
        logger.debug("Cached image for key: \(key)")
    }
    
    func get(forKey key: String) -> UIImage? {
        if let image = cache.object(forKey: key as NSString) {
            logger.debug("Retrieved cached image from memory for key: \(key)")
            return image
        }
        
        let imagesPath = cacheDirectory.appendingPathComponent(CacheCategory.images.rawValue)
        let fileURL = imagesPath.appendingPathComponent(key.md5)
        
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: key as NSString)
            logger.debug("Retrieved cached image from disk for key: \(key)")
            return image
        }
        
        return nil
    }
    
    func calculateSize() async throws -> [CacheCategory: Int] {
        var sizes: [CacheCategory: Int] = [:]
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        
        let imagesPath = cacheDirectory.appendingPathComponent(CacheCategory.images.rawValue)
        var totalSize = 0
        
        if let enumerator = fileManager.enumerator(at: imagesPath,
                                                  includingPropertiesForKeys: Array(resourceKeys),
                                                  options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                totalSize += resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0
            }
        }
        
        sizes[.images] = totalSize
        return sizes
    }
    
    func clearCache(category: CacheCategory? = nil) async throws {
        // Очищаем память
        cache.removeAllObjects()
        
        // Очищаем диск
        let imagesPath = cacheDirectory.appendingPathComponent(CacheCategory.images.rawValue)
        let contents = try fileManager.contentsOfDirectory(at: imagesPath, includingPropertiesForKeys: nil)
        for file in contents {
            try fileManager.removeItem(at: file)
        }
        logger.info("Cache cleared successfully")
    }
    
    // Метод для миграции существующего кэша в новую структуру
    func migrateExistingCache() async throws {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        let imagesPath = cacheDirectory.appendingPathComponent(CacheCategory.images.rawValue)
        
        for file in contents {
            if file.lastPathComponent != ".DS_Store" && 
               file.lastPathComponent != CacheCategory.images.rawValue {
                let newPath = imagesPath.appendingPathComponent(file.lastPathComponent)
                try fileManager.moveItem(at: file, to: newPath)
            }
        }
        logger.info("Cache migration completed")
    }
}

extension String {
    var md5: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        
        if let d = self.data(using: .utf8) {
            _ = d.withUnsafeBytes { body -> String in
                CC_MD5(body.baseAddress, CC_LONG(d.count), &digest)
                return ""
            }
        }
        
        return digest.reduce("") { $0 + String(format: "%02x", $1) }
    }
}

class TicketAPI {
    static let shared = TicketAPI()
    private let baseURL = URL(string: "https://mb0.tech/api")!
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "API")
    
    private init() {
        logger.info("TicketAPI initialized with base URL: \(self.baseURL.absoluteString)")
    }
    
    func fetchTickets(completion: @escaping (Result<[Ticket], Error>) -> Void) {
        let url = self.baseURL.appendingPathComponent("tickets/")
        
        logger.debug("Fetching tickets from \(url.absoluteString)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Network error fetching tickets: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("Invalid response type")
                completion(.failure(NSError(domain: "Invalid response", code: 0)))
                return
            }
            
            self.logger.debug("Received response with status code: \(httpResponse.statusCode)")
            
            guard let data = data else {
                self.logger.error("No data received")
                completion(.failure(NSError(domain: "No data", code: 0)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(TicketsResponse.self, from: data)
                self.logger.info("Successfully decoded \(response.tickets.count) tickets")
                completion(.success(response.tickets))
            } catch {
                self.logger.error("Failed to decode tickets: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchMessages(ticketId: Int, completion: @escaping (Result<[TicketMessage], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("tickets/\(ticketId)/messages")
        
        logger.debug("Fetching messages for ticket \(ticketId)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Network error fetching messages: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                self.logger.error("No data received for messages")
                completion(.failure(NSError(domain: "No data", code: 0)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(TicketMessagesResponse.self, from: data)
                self.logger.info("Successfully decoded \(response.messages.count) messages")
                completion(.success(response.messages))
            } catch {
                self.logger.error("Failed to decode messages: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func sendMessage(ticketId: Int, senderType: String, senderId: Int64, message: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("tickets/\(ticketId)/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "sender_type": senderType,
            "sender_id": senderId,
            "message": message
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to serialize message body: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        logger.debug("Sending message to ticket \(ticketId): \(message)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Network error sending message: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("Invalid response type")
                completion(.failure(NSError(domain: "Invalid response", code: 0)))
                return
            }
            
            self.logger.debug("Received response with status code: \(httpResponse.statusCode)")
            
            guard let data = data else {
                self.logger.error("No data received in response")
                completion(.failure(NSError(domain: "No data", code: 0)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(SendMessageResponse.self, from: data)
                self.logger.info("Message sent successfully with ID: \(response.message_id)")
                completion(.success(response.message_id))
            } catch {
                self.logger.error("Failed to decode send message response: \(error.localizedDescription)")
                self.logger.error("Response data: \(String(data: data, encoding: .utf8) ?? "unable to convert to string")")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func updateTicketStatus(ticketId: Int, newStatus: String) async throws {
        let url = baseURL.appendingPathComponent("tickets/\(ticketId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["status": newStatus]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        logger.debug("Updating ticket \(ticketId) status to \(newStatus)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw NSError(domain: "Invalid response", code: 0)
        }
        
        logger.debug("Received response with status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            logger.error("Server returned error: \(httpResponse.statusCode)")
            throw NSError(domain: "Server error", code: httpResponse.statusCode)
        }
        
        // Пытаемся декодировать обновленный тикет
        do {
            let updatedTicket = try JSONDecoder().decode(Ticket.self, from: data)
            logger.info("Successfully updated ticket status to: \(updatedTicket.status)")
        } catch {
            logger.error("Failed to decode updated ticket: \(error.localizedDescription)")
            // Не выбрасываем ошибку, так как основная операция успешна
        }
    }
    
    func uploadPhoto(ticketId: Int, image: UIImage, senderType: String, senderId: Int64, messageId: Int?) async throws -> Int {
        let url = URL(string: "https://mb0.tech/api/tickets/\(ticketId)/photos")!
        logger.info("Uploading photo to URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Добавляем обязательные поля
        var parameters = [
            "ticket_id": String(ticketId),
            "sender_type": senderType,
            "sender_id": String(senderId)
        ]
        
        // Добавляем опциональное поле message_id, если оно есть
        if let messageId = messageId {
            parameters["message_id"] = String(messageId)
        }
        
        // Добавляем все параметры в multipart form
        for (key, value) in parameters {
            data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)".data(using: .utf8)!)
        }
        
        // Добавляем само фото
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            logger.debug("Image size: \(imageData.count / 1024)KB")
            data.append(imageData)
        } else {
            logger.error("Failed to convert image to data")
            throw NSError(domain: "Image conversion failed", code: 0)
        }
        
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw NSError(domain: "Invalid response", code: 0)
        }
        
        logger.debug("Received response with status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            logger.error("Server returned error: \(httpResponse.statusCode)")
            if let responseString = String(data: responseData, encoding: .utf8) {
                logger.error("Response body: \(responseString)")
            }
            throw NSError(domain: "Server error", code: httpResponse.statusCode)
        }
        
        do {
            let response = try JSONDecoder().decode(TicketPhoto.self, from: responseData)
            logger.info("Successfully uploaded photo with ID: \(response.id)")
            return response.id
        } catch {
            logger.error("Failed to decode photo upload response: \(error.localizedDescription)")
            if let responseString = String(data: responseData, encoding: .utf8) {
                logger.error("Response body: \(responseString)")
            }
            throw error
        }
    }
    
    func fetchPhotos(ticketId: Int, messageId: Int) async throws -> [TicketPhoto] {
        let url = baseURL.appendingPathComponent("tickets/\(ticketId)/messages/\(messageId)/photos")
        
        logger.debug("Fetching photos for ticket \(ticketId) and message \(messageId)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw NSError(domain: "Invalid response", code: 0)
        }
        
        logger.debug("Received response with status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            logger.error("Server returned error: \(httpResponse.statusCode)")
            throw NSError(domain: "Server error", code: httpResponse.statusCode)
        }
        
        do {
            let response = try JSONDecoder().decode(TicketPhotosResponse.self, from: data)
            logger.info("Successfully fetched \(response.photos.count) photos")
            return response.photos
        } catch {
            logger.error("Failed to decode photos response: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchTicketDetails(ticketId: Int) async throws -> TicketFullResponse {
        let url = baseURL.appendingPathComponent("tickets/\(ticketId)")
        
        logger.debug("Fetching ticket details from \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw NSError(domain: "Invalid response", code: 0)
        }
        
        logger.debug("Received response with status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            logger.error("Server returned error: \(httpResponse.statusCode)")
            throw NSError(domain: "Server error", code: httpResponse.statusCode)
        }
        
        do {
            let response = try JSONDecoder().decode(TicketFullResponse.self, from: data)
            logger.info("Successfully decoded ticket details with \(response.messages.count) messages and \(response.photos?.count ?? 0) photos")
            return response
        } catch {
            logger.error("Failed to decode ticket details: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchUsers() async throws -> [User] {
        let url = baseURL.appendingPathComponent("users")
        
        logger.debug("Fetching users from \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw NSError(domain: "Invalid response", code: 0)
        }
        
        logger.debug("Received response with status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            logger.error("Server returned error: \(httpResponse.statusCode)")
            throw NSError(domain: "Server error", code: httpResponse.statusCode)
        }
        
        do {
            let response = try JSONDecoder().decode(UsersResponse.self, from: data)
            logger.info("Successfully decoded \(response.users.count) users")
            return response.users
        } catch {
            logger.error("Failed to decode users: \(error.localizedDescription)")
            throw error
        }
    }
    
    func attachPhotoToMessage(photoId: Int, messageId: Int) async throws {
        let url = baseURL.appendingPathComponent("photos/\(photoId)/attach")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters = ["message_id": messageId]
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        logger.debug("Attaching photo \(photoId) to message \(messageId)")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw NSError(domain: "Invalid response", code: 0)
        }
        
        guard httpResponse.statusCode == 200 else {
            logger.error("Server returned error: \(httpResponse.statusCode)")
            throw NSError(domain: "Server error", code: httpResponse.statusCode)
        }
        
        logger.info("Successfully attached photo \(photoId) to message \(messageId)")
    }
} 
