# Codex Model Shortcuts

Switch OpenAI Codex Desktop model and reasoning presets with one keyboard shortcut on macOS.

This is an unofficial, open-source [Hammerspoon](https://www.hammerspoon.org/) configuration. It opens Codex's model picker, runs a configurable keyboard sequence, closes the picker, and returns focus to the message composer.

## How to select a model in Codex with a keyboard shortcut

Codex Desktop provides a shortcut for opening the model picker, but it does not currently provide a separate shortcut for every model and reasoning preset. Codex Model Shortcuts adds that missing layer:

1. Press a global shortcut while Codex is the frontmost application.
2. Hammerspoon opens the Codex model picker.
3. A configurable arrow-key sequence selects the model and reasoning effort.
4. The picker closes and focus returns to the Codex input field.

The included presets are:

| Shortcut | Preset | Suggested use |
| --- | --- | --- |
| `Cmd + Shift + K` | GPT-5.6 Luna High | Cost-efficient long-running or overnight tasks |
| `Cmd + Shift + L` | GPT-5.6 Terra High | Fast, focused tasks |
| `Cmd + Shift + M` | GPT-5.6 Sol High | Standard tasks and the default intelligence/speed tradeoff |

The default keys progress from `K` to `M` with increasing benchmark intelligence: Luna High, Terra High, then Sol High.

As of August 2026, these are our practical recommendations based on the current [Artificial Analysis model comparison](https://artificialanalysis.ai/models?models=claude-opus-5%2Cclaude-opus-5-xhigh%2Cclaude-opus-5-high%2Cclaude-opus-5-medium%2Cclaude-fable-5%2Cgrok-4-5%2Cgpt-5-6-sol%2Cgpt-5-6-sol-xhigh%2Cgpt-5-6-sol-high%2Cgpt-5-6-sol-medium%2Cgpt-5-6-terra%2Cgpt-5-6-terra-high%2Cgpt-5-6-terra-xhigh%2Cgpt-5-6-terra-medium%2Cgpt-5-6-terra-low%2Cgpt-5-6-sol-low%2Cgpt-5-6-luna%2Cgpt-5-6-luna-low%2Cgpt-5-6-luna-high%2Cgpt-5-6-luna-xhigh%2Cgpt-5-6-luna-medium%2Cdeepseek-v4-flash%2Cdeepseek-v4-pro-high%2Cmistral-medium-3-5):

- **Terra High** is the fast and capable choice for short tasks.
- **Sol High** offers the best speed-to-intelligence balance for standard tasks.
- **Luna High** offers the best cost-to-intelligence balance for long-running or overnight tasks.

These are project recommendations, not permanent or universal rankings. Benchmarks, prices, available models, and Codex menu layouts can change.

## Install with your coding agent

Use a coding agent with access to your Mac. Copy this prompt with GitHub's copy button and send it to the agent:

```text
Set up the tool from this repository on my Mac: https://github.com/clement0909472/codex-model-shortcuts
```

The agent should follow the installation instructions below. macOS may still require you to approve Hammerspoon's Accessibility permission manually.

### Installation instructions for the agent

When a user asks you to set up this repository, complete the installation on their Mac as follows:

1. Confirm the machine is running macOS and that you have access to a local shell.
2. Inspect the repository and preserve the user's existing Hammerspoon configuration. Never overwrite `~/.hammerspoon/init.lua` or unrelated files.
3. Check whether Hammerspoon is installed. If it is missing and Homebrew is available, run `brew install --cask hammerspoon`. If Homebrew is unavailable, explain the blocker before installing any additional package manager.
4. Create `~/.hammerspoon` if needed and copy `codex-model-shortcuts.lua` from this repository to `~/.hammerspoon/codex-model-shortcuts.lua`.
5. Ensure `~/.hammerspoon/init.lua` contains the following loader exactly once:

   ```lua
   local codexModelShortcuts = dofile(hs.configdir .. "/codex-model-shortcuts.lua")
   codexModelShortcuts.start()
   ```

6. Start Hammerspoon if it is not running. Reload its configuration after changing the files.
7. Check that Hammerspoon has macOS Accessibility access. If it does not, open **System Settings → Privacy & Security → Accessibility** and ask the user to enable Hammerspoon. Do not attempt to bypass macOS permission controls.
8. Verify that the Lua file exists, the loader appears only once, and the configuration loads without an error. Then ask the user to focus Codex and test one shortcut.

Keep the installation idempotent: running it again must update the script without duplicating the loader or deleting the user's existing configuration.

## Requirements

- macOS
- [Codex Desktop](https://openai.com/codex/)
- [Hammerspoon](https://github.com/Hammerspoon/hammerspoon)
- Accessibility permission enabled for Hammerspoon in **System Settings → Privacy & Security → Accessibility**

## Installation

Install Hammerspoon:

```bash
brew install --cask hammerspoon
```

Copy `codex-model-shortcuts.lua` into your Hammerspoon configuration directory:

```bash
cp codex-model-shortcuts.lua ~/.hammerspoon/codex-model-shortcuts.lua
```

Add this to `~/.hammerspoon/init.lua`:

```lua
local codexModelShortcuts = dofile(hs.configdir .. "/codex-model-shortcuts.lua")
codexModelShortcuts.start()
```

Reload Hammerspoon from its menu bar icon, then test a shortcut while Codex is open and focused.

## Customize shortcuts and model presets

Edit `M.config.presets` near the top of `codex-model-shortcuts.lua`.

Each preset has:

- `key`: the letter used with `Cmd + Shift`;
- `label`: the notification displayed after selection;
- `steps`: the exact keyboard sequence sent after the Codex picker opens.

Example:

```lua
{
  key = "L",
  label = "Terra High",
  steps = {
    "down", "right", "down", "return",
    "left", "down", "right", "down", "down", "return",
    "escape",
  },
}
```

To assign another model or reasoning level, open the Codex advanced model picker manually and note the required arrow sequence. Then replace the preset's `steps` list. You can also change `key` to any unused letter.

### Keyboard layout note

The tested defaults use `K`, `L`, and `M`. On a US QWERTY keyboard, `K` and `L` are adjacent while `M` is diagonally below them. If you prefer three keys on the same row, change the shortcuts to `J`, `K`, and `L`.

## Why the focus helper exists

After keyboard navigation, Codex may leave focus on the model control. Pressing Return can then reopen the picker instead of sending the message. This project finds the Codex composer through macOS Accessibility and focuses it directly. If Electron rejects the focus request, it clicks inside the accessible composer frame as a fallback. It does not insert and delete temporary text.

## Troubleshooting

### The wrong model is selected

The Codex menu order may differ because of app updates, account availability, or model rollout changes. Open the picker manually, count the required arrow presses, and update the relevant `steps` list.

### Nothing happens

Confirm that:

- Hammerspoon is running;
- Hammerspoon has Accessibility permission;
- Codex is the frontmost application;
- the shortcut is not already used by another application.

### The picker opens when I press Return

Make sure you are using the latest version of this script, which explicitly restores focus to the Codex composer after the selection sequence.

## Limitations

- The automation depends on Codex's current menu structure and may require updated arrow sequences after a UI change.
- It is currently tested on macOS with a US QWERTY keyboard.
- This project is not affiliated with or endorsed by OpenAI.

## License

[MIT](LICENSE)
