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

## Good Folk list (2026-11-24, released in v0.1.1)

Tim (2026-11-24): "a second list I can add people to, which are the good folk, and it puts a heart next to their name instead of the target icon."

**Where:** PR #2 (`feature/good-folk`), squash-merged to `main` as `2d82563` at Tim's request ("merge and do point release"). **Released as v0.1.1** (2026-11-24): https://github.com/ninepointlabs/the-terminal-list/releases/tag/v0.1.1. The annotated tag points at `b7b79ae` (README status line → v0.1.1).
  - Before tagging, `omaforge clients` reported Forever 1.60.1.71091 / Interface 16001, which matches both TOCs. Tests on merged `main`: 54/54.
  - The Release workflow passed (run 45484121318). Assets: `TheTerminalList-v0.1.1.zip` (TOC `## Version: v0.1.1`, Interface 16001; Core, Modules, UI, `Media/Crosshair.tga` + `Media/Heart.tga`, LICENSE, CHANGELOG; checked by downloading it) and `release.json` (flavor `forever`, interface 16001). Packager notes were replaced with a feature summary and install steps. No autonomix-cli line: no Linux executables.
  - `omaforge check -c forever` shows Tim's install as `v0.1.0 -> v0.1.1`. I did **not** run `omaforge update`; Tim updates it himself.
  - `docs/` and the website are untouched (the site still says v0.1.0). Nothing installed into the live AddOns folder (`tools/install-dev.sh` only into a scratch folder: 22 files, `Media/Heart.tga` included).

**What landed:**
- **Data:** `TheTerminalListDB.good` (key `name-realm` → entry), same identity model and fields as The List minus `kills`/`assists`/`lastKill`; `source` is always `manual`. `ns.Good` (`Get`/`Add`/`Remove`/`SetNote`/`Count`) lives in `Modules/List.lua` next to `ns.List`; `List.Which(key)` returns the entry and `"list"`/`"good"`. `List.ResolveKey` and the known-realm check look at both lists.
- **Schema 2 migration** (`Core/DB.lua`, `DB.Migrate`): a schema-1 (v0.1.0) account gets an empty `good` table and `schema = 2`; `entries`, settings, minimap, sort and filter are not touched (tested with a deep compare). Per-character DB just gets `schema = 2`. Running it again changes nothing.
- **One list at a time:** `List.Add` (manual) moves someone off the Good Folk and `Good.Add` moves them off The List, printing "X was on The Terminal List and has been moved to the Good Folk" (or the reverse). The note carries over unless the add gives a new one; class/race/faction/last name/last seen carry over. Moving to the Good Folk drops the PvP record and says so ("Their PvP record there (2 kills, 0 assists) was not carried over").
- **Slash:** `/tlist good [Name[-Realm]] [note]` (no name = target), `/tlist ungood [Name]` or `/tlist good remove [Name]`, `/tlist goodnote [Name] [text]` or `/tlist good note …` (no text opens the Good Folk note editor). `/tlist add`/`remove`/`note` still mean The Terminal List only; `/tlist remove` on a Good Folk name leaves them and points at `/tlist ungood`. Documented in `/tlist help`, Settings › About and › List & PvP, README.
- **Right-click menus:** separate entries: **Add to the Good Folk** / **Edit Good Folk note** / **Remove from the Good Folk** (asks first). For someone on one list the other list's entry reads **Move to The Terminal List** / **Move to the Good Folk**.
- **Window:** a **Good Folk** filter tab (heart rows, "Good Folk" chip, Note/Remove, "Add a good one…" and "Add my target" go to the Good Folk). All / PvP kills / Manual stay The Terminal List only. Both empty states mention `/tlist good`.
- **Marks:** `Media/Heart.tga` (64×64 32-bit TGA, pink filled heart with dark outline and highlight) from `tools/make-heart.py`. `ns.HEART` / `ns.HeartIcon()`; `ns.Icon()` is still the crosshair. Nameplate and target-frame marks swap texture per update (a recycled plate goes heart → crosshair correctly). Tooltip: heart + "Good Folk", the note, "Added <date>"; no "On The Terminal List", kills or source. Target-mark tooltip title is "Good Folk". Chat: heart in front of their lines; their names in message text are not coloured.
- **`Alert.Check`** returns `entry, "list"|"good"`, records last seen for both, and **alerts for The Terminal List only**. No new setting.
- **PvP:** auto-add (killing blow, recent-damager assists, and Yes on the ask popup) only ever writes The Terminal List. `List.Add` with `source = "pvp"` on a Good Folk key returns `nil, false, "good"`; Combat prints "♥ X killed you, but they're on the Good Folk ("note"), so they weren't added to The Terminal List." No move, no kill/assist bump. `Good.Add` refuses any non-manual source. Battleground/arena/instance/duel and `autoAdd`/`addRecentDamagers` rules unchanged.

**Decisions I made (Tim's to change):**
1. Heart colour **pink** (`#ff78b5`), so it can't be confused with the red crosshair.
2. **No** Good Folk alert setting (the brief allowed one, default off). Simpler; easy to add later.
3. Moving someone to the Good Folk drops their kills/assists (printed in the notice). Moving back starts them at 0 kills, source `manual`.
4. The existing Recognition toggles (nameplate, target, tooltip, chat) apply to both marks; no separate Good Folk toggles.
5. The ask popup still appears after a death with a Good Folk hostile target (the brief covers the "Yes" case: nothing added, note printed). It could skip asking instead.
6. `/tlist good Note …` / `/tlist good Remove …` read `note`/`remove` as subcommands, so a player literally named Note or Remove has to be added by target or right-click (or `/tlist good Note-Realm`).

**Tests:** `lua5.1 tests/run.lua` → **54 passed, 0 failed** (43 before + 11 new); `luajit tests/run.lua` → 54/54; `luac5.1 -p` on every `.lua` passes. New coverage: heart TGA format and difference from the crosshair, no raid-target/skull textures; schema-1 migration (deep compare, fresh install, idempotent); `/tlist good` by target / Name / Name-Realm / note, self and bad names refused, no duplicate, re-add offers the note editor; `goodnote` / `good note` / editor dialog; `ungood` / `good remove` by name and target; moves both ways with notices and note handling, never on both lists; menus (distinct entries, Move labels, remove confirm, chat-name menu); heart on target frame, nameplate (incl. recycled plate), tooltip text, chat, no alert/sound/raid warning; PvP: Good Folk killer and assist not added/moved/counted with the note printed, Terminal List and unknown killers as before, `Resolve` returns `"good"`, nobody ever on the Good Folk with source `pvp`; ask-popup Yes on a Good Folk target; window filters, empty states, About/Recognition/help text.

**In-game checklist (Good Folk):**
1. `/tlist good` with a friendly player targeted: chat line with a pink heart; `/tlist` › Good Folk shows them.
2. Heart (not crosshair) **beside their nameplate**, readable at plate scale.
3. Heart on the **target frame** portrait; hovering it shows "Good Folk" and the note.
4. **Tooltip** on mouse-over: heart + "Good Folk" + note; no "On The Terminal List", no kill count.
5. **Chat:** heart in front of their say/whisper/channel lines; their name in someone else's message is not red.
6. **Right-click** their portrait and their chat name: Add to the Good Folk / Edit Good Folk note / Remove from the Good Folk, and the Move entries.
7. **Moving:** `/tlist good` on a Terminal List player prints "…was on The Terminal List and has been moved to the Good Folk"; `/tlist add` on a Good Folk player prints the reverse. The crosshair/heart swap right away.
8. **PvP:** die to a Good Folk player in the open world (combat log or ask-popup Yes): chat says they're on the Good Folk (with the note) and they are **not** added to The Terminal List.
9. With the alert on, seeing a Good Folk player gives **no** chat alert, raid warning or sound.
10. Existing Terminal List players still show the **red crosshair** everywhere; an existing v0.1.0 list is intact after `/reload`.
11. `Media/Heart.tga` loads (no green square).

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
12. *(2026-11-24, v0.1.1)* The Good Folk list and its heart: see **Good Folk list** above.

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
- `b86a298` Site: GitHub Pages for ttl.myazerothlife.com

## Website (2026-11-20)

- **Site:** `docs/` (`index.html`, `favicon.svg`, `CNAME`), committed in `b86a298`. Single static page, no build step. `.pkgmeta` already ignores `docs`, so release zips are unaffected.
- **Domain:** `docs/CNAME` = `ttl.myazerothlife.com`. **Live** at https://ttl.myazerothlife.com (checked 2026-11-20): Pages builds from `main` / `docs`, DNS resolves to `ninepointlabs.github.io`, GitHub's certificate is approved (expires 2027-02-18), HTTPS is enforced, and the served page matches `docs/index.html`.
- **Analytics:** GoatCounter snippet as on the MAL / Nine Point Labs sites.
- **Content:** hero tagline and a Rules of Engagement memo (help is the default; The List is for those who forfeited it), ten invented redacted target files (all eight from the brief plus The Spectator and The Critic), the feature list from README, the combat-log caveat stated plainly (ask-popup; automatic killing-blow path not yet confirmed in game), commands, OmaForge install command, v0.1.0 release link and manual unzip path, sister-addon links (Tristan's, Tazu's and Forever Rogue link to GitHub because their custom domains didn't resolve on 2026-11-20).
- **Rules followed:** original wording only; no book/show text, names, logos, cover art or stills; no screenshots. The crosshair is an SVG redraw of `Media/Crosshair.tga`. Footer carries the unofficial fan-nod disclaimer and the Blizzard disclaimer.
- **Checked:** headless Chromium render at 1280 px and 390 px; no horizontal overflow at 390 px.
- README gained a Website line. TOC `X-Website` left on GitHub. **No new tag or release; v0.1.0 untouched.**

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
13. **Good Folk** (after `omaforge update -c forever`): the 11-point checklist under **Good Folk list** above.
