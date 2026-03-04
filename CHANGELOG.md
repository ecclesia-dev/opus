# Changelog

All notable changes to Opus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.2.0] - 2026-03-03

### Added
- Matins with nocturns, invitatory, psalms, lessons from Tempora
- Liturgical calendar: Easter computation, full season detection
- `--date YYYY-MM-DD` flag for any date
- `--latin` / `--english` flags (Latin data pending)
- Seasonal hymns, chapters, responsories for all hours
- Seasonal Marian antiphons at Compline
- Benedictus at Lauds, Magnificat at Vespers with proper antiphons
- Nunc Dimittis at Compline, Te Deum at Sunday Matins
- Saint of the day from Sanctoral cycle
- Collect from Tempora files

### Changed
- Complete rewrite of all 8 hours with proper data file parsing
- Day-of-week psalm rotation for all hours

## [0.1.0] - 2026-03-03

### Added
- Traditional Divine Office (1962 Breviary) in the terminal
- Executable wrapper script
- GitHub Actions CI workflow
- Pre-push hook auto-install script
- Security gitignore patterns
