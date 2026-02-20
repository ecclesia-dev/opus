# opus

**Pray the Traditional Divine Office from your terminal.**

`7 Canonical Hours · 1962 Rubrics · 150 Psalms · POSIX Shell`

A command-line tool for praying the Divine Office (Breviary) according to the 1962 rubrics — the traditional Roman Rite as codified under Pope John XXIII. Outputs the proper hymns, psalms, antiphons, responsories, and prayers for each canonical hour based on the day of the week and liturgical season.

Prayer data from the [Divinum Officium](https://github.com/DivinumOfficium/divinum-officium) project (MIT licensed), bundled in `data/`.

---

## Quick Start

```
$ opus terce

══════════════════════════════════════

  Terce — Third Hour
  Friday, February 20, 2026
══════════════════════════════════════

  ℣. O God, ✠ come to my assistance.
  ℟. O Lord, make haste to help me.

  ── Hymn ──

  Come Holy Ghost who ever One
  Art with the Father and the Son,
  It is the hour, our souls possess
  With thy full flood of holiness.

  ── Psalms ──

  Psalm 79:2-8

  Give ear, O thou that rulest Israel:
  thou that leadest Joseph like a sheep...
```

## Installation

```sh
git clone https://github.com/ecclesia-dev/opus.git
cd opus
sudo make install
```

To uninstall:

```sh
sudo make uninstall
```

## Usage

```
opus [hour]
```

Without arguments, `opus` auto-detects the current hour based on the time of day.

### Hours

| Hour | Time | Command |
|------|------|---------|
| Lauds | ~6 AM | `opus lauds` |
| Prime | ~7 AM | `opus prime` |
| Terce | ~9 AM | `opus terce` |
| Sext | ~12 PM | `opus sext` |
| None | ~3 PM | `opus none` |
| Vespers | ~6 PM | `opus vespers` |
| Compline | ~9 PM | `opus compline` |

### Piping

```sh
opus vespers | say -v Daniel    # read aloud (macOS only)
opus compline | less             # page through
opus terce > terce.txt           # save to file
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OPUS_DATA` | Path to Divinum Officium data | `<script dir>/data` |
| `TZ` | Timezone for date computation | system default |

## What's Included

Each hour outputs the proper:

- **Opening versicle** (*Deus in adjutórium*)
- **Hymn** (varies by hour)
- **Antiphon** (varies by day of week)
- **Psalms** (proper to the day and hour, with verse ranges)
- **Little Chapter** (capitulum)
- **Responsory**
- **Versicle**
- **Closing prayers**
- **Marian antiphon** (Compline)

## Related Projects

Part of the command-line Catholic ecosystem:

| Tool | Description |
|------|-------------|
| **[drb](https://github.com/ecclesia-dev/drb)** | Douay-Rheims Bible with Haydock & Lapide commentary |
| **[opus](https://github.com/ecclesia-dev/opus)** | Traditional Divine Office (1962 Breviary) |

## License

MIT. See [LICENSE](LICENSE) for details.

*℣. Dómine, exáudi oratiónem meam.*
*℟. Et clamor meus ad te véniat.*
