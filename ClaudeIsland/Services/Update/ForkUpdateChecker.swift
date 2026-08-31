//
//  ForkUpdateChecker.swift
//  ClaudeIsland
//
//  Silent GitHub check for commits newer than this build. No downloads and
//  no Sparkle — the settings menu just shows "Update available" with an info
//  icon linking to the README's update instructions.
//

import Foundation
import SwiftUI

@MainActor
final class ForkUpdateChecker: ObservableObject {
    static let shared = ForkUpdateChecker()

    @Published var updateAvailable = false

    static let updateInstructionsURL = "https://github.com/AfrazSyed6434/vibe-notch/tree/afraz-fork#updating"
    private static let apiURL = URL(string: "https://api.github.com/repos/AfrazSyed6434/vibe-notch/commits/afraz-fork")!
    private static let checkIntervalNs: UInt64 = 6 * 60 * 60 * 1_000_000_000

    private var started = false

    func start() {
        guard !started else { return }
        started = true
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.check()
                try? await Task.sleep(nanoseconds: Self.checkIntervalNs)
            }
        }
    }

    private func check() async {
        guard let buildDate = Self.buildDate() else { return }
        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = json["commit"] as? [String: Any],
              let committer = commit["committer"] as? [String: Any],
              let dateString = committer["date"] as? String,
              let remoteDate = ISO8601DateFormatter().date(from: dateString) else { return }
        // 10 min slack — the push usually lands moments after the local build
        updateAvailable = remoteDate > buildDate.addingTimeInterval(600)
    }

    /// The binary's own modification date stands in for a build timestamp,
    /// so nothing needs to be injected at build time.
    private static func buildDate() -> Date? {
        guard let url = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return attrs[.modificationDate] as? Date
    }
}
