import Foundation
import AppKit
import UniformTypeIdentifiers

enum ExtensionCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case audio = "Audio"
    case video = "Video"
    case images = "Images"
    case documents = "Text & Documents"
    case development = "Development"
    case archives = "Archives"
    case fonts = "Fonts"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .audio: return "waveform"
        case .video: return "film"
        case .images: return "photo"
        case .documents: return "doc.text"
        case .development: return "chevron.left.forwardslash.chevron.right"
        case .archives: return "archivebox"
        case .fonts: return "textformat"
        case .other: return "square.grid.2x2"
        }
    }

    var extensions: [String] {
        switch self {
        case .audio:
            return ["mp3", "m4a", "aac", "wav", "aiff", "flac", "ogg", "opus", "mid"]
        case .video:
            return ["mp4", "mov", "m4v", "mkv", "avi", "webm", "wmv", "flv", "mpg", "3gp"]
        case .images:
            return ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "svg", "ico", "psd"]
        case .documents:
            return ["txt", "md", "rtf", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "epub", "pages", "numbers", "key"]
        case .development:
            return ["swift", "js", "jsx", "tsx", "py", "rb", "go", "rs", "java", "kt", "c", "cpp", "h", "cs", "php", "sh", "json", "yaml", "yml", "toml", "xml", "html", "css", "scss", "sql", "plist"]
        case .archives:
            return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso"]
        case .fonts:
            return ["ttf", "otf", "woff", "woff2"]
        case .other:
            return ["torrent", "ics", "vcf", "log"]
        }
    }
}

struct HandlerApp: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String

    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
    }

    var id: URL { url }
}

struct ExtensionEntry: Identifiable, Hashable, Sendable {
    let ext: String
    let category: ExtensionCategory
    let typeID: String?
    let typeDescription: String
    var defaultApp: HandlerApp?
    var candidates: [HandlerApp]

    var id: String { ext }
}

enum ExtensionCatalog {
    static func buildEntries() -> [ExtensionEntry] {
        let ws = NSWorkspace.shared
        var result: [ExtensionEntry] = []
        for category in ExtensionCategory.allCases {
            for ext in category.extensions {
                let type = UTType(filenameExtension: ext)
                let defaultApp = type.flatMap { ws.urlForApplication(toOpen: $0) }.map(HandlerApp.init)
                var seen = Set<URL>()
                let candidates = (type.map { ws.urlsForApplications(toOpen: $0) } ?? [])
                    .map(HandlerApp.init)
                    .filter { seen.insert($0.url).inserted }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                result.append(
                    ExtensionEntry(
                        ext: ext,
                        category: category,
                        typeID: type?.identifier,
                        typeDescription: type?.localizedDescription ?? "\(ext.uppercased()) file",
                        defaultApp: defaultApp,
                        candidates: candidates
                    ))
            }
        }
        return result
    }
}
