import Foundation

enum BookStatus: String, CaseIterable, Codable, Identifiable {
    case toRead
    case reading
    case finished

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toRead:
            return "To Read"
        case .reading:
            return "Reading"
        case .finished:
            return "Finished"
        }
    }
}
