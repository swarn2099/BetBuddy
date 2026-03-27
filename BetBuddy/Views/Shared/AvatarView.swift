import SwiftUI

struct AvatarView: View {
    let name: String
    let size: CGFloat
    let imageURL: String?

    init(name: String, size: CGFloat = 40, imageURL: String? = nil) {
        self.name = name
        self.size = size
        self.imageURL = imageURL
    }

    private static let gradients: [(Color, Color)] = [
        (Color(hex: 0x6366F1), Color(hex: 0x8B5CF6)),
        (Color(hex: 0xF59E0B), Color(hex: 0xEF4444)),
        (Color(hex: 0x22C55E), Color(hex: 0x10B981)),
        (Color(hex: 0xEC4899), Color(hex: 0x8B5CF6)),
        (Color(hex: 0x06B6D4), Color(hex: 0x3B82F6)),
        (Color(hex: 0xF97316), Color(hex: 0xEC4899)),
    ]

    private var gradient: LinearGradient {
        let idx = Int(name.first?.asciiValue ?? 0) % Self.gradients.count
        let pair = Self.gradients[idx]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        if let url = imageURL, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackAvatar
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}
