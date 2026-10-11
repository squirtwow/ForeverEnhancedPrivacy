# Forever Enhanced Privacy: private notes

Personal and unpublished (no CurseForge, no GitHub remote). By Squirt, original code,
Interface 16001, Lua 5.1, All Rights Reserved. Settings: `ForeverEnhancedPrivacyDB` (account-wide).
`/privacy` opens the window; `/privacy on|off|toggle`. Key: Key Bindings > AddOns > Toggle private mode.

Feasibility research (the safe hook for every surface, what is secret where): the main session's
`scratchpad/privacy-check-1.json` and `privacy-check-2.json`.

## Files

| File | What it covers |
| --- | --- |
| Core.lua | Every setting's row (P.PAGES, P.SECTIONS, P.ROWS, P.KEYS: one table, the window and defaults come from it), saved settings, private mode and its modes, `/privacy`, the key binding, Options > AddOns, the modules, the record of changes and putting it back, CVars (saved originals, crash recovery, combat queue), screenshots |
| Theme.lua | The window's look (palette from the mockup, ticks, options, choice rows, text box, scroll) |
| Names.lua | What names become (all the naming helpers below), and the "Names" module that notes group, guild and friends names while private |
| UnitFrames.lua | playerFrame, charTitles, ownHead, targetFrames, groupFrames, nameplates, otherHeads, petNames |
| Chat.lua | chatNames, publicChannels, instChat, whispers, cleanOld, channels, timestamps, bubbles |
| Social.lua | friends, bnToasts, whoList, roster, news, guildName, mail, groupFinder, calendar |
| Windows.lua | popups, readyCheck, menus, trade, loot, meter, professions, scoreboard |
| World.lua | questText, tooltips, craftedBy, zoneText, coords, zonePopups, clock, worldMap, gold |
| Window.lua | The settings window (the approved mockup: pages, ticks, choices, Overview with your name and made-up BattleTag boxes, preview, footer notes, credit; Reset all settings at the bottom right of the Overview) |
| Eye.lua | The small eye at the top of the screen while private (hidden during screenshots) |
| Bindings.xml | The key binding (calls `ForeverEnhancedPrivacy_Toggle()`); loads on its own, not in the TOC |

The owner of each row is the `owner` field in Core.lua's P.SECTIONS. Tags ("experimental",
"hide only") are quiet lower-case words after the label.

## How private mode works

- Modes (`P:Get("mode")`): `key` (the key or `/privacy`), `shots` (on at SCREENSHOT_STARTED, off at
  SCREENSHOT_SUCCEEDED / SCREENSHOT_FAILED; experimental), `always` (on from login). The key, `/privacy`
  and the window's big button work in every mode.
- A /reload keeps private mode as it was (`db.wasOn`, read at the first PLAYER_ENTERING_WORLD with
  isReloadingUi). A fresh login is off unless the mode is `always`. Screenshots never set `wasOn`.
- CVar originals live in `db.cvarBackup` while changed. At the first PLAYER_ENTERING_WORLD: private
  off, every backup is put back; private on (always, or a /reload), backups nothing uses are put back.
  At PLAYER_LOGOUT (logout and /reload) every backup is put back too, out of combat only, so turning the
  addon off before the next login leaves no name hidden (seen in game 2026-10-11: names above heads
  stayed hidden with the addon disabled). Private mode then re-applies at login with fresh originals.
  A backup of a CVar the game caches (left by the first build) is dropped at load and the player is told
  once in chat to set it again by hand; putting it back from addon code would do the same harm.
- `P:ShotOnly()`: private mode is on only for the screenshot being taken (known before any module is told).
  Nothing that can't be put back happens then (chat), unless "Clean lines already in chat" asks for it.
- Your BattleTag becomes (Overview, right under "Your name becomes" and styled the same; `myTag`, default
  `""` = off, added 2026-10-11): a made-up BattleTag shown instead of yours while private, only where your
  own BattleTag shows: the header of both friends windows (the older `FriendsFrameBattlenetFrame.Tag` and the
  newer window's strip). Tidied like `myName` (`P:CleanTag`: pipes and control characters out, spaces
  trimmed and squeezed, at most `P.TAG_MAX` = 24 letters, which still fits the older window's 190-wide
  BattleTag box), checked and tidied again at load, and in `P.NAME_KEYS`, so a change while private
  re-labels at once. In the Name colour (below): Game's own draws it as the game draws the real one (the
  part before "#" in the header's colour, "#" and the number in the game's darker blue, read off the game's
  own text; plain when that text is a secret), any other choice colours all of it. The Hidden style leaves
  a typed BattleTag. Empty: as before (your typed name, else "Battle.net", blank when Hidden). Nothing is
  ever copied: the newer header's copy button stays under our strip (an addon can't put text on the
  clipboard, so there's no copying the made-up one either). The preview has no BattleTag, so it doesn't
  show it.
- Name colour (Overview, under "Your name becomes" and "Your BattleTag becomes"; `myColour`, default `game`,
  added 2026-10-11): your typed name's (and made-up BattleTag's) colour while private: Game's own, Purple,
  Your class colour or White. Game's own is
  no colour of ours: unit frames keep their own (gold), a tooltip line the colour the game drew it in,
  the trade window, master loot and boss banner theirs, chat the colour the game gave you as the sender
  (class colours in chat: the code in the decorated name the sender filter is handed) or the line's own
  in text, and the roll history and the meter's breakdown (which write every name in its class colour)
  your class colour. Switching to Game's own while private puts the game's colour back at once (the
  record's kept colour, UnitFrames' own `painted`, the /who and mail covers take the covered name's
  colour); tooltips change from the next one. Quest and gossip text, raid-style frames, plates, the Raid
  tab, titles, menus, meter rows, the scoreboard, roster and calendar never colour names, so the choice
  doesn't show there. No colour picker (the game's must not be borrowed). With no typed name or BattleTag
  it changes nothing. The preview follows it (Game's own: the colour your real name has in the preview).
- Reset all settings (added 2026-10-11): a button at the bottom right of the Overview, under the preview
  and as wide as it (moved there from the foot of Good to know the same day; the user: "i kinda want it in a
  spot they can see, not have to dig for it"), styled like the window's own buttons (`T:Button`). It asks
  first, inside the window: the button gives way to "Are you sure?", Reset (in the accent), then Cancel at the
  right where the button's end was. Reset ignores clicks for half a second after the question shows
  (RESET_WAIT), so a double click on the button can't reset. Never one of the game's pop-ups
  (`StaticPopupDialogs` is Blizzard's table; writing in it taints). Cancel, another page or closing the window
  (Escape too) puts the button back; a setting changing meanwhile doesn't. Reset saves a name being typed
  first (so it's emptied with the rest), then `P:Reset()`: private mode off through `P:SetPrivate(false, "reset")`
  (every module's Apply(false), every swap, cover and CVar put back, the backups emptied), then every key in
  `ForeverEnhancedPrivacyDB` dropped, so each setting is its default (`P.DEFAULTS`): your name and BattleTag
  empty, "With its key", class names, the game's own colour, the eye on, every tick and choice as it started.
  Only `wasOn = false` and `cvarBackup` stay: empty, unless a CVar couldn't be put back (in combat), when its
  original waits there and goes back when the fight ends (the usual combat queue), or at the next login.
  Listeners hear "reset" (the window refreshes every control and the preview, the eye hides), and chat says
  "Forever Enhanced Privacy: Settings reset." once. The key binding is the game's (Key Bindings), so it stays.
- Nothing does work while private mode has never been on this session: modules are set up lazily, apart
  from the registrations the feasibility check says to make at load (tooltip post-calls, menu callbacks)
  and mixin hooks, which all return at once while off.

## The module contract

Each module file starts with a header comment naming every setting it owns (TestRules checks), then:

```lua
local _, P = ...

local M = P:Module("UnitFrames")   -- exactly this line: registers with the core

function M:Setup()          -- optional
end

function M:Apply(on, key)   -- required
end
```

### Lifecycle

- `P:Module(name)` returns the module table (made once). Modules are told things in TOC order:
  Names, UnitFrames, Chat, Social, Windows, World (turning off: the reverse).
- `M:Setup()` runs once per session, the first time private mode turns on, just before that first
  `Apply(true)`. Install hooks, filters, post-calls and `Menu.ModifyMenu` callbacks here. If Setup
  errors, it's said once in chat and the module is left alone for the rest of the session.
  Exceptions, at file load (say why in a comment): a hook that must exist before Blizzard builds its
  frames (a mixin whose rows are created later and copy the mixin's methods), and the registrations the
  feasibility check says never to make lazily: `TooltipDataProcessor` post-calls (World) and
  `Menu.ModifyMenu` callbacks (Windows).
- `M:Apply(on, key)` is called inside a pcall (an error is said once in chat; the other modules
  carry on; it's called again next time). Inside it, run each surface (and each step) through its own
  `P:Guard(M, fn)`, built once, so one failing surface never stops the others (World's APPLY,
  Windows' REFRESH, Chat's Steps, UnitFrames' refreshers):
  - `Apply(true)` (key nil): private mode just turned on. Apply every surface whose setting is on
    (`P:IsOn(key)`), including what's already on screen.
  - `Apply(false)` (key nil): private mode just turned off. Put back anything not recorded through
    the helpers below. After Apply(false) the core puts back everything recorded.
  - `Apply(true, key)` with one of your row keys: that setting just changed while private. If it's
    now off, the core has already put back what's recorded under it; put back anything else of
    yours for it. If it's now on (or a choice changed), apply it.
  - `Apply(true, key)` with a key in `P.NAME_KEYS` (`nameStyle`, `myName`, `myColour`, `myTag`): sent to
    every module: re-label what's showing. (`myTag` only shows in Social's headers; the others re-label
    anyway or, like Chat, skip it, which writes nothing new.)
  - Apply must be safe to run twice in a row (idempotent).
- While private mode is off, every hook, filter and post-call returns at once:
  `if not P:IsOn(KEY) then return end` first (a chat filter returns nothing, which means unchanged).
  Wrap each in `P:Guard(M, fn)` so an error is said once and swallowed.

### Settings

- `P:Private()`: private mode is on.
- `P:IsOn(key)`: private mode is on and the row is ticked; for a choice row, its value isn't `"leave"`.
- `P:Get(key)`: a setting's value (`"names"|"chat"|"leave"` for instChat, `"hide"|"leave"` for worldMap,
  `"class"|"player"|"hidden"` for nameStyle, the typed `myName` and `myTag`, `"game"|"accent"|"class"|"white"`
  for myColour, booleans for ticks).
- Never call `P:Set` or `P:Reset` from a module (the window does that).

### Changing things, so they can be put back

Everything goes under one of your setting keys. The core puts it back when that key is unticked
while private, or when private mode turns off.

- `P:SwapText(key, region, text [, r, g, b])`: sets a FontString's text (and colour), keeping the
  game's text to put back. Safe in hooks that run on every game update: the original is taken afresh
  each time the game has written new text since ours, and never kept when it's a secret. On putting
  back, the original returns only if the region still shows our text (if the game rewrote it, or the
  original was a secret, it's left for the game's next update). The text may be `""`. The game's
  colour is kept when ours first goes on (afresh if the game has painted its own over ours since, never
  ours); called with no colour while ours is still on, ours comes off at once and the kept colour is
  back (your typed name in the game's own colour). Put back only while ours still shows.
- `P:Showing(key, region, text [, r, g, b])`: the region already shows that text in that colour (with
  no colour: with none of ours left on it), so a swap would change nothing. For "applying twice writes
  nothing" checks that also follow colour changes (Windows' Put).
- `P:HideRegion(key, region)`: `SetAlpha(0)`, keeping the alpha to put back. Only for regions that
  aren't protected (FontStrings, textures, plain frames).
- `P:SetCVar(key, name, value)`: changes a CVar while private; its original is saved in the
  settings (crash recovery) and changed only out of combat (queued till the fight ends, both ways).
  Returns false if this client has no such CVar, or if it's one the game caches (`P.CACHABLE_CVARS`,
  plus anything `CVarCallbackRegistry.cachable` marks): CVAR_UPDATE is a synchronous event, so an
  addon's change runs the registry's OnEvent under the addon's taint and taints the cached value until
  the next change; the game's own readers (heal numbers, every nameplate) then fail on secret values,
  even after private mode is off. That's why healer names (floatingCombatTextFriendlyHealers_v2) and
  nameplateForceShowUnitName are left alone. Several keys can share one CVar; it comes back when the
  last lets go. This is the only way to change a CVar (TestRules, which also keeps the cached list
  complete and refuses any module naming one).
- `P:SetTransient(region, text [, r, g, b])`: sets a tooltip line with nothing kept to put back. Only
  inside a `TooltipDataProcessor` post-call: tooltip lines are reused by every later tooltip, so a
  recorded original could be put back into somebody else's tooltip.
- `P:OnRestore(key, id, fn)`: anything else to undo (hide your overlay frame, `SetPassword(false)`,
  remove a chat filter). Runs once; the same id replaces an earlier one.
- `P:NeedsReload(key)`: something under this key only comes back fully after a /reload. When it's
  put back, the footer (window open) or chat says "Some things only come back fully after a /reload." once.
- `P:Restore(key)`: put back everything under a key now (rarely needed; the core calls it).

### Other helpers

- `P:Guard(M, fn)`: a safe copy of fn: an error is said once ("The <Module> part hit an error...") and
  swallowed (returns nothing); answers pass through, nils included.
- `P:OnAddOnLoaded(name, fn, M)`: runs fn once Blizzard's load-on-demand addon `name` has loaded
  (now, if it has). Errors are said once against M.
- `P:InCombat()`, `P.IsSecret(value)` (safe when the game has no `issecretvalue`).
- `P:Print(text)`: chat, prefixed with the addon's name. `P:Say(text)`: the window's footer if open,
  else chat. Modules never call `print` or `AddMessage` themselves (TestRules).

### Names (Names.lua)

Every label comes with its colour: `label, r, g, b`, except your typed name in the game's own colour
(Name colour "Game's own", the default), which comes with none (`r` is nil): leave the game's colour
(SwapText with no colour, `P:Colourise` gives the plain label, a tooltip line keeps its colour, never
`SetTextColor(nil)`). A label of `""` is the Hidden style. None of these ever returns, reads or joins a
secret.

- `P:NameFor(unit)`: what a unit's name becomes. You (the player, or any token `UnitIsUnit` says is
  you): `P:MyLabel()`. Another player: `P:StyleLabel(classFile)`, "Player" when the class is secret
  or unknown, or when the game won't say whether it's a player. A pet or other player-controlled
  non-player: `P:PetLabel()`. An NPC or no unit: `nil`, meaning leave it alone.
- `P:MyLabel()`: your typed name (`myName`) in its Name colour (`myColour`: `accent` the purple,
  `class` your class colour (none if the game won't say your class), `white`, `game` none), else the
  name style with your class (the Name colour plays no part then).
- `P:MyTag()`: your made-up BattleTag (`myTag`) in the same Name colour (none for `game`), or nil when none
  is typed. Only for where your own BattleTag shows (Social's headers).
- `P:StyleLabel(classFile)`: class style: the class name in its colour ("Player" if classFile is nil
  or unknown); player style: "Player"; hidden: "".
- `P:PetLabel()`: "Pet" ("" when hidden).
- `P:LabelForName(name [, classFile])`: a name seen as text: yours, or someone's by class (given,
  else noted, else "Player").
- `P:LabelForGUID(guid)`: by GUID (chat senders): yours, else the class from `GetPlayerInfoByGUID`.
- `P:IsMyName(text)`: true for your first name or your full "First Surname". False for a secret.
- `P:MyNames()`: `first, full` (`full` is "First Surname", or the first name again with no surname);
  nil while unknown.
- `P:Learn(name, classFile)`: note a player's name for text swaps (session only; a realm suffix is
  dropped; never your own, a secret or "Unknown"); returns the name as noted. The Names module notes
  your group, guild and friends while private; Chat notes senders it sees.
- `P:ClassOf(name)`: the noted class file, or nil.
- `P:ReplaceNames(text [, me [, colour [, mineOnly]]])`: swaps every known name in text: yours (full name, then
  first name) and every noted name (the full name anywhere; the first name alone anywhere for your
  current group, but for anyone else only when it doesn't start a sentence or a line, so a guildmate
  called "Will Ashford" never turns "Will you tank?" into "Mage you tank?"), whole words only, never inside a
  link's data (`|Hplayer:...|h` stays, so whispers still work), a texture, an atlas, a colour code or a
  Battle.net `|K...|k` name. `me`: your own words for you instead of your label (quest text's
  "adventurer"). `colour`: wrap each label in its colour code. `mineOnly`: your name alone, every noted
  name left (Chat's public channels); a noted full name that starts with your first name ("Zriel Blackmoor" when
  you're Zriel Gustbellow) is left whole, never taken for yours. Returns `text, changed`; a secret comes back untouched with `false`.
- `P:ClassName(classFile)`, `P:ClassColour(classFile)`, `P:Colourise(label, r, g, b)`.

### Safety rules (Forever)

- Only `hooksecurefunc` post-hooks, `HookScript`, Blizzard's filters (`ChatFrameUtil.AddMessageEventFilter`
  / `AddSenderNameFilter`, `TooltipDataProcessor` post-calls, `Menu.ModifyMenu`) and cosmetic setters on
  regions (`SetText`, `SetFormattedText`, `SetTextColor`, `SetVertexColor`, `SetAlpha`; Show and Hide only on
  regions that aren't protected). Never replace a Blizzard function, never write a key on a Blizzard
  frame, never hook a method on a protected frame (prefer the global function or the FontString), never
  Show/Hide/SetPoint/SetSize a protected frame, never call a Blizzard function yourself (`Name_Update` and
  friends: TestRules refuses any `Upper_Case(` call), never `SetOverrideBinding` (refused).
- Never read, compare, join, measure or format a secret: `P.IsSecret(v)` first; pass secrets only straight
  into a widget's setter. The harness can't catch `secret == "text"` (Lua can't), so always check first.
- `GameTooltip` is never named in addon code (TestRules). Tooltip lines change only from a
  `TooltipDataProcessor` post-call, through its `tooltip` argument: `tooltip:GetLeftLine(i)` or
  `_G[tooltip:GetName() .. "TextLeft" .. i]`, with `lineData.lineIndex`, and only through
  `P:SetTransient` (nothing recorded). Register post-calls once, at load (they can't be removed), and
  bail while off. No other hook may touch a tooltip (`GetOwner` is refused by TestRules, and a
  `tooltip:` method call anywhere but World's TipLine fails it), so the world map's group dots
  (`UpdateUnitTooltips` on each pin) are left alone and listed on Good to know.
- CVars the game caches are never written (see `P:SetCVar`). Any other CVar change still fires the
  game's own CVAR_UPDATE handlers from our code (the minimap and world map coordinate callbacks write a
  field on their frame): check each CVar-backed setting in game (below).
- No window of Blizzard's opened or closed (`ShowUIPanel`, `HideUIPanel`, `ToggleWorldMap` refused).
  The world map "Keep closed" choice needs an own curtain frame over the map, or a hook that only
  covers, never closes.
- CVars only through `P:SetCVar`.
- Lua 5.1: `unpack` (not `table.unpack`), no `//`, no `goto`; no function with more than 60 upvalues or
  200 live locals (TestLuaLimits); split big builders into local helpers.
- Player text: short, plain, British spelling (TestRules checks colour/centre/grey and friends), no em dash.
- Chat lines changed in the history (TransformMessages / RemoveMessagesByPredicate) never come back:
  lines already in chat only with cleanOld; new locked lines and the message of the day as they arrive,
  never while `P:ShotOnly()` (unless cleanOld). The window and Good to know say so.
- Put module-only stand-ins in your own test file.

## Writing a module's test

`Tools/Test<Module>.lua`, run from the addon folder:

```
& 'C:\AddonDev\_Toolchain\lua-check\node_modules\.bin\fengari.cmd' Tools/TestUnitFrames.lua
```

Read the output: a failure can still exit 0. It must end with `Test<Module>: N checks passed`.

```lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True

H.Environment()
-- Blizzard's side first: its frames (sealed) and the functions the module hooks.
local target, targetName = H.UnitFrame("TargetFrame", "target")      -- protected, .unit, .name
_G.UnitFrame_Update = function(frame) frame.name:SetText(GetUnitName(frame.unit)) end
H.units.target = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR",
    player = true, guid = "Player-1-0002" }
local P = H.Load(nil)                                                 -- the real files, logged in

H.Blizzard(UnitFrame_Update, target)                                  -- the game's own update
Equal(H.Text(targetName), "Brannoc Stonehelm", "off: the real name")
Equal(H.Writes(), 0, "off: nothing of Blizzard's touched")
P:SetPrivate(true)
Equal(H.Text(targetName), "Warrior", "on: swapped at once")
H.Blizzard(UnitFrame_Update, target)
Equal(H.Text(targetName), "Warrior", "and after the game's next update")
P:Set("targetFrames", false)
Equal(H.Text(targetName), "Brannoc Stonehelm", "unticked: put back")
P:SetPrivate(false)
Equal(H.Problems(), "", "no violations, hook errors or prints")
io.stdout:write("TestUnitFrames: " .. H.checks .. " checks passed\n")
```

Check at least: off does nothing (`H.Writes() == 0`, no CVar written, `H.cvarWrites` empty), on swaps
or hides, every setting's tick puts its own surface back and leaves the others, off puts it all back,
secrets (a `secret...` unit, `H.SECRET` text) cause no violation, CVars aren't touched in combat, and
`H.Problems() == ""` at the end.

### The harness (Tools/Harness.lua)

- `H.Environment()`: a fresh game. Build Blizzard's frames and functions after it, then `H.Load(saved, opts)`
  (`opts.reload` for a /reload, `opts.beforeLogin` to stop after ADDON_LOADED). Returns P.
- Blizzard's objects are sealed: a key written on one, a method other than a read (`Get`, `Is`, `Has`,
  `Can`, `Enumerate`, `Num`, `Does`), `HookScript`, a cosmetic setter or a chat history edit
  (`TransformMessages`, `RemoveMessagesByPredicate`) called on one, or a hook on a protected one, is
  a recorded violation. That covers the methods a test gives an object (fields, or `rawset` after): a
  sealed object keeps its functions apart, `rawset`/`rawget` reach them as on the game's frame, and a
  method hooked with `hooksecurefunc` stays behind the check, so the addon's own `SetText` on a hooked
  FontString still counts in `H.Writes()`. Test code calling such a method itself must do it inside
  `H.Blizzard` (pass `function() frame:Update() end`, not `frame.Update`). A tooltip's lines
  (`H.NewTooltip`) changed by the addon outside a tooltip pre- or post-call are a violation, and so is
  writing a CVar the game caches (`H.CACHABLE`; `CVarCallbackRegistry.cachable` stands in). Make them with
  `H.BlizzardFrame(kind, globalName, parent, fields)` (fields: plain keys such as `unit` or a parentKey),
  `H.BlizzardText(globalName, parent, text)`, `H.UnitFrame(name, unit)` (protected, with `.unit` and
  `.name`), `H.Protect(obj)`, `H.NewTooltip(name, lines)`.
- Run Blizzard's own code through `H.Blizzard(fn, ...)`: it may do anything. A global function hooked with
  `hooksecurefunc` runs its original as whoever called it and the hook as the addon's code, so call it
  through `H.Blizzard` to stand for the game.
- `H.Text(region)`, `H.Alpha(region)`, `H.Shown(region)`, `H.Under(region, root)`, `H.Find(text, part)`,
  `H.Script(frame, "OnEnter")`, `H.Writes()` / `H.ResetWrites()` / `H.writeLog` (the addon's cosmetic
  calls on Blizzard's objects).
- Units: `H.units[token] = { name, surname, class, classFile, player, pet, guid, secretName, secretClass,
  secretPlayer, secretCompare }`; the player is Zriel Gustbellow, a druid. `H.raid = true` for raid tokens.
  `H.guild = { { name, classFile } }`, `H.friends = { { name, className } }`.
- `H.SECRET` is the secret: using it is a violation. `issecretvalue`, `canaccessvalue` stand in.
- Events: `H.Fire(event, ...)`, `H.Combat(true|false)`, `H.Screenshot("start"|"done"|"fail")`,
  `H.LoadAddOn(name)`, `H.RunTimers()` (C_Timer.After).
- CVars: `H.cvars` (name: text; missing means the client hasn't it; add yours before H.Load),
  `H.cvarWrites` ("name=value" list). Changing one in combat is a violation.
- Chat: `H.Chat(event, ...)` runs the message filters as Blizzard does (skipped while any argument is a
  secret; returns `discard, args...`; a filter's second return replaces every argument), on
  `H.chatFrame` ("ChatFrame1"). `H.SenderName(event, decorated, ...)` runs the sender name filters.
- Tooltips: `H.Tooltip(Enum.TooltipDataType.Unit, tooltip, { lines = { { type = Enum.TooltipDataLineType.UnitName,
  leftText = "...", unitToken = "target" } } })` runs pre-calls, each line (drawn, then its post-calls),
  then the tooltip's post-calls. `GameTooltip` exists (8 lines).
- Menus: `H.Menu(tag, contextData, title, owner)` opens a tagged menu: runs the `Menu.ModifyMenu`
  callbacks, then draws the title (Blizzard's initializer, then any added); returns the title as drawn.
- `H.Problems()`: every violation, hook error and printed line, joined; `H.Clear()` after an expected print.

## Tests

From `C:\AddonDev\ForeverEnhancedPrivacy`:

- `node Tools/RunTests.mjs`: everything below in one go (each Lua test must end "TestX: N checks
  passed"); exits 1 on any failure.
- `& 'C:\AddonDev\_Toolchain\lua-check\node_modules\.bin\fengari.cmd' Tools/TestCore.lua` (and TestWindow,
  each module's Test<Module>.lua)
- `$env:FENGARI='C:\AddonDev\_Toolchain\lua-check\node_modules\fengari'; node --test Tools/TestLuaLimits.mjs`
- `node --test Tools/TestRules.mjs`
- `node 'C:\AddonDev\_Toolchain\lua-check\check.js' (Get-ChildItem *.lua, Tools\*.lua)`
- Art: `node Tools/GenerateArt.mjs` redraws Media/Heart.tga, Eye.tga and Icon.tga.

## Needs an in-game check (core and window)

- Key Bindings > AddOns lists "Toggle private mode" under the addon's name, and the key works.
- Name colour: the four buttons fit beside the preview, and with a typed name each choice shows on the
  player frame, your tooltip and when you talk in chat (Game's own: gold frame name, your class colour
  as the sender with class colours in chat on, the line's colour with them off).
- Your BattleTag becomes: the box sits under "Your name becomes" and looks the same; Name colour and Extras
  below it, the key note clear of the footer. Type a made-up BattleTag (with a "#" and a number) while
  private: both friends windows' headers show it at once (Game's own: the number darker, like the real
  one; each other colour: all of it). 24 letters fit the older window's box and don't run over the newer
  header's status menu. Clicking the copy button's spot copies nothing (no "copied" line in chat). Emptied:
  your typed name, else "Battle.net"; private off or friends unticked: the real BattleTag and the copy
  button back.
- The window: sizes, fonts and wrapping (title over two lines, option buttons fit, rows fit two columns,
  preview chat lines wrap inside their box, footer notes fit two lines), the heart tinted purple, Escape
  closes it, Options > AddOns opens it.
- A /reload while private keeps it on (PLAYER_ENTERING_WORLD's isReloadingUi on Forever).
- Reset all settings: bottom right of the Overview, under the preview, looks like the window's own buttons.
  Click it: "Are you sure?" with Reset and Cancel in its place (they fit, the footer's note follows the mouse).
  Double-click the button: nothing resets (Reset ignores clicks for half a second). Cancel, another page, Escape and the close button
  each put the button back. Then change a few things (private on with names above heads and bubbles hidden,
  a typed name and BattleTag, another mode, colour and name style, some ticks) and Reset: private mode off,
  names above heads and bubbles back, every page's ticks and choices and the Overview as on a first install,
  both boxes empty, the eye gone, one "Settings reset." line in chat, no Lua errors (`/console taintLog 0`).
  /reload after: still off, nothing changed back. The key binding still works. Once in combat too: the
  settings reset at once, names above heads come back when the fight ends.
- "For screenshots" (experimental): whether the change lands in the captured picture at all.
- The eye: top centre, out of the way, gone from screenshots.
- A CVar left changed by a crash comes back at the next login.
- Every CVar-backed setting, with `/console taintLog 0` as usual: tick each one (ownHead, otherHeads,
  timestamps, bubbles, coords, clock), turn private mode on and off a few times (key and "For
  screenshots"), then open the map, watch the minimap coordinates, look at nameplates and take heals in
  combat (combat text on). Any "secret value ... tainted by ForeverEnhancedPrivacy" error, or blocked
  action, means that CVar must go the same way as healer names (left to the game's options). If healer
  names were ever turned off by the first build, the login message says to turn them back on.
- Each module's own checks: see the feasibility files and the module's notes below.

## Module notes

Each module edits only its own subsection (they're written at the same time).

### UnitFrames

Built. Test: `Tools/TestUnitFrames.lua` (133 checks).

| Key | Surface | How |
| --- | --- | --- |
| playerFrame | PlayerFrame, PetFrame (your pet; you in a vehicle) | `UnitFrame_Update` post-hook + SetText hook on each name |
| targetFrames | TargetFrame, FocusFrame, TargetFrameToT, FocusFrameToT | same |
| groupFrames | PartyFrame.MemberFrame1-4; raid-style party/raid frames (you included); Raid tab `RaidGroupButton<i>Name`; pullouts (names, target and target-of-target lines); Social view raid list | `UnitFrame_Update`, `CompactUnitFrame_UpdateName`, `RaidGroupFrame_Update`, `RaidPullout_Update`, `RaidPullout_UpdateTarget` (Blizzard_RaidUI), `SocialUIFrame.RaidFrame:UpdateContents` (hooked on the instance) |
| petNames | party pet frames, raid-style pet frames, pet pullouts; pets' nameplates (needs nameplates too) | same hooks; group tokens with "pet" in them |
| nameplates | names on plates addons may touch (players, pets; NPCs left) | `CompactUnitFrame_UpdateName` for `nameplate*` units; forbidden plates skipped |
| charTitles | character window title (its own page only), inspect window title, inspect talents title | SetText hook on each title FontString (`GetTitleText()`); Blizzard_InspectUI, Blizzard_PlayerSpells when they load |
| ownHead | your name, guild and title above your head | CVar UnitNameOwn = 0 |
| otherHeads | other players' names, guilds, titles and pets' names above heads, your target's name | CVars UnitNameFriendlyPlayerName, UnitNameEnemyPlayerName, UnitNamePlayerGuild, UnitNamePlayerPVPTitle, UnitNameGuildTitle, UnitNameFriendlyMinionName, UnitNameEnemyMinionName, UnitNameFocused = 0 (missing ones skipped). Not nameplateForceShowUnitName: the game caches it (a change from here broke every plate's update); it's off unless set by hand, and the nameplates tick swaps names on the plates addons may touch anyway |

- The SetText hooks on unit frame names win against anything that writes the name again (the EraUI
  target/focus and player name keepers): our write runs with a `busy` flag, so the hook lets it pass.
- Colours: unit frame names get the label's colour (class colour, grey Player, your typed name in its
  Name colour). The game never sets those colours again, so the module keeps each name's colour from
  before and puts it back itself (`P:OnRestore`, per FontString), and puts it back at once when the unit
  turns into an NPC or shows your typed name in the game's own colour. Raid-style frames, plates, the
  Raid tab and titles keep the game's own colours.
- The newest text the game (or another addon) wrote is what comes back when private mode turns off.
- The inspect window's guild tab is Social's (guildName), not handled here.
- On a setting change: what's off is put back (pets' plates are filed under nameplates, so unticking
  petNames puts nameplates back first), then every surface is swapped again. After a loading screen
  while private, the CVars and labels are applied again.

Needs an in-game check:
- No errors or taint with `/console taintLog 0` while private in combat (SetText hooks on PlayerName,
  the target/focus names and the party names; target changes in combat; raid frames in combat).
- Which Raid tab Forever shows: `/dump C_SocialUI.IsSystemEnabled()` (true: the Social list;
  false: the classic group buttons, which load with Blizzard_RaidUI). Both are hooked.
- The name CVars exist and are settable: `/dump C_CVar.GetCVarInfo("UnitNamePlayerGuild")`, and the
  same for UnitNamePlayerPVPTitle and UnitNameGuildTitle. Whether otherHeads hides guild lines too.
- Which plates are locked in dungeons (friendly plates on retail): they keep names unless otherHeads.
- Long labels on plates: the click area follows the name.
- EraUI's keepers and ours: the label should stay without flicker on target change.
- Focus exists in Forever; a vehicle (if any) shows "Pet" on the player frame.
- The character title on its own page and not on Reputation/Skills; the inspect talents title.
- Not covered (EraUI's own copies): EraUI's inspect talents title (Classic/Talents.lua) and quest log
  party names. The Raid tab's class button hover lists names (a GameTooltip; avoid hovering on stream).

### Chat

Chat.lua owns chatNames, publicChannels, instChat, whispers, cleanOld, channels, timestamps and bubbles. It also does the
chat side of rows owned elsewhere: loot and roll lines follow `loot`, ready check lines follow `chatNames`
(and `instChat` in dungeons), the guild message of the day in chat follows `news`, and Battle.net
came-online lines follow `chatNames` or `bnToasts`. Test: `Tools/TestChat.lua` (Blizzard's chat stood in for inside the test file:
chat frames with their history and the secure mixin's TransformMessages / RemoveMessagesByPredicate, the
message handler (as Forever's: only players' lines keep their event and the event's own values; the game's own
lines, joins and /chatlist are added bare), edit box headers, whisper windows; nothing added to the harness).

| Surface | How | Key |
| --- | --- | --- |
| Sender names (say, party, guild, channels, whispers, emotes, achievements) | `ChatFrameUtil.AddSenderNameFilter`: the class label by the sender's GUID (noted with `P:Learn`), you by name or GUID, Battle.net senders "Player". The link keeps the real name, so whisper and invite still work | chatNames |
| Names in text, NPC lines (`$N`), system lines, rolls, joins, duels, ready checks | `AddMessageEventFilter` on each event: the game's own lines matched against their global strings (templates, `%1$s` order kept, only the values that are names, a capture must look like "First" or "First Surname"); player links show a label (data kept); `P:ReplaceNames` for known names; `\|K...\|k` Battle.net names | chatNames |
| Public channels: General, Trade (and its Services and Local channels) and LookingForGroup | With the tick on, other players' names there are left as the game sends them (the sender filter returns nothing for them, the text and /chatlist swap only your name: `SwapMine`, `P:ReplaceNames(..., mineOnly)`, `SwapList(list, true)`, join notices only yours); your own name is still swapped (you talking, your name or a link to you in their lines; someone noted whose full name starts with your first name is left whole), and Battle.net `\|K` names (your friends') still hidden. Senders are still noted (`P:Learn`), so their names stay hidden where chat stays private. Told apart by the event's own values, never by the name shown: the channel id (arg7, zoneChannelID, never secret) in `PUBLIC_IDS`, else, when the id is 0 or missing, the base name (arg9) in `PUBLIC_NAMES`. Ids from the game's ChatChannels table (wago.tools, 2026-10-11): `wow_classic_beta` (Forever's client folder): General 1, Trade 2, LocalDefense 22, LookingForGroup 26, Newcomer Chat 32, Trade (Services) 42, HardcoreDeaths 44, Trade (Local) 46; Classic Era: LookingForGroup 24, GuildRecruitment 25, Services 45. Public: 1, 2, 24, 26, 42, 45, 46. Custom channels (id 0, a name of their own), LocalDefense, Newcomer Chat and every other channel stay private. Channel names still follow `channels`; nothing changes with chatNames off | publicChannels (off by default; only with chatNames) |
| Loot and roll lines (CHAT_MSG_LOOT) | the same, templates for LOOT_ITEM, LOOT_ROLL_*, CREATED_ITEM | loot (Windows' row) |
| Whispers, Battle.net whispers, AFK/DND replies | dropped by the filter; locked ones (dungeons) taken out by the OnEvent hook | whispers |
| Battle.net "came online/offline", removed, broadcast lines | dropped (the game builds the name from the account itself, so it can't be swapped); the window's preview shows the line gone | chatNames or bnToasts |
| Guild message of the day (printed straight into chat by ChatFrameUtil.DisplayGMOTD, no chat event, no filter) | the OnEvent hook after GUILD_MOTD / UPDATE_CHAT_WINDOWS, and at turn-on: `TransformMessages` makes it "Guild Message of the Day: (hidden)". One way | news (Social's row) |
| Channel names, "Changed Channel" notice, /chatlist, join/leave notices | arg4 "1. General - Zone" to "1. General" (the number must stay: the game needs it). LocalDefense lines are dropped (they say where you are) | channels |
| Dungeons, raids, battlegrounds | the game makes those lines secret and skips addon filters. `HookScript("OnEvent")` on each chat frame: after an event with a secret value, `TransformMessages` swaps every secret line in that frame (the whole line, older ones too: the game can't say which is new) for "[Party] (hidden)" (Hide names) or `RemoveMessagesByPredicate` takes them out (Hide chat). Only `issecretvalue` is asked of them. One way, and never while `P:ShotOnly()` | instChat |
| Lines already in chat | when private turns on (or the tick goes on while private): names, links and channel zones cleaned, locked lines hidden (instChat), old whispers taken out (with Hide whispers). With publicChannels ticked, a public channel's old line is cleaned as a new one is (only your name, the zone still stripped), told apart by the event and its values the game keeps with a player's line (`GetMessageInfo`'s 8th and 9th: `event`, `eventArgs`, a `SafePack` of the event's own values, only read; checked in Forever's ChatFrameOverrides). Join and /chatlist lines are added bare (no event, no values), so an old one in a public channel is cleaned in full (its channel is only known by the translated name shown). One way; nothing of this happens without the tick | cleanOld |
| Edit box header ("Tell Name:", your name on /e, "[1. General - Zone]:") | `hooksecurefunc(header, "SetFormattedText")` on each ChatFrameNEditBoxHeader: our text is in before UpdateHeader measures it. The text is worked out from the box's GetChatType / GetTellTarget / GetChannelTarget, never from the header | chatNames, channels |
| Whisper tabs, minimised buttons, dock overflow list | post-hooks on FCF_SetWindowName, FCF_CreateMinimizedFrame, FCFDockOverflowListButton_SetValue; FCF_OpenTemporaryWindow hooks new windows (with any of instChat, whispers, chatNames, channels) and, a frame later, takes locked lines out of whisper windows (the game resends the whisper into the new window through GetScript, which may skip hooks) | whispers, else chatNames |
| Timestamps | `P:SetCVar` showTimestamps "none" | timestamps |
| Bubbles | `P:SetCVar` chatBubbles, chatBubblesParty, chatBubblesRaid "0" (Raid skipped if missing) | bubbles |

- Filters are added on `Apply(true)` and removed on `Apply(false)`, so nothing runs in chat while off. The
  hooks stay (they can't be removed) and return at once.
- Labels in chat text are coloured and never hold a "%": NPC and achievement lines are format strings and an
  emote's link is a gsub replacement. A "%" typed in "Your name becomes" is dropped in chat only.
- publicChannels changing while private: new lines follow it at once (the filters read it each time); lines
  already printed stay as they were, as with every other chat setting. Locked channel lines (an encounter in
  the open world) are instChat's as ever. The Chat page lists it right under "Swap names in chat": the two
  columns fill row by row, so the rows are in the order chatNames, whispers, publicChannels, cleanOld, then
  the instChat choice on its own row (moved below them on 2026-10-11 so the new tick could sit under
  chatNames). The preview's General line follows it (the sample sender's real name, the zone still gone).
- A /wave (TEXT_EMOTE): the sender's own name is left in the text, since the game swaps it for their link.
- Template captures are never noted with `P:Learn` (a wrong match would teach a word as a name); player
  links and senders are.
- A whisper tab whose name was secret can't be put back: `P:NeedsReload` (temporary windows don't outlast a
  /reload).
- TestCore's "always" block stubs Chat's Apply as it does UnitFrames', since the real module now uses
  chatBubbles from login (that block checks a CVar nothing uses is put back).
- Not covered: Discord display names in guild chat (the game returns them before the sender filter runs);
  the Chat Channels window (check first whether Forever shows zones there); centre-screen raid warnings.
- Known costs: lines that are cleaned or hidden don't come back after private mode turns off (the big
  button's note, instChat's description and Good to know say so); a transformed line's fade timer restarts,
  so a faded line can show again for a moment; a hidden whisper doesn't set the reply target (R); with Hide
  whispers, a whisper still opens its own (empty) tab when whispers pop out (FloatingChatFrameManager opens
  it before any filter; the whispers description says so).
- "For screenshots": nothing one-way happens during the shot (old lines, locked lines and the message of
  the day stay as they are), so chat history survives every screenshot; cleanOld opts in.

Needs an in-game check:

- In a dungeon: `/dump C_ChatInfo.InChatMessagingLockdown()`; party lines show "[Party] (hidden)" with Hide
  names, vanish with Hide chat, stay with Leave as is. No taint or Lua errors from the OnEvent hook.
- The edit box: /w, /e and /1 show the swapped header with no big gap, and slash commands and macros typed in
  chat still work afterwards (the edit box is security-sensitive).
- Channel names arrive as "1. General - Elwynn Forest" on Forever, and LocalDefense is named "LocalDefense".
- Seen in game 2026-10-11: Forever's channel BASE name (the event's 9th value) carries the zone too ("General - Darkshore"),
  and General's channel id was not 1, so the first public-channels build never matched and General names stayed swapped.
  Public channels and the LocalDefense drop now go by the base name's part before " - " (Chat.lua BaseOf); the id only
  counts when the game sends no base name.
- Leave public channels as they are: on Forever, `/run local f=CreateFrame("Frame") f:RegisterEvent("CHAT_MSG_CHANNEL")
  f:SetScript("OnEvent",function(_,_,...) print(select(7,...),select(9,...)) end)` prints each channel line's id and
  base name: General 1, Trade 2, LookingForGroup 26 (or 24) expected, a custom channel 0. Then, private with
  the tick on: Trade, General and Looking for Group show real senders and names, your own name is still
  swapped there (you talking, someone saying your name), say, party, guild and whispers still swapped, a
  custom channel still swapped, "General - Elwynn Forest" still shortened with Channel names. Untick it while
  private: new lines swapped, old ones as they were. With Clean lines already in chat ticked, turning
  private on leaves Trade's old lines' names (yours swapped). If an id differs, add it to `PUBLIC_IDS`.
- Loot and roll lines match their global strings on Forever (any missing string is skipped quietly).
- showTimestamps "none" stops timestamps at once (the chat reads it through Settings.GetValue).
- NPC speech bubbles obey chatBubbles.
- Whisper popout tabs read well after the swap (their width was set for the real name).
- A locked whisper in a dungeon with only Hide whispers ticked: the pop-out window opens empty (taken out
  at once if the resend runs the hook, else a frame later).
- The guild message of the day: GUILD_MOTD_TEMPLATE starts "Guild Message of the Day: " on Forever; the
  line at login and a new one set while private both show "(hidden)".
- "For screenshots" in a dungeon: chat history unchanged after the shot.

### Social

Tests: `Tools/TestSocial.lua` (its own stand-ins for every window below; none added to the harness) and
`Tools/TestSocialUI.lua` (Forever's newer social window, stood in for from Blizzard_SocialUI's real code).

How it changes things:
- Names go through `Put` (the core's `P:SwapText`, skipped when the text already shows, so applying twice writes
  nothing). Notes, zones and free text are hidden by alpha (`Mask`), never blanked as text, so a reused row
  can't get someone else's note "put back". Names the game reads back off the screen (/who right-click, mail
  Reply) are never rewritten: alpha 0 plus our own label laid over them (`Cover`).
- Mixin hooks go in at load (rows copy the mixin when made): `CommunitiesMemberListEntryMixin` SetMember and
  RefreshExpandedColumns, `CommunitiesListEntryMixin.Init`, `LFGWhoListButtonMixin.InitButton` (when the group
  finder loads), `RecentAlliesEntryMixin.SetCharacterName`, and the newer window's (below). Everything else goes
  in at Setup.

| Setting | Covers | Hook |
| --- | --- | --- |
| friends | WoW friends (class + level, zone hidden), Battle.net friends ("Friend (Mage)"), friend requests, your BattleTag (your made-up BattleTag, else your typed name, else "Battle.net"; worked out from the game's own text, so a blank Hidden label is labelled again when the style changes), your broadcast box (stars), the friends hover box (name, character line, zone, note, broadcast). The newer social window (below): your BattleTag in its header (its copy button out of reach), friend and request cards, the broadcast box. Quick Join and Recruit-A-Friend in both windows | `FriendsFrame_UpdateFriendButton`, `_UpdateFriendInviteButton`, `_CheckBattlenetStatus`, `FriendsFrameTooltip_SetLine` (its own frame, not the game's tooltip); the newer window's hooks below |
| bnToasts | Came online / offline / broadcast pop-ups say "A friend"; the late character line hidden. The same pop-up serves both windows (`BNToastFrame` inherits Blizzard_SocialToast's template, whose other users name nobody) | `BNToastFrame` ShowToast, its MiddleLine's SetFormattedText |
| whoList | /who rows (covered; your own row's zone and guild hidden), ignore and block list, recent players; the newer window's ignore list and recent allies | mixins above, `IgnoreList_InitButton`; the newer window's hooks below |
| roster | Roster names (you: your label), notes, your zone; details panel name, both notes, your zone; guild event log hidden | mixins above, `CommunitiesFrame.GuildMemberDetailFrame` DisplayMember |
| news | News rows ("Warrior obtained [item]"), the news feed's MOTD row, the Info tab's MOTD and guild info (hidden) | `GuildNewsButton_SetNews`, `GuildNewsButton_SetMOTD` |
| guildName | Guild and community list ("Guild" / "Community"), the inspect window's guild tab | `CommunitiesListEntryMixin.Init`, `InspectGuildFrame_Update` |
| mail | Inbox senders (player mail only) and names in subjects, the open letter (sender covered, names in the body, invoice buyer), the To box's suggestions (the To box itself stays readable: the user needs to see the name typed, 2026-10-11) | `InboxFrame` Update, `OpenMailFrame` Update, `AutoComplete_UpdateResults` (only when the To box owns it) |
| groupFinder | Listing leaders, the hover box (leader, members by their colour, comment), listing comments | `LFGBrowseSearchEntry_Update`, `LFGBrowseSearchEntryTooltip_UpdateAndShow`, `LFGBrowseGroupDataDisplayComment_Update` |
| calendar | Invite lists, "Created by" in the view and edit windows | `CalendarEventInviteList_InitButtonShared`, `CalendarViewEventFrame_Update`, `CalendarCreateEventFrame_Update` |

The newer social window (Blizzard_SocialUI; Forever uses it: `C_SocialUI.IsSystemEnabled()` is true, checked in
game 2026-10-11). Its tabs: Friends, Recent Allies, Quick Join, Friend Requests, Recruit-A-Friend and Raid (the Raid
list is UnitFrames' groupFrames); no guild or community page, so roster, news and guildName have nothing here.
Cards are recycled: each hook is on the step that writes a card's text, so it runs on every fill (whoever the card
shows now) and before the game measures the text for the layout.

| Surface | What shows | How | Key |
| --- | --- | --- | --- |
| Header: your BattleTag | The label the old window uses (your made-up BattleTag, else your typed name, else "Battle.net"; in the Name colour, the game's own being the BattleTag's, and a made-up one in the game's own drawn like the real one: its name in the BattleTag colour, "#" and the number in the suffix colour). The game's text is hidden by alpha, never rewritten, so it comes back exactly as the game laid it out. A strip of our own over the whole BattleTag area shows the label and takes the mouse: the copy button (hidden too) can't be clicked, so the real BattleTag never reaches the clipboard, and the hover that repeats a cut-short BattleTag can't show. A BattleTag the game makes a secret (with the copy button up) is covered the same way, its label plain. "Battle.net unavailable" and its button are left | `ShowBestDisplayTextAndButton` on `SocialUIFrame.BattleNetBar.ControlsContainer.PersonalBattleTagDisplay` (the instance, at Setup or when Blizzard_SocialUI loads) | friends |
| Broadcast side window | Stars, as the old window's box | `Stars` on `SocialUIFrame.BattleNetBroadcastFrame.EditBox` | friends |
| Friend cards (search and filter results are the same cards) | `FriendName` "Friend (Mage)" in the card's own blue or grey; `Name` (the character) by its label (class colour online, the game's dark grey offline); another game's name, or the BattleTag the game puts in its place, hidden; `Location` hidden while online ("Last online" kept); level and class kept | `FriendsListSocialCardMixin` RefreshFriendNameDisplayText, RefreshFriendCharacterDataDisplayText, RefreshLocationDisplayText (at load) | friends |
| Friend request cards | `Name` "Friend request" in the game's colour; when sent and the kind of request kept | `FriendRequestsListSocialCardMixin.InitializeRequesterNameText` (at load) | friends |
| Quick Join rows (this window's tab and the old one's) | Each member's link keeps its data (the real name, for right-click and whisper); only the name shown becomes the label: a Battle.net friend "Friend (Mage)", anyone else by class from their GUID, you your label. A name with no link (unknown) is left | `QuickJoinButtonMixin.SetEntry` and `QuickJoinEntryMixin.ApplyToFrame` (at load). Rows older than the hooks (Quick Join fills its lists as it loads, so after a /reload) are hooked on the row when private turns on; one kept back in the list's pool then is still labelled when it comes back, since each list makes its group entries afresh (from the hooked mixin) whenever it opens | friends (Quick Join lists your friends', guildmates' and community groups, and sits in the friends window) |
| Recruit-A-Friend rows (both windows) | `Name` "Friend (Mage)" (the recruit's Battle.net name or BattleTag), `CharacterName` by its label; "Pending Recruit" and the status line left | `RecruitListButtonMixin.SetupRecruit` and `RecruitListButtonSocialMixin.UpdateCardTextColors` (at load). Rows older than the hooks (the lists also fill as they load): a newer-window row always passes through the hooked `RecruitListButtonMixin.SetupRecruit`, which hooks the row's own colour step just before it runs (`HookRecruit`); the older window's are hooked when private turns on and after each `UpdateRecruitList` of `RecruitAFriendFrame` (hooked on the instance at Setup), so one kept back in the pool is caught when the list next updates | friends (recruits are Battle.net friends) |
| Ignore side window | An ignored player by class (else "Player"), a Battle.net block "Player" | `SocialUIIgnoreListEntryMixin.RefreshName` (at load) | whoList |
| Recent allies cards | `Name` by class, as the old list (their zone and last activity kept, as /who keeps others' zones) | `RecentAlliesSocialCardMixin.RefreshCharacterDataDisplayText` (at load) | whoList |

- Turning on, a setting change or a name setting re-labels every card the lists are showing (`Rows` on each
  content frame's ScrollBox: `SocialUIFrame.FriendsList`, `.FriendRequestsList`, `.QuickJoinFrame`,
  `.RecruitAFriendFrame`, `.IgnoreListFrame`, `.RecentAlliesList`, plus `QuickJoinFrame` and
  `RecruitAFriendFrame.RecruitList` of the old window). Headers and spacers are skipped (no card data). Each list
  (and the header) is its own `OnScreen` entry, so its own guard: one failing never stops the others.
- A friend card whose character or online state can't be read (a secret) has its character line and zone hidden,
  never shown or read.
- Right-click titles: friend cards open `BN_FRIEND` / `BN_FRIEND_OFFLINE` and recruit rows `RAF_RECRUIT`, all under
  Windows' `menus` (RAF_RECRUIT added there 2026-10-11, its title "Player").
- Known cost: a card showing when private mode turns on keeps the width the game measured for the real name
  until the list redraws (it does on any friend change, a search, or reopening), so a longer label may be cut
  short for a moment; the same the other way when private mode turns off. The header has no such cost.

Not covered (left alone on purpose):
- Guild charters: the Windows module does them (its `popups` setting), so they're not hooked here.
- Hover tooltips that use the game's tooltip: guild roster rows, /who rows with long names, recent players, the
  calendar's day buttons ("Invited by"), the minimap's "You have mail from". The friends-of-friends window.
  Quick Join toasts (their text alpha is animated). Battle.net "came online" lines in chat are the Chat module's.
- The newer window's hover boxes all use the game's tooltip (`GetAppropriateTooltip()`, filled with AddLine, no
  tooltip data, so no `TooltipDataProcessor` post-call runs): friend cards (account name, character, zone, note,
  broadcast), request cards (the requester's name), recent allies, Quick Join rows (group leader) and
  Recruit-A-Friend rows (the recruit's name; in the old window too). Don't hover them on stream (Good to know and
  the friends row's description say so). The only way short of the rules would be a motion-only frame over each
  card that passes clicks on: not built, it needs a decision first.
- Quick Join's right-click menu title (`MENU_QUICK_JOIN`, the member's real name): the menu is tagged with no
  context data, so Windows' `menus` can't tell whose it is; not hooked (Good to know says so).
- The note editors (clicking a note opens the real text) and the MOTD / info edit boxes.

Needs an in-game check:
- The newer window's header: the label sits where the BattleTag was, Name colour follows (Game's own: the
  BattleTag's blue), the copy button is gone and clicking its spot copies nothing (no "copied" line in chat); the
  status menu and the Battle.net menu still work; off (or friends unticked) brings the BattleTag and the copy
  button back exactly. With Battle.net down, the "unavailable" notice and its button still show and click. A long
  typed name: our label isn't cut short, so check it doesn't run over the status menu. Hovering the strip shows
  nothing (the game's "cut short" hover and the copy button's hover are both under it).
- A made-up BattleTag in both headers (the list under "Needs an in-game check (core and window)"); the older
  window's header after switching from the Hidden style back shows its label again without reopening.
- Friend cards: labels, other games' names hidden, zones hidden online, last online kept; a search; scrolling
  (recycled cards follow); no Lua errors with `/console taintLog 0` while clicking cards, inviting from a card's
  party button, right-clicking a card.
- Friend requests tab, the broadcast side window (stars, still saves), the ignore side window, recent allies.
- Quick Join (only with groups to join): labels, a click on a name and right-click still work (the link data is
  the real name). Recruit-A-Friend: the recruit card, and its right-click title reads "Player" (with `menus`).
- After a /reload (Quick Join and Recruit-A-Friend fill their lists as they load, before this addon's hooks),
  their rows still swap once private mode is on, and still do when groups come and go (rows kept back and reused).
- The friends list, its hover box and your BattleTag swap; the broadcast box shows stars and still saves.
- A came-online pop-up says "A friend" and the character line stays empty.
- /who: the label sits over the name, right-click still targets the real player; recent players tab exists?
- Guild window: roster rows, notes and your zone, the details panel, the guild list's name, News and Info tabs.
  Rows made before the addon loaded wouldn't have the mixin hooks (they're made when the window first shows).
- Mail: inbox, letter (Reply still fills the right name), invoice, the To box shows what you type, suggestions hidden.
- Private on, addon turned off in the AddOns list, /reload: names above heads show again.
- Group finder rows, hover box and comments; the calendar invite list and creator line; the inspect guild tab.
- No errors with the guild window, group finder or calendar open inside a dungeon (their data is secret there).

### Windows

Test: `Tools/TestWindows.lua` (Blizzard's side is built in the test file; nothing added to the harness).

How it changes things:
- Text goes through `Put` (the core's `P:SwapText`, skipped when the text already shows, so applying twice
  writes nothing); faces and tabards through `Conceal` (`P:HideRegion`, skipped when already hidden). Nothing
  else to put back: menus are drawn fresh each time they open. No CVars, no `NeedsReload`.
- Mixin hooks go in at load (rows copy the mixin when made): `LootHistoryElementMixin.Init` and
  `LootHistoryRollTooltipLineMixin.Init` (Blizzard_FrameXML; the hover's line pool is made at load but its
  lines only on the first hover), `DamageMeterSessionWindowMixin.InitEntry` and `DamageMeterSpellEntryMixin.Init`
  (Blizzard_DamageMeter), `ProfessionsGuildCrafterButtonMixin.Init` (Blizzard_Professions), `PVPCellNameMixin.Populate`
  (Blizzard_PVPMatch). Frames made before those hooks (the loot history's roll animation, the meter's session
  windows) get the same hook on the instance in Setup (only when their own copy, read raw, is still the old
  one, so a window made later is never hooked twice). The `Menu.ModifyMenu` callbacks also go in at load
  (never lazily; Setup adds them only if Menu wasn't there). Everything else goes in at Setup.
- The meter hooks the session window's `InitEntry`, not the row's `Init`: every row and your pinned row go
  through it, so rows built before the hook (meter rows made at load after a /reload) are caught too.

| Setting | Covers | Hook |
| --- | --- | --- |
| popups | Pop-ups (StaticPopup1-4): party invite (queue warning kept), trade request, duel, duel to the death (no link left to hover), res with and without a timer, summon ("a hidden place"), chat channel invite (channel kept), join request ("A player wants to join your group."). The role-asking invite (LFGInvitePopup). The guild invite (inviter "A player", guild "A guild", the leave-your-guild warning made generic, tabard hidden). A guild charter (title "Guild Charter", guild "Hidden", starter and signers as labels) | `Init` on each StaticPopup frame (before the game sizes it) and `StaticPopup_OnUpdate` (timers rewrite every frame); `LFGInvitePopup_Update`; `GuildInviteFrame:HookScript("OnEvent")` (its handler is bound in XML); `PetitionFrame_Update` |
| readyCheck | "A player has initiated a ready check." with the game's difficulty line rebuilt; the starter's face hidden. Never reads who started it (secret in dungeons) | `ShowReadyCheck` |
| menus | The title of right-click unit menus: a unit's (`P:NameFor`, NPCs left), a GUID's (scoreboard), or a name's (friends, guild, chat, Battle.net, a Recruit-A-Friend row: the recruit's account name, so "Player") | `Menu.ModifyMenu("MENU_UNIT_<which>")` for 27 unit menus (RAF_RECRUIT added 2026-10-11), adding an initializer after Blizzard's |
| trade | Your name and your trading partner's ("NPC" unit), in the label's colour | `TradeFrame_Update` |
| loot | Master loot list (in the label's colour; its confirm pop-up reads the button, so it says the label too), roll history winner and current leader (yours: your label), who rolled on the roll history's hover (each roller's own small frame laid into the tooltip, in the class colour, off-spec kept), the boss kill banner's loot list. Loot lines in chat are Chat.lua's, under this tick | `MasterLooterFrame_UpdatePlayers`, mixins above, `BossBanner_ConfigureLootFrame` |
| meter | Session rows ("1. Warrior", yours "2. Druid", a death row the label alone), creatures left; breakdown rows that name a player ("Heroic Strike (Warrior)"; in combat the spell is secret, so the label alone); pets' own lines left | mixins above; only never-secret fields are read (class, isLocalPlayer, index, deathRecapID) |
| professions | "Tailoring [Warrior]" on a linked profession (no brackets when names are hidden); guild crafters | `ProfessionsFrame` SetTitle (instance, when Blizzard_Professions loads), mixin above |
| scoreboard | Battleground scoreboard and results name column; your row told by name, never by GUID | `PVPCellNameMixin.Populate` (results use the same cells; turning on walks PVPMatchScoreboard.ScrollBox and PVPMatchResults.scrollBox) |

Each surface's refresh runs on its own guard (REFRESH), so one failing never stops the rest.

Not covered (left alone on purpose):
- Hover tooltips that use the game's tooltip: the roll history hover's "Waiting on: names" line, a master loot
  button's hover (only when the real name was too long to fit), the trade button's "offer changed" warning,
  scoreboard name hovers, the guild invite's hover (only for a truncated name; our labels are short).
- The master loot menu used with a gamepad (`MENU_GROUP_LOOT`), the group finder's right-click title (Social's
  notes), custom pet names in the meter's breakdown, the faction icon on enemy meter rows in PvP (dropped while
  swapped). Ready check lines in chat follow chatNames (Chat.lua).
- Box sizes: a res or summon pop-up is sized by the game for its own text each frame, so ours (shorter) may
  leave a little room; restored text isn't resized either (the addon may not call the game's Resize).

Needs an in-game check:
- No errors or blocked actions with `/console taintLog 0` when accepting a party invite, trade, duel, res and
  summon while private (the StaticPopup `Init` hooks are on the frames; if anything is blocked, drop those
  four and keep only the `StaticPopup_OnUpdate` hook, which covers every pop-up a frame later).
- Each pop-up's wording and size: party invite (with and without the queue line), the role-asking invite,
  guild invite (tabard hidden), charter, channel invite (its string is positional, `%2$s`), join request
  (does Forever send them?), duel to the death (hardcore only).
- Ready check inside a dungeon (the starter is secret there): the line swaps, the face is hidden, no errors.
- Right-click titles on player, party, raid, target, focus, friend, guild, chat and Battle.net menus; Set Focus
  and Target from a menu still work in combat.
- Trade window names and colours. Master looter (only if Forever offers it), `/loot` roll history (does
  Forever fill C_LootHistory?), the boss kill banner's loot list (does it show on Forever?).
- Damage meter: rows in and out of combat, your pinned row, a second window, a breakdown that names a player
  (duels).
- A linked profession's title; the guild crafters list (only if Forever has the guild view).
- Scoreboard (experimental): once battlegrounds are in Forever.

### World

Test: `Tools/TestWorld.lua` (only Names and World run in it; Blizzard's side is built in the test file).

| Setting | What it does | How |
| --- | --- | --- |
| questText | Your name (first, or "First Surname") in quest text, the progress and greeting pages, the NPC portrait text, gossip and gossip options becomes your typed name, else "adventurer" ("Adventurer" to start a sentence). Only your name: a guildmate called "Light" doesn't change "the Light". Boss emotes and raid warnings in the middle of the screen get every known name swapped as chat does (`P:ReplaceNames`, coloured). | Setup: `QuestInfo_Display`, `QuestFrame_UpdatePortraitText`, `HookScript("OnShow")` on QuestFrameProgressPanel and QuestFrameGreetingPanel, `hooksecurefunc(RaidWarningFrame, "AddMessage")`. At load: `GossipGreetingTextMixin.Setup` and `GossipOptionButtonMixin.Setup` (rows copy the mixin when the gossip window first builds them, maybe before private mode is on). Apply also swaps an open gossip window through `ScrollBox:GetFrames()`. |
| tooltips | Unit tooltips: the name line (title and all) becomes the label in its colour; the type-None lines right under a player's or pet's name (the guild line) go blank; "Name's Pet" owner lines and any known name in other lines (party quest progress) are swapped. Corpse tooltips ("Corpse of Name"; a secret name line becomes "Corpse"). Minimap dot hovers (known names). Hovering a player notes their name (`P:Learn`). World map and zone map group dots are left alone: their hover is built outside the post-calls (a hook on each pin plus `GetOwner` on the game's tooltip), so they're on Good to know instead. | TooltipDataProcessor post-calls (Unit, Corpse, MinimapMouseover), registered once at load; lines set with `P:SetTransient` (nothing recorded: the lines are reused by every later tooltip). |
| craftedBy | "<Made by Name>" on every item tooltip (chat links and comparison tooltips too) becomes "<Made by label>", or a blank line when names are hidden. | Item post-call, matching the game's `ITEM_CREATED_BY`. |
| zoneText | The zone name above the minimap is blank; a frame of our own covers its button so the hover (zone, subzone, faction) can't show. | `Minimap_Update` hook. The cover also takes the click that opens the map (M still works). |
| coords | The minimap and world map coordinates. | CVars minimapShowPlayerCoords, worldMapShowPlayerCoords, worldMapShowCursorCoords. |
| zonePopups | The big zone, subzone and PvP lines in the middle of the screen. | `P:HideRegion` on ZoneTextString, SubZoneTextString, PVPInfoTextString, PVPArenaTextString (the game fades the frames, never these). |
| clock | The minimap clock shows realm time; its hover (which always lists local time) and click are covered. | CVar timeMgrUseLocalTime; the cover goes on when Blizzard_TimeManager loads. |
| worldMap | "Keep closed": a curtain of our own covers the world map and the zone map (Shift+M) while they're open, with "The map is hidden while private mode is on. Press Escape to close it." | The addon may not close Blizzard's windows (no HideUIPanel, ToggleWorldMap or Hide), so it covers instead. Our frame: child of the map, all points, frame level +2000, takes the mouse and wheel. |
| gold | Your own gold: the backpack, combined bags, vendor and send-mail money, plus any other PLAYER-type money frame the game updates with your gold (trainer, bank). Prices are left alone, even on PLAYER-type frames, and even one equal to your gold on a STATIC frame. | `MoneyFrame_Update` hook (UpdateMoney's OnShow is bound in XML, so a hook there would miss it) and `P:HideRegion` (alpha). The Forever character window has no money frame. |

Healer names on heal numbers had a row (combatText, through floatingCombatTextFriendlyHealers_v2). The game
caches that CVar, so our change tainted the cached value and every heal in combat text then hit a secret
(`UnitName(self.unit) ~= data` or `BreakUpLargeNumbers(arg3)` in CombatText_OnEvent), even after private mode
was off. The row is gone; Good to know tells the player to untick it in the Combat options by hand.

Tooltips and "Made by" change from the next tooltip on; nothing needs a /reload. Turning off needs nothing
of World's own: every text, alpha, CVar and cover is recorded through the core (tooltip lines on purpose
aren't). Each surface's apply runs on its own guard (APPLY), so one failing never stops the rest.

Needs an in-game check:

- Player tooltips (experimental): no errors over many hovers, in and out of combat (`/console taintLog 0`);
  the guild line really is type None right under the name; a longer label doesn't overflow (the game
  resizes after post-calls, so it shouldn't).
- Whether `$N` in quest and gossip text gives "First" or "First Surname" (both are handled).
- Corpses: Forever reports a player corpse as tooltip type Corpse, and which line holds the name.
- The minimap dot hover's line layout (one line per name, or joined), and secret lines in dungeons (left alone).
- The world map curtain sits above every map layer (pins, quest panel, nav bar) and Escape closes the map.
- Gold: the bags, vendor and mail money hidden; trainer and bank money hidden once the game updates them;
  a vendor's prices and a confirm pop-up's price still shown.
- The zone and clock covers sit right over their buttons (Camelot minimap skin) and block the hover.
- Centre-screen boss emotes in a dungeon: whether their text is readable there (raid warnings are secret).
- "For screenshots": coordinates update on a 0.1 s timer and may not clear before the picture is taken.

Left out: the zone name hover text can't be changed (only covered); the clock's hover lists local time
(covered, not changed); the minimap terrain itself shows towns (not covered); a unit whose token and
GUID are both secret keeps its name line (PvP, needs a check); the world map's group dot hovers and the
battleground AFK report menu on map dots. Arenas: nothing yet.
