# Codex Model Shortcuts

Five keyboard presets for the September 2026 Codex desktop model picker on macOS, using [Hammerspoon](https://www.hammerspoon.org/).

**Supported setup for the complete default preset set: ChatGPT Pro $500/month (USD), with GPT-6 Astra, GPT-6.1 Sol, GPT-6 Luna and Astra Ultrafast available in the picker.** Other personal plans are not supported by these defaults as-is, because H requires Astra Ultrafast. The script does not grant model access or change your subscription.

OpenAI also lists eligible Enterprise/Edu access to Ultrafast; those configurations have not been validated by this project. See the official [plan pricing](https://learn.chatgpt.com/docs/pricing) and [Ultrafast availability](https://learn.chatgpt.com/docs/agent-configuration/speed#ultrafast-mode). Prices here are USD, not a claim about local euro pricing.

Updated for Codex **26.928.21956 (build 12404)** on September 30, 2026. The full preset configuration was exercised manually by the maintainer; the final rapid-navigation patch has regression-test coverage and awaits an additional manual check. Future Codex releases may change the picker.

## Shortcuts

| Shortcut | Model | Reasoning | Speed |
| --- | --- | --- | --- |
| Option + Command + M | GPT-6 Astra | XHigh / Très élevé | Standard |
| Option + Command + L | GPT-6 Astra | Low / Minimal | Standard |
| Option + Command + K | GPT-6.1 Sol | High / Élevé | Standard |
| Option + Command + J | GPT-6 Luna | Max / Maximum | Standard |
| Option + Command + H | GPT-6 Astra | Low / Minimal | Ultrafast |

Low can appear as Minimal or Léger. Medium/High can be announced as Standard/Extended by the accessibility layer. Ultra reasoning and Ultrafast speed are different settings; none of these presets requests Ultra reasoning.

## Install or update

Requirements: macOS, Codex Desktop, Hammerspoon, and macOS Accessibility permission for Hammerspoon. The supported picker labels are French and English.

1. Download or clone this repository. Preserve your existing Hammerspoon configuration.
2. Copy `codex-model-shortcuts.lua` into `~/.hammerspoon/`. No other repository or private tooling is required.
3. Add this loader **once** to `~/.hammerspoon/init.lua`:

   ```lua
   local codexModelShortcuts = dofile(hs.configdir .. "/codex-model-shortcuts.lua")
   codexModelShortcuts.start()
   ```

4. Remove conflicting older bindings for these shortcuts. In Hammerspoon, select **Reload Config**. Do not overwrite unrelated configuration.
5. With Codex focused and its picker closed, test a preset. Allow the picker to close before pressing another shortcut.

If needed, install Hammerspoon with `brew install --cask hammerspoon`. Enable its Accessibility permission manually under **System Settings → Privacy & Security → Accessibility**. Lua is only needed separately to run the offline tests.

## How it works

The script opens the native picker with Control + Shift + M. It reads the focused model in the list when the initial control only says “Select model”, then calculates the relative arrow movement. It supports Astra's Standard/Fast/Ultrafast menu and the Standard/Fast toggle on other models.

Navigation waits for focus to move between Speed, Reset and Power; it never activates Reset. Reasoning is read from the control or its adjacent live status. Each Left/Right press must produce the expected next level before another is sent. Stale values, contradictory labels, disabled controls and unexpected focus stop the sequence. A short closing delay prevents another preset from reopening a picker that is still closing. Extra preset presses during a switch are ignored rather than queued.

The last selection action is Enter on Power. There is no mouse click, account switch, message submission or extra composer-focus operation. App/window changes cancel the sequence. A legacy custom-app bundle ID remains recognized for compatibility but is not part of this release's validation.

## Diagnostics

Diagnostics remain enabled. On failure, the script writes the latest local report to:

```text
~/.hammerspoon/codex-model-shortcuts/diagnostic.json
```

It records the requested preset, sent keys, model/effort readings and bounded accessibility details of the relevant controls. `completed: false` means the preset did not finish; earlier changes are not automatically rolled back. The next failure overwrites the previous report.

For a separate read-only probe, start with the picker closed and press **Control + Option + Command + D**. It opens the picker, samples it and reveals the report in Finder without selecting a model.

Reports are not uploaded automatically. They are intended to exclude conversation fields, but accessibility labels can still contain private information: review and redact a report before sharing it. Do not commit real diagnostics, screenshots, account files or credentials. The repository contains only synthetic tests and ignores diagnostic output.

`M.config.diagnosticDirectory` can override the report directory. The parent directory must already exist. Presets and timing values are also configurable near the top of the script; model availability and menu order must match your account. Unsupported plans and model catalogs need their own validation.

## Validation

```sh
lua test-picker.lua
luac -p codex-model-shortcuts.lua
luac -p test-picker.lua
```

Tests use a simulated accessibility tree and keyboard state machine. They cover the preset matrix, real-observed label formats recreated with synthetic data, delayed reasoning updates, delayed focus, cancellation and rapid repeated shortcuts. They do not control Codex or prove every native/account configuration works. On a new app release, verify the resulting model, reasoning and speed visually.

If a shortcut stops, close the picker before retrying and inspect the report. Do not keep retrying a sequence that repeatedly fails.

See [CHANGELOG.md](CHANGELOG.md) for release notes. This unofficial project is not affiliated with or endorsed by OpenAI.

## License

[MIT](LICENSE)
