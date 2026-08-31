//
//  DesktopAppLauncher.swift
//  ClaudeIsland
//
//  Brings the app that owns a session to the front — the correct Claude
//  desktop instance when several run with different --user-data-dir values,
//  or the hosting terminal/IDE for terminal sessions.
//

import AppKit
import Foundation
import os.log

enum DesktopAppLauncher {

    private static let logger = Logger(subsystem: "com.claudeisland", category: "AppLauncher")

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
