# Changelog

## 2026.10.09

- Add Option + Command + G for GPT-6.1 Sol **Low + Ultrafast**. Existing H/J/K/L/M presets keep their settings.
- Support the Sol 6.1 Standard/Fast/Ultrafast speed menu.
- Fix switching after reopening the picker on another control and wait for delayed picker/model focus before sending another arrow or Enter. This includes the Astra-to-Sol route used by K.
- Add picker-opening readings to local failure reports and lifecycle traces to the Hammerspoon console. Reports are never uploaded automatically.

Validation: 10,176 simulated transitions plus targeted regression checks pass; the maintainer confirmed the updated shortcuts work in the native app. Other accounts and model catalogs remain unverified.

## 2026.09.30

Updated for the September 2026 Codex picker, tested with Codex 26.928.21956 (12404).

- Add GPT-6.1 Sol High, GPT-6 Astra XHigh/Low, GPT-6 Luna Max and Astra Low Ultrafast presets on Option + Command + H/J/K/L/M.
- Document ChatGPT Pro $500 USD/month as the supported personal subscription for the complete default preset set, including Ultrafast.
- Open the picker with Control + Shift + M and handle current-position model selection, three-speed Astra menus, and renamed reasoning labels.
- Wait for reasoning changes and focus transitions to avoid repeated arrows, overshooting and rapid-navigation failures. Ignore extra shortcut presses while switching and closing.
- Keep automatic local failure diagnostics, with key and reasoning traces. No automatic uploads.
- Ship a standalone script and portable synthetic tests, with no private tooling dependency.

Manual testing covers the preset configuration. The final rapid-navigation patch passes offline regression tests; an additional native check remains pending. Account/subscription switching is outside this project and this release.
