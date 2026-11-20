# The Terminal List

A personal watch list for **World of Warcraft: Forever**. It keeps track of players who crossed you, were rude, or
just don't play nice, on **both factions**, and marks them so you recognise them next time: a **red crosshair** beside
their nameplate and on the target frame, a line on their tooltip, and a mark on their chat lines.

It's a sibling of [Andric's Addon](https://andricsaddon.myazerothlife.com),
[Parzelle's Addon](https://parzelles-addon.myazerothlife.com),
[Tristan's Addon](https://tristans-addon.myazerothlife.com),
[Tazu's Addon](https://github.com/ninepointlabs/tazus-addon) and
[Forever Rogue](https://github.com/ninepointlabs/forever-rogue), and uses their window style. It isn't a class addon.

> **Status:** [v0.1.0](https://github.com/ninepointlabs/the-terminal-list/releases/latest). Early in-game testing; see `STATUS.md` for the checklist.

- WoW Forever only (`WOW_PROJECT_ID 18`), Interface `16001`. No Ace3; Blizzard API only. MIT.
- The list is stored **only on your computer**, in the account's saved variables (`TheTerminalListDB`). Every character
  on the account sees the same list. Nothing is uploaded or shared.

## Install

### With OmaForge (Linux)

```sh
omaforge install -c forever github:ninepointlabs/the-terminal-list
omaforge update -c forever          # later versions
```

### By hand (any OS)

Download the zip from [GitHub Releases](https://github.com/ninepointlabs/the-terminal-list/releases) and unzip it so the
folder is `World of Warcraft/_forever_/Interface/AddOns/TheTerminalList`. From a checkout,
`tools/install-dev.sh <AddOns folder>` copies only the files WoW needs. Then `/reload` and `/tlist`.

## Using it

| Command | What it does |
|---|---|
| `/tlist` | open or close the window |
| `/tlist add [Name[-Realm]] [note]` | add a player; no name = your current target |
| `/tlist remove [Name[-Realm]]` | remove; no name = your current target |
| `/tlist note [Name[-Realm]] [text]` | set the reason note (no text opens an editor) |
| `/tlist search <text>` | open the list filtered by name, realm, note, zone, race or class |
| `/tlist settings` | settings |
| `/tlist help` | the commands |

- **Right-click** a player's portrait (target, focus, party, raid) or their name in chat: **Add to The Terminal List**, or
  for someone already listed, **Edit note** / **Remove from The Terminal List**.
- The **window** (`/tlist`, the minimap button or the addon compartment) lists everyone with name-realm, race, class,
  faction, note, how they were added (manual or PvP kill), kill count, date and zone. You can search, filter by
  PvP/manual, sort (newest, most kills, name), edit notes and remove people there.
- Adding someone who's already listed never makes a second row; you're offered the note editor instead.

### Open-world PvP deaths

When another player kills you **in the open world**, they're added to the list (source "PvP kill", 1 kill). If the same
player kills you again, their kill count goes up instead of adding a new row.

These never count: **battlegrounds, arenas, dungeons, raids, scenarios or any other instance, and duels.** That's PvP
you chose. A world PvP flag doesn't stop it, because flagged open-world PvP is exactly what this is for.

An optional setting, **off by default**, also adds everyone who hit you in the last few seconds (default 8 s, 4–12 s)
before the killing blow.

**Caveat:** sister-addon research says Forever doesn't give addons the combat log, and without it no addon can see who
landed the killing blow. If that's the case on your client, the addon doesn't guess. After an open-world death it
asks: "You were fighting <your hostile target>. Add them?" If you had no hostile target, it tells you how to add
someone by hand. When the combat log is available, killers are added automatically, including a player whose pet got
the kill (if the owner is in view).

### Recognising them

All on by default except the alert; each can be switched off in Settings › Recognition.

- **Nameplates:** a red crosshair beside the name. Nameplates only show at fairly close range, so turn on player
  nameplates in the game's options. Blizzard's own nameplates are used; Plater etc. aren't needed.
- **Target frame:** a small crosshair on the portrait.
- **Tooltip:** "On The Terminal List", their note, kill count and how they were added.
- **Chat:** a crosshair in front of their lines, and their name in red when someone mentions them. The clickable
  `[Name]` itself keeps its normal colour, because addons can't recolour it safely.
- **Alert (off by default):** the first time each session you see a listed player (nameplate, target, mouse-over), a
  chat line, a raid-warning message and a short built-in sound.

### Limits

- **Identity is Name-Realm.** If a player renames or transfers realms, they show up as someone new; their old entry stays
  as it was.
- Forever characters can have an optional last name. The addon keys people by first name + realm and shows the last name.
- Inside instances, Forever hides chat and unit details from addons, so marks may not show there.

No keybinds, macros or `/click`.

## Development

```sh
lua5.1 tests/run.lua                 # headless tests against a strict WoW mock
python3 tools/make-crosshair.py      # redraw Media/Crosshair.tga
```

CI (`.github/workflows/test.yml`) runs a syntax check and the tests. `release.yml` packages a `v*` tag with the BigWigs
packager (zip + `release.json` for OmaForge).

## Licence

MIT, © 2026 Nine Point Labs. An unofficial fan project, not affiliated with or endorsed by Blizzard Entertainment.
