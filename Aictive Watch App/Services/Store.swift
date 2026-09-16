//
//  Writer.swift
//  Aictive
//
//  Created by Putu Steven Belva Chan on 09/09/26.
//

import Foundation

enum CSVStore {
    static var directory: URL {
        URL.documentsDirectory.appending(path: "recordings", directoryHint: .isDirectory)
    }

    static func save(_ csvString: String, label: String, date: Date = .now) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appending(path: filename(label: label, date: date))
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

  /// Count and total bytes on disk, for the storage screen.
  static func summary() -> (count: Int, bytes: Int64) {
      let urls = (try? allRecordings()) ?? []
      let bytes = urls.reduce(Int64(0)) { total, url in
          let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
          return total + Int64(size ?? 0)
      }
      return (urls.count, bytes)
  }

  /// Irreversible. Only call after the files have been pulled and verified.
  static func deleteAll() throws {
      for url in try allRecordings() {
          try FileManager.default.removeItem(at: url)
      }
  }

  static func allRecordings() throws -> [URL] {
      guard FileManager.default.fileExists(atPath: directory.path()) else { return [] }
      return try FileManager.default
          .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
          .filter { $0.pathExtension == "csv" }
          .sorted { $0.lastPathComponent > $1.lastPathComponent }
  }

  private static let stamp: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
      f.locale = Locale(identifier: "en_US_POSIX")
      return f
  }()

  private static func filename(label: String, date: Date) -> String {
      let safe = label
          .replacingOccurrences(of: "/", with: "-")
          .replacingOccurrences(of: ":", with: "-")
          .trimmingCharacters(in: .whitespaces)
      return "\(safe.isEmpty ? "unlabeled" : safe)_\(stamp.string(from: date)).csv"
  }
}
