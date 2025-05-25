import SwiftUI
import OSLog

struct TicketMessagesView: View {
    let ticket: Ticket
    let supportId: Int64
    @StateObject private var messagesVM: TicketMessagesViewModel
    @State private var newMessage = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    
    init(ticket: Ticket, supportId: Int64) {
        self.ticket = ticket
        self.supportId = supportId
        _messagesVM = StateObject(wrappedValue: TicketMessagesViewModel(ticketId: ticket.id, supportId: supportId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Информация о тикете
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ticket.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(ticket.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    Spacer()
                    Text(ticket.created_at.prefix(10))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Label {
                        Text(ticket.status)
                            .fontWeight(.medium)
                    } icon: {
                        Image(systemName: ticket.status == "открыт" ? "checkmark.circle.fill" : 
                                       ticket.status == "закрыт" ? "xmark.circle.fill" : "clock.fill")
                    }
                    .foregroundColor(ticket.status == "открыт" ? .green :
                                   ticket.status == "закрыт" ? .red : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    
                    if let category = ticket.category {
                        Label {
                            Text(category)
                                .fontWeight(.medium)
                        } icon: {
                            Image(systemName: "folder.fill")
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(.thinMaterial)
            
            Divider()
                .background(Color(.separator))
            
            // Список сообщений
            List(messagesVM.messages) { msg in
                MessageBubbleView(message: msg, messagesVM: messagesVM)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color(.systemBackground))
            .refreshable { messagesVM.loadMessages() }
            .overlay {
                if messagesVM.isLoading {
                    ProgressView()
                } else if let error = messagesVM.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(10)
                } else if messagesVM.messages.isEmpty {
                    Text("Нет сообщений")
                        .foregroundColor(.secondary)
                }
            }
            
            // Поле ввода сообщения с новым дизайном
            HStack(spacing: 12) {
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                
                HStack {
                    TextField("Сообщение...", text: $newMessage)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                    
                    if !newMessage.trimmingCharacters(in: .whitespaces).isEmpty || selectedImage != nil {
                        Button {
                            if let image = selectedImage {
                                isUploading = true
                                messagesVM.sendMessageWithImage(text: newMessage, image: image) { success in
                                    if success {
                                        newMessage = ""
                                        selectedImage = nil
                                    }
                                    isUploading = false
                                }
                            } else {
                                messagesVM.sendMessage(text: newMessage)
                                newMessage = ""
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 40, height: 40)
                                
                                if isUploading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(45))
                                }
                            }
                        }
                        .disabled(isUploading)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            // Показываем выбранное изображение
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            selectedImage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 20))
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onAppear {
            messagesVM.loadMessages()
        }
    }
} 