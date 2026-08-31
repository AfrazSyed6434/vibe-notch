//
//  DesktopSessionTitles.swift
//  ClaudeIsland
//
//  Resolves the chat title the Claude desktop app shows for a session.
//  Desktop instances keep a per-session JSON store under
//  <user-data-dir>/claude-code-sessions/<org>/<user>/local_*.json whose
//  `cliSessionId` (plus `priorCliSessionIds`) matches the session id that
//  hooks report, and whose `title` is the sidebar chat title.
//

import Foundation

/// Only accessed from the SessionStore actor — no internal locking needed.
enum DesktopSessionTitles {

    private struct CacheEntry {
        let title: String?
        let fetchedAt: Date
    }

    private nonisolated(unsafe) static var cache: [String: CacheEntry] = [:]
    private static let cacheTTL: TimeInterval = 60

    /// Title for a session, or nil for terminal sessions / untitled chats.
    /// Cached for 60s — titles change when the app auto-names or the user
    /// renames a chat, so don't cache forever.
    static func title(cliSessionId: String, claudeBinary: String?) -> String? {
        if let entry = cache[cliSessionId], Date().timeIntervalSince(entry.fetchedAt) < cacheTTL {
            return entry.title
        }
        let resolved = lookup(cliSessionId: cliSessionId, claudeBinary: claudeBinary)
        cache[cliSessionId] = CacheEntry(title: resolved, fetchedAt: Date())
        return resolved
    }

    private static func lookup(cliSessionId: String, claudeBinary: String?) -> String? {
        // Desktop sessions run from <user-data-dir>/claude-code/<ver>/claude.app/…
        // — no such segment means a terminal session with no desktop title.
        guard let binary = claudeBinary,
              let range = binary.range(of: "/claude-code/") else { return nil }
        let storeRoot = String(binary[..<range.lowerBound]) + "/claude-code-sessions"

        let fm = FileManager.default
        guard let subpaths = try? fm.subpathsOfDirectory(atPath: storeRoot) else { return nil }

        let needle = "\"\(cliSessionId)\"".data(using: .utf8)!
        for sub in subpaths {
            let name = (sub as NSString).lastPathComponent
            guard name.hasPrefix("local_"), name.hasSuffix(".json") else { continue }
            let url = URL(fileURLWithPath: storeRoot).appendingPathComponent(sub)
            guard let data = try? Data(contentsOf: url), data.range(of: needle) != nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let prior = json["priorCliSessionIds"] as? [String] ?? []
            if json["cliSessionId"] as? String == cliSessionId || prior.contains(cliSessionId) {
                if let title = json["title"] as? String, !title.isEmpty {
                    return title
                }
                return nil
            }
        }
        return nil
    }
}
