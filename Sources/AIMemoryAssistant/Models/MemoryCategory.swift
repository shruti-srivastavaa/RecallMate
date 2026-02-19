import SwiftUI

/// Represents the type/category of a captured memory.
enum MemoryCategory: String, CaseIterable, Codable {
    case clipboard  = "clipboard"
    case file       = "file"
    case message    = "message"
    case note       = "note"
    case link       = "link"
    case address    = "address"
    case manual     = "manual"

    // MARK: – Display

    var displayName: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .file:      return "File"
        case .message:   return "Message"
        case .note:      return "Note"
        case .link:      return "Link"
        case .address:   return "Address"
        case .manual:    return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .file:      return "doc.fill"
        case .message:   return "message.fill"
        case .note:      return "note.text"
        case .link:      return "link"
        case .address:   return "mappin.and.ellipse"
        case .manual:    return "pencil.line"
        }
    }

    var color: Color {
        switch self {
        case .clipboard: return .cyan
        case .file:      return .orange
        case .message:   return .green
        case .note:      return .yellow
        case .link:      return .blue
        case .address:   return .pink
        case .manual:    return .purple
        }
    }
}
