# Changelog

## 2026.09.30

Updated for the September 2026 Codex picker, tested with Codex 26.928.21956 (12404).

- Add GPT-6.1 Sol High, GPT-6 Astra XHigh/Low, GPT-6 Luna Max and Astra Low Ultrafast presets on Option + Command + H/J/K/L/M.
- Document ChatGPT Pro $500 USD/month as the supported personal subscription for the complete default preset set, including Ultrafast.
- Open the picker with Control + Shift + M and handle current-position model selection, three-speed Astra menus, and renamed reasoning labels.
- Wait for reasoning changes and focus transitions to avoid repeated arrows, overshooting and rapid-navigation failures. Ignore extra shortcut presses while switching and closing.
- Keep automatic local failure diagnostics, with key and reasoning traces. No automatic uploads.
- Ship a standalone script and portable synthetic tests, with no private tooling dependency.

Manual testing covers the preset configuration. The final rapid-navigation patch passes offline regression tests; an additional native check remains pending. Account/subscription switching is outside this project and this release.
