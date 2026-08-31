<div align="center">
  <img src="ClaudeIsland/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">Vibe Notch — multi-account fork</h3>
  <p align="center">
    Dynamic Island-style monitoring for Claude Code sessions, with support for multiple Claude desktop accounts.
    <br />
    Fork of <a href="https://github.com/farouqaldori/vibe-notch">farouqaldori/vibe-notch</a>. See <a href="CHANGELOG.md">CHANGELOG.md</a> for what changed.
  </p>
</div>

## What it does

- Shows every live Claude Code session in the notch — desktop app and terminal — with working / waiting-for-approval / idle states
- Approve or deny permission prompts directly from the notch
- Badges each session with the Claude account it belongs to when you run multiple desktop instances
- Double click a session to jump to the app that owns it
- No analytics, no auto updates

## Requirements

- macOS 15.6+
- Xcode (to build)
- Claude Code (CLI or the Claude desktop app)

## Build and run

No prebuilt releases on this fork — build from source:

```bash
git clone -b afraz-fork https://github.com/AfrazSyed6434/vibe-notch
cd vibe-notch
xcodebuild -scheme ClaudeIsland -configuration Release -derivedDataPath build \
  -destination 'platform=macOS' build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=
codesign --force --deep -s - "build/Build/Products/Release/Vibe Notch.app"
open "build/Build/Products/Release/Vibe Notch.app"
```

The `codesign --force --deep` step is required — the bundled Sparkle framework keeps its upstream signature and the app wont launch without re-signing everything ad-hoc.

On first launch the app installs Claude Code hooks into `~/.claude/settings.json` and a hook script at `~/.claude/hooks/claude-island-state.py`. Thats all the setup — sessions appear in the notch as they run.

## Single account

Nothing to configure. Run Claude Code (terminal or desktop app) and sessions show up.

## Multiple accounts

Run a second Claude desktop instance with its own data dir:

```bash
open -n /Applications/Claude.app --args --user-data-dir="$HOME/.claude-work-desktop"
```

Sessions from each instance get a badge named after the data dir — `.claude-work-desktop` shows as **Work**, the default install shows as **Personal**. Any dir name works: `.claude-<name>-desktop` becomes `<Name>`.

Both instances share `~/.claude` for config by default, so one hook install covers everything. Double clicking a session row activates the instance that owns it.

## Permission prompts

Normal prompts get Allow / Deny buttons in the notch. Some commands are security-flagged by Claude Code itself (`cd` + `git` combos, `curl | bash`, force pushes) and it ignores hook approvals for those — the notch shows an **Open in app** button instead, which brings the right app forward so you can answer there.

## License

Apache 2.0 — same as upstream.
