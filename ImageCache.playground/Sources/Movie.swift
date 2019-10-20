import Foundation

public struct Movie {
    public let id: Int
    public let title: String
    public let overview: String
    public let poster: String
}

extension Movie: Hashable {
    public static func == (lhs: Movie, rhs: Movie) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Movie: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case poster = "poster_path"
    }
}
