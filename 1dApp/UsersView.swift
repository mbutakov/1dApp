import SwiftUI
import OSLog

struct UsersView: View {
    @StateObject private var viewModel = UsersViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск пользователей...", text: $viewModel.searchText)
                        .foregroundColor(.primary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !viewModel.searchText.isEmpty {
                        Button(action: { withAnimation { viewModel.searchText = "" } }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(12)
                .background(.thinMaterial)
                .cornerRadius(16)
                .padding()
                
                // Список пользователей
                List(viewModel.filteredUsers) { user in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(user.full_name ?? "Без имени")
                                .font(.headline)
                            
                            Spacer()
                            
                            if user.is_registered {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if let phone = user.phone {
                            Label {
                                Text(phone)
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: "phone.fill")
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Link(destination: URL(string: "tg://user?id=\(user.id)")!) {
                            Label {
                                Text("Открыть в Telegram")
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .foregroundColor(.blue)
                        
                        if let location = user.location_lat.map({ "\($0), \(user.location_lng ?? 0)" }) {
                            Label {
                                Text(location)
                                    .font(.caption)
                            } icon: {
                                Image(systemName: "location.fill")
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if let date = user.birth_date {
                            Label {
                                Text(date)
                                    .font(.caption)
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listStyle(.plain)
                .refreshable { viewModel.loadUsers() }
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(10)
                    } else if viewModel.users.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Нет пользователей")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Пользователи")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 32)
                }
            }
        }
        .onAppear {
            viewModel.loadUsers()
        }
    }
} 