# Codex Model Shortcuts

Keyboard presets for Codex Desktop on macOS, using Hammerspoon.

## Shortcuts

| Shortcut | Model | Reasoning | Speed |
| --- | --- | --- | --- |
| Option + Command + M | GPT-6 Astra | High | Standard |
| Option + Command + L | GPT-6 Astra | Low | Standard |
| Option + Command + K | GPT-6 Sol | High | Standard |
| Option + Command + J | GPT-6 Luna | Max | Standard |
| Option + Command + H | GPT-6 Astra | Low | Fast |

Shortcuts only act while Codex is frontmost. The script locates the model button
through macOS Accessibility and clicks its current frame, rather than opening
recent models with Ctrl + Shift + M. The opening click was manually validated
by the user in September 2026.

It reads the displayed model and effort to calculate the minimum arrow presses.
If the model is already selected, it skips the model submenu entirely.
For example, Luna Max to Astra High uses two Left presses. Switching from Ultra
to Luna accounts for Codex's fallback to Medium, then uses three Right presses
to reach Max. Speed is toggled only if its accessible state differs from the
requested preset. Codex restores composer focus itself; the script does not
refocus or click the input after selection, preserving the typing caret.
The final action is Return on reasoning, with no subsequent Escape or success
notification.

## Install or update

Requires macOS, Codex Desktop, [Hammerspoon](https://www.hammerspoon.org/), and
Accessibility permission for Hammerspoon.

1. Preserve the existing Hammerspoon configuration and make a backup.
2. Copy `codex-model-shortcuts.lua` into `~/.hammerspoon/`.
3. Add this loader once to `~/.hammerspoon/init.lua`:

   ```lua
   local codexModelShortcuts = dofile(hs.configdir .. "/codex-model-shortcuts.lua")
   codexModelShortcuts.start()
   ```

4. Remove earlier bindings for these Codex shortcuts or replace the test loader
   `startPickerTest()` with `start()` to avoid duplicate bindings.
5. Choose **Reload Config** in Hammerspoon, focus Codex, and test the presets.

For an opening-only diagnostic, use `startPickerTest()` instead of `start()`;
Option + Command + M will only open the picker.

## Validation and troubleshooting

Run `lua test-picker.lua`. Tests use a mocked Accessibility tree and keyboard
state machine, including 170 model/effort/speed transitions. They do not control
Codex. The shortcut behavior, including Fast switching and native focus restoration,
was manually tested in Codex Desktop on the author’s Mac.

If the current model/effort cannot be read, the script stops before opening the
picker. If Speed's state cannot be read, it stops on Speed with an alert; the
model may already have changed. It never assumes Fast is off. Share the exact
alert when reporting a failure. Unknown or ambiguous model buttons also stop
execution instead of guessing a click.

The menu order follows the user's September 2026 screenshots. Displayed model
and effort labels are recognized in French and English. Menu changes, other
languages, or inaccessible toggle states may require an update. Animation
waits can be adjusted in `M.config.timing`: 200 ms for the main picker,
160 ms for the model submenu, 80 ms after model selection, 60 ms after a speed
toggle, and 20 ms between plain navigation keys. These are configured waits,
not measured end-to-end latency. Switching applications or windows
interrupts the sequence.

This unofficial project is not affiliated with OpenAI.

## License

[MIT](LICENSE)
