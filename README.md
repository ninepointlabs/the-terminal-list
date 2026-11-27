# The Terminal List

A personal watch list for **World of Warcraft: Forever**. It keeps track of players who crossed you, were rude, or
just don't play nice, on **both factions**, and marks them so you recognise them next time: a **red crosshair** beside
their nameplate and on the target frame, a line on their tooltip, and a mark on their chat lines.

A second list, **the Good Folk**, is for people you want to remember kindly. They get a **pink heart** in the same
places instead of the crosshair, and are never added by PvP or alerted on.

**Past groups:** everyone you party or raid with is remembered from now on, separately from both lists: how many times
you've grouped, when, where, the dungeon and quests if the game shows them, and which of your characters you were on.
A small **number badge** shows the count beside their name; right-click them for **Group history**.

It's a sibling of [Andric's Addon](https://andricsaddon.myazerothlife.com),
[Parzelle's Addon](https://parzelles-addon.myazerothlife.com),
[Tristan's Addon](https://tristans-addon.myazerothlife.com),
[Tazu's Addon](https://github.com/ninepointlabs/tazus-addon) and
[Forever Rogue](https://github.com/ninepointlabs/forever-rogue), and uses their window style. It isn't a class addon.

> **Website:** [ttl.myazerothlife.com](https://ttl.myazerothlife.com)
>
> **Status:** [v0.2.0](https://github.com/ninepointlabs/the-terminal-list/releases/latest). Early in-game testing; see `STATUS.md` for the checklist.

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
| `/tlist good [Name[-Realm]] [note]` | add to the Good Folk; no name = your current target |
| `/tlist ungood [Name[-Realm]]` | remove from the Good Folk (also `/tlist good remove`) |
| `/tlist goodnote [Name[-Realm]] [text]` | set a Good Folk note (also `/tlist good note`; no text opens an editor) |
| `/tlist groups [Name[-Realm]]` | group history with someone; no name = your target, no target = everyone you've grouped with |
| `/tlist search <text>` | open the list filtered by name, realm, note, zone, race or class |
| `/tlist settings` | settings |
| `/tlist help` | the commands |

- **Right-click** a player's portrait (target, focus, party, raid) or their name in chat: **Add to The Terminal List**, or
  for someone already listed, **Edit note** / **Remove from The Terminal List**. Separate entries handle the Good Folk:
  **Add to the Good Folk**, **Edit Good Folk note**, **Remove from the Good Folk**. For someone on one list, the other
  list's entry reads **Move to …**. Anyone you've grouped with (on a list or not) also gets **Group history**.
- The **window** (`/tlist`, the minimap button or the addon compartment) lists everyone with name-realm, race, class,
  faction, note, how they were added (manual or PvP kill), kill count, date and zone. You can search, filter by
  PvP/manual, sort (newest, most kills, name), edit notes and remove people there. The **Good Folk** filter shows the
  second list; All, PvP kills and Manual only ever show The Terminal List.
- Adding someone who's already listed never makes a second row; you're offered the note editor instead.

### The Good Folk

- A separate, account-wide list with the same identity rules (Name-Realm, optional last name) and optional notes.
- **One list at a time:** adding someone to the Good Folk takes them off The Terminal List, and the reverse. Chat says
  so ("… was on The Terminal List and has been moved to the Good Folk"). Their note comes along unless you give a new
  one; their kill count doesn't.
- **Marks:** a pink heart beside the nameplate, on the target frame and in front of their chat lines; the tooltip says
  "Good Folk" and shows the note. Their name is never painted red, and the "is here" alert never fires for them.
- **Never automatic:** nobody is added to the Good Folk by the addon. If one of the Good Folk kills you (or helps), they
  aren't added to The Terminal List or counted; chat notes that they're on the Good Folk.

### Past groups

- **Going forward only.** Groups from before you installed this version can't be known, so history starts empty.
- **Separate from the lists.** Grouping with someone never adds them to The Terminal List or the Good Folk; removing
  someone from a list keeps their group history.
- **Who:** every other player in your party or raid (never you, pets or NPCs; a name the game hides is skipped). Kept
  account-wide, keyed by Name-Realm like the lists. Battleground and arena raids don't start a session.
- **What each session keeps:** date and time, the zone it started in, any dungeon/instance you entered together, quests
  you accepted, progressed or turned in while grouped, the character you were on, and party or raid. Anything the game
  doesn't show cleanly is left out, never guessed; a dungeon name hidden mid-run is filled in later if it shows up.
- **One session, not five:** seeing the same person in your group again within **15 minutes** (a disconnect, a
  `/reload`, a quick re-invite, a party turned raid) is the same session. Grouping again later counts again.
- The last **50 sessions** per player are kept; the count always includes older ones.
- **Group history** (right-click, `/tlist groups`, or **Past groups** in the window) lists every recorded session.

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
- **Group badge:** a small blue number (times grouped) beside the name on nameplates and the target frame. On its own
  for people on neither list, beside the heart for the Good Folk. The Terminal List keeps just the crosshair; an
  optional setting (off) puts the number beside it too.
- **Tooltip:** "On The Terminal List", their note, kill count and how they were added; for anyone you've grouped with,
  "Grouped together N times" and the last date, zone and dungeon.
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
python3 tools/make-heart.py          # redraw Media/Heart.tga (the Good Folk mark)
```

CI (`.github/workflows/test.yml`) runs a syntax check and the tests. `release.yml` packages a `v*` tag with the BigWigs
packager (zip + `release.json` for OmaForge).

## Licence

MIT, © 2026 Nine Point Labs. An unofficial fan project, not affiliated with or endorsed by Blizzard Entertainment.
