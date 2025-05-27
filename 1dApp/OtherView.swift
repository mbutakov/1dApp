import SwiftUI

struct CalendarCard: View {
    @State private var isHovered = false
    @State private var offset = CGSize.zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                
                Text("Календарь тикетов")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Text("Просмотр тикетов в календарном виде с группировкой по дням, неделям и месяцам")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.478, blue: 1.0), // #007AFF
                            Color(red: 0.345, green: 0.337, blue: 0.839) // #5856D6
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    GeometryReader { geometry in
                        let size = geometry.size
                        Canvas { context, size in
                            context.addFilter(.blur(radius: 30))
                            context.drawLayer { ctx in
                                for i in 0..<3 {
                                    let rect = CGRect(x: CGFloat.random(in: 0...size.width),
                                                    y: CGFloat.random(in: 0...size.height),
                                                    width: CGFloat.random(in: 50...150),
                                                    height: CGFloat.random(in: 50...150))
                                    ctx.fill(
                                        Circle().path(in: rect),
                                        with: .color(Color.white.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .scaleEffect(isHovered ? 1.02 : 1)
        .offset(offset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let translation = gesture.translation
                    let constrainedX = min(max(translation.width, -10), 10)
                    let constrainedY = min(max(translation.height, -10), 10)
                    offset = CGSize(width: constrainedX, height: constrainedY)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        offset = .zero
                    }
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct TicketCalendarDay: Identifiable {
    let id = UUID()
    let date: String
    let totalTickets: Int
    let statusCounts: [String: Int]
    
    static let mockData: [TicketCalendarDay] = [
        .init(date: "27.05.2025", totalTickets: 12, statusCounts: ["создан": 3, "в работе": 5, "закрыт": 4]),
        .init(date: "26.05.2025", totalTickets: 8, statusCounts: ["создан": 2, "назначен": 3, "в работе": 3]),
        .init(date: "25.05.2025", totalTickets: 15, statusCounts: ["создан": 4, "в работе": 8, "закрыт": 3]),
        .init(date: "24.05.2025", totalTickets: 10, statusCounts: ["создан": 2, "назначен": 4, "в работе": 2, "закрыт": 2]),
        .init(date: "23.05.2025", totalTickets: 7, statusCounts: ["в работе": 4, "закрыт": 3]),
        .init(date: "22.05.2025", totalTickets: 13, statusCounts: ["создан": 5, "назначен": 3, "в работе": 3, "закрыт": 2]),
        .init(date: "21.05.2025", totalTickets: 9, statusCounts: ["создан": 2, "в работе": 4, "закрыт": 3])
    ]
}

struct StatusBadge: View {
    let status: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(status.capitalized)
                .font(.caption)
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatusFilterItem: View {
    let status: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(status.capitalized)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatusGrid: View {
    let statusCounts: [String: Int]
    let statusColors: [String: Color]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(Array(statusCounts.keys.sorted()), id: \.self) { status in
                if let count = statusCounts[status] {
                    StatusBadge(
                        status: status,
                        count: count,
                        color: statusColors[status, default: .gray]
                    )
                }
            }
        }
    }
}

struct FilterPanel: View {
    let statusColors: [String: Color]
    let statusCounts: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Фильтры")
                .font(.headline)
            
            ForEach(Array(statusColors.keys.sorted()), id: \.self) { status in
                StatusFilterItem(
                    status: status,
                    count: statusCounts[status, default: 0],
                    color: statusColors[status, default: .gray]
                )
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct DayHeader: View {
    let date: String
    let totalTickets: Int
    @Binding var showFilters: Bool
    
    var body: some View {
        HStack {
            Text(date)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                withAnimation {
                    showFilters.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle\(showFilters ? ".fill" : "")")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            
            Text("\(totalTickets)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
        }
    }
}

struct DayContent: View {
    let statusCounts: [String: Int]
    let statusColors: [String: Color]
    let showFilters: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            StatusGrid(statusCounts: statusCounts, statusColors: statusColors)
            
            if showFilters {
                FilterPanel(statusColors: statusColors, statusCounts: statusCounts)
            }
        }
    }
}

struct TicketCalendarDayView: View {
    let day: TicketCalendarDay
    @State private var showFilters = false
    
    private let statusColors: [String: Color] = [
        "создан": .blue,
        "назначен": .purple,
        "в работе": .orange,
        "ожидает ответа пользователя": .yellow,
        "ожидает действий поддержки": .red,
        "закрыт": .gray,
        "отменён": .secondary
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            DayHeader(
                date: day.date,
                totalTickets: day.totalTickets,
                showFilters: $showFilters
            )
            
            DayContent(
                statusCounts: day.statusCounts,
                statusColors: statusColors,
                showFilters: showFilters
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return calculateTotalSize(for: rows)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        placeRows(rows, in: bounds)
    }
    
    private func calculateTotalSize(for rows: [[LayoutSubview]]) -> CGSize {
        rows.reduce(CGSize.zero) { size, row in
            let rowWidth = calculateRowWidth(for: row)
            let rowHeight = row.first?.sizeThatFits(.unspecified).height ?? 0
            return CGSize(
                width: max(size.width, rowWidth),
                height: size.height + rowHeight
            )
        }
    }
    
    private func calculateRowWidth(for row: [LayoutSubview]) -> CGFloat {
        row.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } + CGFloat(row.count - 1) * spacing
    }
    
    private func placeRows(_ rows: [[LayoutSubview]], in bounds: CGRect) {
        var currentY = bounds.minY
        
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            placeRow(row, at: currentY, startX: bounds.minX)
            currentY += rowHeight + spacing
        }
    }
    
    private func placeRow(_ row: [LayoutSubview], at y: CGFloat, startX: CGFloat) {
        var currentX = startX
        
        for subview in row {
            let size = subview.sizeThatFits(.unspecified)
            subview.place(at: CGPoint(x: currentX, y: y), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
        }
    }
    
    private func shouldStartNewRow(currentWidth: CGFloat, subviewWidth: CGFloat, maxWidth: CGFloat?) -> Bool {
        guard let maxWidth = maxWidth else { return false }
        return currentWidth + subviewWidth > maxWidth
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var currentRow = 0
        var currentWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if shouldStartNewRow(currentWidth: currentWidth, subviewWidth: size.width, maxWidth: proposal.width) {
                currentRow += 1
                rows.append([])
                currentWidth = size.width + spacing
            } else {
                currentWidth += size.width + spacing
            }
            
            rows[currentRow].append(subview)
        }
        
        return rows
    }
}

struct OtherView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(TicketCalendarDay.mockData) { day in
                        TicketCalendarDayView(day: day)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Календарь тикетов")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 32)
                }
            }
        }
    }
} 