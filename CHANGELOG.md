# Changelog

Changes on this branch after forking from upstream v1.3.

- Removed Mixpanel analytics completely. Nothing is tracked
- Removed auto updates so upstream releases dont overwrite this build
- Sessions show which Claude account they belong to when you run multiple desktop instances (e.g. Work / Personal badges)
- Double click a session row to jump to the app that owns it
- Permission cards show the command description, same text as the in-app dialog
- Commands Claude Code refuses to let hooks approve (like cd + git combos) now show an "Open in app" button instead of Allow/Deny buttons that silently do nothing
- Removed the always-on spinner in the closed notch. Claude icon moved to the right, and a count of sessions waiting for approval shows on the left in amber
- In the expanded view the Claude icon on the right opens settings
- Menu cleaned up: no star on github, no update checks, just a link to this repo
- Sessions show the chat title from the desktop app instead of a truncated first message
- App writes its own log file to `~/Library/Logs/VibeNotch.log` for easy debugging
- Silent update check against this repo — settings shows "Update available" with a link to the update instructions. Nothing downloads automatically
