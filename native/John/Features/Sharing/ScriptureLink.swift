import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A passage that other apps can receive as a URL. The URL uses the `nrsv://` scheme, so a tap on it
/// opens the passage in this app ("Open in John"). A Share Extension is not needed.
struct ScriptureLink: Transferable {
    let bookCode: String
    let chapter: Int
    let verse: String?

    var url: URL {
        var components = URLComponents()
        components.scheme = "nrsv"
        components.host = "read"
        var items = [URLQueryItem(name: "book", value: bookCode), URLQueryItem(name: "chapter", value: String(chapter))]
        if let verse { items.append(URLQueryItem(name: "verse", value: verse)) }
        components.queryItems = items
        return components.url ?? URL(string: "nrsv://read")!
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { (link: ScriptureLink) in link.url }
    }
}
