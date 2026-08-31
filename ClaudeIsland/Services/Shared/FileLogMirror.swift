//
//  FileLogMirror.swift
//  ClaudeIsland
//
//  Mirrors the app's own os_log output (subsystem com.claudeisland) to
//  ~/Library/Logs/VibeNotch.log so issues can be inspected or reported
//  without running `log stream` in a terminal. Rotates at 5 MB.
//

import Foundation
import OSLog

actor FileLogMirror {
    static let shared = FileLogMirror()

    private var running = false
    private var lastDate = Date()
    private let pollSeconds: UInt64 = 10
    private let maxBytes: UInt64 = 5_000_000
    private let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/VibeNotch.log")

    func start() {
        guard !running else { return }
        running = true
        Task {
            while await self.running {
                await self.mirrorNewEntries()
                try? await Task.sleep(nanoseconds: self.pollSeconds * 1_000_000_000)
            }
        }
    }

    private func mirrorNewEntries() {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return }
        let position = store.position(date: lastDate)
        guard let entries = try? store.getEntries(at: position) else { return }

        let formatter = ISO8601DateFormatter()
        var lines = ""
        var newest = lastDate
        for entry in entries {
            guard let log = entry as? OSLogEntryLog,
                  log.subsystem == "com.claudeisland",
                  log.date > lastDate else { continue }
            lines += "\(formatter.string(from: log.date)) [\(log.category)] \(log.composedMessage)\n"
            if log.date > newest { newest = log.date }
        }
        lastDate = newest

        guard !lines.isEmpty, let data = lines.data(using: .utf8) else { return }
        rotateIfNeeded()
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            FileManager.default.createFile(atPath: logURL.path, contents: data)
        }
    }

    private func rotateIfNeeded() {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: logURL.path),
              let size = attrs[.size] as? UInt64, size > maxBytes else { return }
        let old = logURL.deletingPathExtension().appendingPathExtension("old.log")
        try? fm.removeItem(at: old)
        try? fm.moveItem(at: logURL, to: old)
    }
}
