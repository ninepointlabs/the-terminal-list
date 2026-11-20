# STATUS: The Terminal List (2026-11-20)

**What it is:** a WoW Forever-only personal watch list for players who crossed Tim, were rude, or don't play nice, on both factions. He can add and remove people by hand (`/tlist`, right-click menus, a list window). A player who kills him in **open-world** PvP is added automatically. Listed players are marked with a **red crosshair** on nameplates and the target frame, a tooltip line, marked chat lines, and an optional once-per-session alert. The list is account-wide, so a name added on Rip shows on Andric, Parzelle, Tazu, Tristan and Ghoulsbie too. It reuses the sister addons' window, widget kit, Options style, strict-mock tests and release workflow. It isn't a class addon: no Data/ pipeline, talents, pollers or spec chrome.

**Repo:** https://github.com/ninepointlabs/the-terminal-list (public, default branch `main`, topics `wow-addon` + `world-of-warcraft`), local `/home/tim/Projects/the-terminal-list`, `origin` set. Commits use `Nine Point Labs <179739321+ninepointlabs@users.noreply.github.com>` (repo-local git config).
- **Created and released 2026-11-20 at Tim's request** ("make repo, label it addon or whatever omaforge needs to install it"). OmaForge installs GitHub addons only from a release zip with `release.json`, so that request covered the repo, the topics, and a `v0.1.0` tag and release.
- `main` and `feature/initial-addon` point at the same commits. Tim asked for an installable addon, not a PR, as with Forever Rogue.
- **CI:** Test passed on the first push to `main` (run 44777024780).
- **Released:** **v0.1.0**, https://github.com/ninepointlabs/the-terminal-list/releases/tag/v0.1.0. The annotated tag points at `d19c919` on `main`. Before tagging, `omaforge clients` reported Forever 1.60.1.70959 / Interface 16001, matching both TOCs.
  - The Release workflow (BigWigs packager) passed (run 44777118658).
  - Assets: `TheTerminalList-v0.1.0.zip` (TOCs `## Version: v0.1.0`, Interface 16001; Core, Modules, UI, Media, LICENSE, CHANGELOG; no tests/tools/README/STATUS, checked by downloading it) and `release.json` (flavor `forever`, interface 16001).
  - The packager's commit-list notes were replaced with a short feature summary and install steps. No autonomix-cli line, because the release ships no Linux executables.
- **OmaForge:** `omaforge search -c forever ninepointlabs/the-terminal-list` finds `github:ninepointlabs/the-terminal-list`. Its GitHub provider resolves **v0.1.0 → `TheTerminalList-v0.1.0.zip`, compat `ok`**. Tim installs it himself with `omaforge install -c forever github:ninepointlabs/the-terminal-list`. I did **not** run `omaforge install`.
- **Not done (not authorized):** CurseForge/Wago, GitHub Pages, DNS, email or social posts. Nothing was installed into the live WoW folder: `tools/install-dev.sh` was only run into a scratch folder. WTF/SavedVariables and screenshots weren't touched; the installed AddOns folder was only read, to learn APIs.
- `BRIEF.md` is gitignored (as in Forever Rogue), because it describes Tim's characters and install paths.

## Decisions

**Tim decided (2026-11-20):**
1. The name is **The Terminal List**. Folder/TOC `TheTerminalList`; SavedVariables `TheTerminalListDB` (account) and `TheTerminalListCharDB` (character, window state only).
2. The marker is a **crosshair, not a skull**: `Media/Crosshair.tga`, drawn by `tools/make-crosshair.py` (64×64, red ring, ticks and centre dot, dark outline). No raid-target textures are used anywhere (a test checks this).
3. PvP auto-add **ignores battlegrounds and other places where he chooses to PvP**: arenas, every instance type (party, raid, scenario…) and duels.
4. Both factions. 5. Manual add/remove via slash, right-click and the window. 6. Auto-add on an open-world PvP death. 7. Recognition marks.

**Defaults (the brief's or mine; all still Tim's to change):**
1. **Slash:** `/tlist` only. No clash in the sibling addons or Tim's installed Forever AddOns (rechecked 2026-11-20). I couldn't check addons he might install later.
2. **Account-wide list**; every setting is account-wide too. Only the window's last tab is per character.
3. **"Also add everyone who hit me in the last few seconds": off.** The window is **8 s** (4/6/8/10/12 in Settings).
4. **Recognition:** nameplate crosshair, target-frame mark, tooltip line and chat marking **on**; session alert **off**. When the alert is on, its sound is on (`SOUNDKIT.RAID_WARNING`, built in; no audio files ship).
5. **No keybinds** (none bound, none offered), no macros, no `Bindings.xml`, no `/click`.
6. MIT, no Ace3, Interface 16001, local only.
7. *(mine)* **Recent damagers** who didn't land the killing blow are added as source `pvp`, but their **kill count isn't raised**. Instead they get a separate `assists` count ("helped 2 times"), so "kills" keeps meaning killing blows.
8. *(mine)* **No combat log:** after an open-world death the addon **asks** "You were fighting X. Add them?", where X is the hostile player Tim had targeted in the last 30 s. It never adds anyone silently on a guess. Setting "If the killer can't be read, ask…" is **on**. With no hostile target it explains once per session how to add someone by hand. See *Big caveat* below.
9. *(mine)* Someone added by hand doesn't trigger the "is here" session alert for the rest of that session (you're looking at them). PvP-added killers still alert.
10. *(mine)* Duels: a duel counts as active from `DUEL_REQUESTED` or Tim's own `StartDuel` until `DUEL_FINISHED`, plus 10 s of grace for DoTs. A request that never finishes stops counting after 5 minutes. The duel opponent is never auto-added within 60 s of the duel ending.
11. *(mine)* Category `PvP` in the TOC; window sidebar **The List** · **Settings** (List & PvP · Recognition · About).

## Big caveat: the combat log on Forever

The brief asks for killing-blow detection from the combat log. Two sources say Forever **doesn't give addons the combat log**:
- Forever Rogue's and Tristan's `Data/PvP.lua` research (wowforevertierlist, 2026-11-10): "COMBAT_LOG_EVENT is removed… no kill-blow credit".
- The installed AMR Adventurer's Pack (`Vows.lua`): "CombatLogGetCurrentEventInfo isn't there" on Forever.

So the addon detects it: it registers `COMBAT_LOG_EVENT_UNFILTERED` only when `CombatLogGetCurrentEventInfo` exists.
- **With the log:** the hit on Tim with `overkill > 0` is the killing blow. As a backstop, `PLAYER_DEAD` or `UNIT_DIED` takes the last hit within 3 s.
  - A `Player-` GUID is added.
  - A player-controlled pet is credited to its **owner** when the owner can be found: `UnitGUID(<target|focus|mouseover>pet)`, or `UnitTokenFromGUID` + `UnitIsOwnerOrControllerOfUnit` over target, focus, mouseover and nameplate1–40.
  - NPCs, environmental damage (falling, drowning, lava, fatigue) and pets whose owner can't be found are ignored.
- **Without the log (expected on Forever):** nothing is added automatically. Tim gets the ask-popup instead (default 8 above).

Both paths are fully tested headlessly. Which one runs on Forever needs one in-game check (item 1 below). I didn't use the death recap API: I couldn't confirm what Forever exposes there, and the brief says not to invent.

## What works (verified headlessly, 2026-11-20)

| Check | Result |
|---|---|
| `lua5.1 tests/run.lua` | **43/43 pass** |
| `luajit tests/run.lua` | 43/43 pass (the CI fallback interpreter) |
| Lua syntax | every `.lua` in the repo loads with `lua5.1` |
| `tools/install-dev.sh <scratch dir>` | copies only the 2 TOCs, Core, Modules, UI, Media and LICENSE (21 files) |
| `omaforge clients` (TUF, 2026-11-20) | Forever `1.60.1.70959`, Interface `16001`, which matches both TOCs |
| CI | `.github/workflows/test.yml` (syntax + tests): pass on `main` (run 44777024780) |

The strict WoW mock (`tests/wow_mock.lua`, in Tazu's style) treats undefined globals as errors and loads every TOC file. The tests cover:
- **TOCs:** identical, Interface 16001, title, author, version token, X-Website, Category PvP (not Class), IconTexture, compartment, SavedVariables. Every listed file exists; there's no `Bindings.xml`. The crosshair is a valid 64×64 32-bit TGA.
- **Forever-only guard:** with `WOW_PROJECT_ID` ≠ 18 nothing is wired, the slash command refuses, and no menus or chat filters are hooked.
- **`/tlist`:** toggles the window. The empty state explains the rules. `add` works by target (class, race and faction from the unit) and by name (`Name`, `Name-Realm`, cased like the game). Bad names and yourself are refused.
  - No duplicates: re-adding with a note opens the note editor prefilled.
  - `note` works by name or for the listed target, and `note Name` with no text opens the editor.
  - `remove` works by name (any case) or target. `search`, `settings`, `about` and `help` work.
- **Account-wide:** a second character's DB sees the same entries, and adds made there show for the first. Window state stays per character.
- **Auto-add:**
  - A player killing blow in the open world adds them (pvp, 1 kill, zone, class/race, faction from race).
  - A second death bumps the count to 2 with no new row. A manual entry keeps source `manual` and gains a kill.
  - **Never** in `pvp`/`arena`/`party`/`raid`/`scenario` instances, when `C_PvP.IsBattleground` or `IsActiveBattlefieldArena` says so, or when the instance type is secret. Never during an incoming or outgoing duel or its grace period; it counts again afterwards.
  - Never for NPCs, falling, drowning or unresolvable pets. A pet kill goes to its visible owner (both lookup routes).
  - Recent damagers: off by default (killer only). When on, damagers inside the window are added as assists and those outside aren't, a wider window catches them, and instances and duels are still ignored.
  - Auto-add off adds nothing. `PLAYER_DEAD` with no overkill takes the last hit.
- **No combat log:** asks about the hostile target and adds only on Yes. No hostile target gives one explanation. It never asks in a battleground or duel, and never about a friendly target.
- **Recognition:**
  - Target-frame crosshair: shown for a listed target, hidden for others, when turned off and right after a remove.
  - Nameplate crosshair: on listed plates only, honours the setting, hides on `NAME_PLATE_UNIT_REMOVED`, skips forbidden plates, records last seen.
  - Tooltip: note, kill count, how added; nothing for unlisted players or when off.
  - Chat: crosshair for a listed sender, a listed name inside text turns red. Lines with links, secret lines, unlisted lines and lines with the setting off are left alone.
  - Alert: silent by default. When on, once per player per session with sound and a raid-warning message.
- **Forever last names** ("Eugene Snorkel"): unit, typed (`Eugene Snorkel`, `Eugene-Snorkel`) and chat spellings all find one entry. A known other realm stays a separate person.
- **Right-click menus:** Add for unlisted players (then the note editor); Edit note and Remove (with confirmation) for listed ones. Chat-name context (name + server) works. Nothing is offered on NPCs, yourself or your own chat name.
- **Window:** every column shows. Notes are escaped (a `|c` colour code in a note is shown, not run). Filters and sorts work, and every screen and Settings tab renders without errors.
- **Settings:** toggles write to `TheTerminalListDB` and survive a reload. The minimap button and compartment toggle the window; right-click opens Settings.
- **Hygiene:** no leftover Shaman/Paladin/Priest/Mage/Rogue/spec code (sister-addon links in About are the only exception), no skull, no macros, keybinds or `/click`.

## Features (v0.1)

- **Entry fields** (`Modules/List.lua`):
  - Identity: `key` (lower-case `name-realm`), `name`, `last` (Forever last name, display only), `realm`.
  - Facts: `class`, `race`, `faction` (nil when unknown; faction from a unit or a classic race), `guid`.
  - Dates and places: `added`, `updated`, `lastSeen`, `zone`, `seenZone`.
  - Tracking: `note`, `source` (`manual`/`pvp`), `kills`, `assists`, `lastKill`.
- **Menus** (`Modules/Menus.lua`): `Menu.ModifyMenu("MENU_UNIT_*")` for PLAYER, ENEMY_PLAYER, TARGET, FOCUS, PARTY, RAID_PLAYER, RAID, FRIEND (chat names), CHAT_ROSTER, GUILD and the two COMMUNITIES member menus. Tags the client lacks are skipped. This is the route the installed AMR pack and Plumber use on Forever. The old `UnitPopup` route isn't hooked; without the Menu API, `/tlist add` still works.
- **Nameplates** (`Modules/Nameplates.lua`): `C_NamePlate.GetNamePlateForUnit` plus `NAME_PLATE_UNIT_ADDED`/`REMOVED`. The crosshair sits left of `UnitFrame.name`, or above the plate. Same route as the installed AMR pack's badges. If `C_NamePlate` is missing, the setting is disabled with an explanation.
- **Target frame** (`Modules/Target.lua`): a 26 px crosshair on `TargetFrame.portrait` (or `TargetFramePortrait` / `TargetFrameContainer.Portrait`). It has its own tooltip.
- **Tooltip** (`Modules/Tooltip.lua`): `TooltipDataProcessor` Unit post-call, falling back to `OnTooltipSetUnit`.
- **Chat** (`Modules/Chat.lua`): one message filter per event via `ChatFrameUtil.AddMessageEventFilter`, or the old global if that's missing, never both. It covers say, yell, emote, whisper, channel, guild, officer, party, raid and system. **Deviation from the brief:** the clickable `[Name]` keeps its colour, because filters can't change it and replacing Blizzard's name functions risks taint. Instead the line gets a crosshair, and listed names inside message text turn red.
- **Window:** The List (sidebar search, PvP/Manual filter, sort, Note/Remove per row, "Add a player…", "Add my target") · Settings (List & PvP · Recognition · About). Minimap button, addon compartment, a Blizzard Settings stub that opens the window.

## Known limits (as the brief asked, no workarounds invented)

- **A rename or realm transfer drops someone off the list**: the identity is Name-Realm, so they show up as new and the old entry stays.
- **`/tlist add First Last note`**: the first word is the name. `/tlist add Eugene Snorkel` adds Eugene with the note "Snorkel" (or offers it as the note if he's listed). Right-click or targeting avoids this.
- **Same first name on another realm:** "Name-X", where X isn't a realm the addon knows (your realm or one already on the list), is also matched against Name on your realm. This is because Forever last names can arrive dash-joined. A real player from an unknown realm with the same first name as someone listed could match.
- Inside instances, Forever makes chat and unit details secret, so marks may not appear there. Auto-add never runs there anyway.

## Install / test on TUF

```sh
cd ~/Projects/the-terminal-list
lua5.1 tests/run.lua
tools/install-dev.sh "<scratch AddOns folder>"   # the live AddOns path only with Tim's OK
```

In game: `/reload`, then `/tlist`. Check the client with `/run print(GetBuildInfo()) print(WOW_PROJECT_ID)`.

## Client check

| | Value |
|---|---|
| `omaforge clients` on TUF (2026-11-20) | Forever `1.60.1.70959`, Interface `16001` |
| `.toc` Interface used | `16001` (matches), in `TheTerminalList_Forever.toc` and the identical `TheTerminalList.toc` |
| Runtime guard | runs only when `WOW_PROJECT_ID == 18` (`WOW_PROJECT_CAMELOT`); prints a message otherwise |

Before any future tag, re-run `omaforge clients` and bump `## Interface` in both TOCs if it changed.

## Release workflow

`release.yml` is Tazu's BigWigs packager workflow: on `v*` tags, `args: -u -n "{package-name}-{project-version}"`, `pandoc: false`, `GITHUB_OAUTH`. It also has `workflow_dispatch`, as Forever Rogue added after push events failed to start runs there. `.pkgmeta` packages as `TheTerminalList` and ignores README, STATUS, BRIEF, tests, tools and docs. autonomix-cli doesn't apply: the addon ships no Linux executables.

## Commits (`main` = `feature/initial-addon`)

- `843ce2f` The Terminal List v0.1: account-wide watch list for WoW Forever
- `a06c500` STATUS: v0.1 delivery, decisions and defaults, combat-log caveat, in-game checklist
- `d19c919` README: OmaForge install and release links for v0.1.0 (tagged `v0.1.0`)
- the STATUS commit for the repo and release (see `git log`)

## Still to check in game

1. **Combat log:** `/run print(CombatLogGetCurrentEventInfo ~= nil)`. If true, the automatic killing-blow path runs. Check:
   - the payload layout (overkill at arg 13 for `SWING_DAMAGE`, 16 for `SPELL_*`/`RANGE_*`, 14 for `ENVIRONMENTAL_DAMAGE`; `-1` = no overkill);
   - that `GetPlayerInfoByGUID` gives name, realm, race and class for an enemy;
   - pet-owner lookup.

   If false (expected), check the ask-popup after an open-world death while a hostile player is targeted.
2. **Instance types:** what `IsInInstance()` / `GetInstanceInfo()` report in the open world (`none`), a battleground (`pvp`), Darkspear Islands, arenas, dungeons and raids. Check whether `C_PvP.IsBattleground` / `IsActiveBattlefieldArena` / `UnitInBattleground` exist on Forever. A death in a battleground must add nobody.
3. **Duels:** `DUEL_REQUESTED` (incoming), `StartDuel` (outgoing) and `DUEL_FINISHED` (also on a declined or cancelled duel?). Get killed by a third party right after a duel: nobody is added within 10 s.
4. **Right-click menus:** the entries show on the target and focus portraits, party/raid frames, an enemy player's portrait and a name in chat (`MENU_UNIT_FRIEND`?). Which `MENU_UNIT_*` tags exist on Forever?
5. **Nameplates:** the crosshair shows beside an enemy and a friendly player's plate, placed left of the name and readable at plate scale. Are enemy player plates forbidden on Forever?
6. **Target frame:** the crosshair sits on the portrait's top-left without hiding the level or elite dragon.
7. **Tooltip line** on mouse-over of a listed player in the world.
8. **Chat:** the crosshair shows in say, yell, channel and whisper. What format does the sender name arrive in for players with a last name ("First Last", "First-Last" or "First-Realm")? Are listed names inside messages red?
9. **Session alert** (turn it on): one chat line, a raid-warning message and the sound, once per player per session.
10. **Forever last names:** does `UnitName(unit)` return a last name as the second value, and does `GetPlayerInfoByGUID` return the realm as `""` for your own realm? The realm/last-name split depends on this.
11. **Crosshair texture:** the TGA loads (no green square) on nameplates, the target frame, the minimap button, the window header and the addon list icon.
12. Window layout and scrolling with many entries, the minimap button position, Lua errors (`/console scriptErrors 1`).
