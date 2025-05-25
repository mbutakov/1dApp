import Foundation
import Combine
import OSLog

class UsersViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "Users")
    
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return users
        }
        return users.filter { user in
            guard let name = user.full_name else { return false }
            return name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func loadUsers() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        Task { @MainActor in
            do {
                let fetchedUsers = try await TicketAPI.shared.fetchUsers()
                self.users = fetchedUsers
                self.error = nil
                logger.info("Successfully loaded \(fetchedUsers.count) users")
            } catch {
                self.error = error.localizedDescription
                logger.error("Failed to load users: \(error.localizedDescription)")
            }
            self.isLoading = false
        }
    }
} 