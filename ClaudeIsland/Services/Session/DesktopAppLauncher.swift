//
//  DesktopAppLauncher.swift
//  ClaudeIsland
//
//  Opens a session's chat in the owning Claude desktop app instance via the
//  claude://code/<local_sessionId> deep link. The desktop apps keep a
//  per-session JSON store mapping their internal local_* ids to the CLI
//  session id that hooks report, and the deep link routes to the correct
//  instance (work/personal user-data-dir) automatically.
//

import AppKit
import Foundation
import os.log

enum DesktopAppLauncher {

    private static let logger = Logger(subsystem: "com.claudeisland", category: "AppLauncher")

    /// Session store roots, one per desktop instance (user-data-dir)
    private static var storeRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".claude-work-desktop/claude-code-sessions"),
            home.appendingPathComponent("Library/Application Support/Claude/claude-code-sessions"),
        ]
    }

    /// Bring the app that owns this session to the front — the correct Claude
    /// desktop instance (work/personal, resolved by pid, since both share one
    /// bundle id), or the hosting terminal/IDE for terminal sessions.
    ///
    /// Chat-level navigation via claude:// deep links is deliberately not used:
    /// tested forms either don't navigate (/code/<id>), route to an arbitrary
    /// instance (LaunchServices), or open a new window with a blank chat
    /// (continue?session=). Activation of the existing window is the only
    /// side-effect-free behavior.
    @discardableResult
    static func open(session: SessionState) -> Bool {
        logger.info("activate requested for \(session.sessionId.prefix(8), privacy: .public) pid:\(session.pid ?? -1, privacy: .public)")
        return activateOwningApp(pid: session.pid)
    }

    /// Scan the desktop session stores for the local_* session whose
    /// cliSessionId (current or prior) matches the hook-reported session id.
    private static func findLocalSessionId(cliSessionId: String, claudeBinary: String?) -> String? {
        let fm = FileManager.default
        var roots = storeRoots
        // Search the session's own account store first
        if let binary = claudeBinary {
            roots.sort { a, _ in
                binary.contains("/.claude-work-desktop/") == a.path.contains("/.claude-work-desktop/")
            }
        }
        let needle = "\"\(cliSessionId)\""
        for root in roots {
            guard let subpaths = try? fm.subpathsOfDirectory(atPath: root.path) else { continue }
            for sub in subpaths {
                let name = (sub as NSString).lastPathComponent
                guard name.hasPrefix("local_"), name.hasSuffix(".json") else { continue }
                let url = root.appendingPathComponent(sub)
                guard let data = try? Data(contentsOf: url),
                      let text = String(data: data, encoding: .utf8),
                      text.contains(needle),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                let prior = json["priorCliSessionIds"] as? [String] ?? []
                if json["cliSessionId"] as? String == cliSessionId || prior.contains(cliSessionId) {
                    return json["sessionId"] as? String
                }
            }
        }
        return nil
    }

    /// Walk the process tree from the session's pid up to the root Claude app
    /// process and activate it by pid — necessary because both desktop
    /// instances share one bundle identifier.
    private static func activateOwningApp(pid: Int?) -> Bool {
        guard let sessionPid = pid else { return false }
        let tree = ProcessTreeBuilder.shared.buildTree()
        var current = sessionPid
        var hops = 0
        var lastAppPid: Int?
        while hops < 20, let info = tree[current] {
            if info.command.hasPrefix("/Applications/Claude.app/Contents/MacOS/Claude") {
                logger.info("activating Claude instance pid \(info.pid, privacy: .public)")
                NSRunningApplication(processIdentifier: pid_t(info.pid))?.activate(options: [.activateIgnoringOtherApps])
                return true
            }
            // Remember the nearest GUI-app ancestor (terminal emulator, IDE)
            // as the fallback for terminal sessions
            if info.command.contains(".app/Contents/MacOS/") {
                lastAppPid = info.pid
            }
            current = info.ppid
            hops += 1
        }
        if let appPid = lastAppPid {
            logger.info("activating host app pid \(appPid, privacy: .public)")
            NSRunningApplication(processIdentifier: pid_t(appPid))?.activate(options: [.activateIgnoringOtherApps])
            return true
        }
        logger.warning("no app ancestor found for pid \(sessionPid, privacy: .public)")
        return false
    }
}
