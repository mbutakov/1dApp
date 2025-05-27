import SwiftUI
import OSLog

struct MessageDateIndicator: View {
    let dates: [String]
    @Binding var showCalendar: Bool
    
    var body: some View {
        Button {
            showCalendar = true
        } label: {
            Text(dates.first?.prefix(10) ?? "")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}

struct ImagePreviewView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    private let screenSize = UIScreen.main.bounds.size
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "ImagePreview")
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            CachedAsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: screenSize.width, maxHeight: screenSize.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale *= delta
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
        .preferredColorScheme(.dark)
        .onDisappear {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}

struct MessageCalendarView: View {
    let messages: [TicketMessage]
    let onDateSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var messagesByDate: [String: [TicketMessage]] {
        Dictionary(grouping: messages) { $0.created_at.prefix(10).description }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(messagesByDate.keys.sorted().reversed(), id: \.self) { date in
                    Button {
                        if let firstMessage = messagesByDate[date]?.first {
                            onDateSelected(firstMessage.created_at)
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Text(date)
                                .font(.system(.body, design: .rounded))
                            
                            Spacer()
                            
                            Text("\(messagesByDate[date]?.count ?? 0)")
                                .font(.system(.caption, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .navigationTitle("История сообщений")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TicketMessagesView: View {
    let ticket: Ticket
    let supportId: Int64
    @StateObject private var messagesVM: TicketMessagesViewModel
    @State private var newMessage = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var showStatusMenu = false
    @State private var currentStatus: String
    @State private var isUpdatingStatus = false
    @State private var showCalendar = false
    @State private var visibleMessageIds: Set<Int> = []
    @State private var showImagePreview = false
    @State private var selectedPreviewURL: URL?
    @State private var showDateIndicator = false
    private let dateIndicatorTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    private let statuses = [
        ("Создан", "🆕 Создан", "Тикет отправлен, ожидает назначения"),
        ("Назначен", "👨‍💻 Назначен", "Назначен конкретному агенту"),
        ("В работе", "🔧 В работе", "Агент работает над тикетом"),
        ("Ожидает ответа пользователя", "❓ Ожидает ответа", "Ждём ответа от пользователя"),
        ("Ожидает действий поддержки", "⏳ Ожидает поддержку", "Ждём действий от поддержки"),
        ("Закрыт", "Закрыт", "Тикет закрыт"),
        ("Отменён", "🚫 Отменён", "Ошибочный тикет или дубль")
    ]
    
    private let statusColors: [String: Color] = [
        "Создан": .blue,
        "Назначен": .purple,
        "В работе": .orange,
        "Ожидает ответа пользователя": .yellow,
        "Ожидает действий поддержки": .red,
        "Закрыт": .gray,
        "Отменён": .secondary
    ]
    
    init(ticket: Ticket, supportId: Int64) {
        self.ticket = ticket
        self.supportId = supportId
        _messagesVM = StateObject(wrappedValue: TicketMessagesViewModel(ticketId: ticket.id, supportId: supportId))
        _currentStatus = State(initialValue: ticket.status)
    }
    
    var visibleDates: [String] {
        let dates = messagesVM.messages
            .filter { visibleMessageIds.contains($0.id) }
            .map { $0.created_at.prefix(10).description }
        return Array(Set(dates)).sorted()
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
                    Menu {
                        ForEach(statuses, id: \.0) { status, title, description in
                            Button(action: {
                                updateStatus(to: status)
                            }) {
                                HStack {
                                    Text(title)
                                    if status == currentStatus {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if isUpdatingStatus {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(ticket.statusIcon)
                                Text(currentStatus.capitalized)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(statusColors[currentStatus])
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColors[currentStatus]?.opacity(0.15))
                        .cornerRadius(8)
                    }
                    
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
            ScrollViewReader { scrollProxy in
                List(messagesVM.messages) { msg in
                    MessageBubbleView(message: msg, messagesVM: messagesVM) { url in
                        selectedPreviewURL = url
                        showImagePreview = true
                    }
                    .id(msg.id)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onAppear {
                        visibleMessageIds.insert(msg.id)
                    }
                    .onDisappear {
                        visibleMessageIds.remove(msg.id)
                    }
                }
                .listStyle(.plain)
                .background(Color(.systemBackground))
                .refreshable { messagesVM.loadMessages() }
                .overlay(alignment: .top) {
                    if !visibleDates.isEmpty && showDateIndicator {
                        MessageDateIndicator(dates: visibleDates, showCalendar: $showCalendar)
                            .padding(.top, 8)
                            .transition(.opacity)
                    }
                }
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
                .onReceive(dateIndicatorTimer) { _ in
                    if showDateIndicator {
                        withAnimation {
                            showDateIndicator = false
                        }
                    }
                }
                .onChange(of: messagesVM.messages) { _ in
                    if let lastId = messagesVM.messages.last?.id {
                        withAnimation {
                            scrollProxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                    visibleMessageIds = []
                }
                .onAppear {
                    if let lastId = messagesVM.messages.last?.id {
                        withAnimation {
                            scrollProxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { _ in
                            withAnimation {
                                showDateIndicator = true
                            }
                        }
                )
                .onChange(of: showCalendar) { show in
                    if !show {
                        // Обновляем видимые даты при открытии календаря
                        visibleMessageIds = []
                    }
                }
                .sheet(isPresented: $showCalendar) {
                    MessageCalendarView(messages: messagesVM.messages) { date in
                        if let messageId = messagesVM.messages.first(where: { $0.created_at.hasPrefix(date) })?.id {
                            withAnimation {
                                scrollProxy.scrollTo(messageId, anchor: .top)
                            }
                        }
                    }
                    .presentationDetents([.medium])
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
        .fullScreenCover(isPresented: $showImagePreview) {
            if let url = selectedPreviewURL {
                ImagePreviewView(imageURL: url)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            messagesVM.loadMessages()
        }
    }
    
    private func updateStatus(to newStatus: String) {
        guard newStatus != currentStatus else { return }
        
        isUpdatingStatus = true
        Task {
            do {
                try await TicketAPI.shared.updateTicketStatus(ticketId: ticket.id, newStatus: newStatus)
                await MainActor.run {
                    currentStatus = newStatus
                    isUpdatingStatus = false
                }
            } catch {
                print("Failed to update status: \(error)")
                await MainActor.run {
                    isUpdatingStatus = false
                }
            }
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
} 
