# EXBoss

A World of Warcraft addon for boss timer tracking, trash CD monitoring, voice alerts, and encounter assistance.

## Included Addons

| Addon | Description |
|-------|-------------|
| `ExwindCore` | Shared framework (required) |
| `EXBoss` | Main addon — timers, alerts, voice, conditions |
| `EXBossData` | Encounter data (auto-generated) |
| `EXBOSS-LocaleBase` | Locale framework |
| `EXBOSS-EXWIND` | EXWIND voice pack (Chinese) |
| `EXBOSS-ENG` | English voice pack |

## Installation

Download from [CurseForge](https://www.curseforge.com/wow/addons/exboss) or [Wago](https://addons.wago.io/).

Place all addon folders into:
```
World of Warcraft\_retail_\Interface\AddOns\
```

## Contributing

Pull requests welcome! Please target the `EXBoss/` folder for most contributions.

## Community Translations

[EXBOSS-Locale](https://github.com/Ex-wind/EXBOSS-Locale)

## Project Relationships and Localization

### Runtime Dependencies

- `EXBoss/EXBoss.toc` declares `ExwindCore`, `EXBossData`, and `EXBOSS-Locale` as required dependencies.
- [EXWINDCORE](https://github.com/Ex-wind/EXWINDCORE) provides the shared framework. Install its `ExwindCore` addon directory alongside EXBOSS.
- `EXBossData`, `EXBOSS-LocaleBase`, and `EXBOSS-Locale` are included in this repository and must remain together in the same addon package.
- [ExwindTools](https://github.com/Ex-wind/ExwindTools) also depends on EXWINDCORE, but it is not required by EXBOSS. Both addons use the shared core.

### Localization

- EXBOSS locale pack: [EXBOSS-Locale](EXBOSS-Locale)
- Locale framework entry point: [EXBOSS-LocaleBase/LocaleInit.lua](EXBOSS-LocaleBase/LocaleInit.lua)
- EXBOSS addon locale entry point: [EXBoss/Locale/Init.lua](EXBoss/Locale/Init.lua)
- Dungeon trash ability names: [EXBossData/TrashCDLocale.lua](EXBossData/TrashCDLocale.lua)
- Shared UI localization: [EXWINDCORE Locale](https://github.com/Ex-wind/EXWINDCORE/tree/main/ExwindCore/Locale)
