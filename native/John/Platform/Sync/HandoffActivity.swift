import Foundation
import SwiftUI

/// Handoff (E15). The activity carries an `nrsv://` URL. The app opens it with the same router as a link.
/// There is no web domain, so there are no https universal links.
enum JohnActivity {
    static let reading = "com.nrsv.verse.reading"
    static let saved = "com.nrsv.verse.saved"
    static let urlKey = "url"

    static func readingURL(bookCode: String, chapter: Int, verse: String?, translation: String) -> URL? {
        var components = URLComponents()
        components.scheme = "nrsv"
        components.host = "read"
        var query = [URLQueryItem(name: "book", value: bookCode), URLQueryItem(name: "chapter", value: String(chapter)),
                     URLQueryItem(name: "translation", value: translation)]
        if let verse, !verse.isEmpty { query.append(URLQueryItem(name: "verse", value: verse)) }
        components.queryItems = query
        return components.url
    }

    static let savedURL = URL(string: "nrsv://saved")

    /// The URL in an incoming activity. Only `nrsv://` URLs are accepted.
    static func url(from activity: NSUserActivity) -> URL? {
        let raw = activity.userInfo?[urlKey] as? String ?? activity.webpageURL?.absoluteString
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "nrsv" else { return nil }
        return url
    }

    static func configure(_ activity: NSUserActivity, title: String, url: URL) {
        activity.title = title
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPrediction = false
        activity.requiredUserInfoKeys = [urlKey]
        activity.userInfo = [urlKey: url.absoluteString]
    }
}

extension View {
    /// Publishes a Handoff activity while `url` is not nil. Debug builds also expose the URL as an accessibility value for UI tests.
    func handoff(type: String, title: String, url: URL?) -> some View {
        userActivity(type, isActive: url != nil) { activity in
            if let url { JohnActivity.configure(activity, title: title, url: url) }
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            Color.clear.frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("handoff-\(type)")
                .accessibilityValue(url?.absoluteString ?? "none")
                .accessibilityIdentifier("handoff-state-\(type)")
        }
        #endif
    }
}
