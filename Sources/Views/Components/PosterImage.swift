import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct PosterImage: View {
    let item: MediaItem
    let request: URLRequest?
    var localURL: URL? = nil

    @Environment(GameBoyTheme.self) private var theme
    @State private var imageData: Data?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let imageData, let image = platformImage(from: imageData) {
                if item.isLiveChannel {
                    theme.paper
                    image
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(12)
                        .saturation(0.42)
                        .contrast(1.18)
                } else {
                    image
                        .resizable()
                        .interpolation(.none)
                        .scaledToFill()
                        .saturation(0.42)
                        .contrast(1.18)
                }
            } else {
                PixelPoster(item: item, isLoading: localURL == nil && request != nil && !didFail)
            }
        }
        .clipped()
        .task(id: localURL ?? request?.url) {
            imageData = nil
            didFail = false
            do {
                if let localURL {
                    imageData = try await Task.detached(priority: .utility) {
                        try Data(contentsOf: localURL, options: .mappedIfSafe)
                    }.value
                } else if let request {
                    imageData = try await PosterRepository.shared.data(for: request)
                }
            } catch is CancellationError {
                return
            } catch {
                didFail = true
            }
        }
        .accessibilityLabel("Poster for \(item.name)")
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(iOS)
            guard let image = UIImage(data: data) else { return nil }
            return Image(uiImage: image)
        #elseif os(macOS)
            guard let image = NSImage(data: data) else { return nil }
            return Image(nsImage: image)
        #endif
    }
}

private actor PosterRepository {
    private struct CacheKey: Hashable {
        let url: URL
        let authorization: String?
    }

    static let shared = PosterRepository()

    private var cache: [CacheKey: Data] = [:]

    func data(for request: URLRequest) async throws -> Data {
        guard let url = request.url else { throw URLError(.badURL) }
        let key = CacheKey(
            url: url,
            authorization: request.value(forHTTPHeaderField: "Authorization")
        )
        if let cached = cache[key] {
            return cached
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else { throw URLError(.zeroByteResource) }
        if cache.count >= 128, let evictionKey = cache.keys.first {
            cache[evictionKey] = nil
        }
        cache[key] = data
        return data
    }
}

private struct PixelPoster: View {
    @Environment(GameBoyTheme.self) private var theme
    let item: MediaItem
    let isLoading: Bool

    private var seed: Int {
        item.name.unicodeScalars.reduce(17) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF }
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = 8
            let rows = 12
            let unit = max(proxy.size.width / CGFloat(columns), 1)

            ZStack {
                theme.mid

                Canvas { context, _ in
                    for row in 0..<rows {
                        for column in 0..<columns {
                            let value = (seed &+ row * 19 &+ column * 37 &+ row * column * 7) % 11
                            guard value < 4 else { continue }
                            let rect = CGRect(
                                x: CGFloat(column) * unit,
                                y: CGFloat(row) * unit,
                                width: ceil(unit),
                                height: ceil(unit)
                            )
                            context.fill(
                                Path(rect),
                                with: .color(value == 0 ? theme.ink : theme.accentSoft)
                            )
                        }
                    }
                }

                VStack(spacing: 6) {
                    Text(monogram)
                        .font(.pixel(.title))
                        .foregroundStyle(theme.paper)

                    if isLoading {
                        Text("...")
                            .font(.pixel(.caption))
                            .foregroundStyle(theme.paper)
                            .accessibilityLabel("Loading image")
                    }
                }
                .padding(8)
                .background(theme.posterAccent)
                .overlay { Rectangle().stroke(theme.ink, lineWidth: 3) }
            }
        }
    }

    private var monogram: String {
        item.name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
