# AGENTS.md

Uzbek speech-to-text dictation app for **macOS and Windows**. Same model, same
inference parameters, two native implementations.

- **macOS** — single-file Swift (`src/dictate.swift`) + C shim over whisper.cpp (Metal).
  Documented below.
- **Windows** — C++20 / Win32 in `win/` (Vulkan). See **`win/README.md`** for its build,
  layout and conventions; **`WINDOWS-PORT-PLAN.md`** for the porting decisions and the
  bugs found during testing.

`win/core/whisper_bridge.c` is a near-verbatim copy of `src/whisper_bridge.c` — keep the
inference parameters (language `uz`, beam size 5, `no_speech_thold 0.25`) identical in both
so the two platforms produce the same output.

No package manager, no test suite on either side.

## Language

All comments, `NSLog` strings, and user-facing UI text are in **Uzbek**. Match that when editing.

## Build & iterate

- `./setup.sh` — full one-time install (deps → whisper.cpp static libs → model → app → login agent)
- `src/build.sh` — rebuild only the app. Requires `whisper.cpp/build-static/` (created by `setup.sh`). Output: `~/Applications/RubaiSTT Dictation.app`. If the LaunchAgent is loaded it restarts it (`launchctl kickstart -k`), so the new build is live immediately.
- `./doctor.sh` — read-only health check (signature, LaunchAgent, permissions, model, crashes). Run it after any change; `setup.sh` runs it at the end.
- `scripts/make_signing_cert.sh` — creates (once) the self-signed "RubaiSTT Local Signing" cert in the login keychain; `scripts/install_launchagent.sh` — writes + (re)bootstraps the LaunchAgent.
- `scripts/release.sh` — Developer ID sign + notarize + bundle model inside `.app` + produce DMG at `dist/RubaiSTT-Dictation.dmg`.

No linter, typechecker, or test runner exists.

## Key conventions & gotchas

- **Model**: `~/rubai-stt/models/ggml-rubaistt.bin` (q8_0). The DMG app reads a copy at `Contents/Resources/ggml-rubaistt.bin`.
- **Info.plist** and **codesign** are generated inside `src/build.sh` — edit them there, not as separate files. Local builds are signed with the self-signed **"RubaiSTT Local Signing"** cert (login keychain, made by `scripts/make_signing_cert.sh`), so the designated requirement is `identifier + certificate leaf`, **not** cdhash — macOS TCC (Accessibility/Microphone) grants survive rebuilds. Never go back to ad-hoc (`-s -`): every rebuild would silently revoke Accessibility. `scripts/release.sh` re-signs with Developer ID + hardened runtime.
- **Entitlements** (`src/entitlements.plist`): only `audio-input` + `allow-jit`.
- **whisper_context** is a process-global C singleton (`whisper_bridge.c:6`). `rubai_transcribe` mallocs the result string — the Swift caller **must** call `rubai_free_str` on it.
- **Recorder** creates a **new `AVAudioEngine`** on every `start()` to avoid a stuck-state bug after login/device change.
- **Hotkey** is persisted in `UserDefaults` under keys `hk.keyCode`, `hk.mods`, `hk.label`. Default: ⌃⌥D.
- **Login item**: DMG distribution uses `SMAppService.mainApp` (macOS 13+). `setup.sh` installs a `LaunchAgent` at `~/Library/LaunchAgents/com.rubaistt.dictation.plist` that runs the bundle executable **directly** with `KeepAlive=true` (not `/usr/bin/open` — that exits immediately and defeats KeepAlive). When the app detects it's LaunchAgent-managed (`XPC_SERVICE_NAME` / plist present) it unregisters SMAppService and disables the menu toggle — both at once launched two instances (double paste). A single-instance guard keeps the launchd copy and terminates others.
- **Logs**: `~/Library/Logs/rubaistt/app.log` (RubaiLog, 5 MB rotation) + `launchd.out/err.log`. Crash reports: `~/Library/Logs/DiagnosticReports/RubaiSTTDictation-*.ips`.
- **Recorder** keeps stopped `AVAudioEngine`s alive 3 s (`retired`) — freeing them immediately crashed in CoreAudio's HAL IO thread.
- **Hotkey** toggles are debounced (400 ms; Carbon repeats `kEventHotKeyPressed` while held) and ignored while a transcription is running.
- **Idle unload**: model is freed from RAM after 180s of inactivity.
- **Permissions** required: Microphone (on first record) + Accessibility (for synthetic ⌘V). `AXIsProcessTrusted()` is polled every 5 s: icon switches `mic.fill` ↔ `mic.slash`, a UNUserNotification is posted once per loss (click opens the Accessibility pane).

## Architecture

Three layers, ObjC-C-bridged:
1. **`src/whisper_bridge.c` / `.h`** — C shim. Exposes `rubai_load`, `rubai_unload`, `rubai_transcribe`, `rubai_free_str`. Params: language `uz`, beam search size 5, no timestamps, GPU + flash attention.
2. **`src/Bridging.h`** — `#include "whisper_bridge.h"` imported via `-import-objc-header`.
3. **`src/dictate.swift`** — the whole app, organized by `// MARK:` sections: `Whisper` → `Recorder` → `Overlay` → `Inserter` → `HotKey*` → `SettingsWindow` → `LoginItem` → `WelcomeWindow` → `AppDelegate`.

Data flow per dictation: ⌃⌥D → `Recorder.start` (mic → 16 kHz float32) → ⌃⌥D → `Recorder.stop` → `Whisper.transcribe` (off main thread, Metal) → `Inserter.insert` (clipboard + ⌘V).

## Gitignored artifacts

`whisper.cpp/`, `*.bin`, `.venv/`, `.assets/`, `dist/`, `assets/dmg-bg.png` — fetched/built, never committed.
