import SwiftUI
import OSLog

struct SettingsView: View {
    @State private var cacheSizes: [ImageCache.CacheCategory: Int] = [:]
    @State private var isClearing = false
    @State private var isMigrating = false
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "Settings")
    
    var totalCacheSize: Int {
        cacheSizes.values.reduce(0, +)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Кэш приложения") {
                    HStack {
                        Label {
                            Text("Размер кэша изображений")
                        } icon: {
                            Image(systemName: "photo.fill")
                        }
                        Spacer()
                        Text(formatSize(totalCacheSize))
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive) {
                        clearCache()
                    } label: {
                        if isClearing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Очистка...")
                            }
                        } else {
                            Label("Очистить кэш", systemImage: "trash")
                        }
                    }
                    .disabled(isClearing)
                    
                    Button {
                        migrateCache()
                    } label: {
                        if isMigrating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Миграция...")
                            }
                        } else {
                            Label("Перестроить структуру кэша", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isMigrating)
                }
                
                Section("О приложении") {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.2 beta")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Настройки")
            .onAppear {
                calculateCacheSize()
            }
            .refreshable {
                calculateCacheSize()
            }
        }
    }
    
    private func calculateCacheSize() {
        Task {
            do {
                let sizes = try await ImageCache.shared.calculateSize()
                await MainActor.run {
                    cacheSizes = sizes
                }
            } catch {
                logger.error("Failed to calculate cache size: \(error.localizedDescription)")
            }
        }
    }
    
    private func clearCache() {
        isClearing = true
        Task {
            do {
                try await ImageCache.shared.clearCache()
                await calculateCacheSize()
            } catch {
                logger.error("Failed to clear cache: \(error.localizedDescription)")
            }
            await MainActor.run {
                isClearing = false
            }
        }
    }
    
    private func migrateCache() {
        isMigrating = true
        Task {
            do {
                try await ImageCache.shared.migrateExistingCache()
                await calculateCacheSize()
            } catch {
                logger.error("Failed to migrate cache: \(error.localizedDescription)")
            }
            await MainActor.run {
                isMigrating = false
            }
        }
    }
    
    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
} 