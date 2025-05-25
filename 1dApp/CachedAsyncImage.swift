import SwiftUI
import OSLog

struct CachedAsyncImage: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var isLoading = false
    private let logger = Logger(subsystem: "tech.mb0.1dApp", category: "CachedImage")
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)
                    .cornerRadius(12)
            } else if isLoading {
                ProgressView()
                    .frame(width: 200, height: 200)
            } else {
                Image(systemName: "photo.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 200, height: 200)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        let cacheKey = url.absoluteString
        
        // Проверяем кэш
        if let cachedImage = ImageCache.shared.get(forKey: cacheKey) {
            self.image = cachedImage
            return
        }
        
        // Если нет в кэше, загружаем
        isLoading = true
        
        // Логируем URL для отладки
        logger.debug("Loading image from URL: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            isLoading = false
            
            if let error = error {
                logger.error("Failed to load image: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                logger.error("No data received")
                return
            }
            
            // Логируем тип контента из ответа
            if let response = response as? HTTPURLResponse {
                logger.debug("Response content type: \(response.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
            }
            
            guard let loadedImage = UIImage(data: data) else {
                logger.error("Invalid image data")
                return
            }
            
            // Сохраняем в кэш и обновляем UI
            ImageCache.shared.set(loadedImage, forKey: cacheKey)
            
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }.resume()
    }
} 