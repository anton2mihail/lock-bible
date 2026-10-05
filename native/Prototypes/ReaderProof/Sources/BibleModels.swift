import Foundation

struct SourceChapter: Decodable, Sendable {
  let edition: String
  let bookCode: String
  let bookName: String
  let longName: String
  let chapter: Chapter
}

struct Chapter: Decodable, Sendable {
  let c: Int
  let verses: [Verse]
}

struct Verse: Decodable, Sendable {
  let n: String
  let t: String
  let br: [SourceBreak]
  let hd: [SourceHeading]

  init(n: String, t: String, br: [SourceBreak] = [], hd: [SourceHeading] = []) {
    self.n = n
    self.t = t
    self.br = br
    self.hd = hd
  }

  private enum CodingKeys: String, CodingKey { case n, t, br, hd }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    n = try container.decode(String.self, forKey: .n)
    t = try container.decode(String.self, forKey: .t)
    br = try container.decodeIfPresent([SourceBreak].self, forKey: .br) ?? []
    hd = try container.decodeIfPresent([SourceHeading].self, forKey: .hd) ?? []
  }
}

struct SourceBreak: Decodable, Sendable {
  let offset: Int
  let kind: String

  init(offset: Int, kind: String) {
    self.offset = offset
    self.kind = kind
  }

  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    offset = try container.decode(Int.self)
    kind = try container.decode(String.self)
  }
}

struct SourceHeading: Decodable, Sendable {
  let kind: String
  let text: String
  let offset: Int?

  init(kind: String, text: String, offset: Int? = nil) {
    self.kind = kind
    self.text = text
    self.offset = offset
  }

  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    kind = try container.decode(String.self)
    text = try container.decode(String.self)
    offset = try container.decodeIfPresent(Int.self)
  }
}

struct WorksSection: Decodable, Sendable {
  let title: String
  let sectionIndex: Int
  let sectionTitle: String
  let paragraphs: [String]
}

enum SampleLoader {
  static func chapter(_ resource: String) throws -> SourceChapter {
    guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode(SourceChapter.self, from: Data(contentsOf: url))
  }

  static func worksSection() throws -> WorksSection {
    guard let url = Bundle.main.url(forResource: "works-section", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode(WorksSection.self, from: Data(contentsOf: url))
  }

  static func unicodeChapter() -> SourceChapter {
    SourceChapter(
      edition: "synthetic",
      bookCode: "SYN",
      bookName: "Unicode fixture",
      longName: "Unicode fixture",
      chapter: Chapter(
        c: 1,
        verses: [
          Verse(
            n: "1-2",
            t: "Before😀e\u{301}—after",
            br: [SourceBreak(offset: 8, kind: "q2"), SourceBreak(offset: 10, kind: "q3")]
          ),
          Verse(n: "3", t: "Second verse.", br: [SourceBreak(offset: 0, kind: "p")])
        ]
      )
    )
  }
}
