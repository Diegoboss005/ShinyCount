# ✨ ShinyCount

**ShinyCount** is a native macOS app for tracking shiny Pokémon encounters. Built for shiny hunters who want a fast, keyboard-driven counter that works alongside their setup — including Stream Deck support.

![Version](https://img.shields.io/badge/version-0.8-blue) ![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey) ![Swift](https://img.shields.io/badge/swift-5.9-orange)

---

## Features

- **Multiple hunts** — track several Pokémon at the same time from the sidebar
- **Shiny sprites** — high quality official Home sprites for every Pokémon
- **Global macros** — assign any key to a counter action (works great with Stream Deck)
- **Auto-save** — each hunt saves automatically to its own `.txt` file
- **Collection** — completed shinys are saved with encounter count and date
- **Appearance** — light, dark or system theme
- **Import / Export** — restore your counter from a `.txt` file

---

## Installation

1. Download the latest `ShinyCount.app.zip` from [Releases](../../releases)
2. Unzip and drag `ShinyCount.app` to your Applications folder
3. Right-click → **Open** the first time (required because the app is not notarized)

**Requirements:** macOS 14 Sonoma or later

---

## Stream Deck Setup

ShinyCount works with Stream Deck out of the box — no plugin needed.

1. Create a macro in ShinyCount and assign a key (e.g. `F`)
2. In Stream Deck, add a **Hotkey** action and set it to that same key
3. Press the Stream Deck button → ShinyCount counts

---

## Building from Source

**Requirements:** Xcode 15 or later

```bash
git clone https://github.com/YOURUSERNAME/ShinyCount.git
cd ShinyCount
open ShinyCount.xcodeproj
```

Press `⌘R` to build and run.

---

## Roadmap

- [ ] Stream Deck native plugin (LCD counter display)
- [ ] Pokémon game & method selector when creating a hunt
- [ ] Statistics and odds calculator
- [ ] iCloud sync

---

## Contributing

Pull requests are welcome. For major changes please open an issue first.

---

## License

MIT License — free to use, modify and distribute.

---

## Support

If you find ShinyCount useful, consider buying me a coffee ☕

> *(Ko-fi / PayPal link coming soon)*

---

*Made with ❤️ for the shiny hunting community*
