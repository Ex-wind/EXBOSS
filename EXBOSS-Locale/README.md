# EXBOSS-Locale

Localization files for the [EXBoss](https://github.com/Ex-wind) World of Warcraft addon.  
Covers zhCN, zhTW, enUS, and placeholder files for other supported locales.

---

## How to Contribute

### Option 1 — Pull Request (preferred)

If you are familiar with GitHub, fork this repository, edit the relevant language file, and open a Pull Request.  
Each file is named after its locale code, e.g. `enUS.lua`, `deDE.lua`, `frFR.lua`.

```lua
L["Settings"] = "Einstellungen"   -- replace the right-hand side with your language
```

### Option 2 — Submit via Issues

Not comfortable with GitHub? No problem.  
Open a **New Issue** and paste the translated strings directly into the issue body. Please mention which language you are contributing. The author will merge it manually.

### Option 3 — Contact the Author Directly

You can also reach out on Discord: **ex_wind**

---

## About This Repository

Due to historical reasons, **only the localization files are hosted in this public repository**. The rest of the addon's source code remains private for now.

EXBoss launched relatively late this season and grew much faster than anticipated, which left some architectural debt. If you have questions about the addon's internal code, feel free to contact the author directly — we are happy to discuss it.

We are planning a significant architectural refactor in **patch 12.1**, at which point we will reorganize the repository structure and revisit what can be made public. Thank you for your patience and understanding.

---

## File Status

| File | Language | Status |
|------|----------|--------|
| `zhCN.lua` | Simplified Chinese | ✅ Complete |
| `zhTW.lua` | Traditional Chinese | 🔤 English placeholder — contributions welcome |
| `enUS.lua` | English | ✅ Complete |
| `koKR.lua` | Korean | 🔤 English placeholder — contributions welcome |
| `ruRU.lua` | Russian | 🔤 English placeholder — contributions welcome |
| `deDE.lua` | German | 🔤 English placeholder — contributions welcome |
| `frFR.lua` | French | 🔤 English placeholder — contributions welcome |
| `esES.lua` | Spanish (Spain) | 🔤 English placeholder — contributions welcome |
| `esMX.lua` | Spanish (Mexico) | 🔤 English placeholder — contributions welcome |
| `ptBR.lua` | Portuguese (Brazil) | 🔤 English placeholder — contributions welcome |
| `itIT.lua` | Italian | 🔤 English placeholder — contributions welcome |

---

*Thank you to everyone who has contributed translations, testing, and feedback.*
