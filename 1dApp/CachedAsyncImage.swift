import SwiftUI
import OSLog

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (Image) -> Content
    @State private var phase: AsyncImagePhase = .empty
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "CachedImage")
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
        
        if let url = url {
            logger.debug("Initializing CachedAsyncImage with URL: \(url.absoluteString)")
        }
    }
    
    init(url: URL?) where Content == Image {
        self.init(url: url) { $0 }
    }
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let image):
                content(image)
            case .failure(let error):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                    Text("Ошибка загрузки")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    logger.error("Failed to load image: \(error.localizedDescription)")
                }
            @unknown default:
                EmptyView()
            }
        }
        .task(id: url?.absoluteString) {
            guard let url = url else { return }
            
            // Проверяем кэш
            if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
                phase = .success(Image(uiImage: cachedImage))
                return
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    ImageCache.shared.set(uiImage, forKey: url.absoluteString)
                    phase = .success(Image(uiImage: uiImage))
                } else {
                    throw URLError(.cannotDecodeRawData)
                }
            } catch {
                phase = .failure(error)
            }
        }
    }
}

extension AsyncImagePhase {
    var image: Image? {
        switch self {
        case .success(let image):
            return image
        default:
            return nil
        }
    }
} 
