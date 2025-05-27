import SwiftUI

struct MessageBubbleView: View {
    let message: TicketMessage
    @ObservedObject var messagesVM: TicketMessagesViewModel
    var onImageTap: ((URL) -> Void)?
    
    var messagePhotos: [TicketPhoto] {
        messagesVM.photos[message.id] ?? []
    }
    
    private func getPhotoUrl(_ photo: TicketPhoto) -> URL? {
        // Убираем лишний путь ../uploads/ из file_path
        let cleanPath = photo.file_path.replacingOccurrences(of: "../uploads/", with: "")
        return URL(string: "https://mb0.tech/api/uploads/\(cleanPath)")
    }
    
    var body: some View {
        HStack {
            if message.sender_type == "support" {
                Spacer()
            }
            
            VStack(alignment: message.sender_type == "support" ? .trailing : .leading, spacing: 4) {
                Text(message.sender_type == "support" ? "Поддержка" : "Пользователь")
                    .font(.caption)
                    .foregroundColor(message.sender_type == "support" ? .accentColor : .blue)
                    .padding(.horizontal, 4)
                
                Text(message.message)
                    .padding(12)
                    .background(message.sender_type == "support" ?
                              Color.accentColor.opacity(0.15) :
                              Color.blue.opacity(0.15))
                    .cornerRadius(16)
                
                // Отображение фотографий с кэшированием
                ForEach(messagePhotos) { photo in
                    if let url = getPhotoUrl(photo) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200)
                                .cornerRadius(12)
                        }
                        .onTapGesture {
                            onImageTap?(url)
                        }
                    }
                }
                
                Text(message.created_at.prefix(16).replacingOccurrences(of: "T", with: " "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.sender_type != "support" {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
} 
