import Foundation
import Combine
import OSLog
import UIKit

class TicketMessagesViewModel: ObservableObject {
    @Published var messages: [TicketMessage] = []
    @Published var photos: [Int: [TicketPhoto]] = [:] // message_id -> photos
    @Published var unattachedPhotos: [TicketPhoto] = [] // Фотографии без message_id
    @Published var isLoading = false
    @Published var error: String?
    @Published var sending = false
    
    let ticketId: Int
    let supportId: Int64 // id текущего пользователя поддержки
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "TicketMessages")
    private var loadingTask: Task<Void, Never>?
    
    init(ticketId: Int, supportId: Int64) {
        self.ticketId = ticketId
        self.supportId = supportId
        logger.info("ViewModel initialized for ticket \(ticketId) with support ID \(supportId)")
        loadMessages()
    }
    
    func loadMessages() {
        loadingTask?.cancel()
        
        loadingTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            
            isLoading = true
            error = nil
            logger.info("Starting to load messages and photos for ticket \(self.ticketId)")
            
            do {
                let response = try await TicketAPI.shared.fetchTicketDetails(ticketId: self.ticketId)
                
                // Группируем фотографии по message_id
                var photosByMessage: [Int: [TicketPhoto]] = [:]
                var unattached: [TicketPhoto] = []
                
                if let photos = response.photos {
                    for photo in photos {
                        if let messageId = photo.message_id {
                            if photosByMessage[messageId] == nil {
                                photosByMessage[messageId] = []
                            }
                            photosByMessage[messageId]?.append(photo)
                        } else {
                            unattached.append(photo)
                        }
                    }
                }
                
                self.messages = response.messages
                self.photos = photosByMessage
                self.unattachedPhotos = unattached
                self.error = nil
                
                logger.info("Successfully loaded \(response.messages.count) messages and \(response.photos?.count ?? 0) photos")
            } catch {
                if self.messages.isEmpty {
                    self.error = error.localizedDescription
                    logger.error("Failed to load messages and photos: \(error.localizedDescription)")
                } else {
                    logger.warning("Non-critical error during refresh: \(error.localizedDescription)")
                }
            }
            
            self.isLoading = false
        }
    }
    
    func sendMessage(text: String) {
        sending = true
        error = nil
        logger.info("Preparing to send message for ticket \(self.ticketId)")
        
        // Создаем временное сообщение
        let tempId = Int.random(in: -999999...(-1))
        let tempMessage = TicketMessage(
            id: tempId,
            ticket_id: self.ticketId,
            sender_type: "support",
            sender_id: self.supportId,
            message: text,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
        logger.debug("Created temporary message with ID \(tempId)")
        
        // Добавляем сообщение локально
        DispatchQueue.main.async {
            self.messages.append(tempMessage)
            self.logger.info("Added temporary message to local list")
        }
        
        Task { @MainActor in
            do {
                let messageId = try await withCheckedThrowingContinuation { continuation in
                    TicketAPI.shared.sendMessage(ticketId: self.ticketId, senderType: "support", senderId: self.supportId, message: text) { result in
                        continuation.resume(with: result)
                    }
                }
                
                logger.info("Message sent successfully with ID \(messageId)")
                
                // После успешной отправки обновляем список сообщений
                loadMessages()
                
            } catch {
                logger.error("Failed to send message: \(error.localizedDescription)")
                self.error = "Ошибка отправки сообщения"
                // Удаляем временное сообщение
                self.messages.removeAll { $0.id == tempId }
            }
            
            self.sending = false
        }
    }
    
    func sendMessageWithImage(text: String, image: UIImage, completion: @escaping (Bool) -> Void) {
        // Проверяем, что текст не пустой
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Необходимо добавить текст к сообщению"
            completion(false)
            return
        }
        
        sending = true
        error = nil
        logger.info("Starting to send message and photo")
        
        Task { @MainActor in
            do {
                // Сначала загружаем фото без привязки к сообщению
                logger.debug("Step 1: Uploading photo")
                let photoId = try await TicketAPI.shared.uploadPhoto(
                    ticketId: ticketId,
                    image: image,
                    senderType: "support",
                    senderId: supportId,
                    messageId: nil // Сначала загружаем без привязки к сообщению
                )
                logger.info("Photo uploaded with ID: \(photoId)")
                
                // Затем отправляем сообщение
                logger.debug("Step 2: Sending message")
                let messageId = try await withCheckedThrowingContinuation { continuation in
                    TicketAPI.shared.sendMessage(
                        ticketId: ticketId,
                        senderType: "support",
                        senderId: supportId,
                        message: text.trimmingCharacters(in: .whitespaces)
                    ) { result in
                        continuation.resume(with: result)
                    }
                }
                logger.info("Message sent with ID: \(messageId)")
                
                // После успешной отправки обновляем список сообщений
                loadMessages()
                completion(true)
                
            } catch {
                logger.error("Error in send process: \(error.localizedDescription)")
                self.error = "Ошибка: \(error.localizedDescription)"
                completion(false)
            }
            
            self.sending = false
        }
    }
    
    private func quietlyRefreshMessages() {
        loadMessages() // Используем основной метод загрузки, но без показа ошибок
    }
    
    deinit {
        loadingTask?.cancel()
    }
} 
