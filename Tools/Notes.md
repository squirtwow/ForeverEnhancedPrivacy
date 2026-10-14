# Forever Enhanced Privacy: private notes

Personal and unpublished (no CurseForge, no GitHub remote). By Squirt, original code,
Interface 16001, Lua 5.1, All Rights Reserved. Settings: `ForeverEnhancedPrivacyDB` (account-wide).
`/privacy` opens the window; `/privacy on|off|toggle`; `/privacy minimap` shows or hides the minimap button;
`/privacy brb` shows or hides the be right back screen; `/privacy inbox` shows or hides the whisper inbox.
Keys: Key Bindings > AddOns > Toggle private mode, and Toggle be right back screen. Minimap button: left-click on/off,
right-click the window, shift-click the whisper inbox.

Feasibility research (the safe hook for every surface, what is secret where): the main session's
`scratchpad/privacy-check-1.json` and `privacy-check-2.json`.

## Files

| File | What it covers |
| --- | --- |
| Core.lua | Every setting's row (P.PAGES, P.SECTIONS, P.ROWS, P.KEYS: one table, the window and defaults come from it; a row with `run` and no key is a button, not a setting), saved settings, stores (saved things that aren't settings: `P:Store`, kept by Reset), private mode and its modes, `/privacy`, the key binding, Options > AddOns, the modules, the record of changes and putting it back, CVars (saved originals, crash recovery, combat queue), screenshots |
| Theme.lua | The window's look (palette from the mockup, ticks, options, choice rows, text box, scroll, the count badge) |
| Names.lua | What names become (all the naming helpers below), and the "Names" module that notes group, guild and friends names while private |
| UnitFrames.lua | playerFrame, charTitles, ownHead, targetFrames, groupFrames, nameplates, otherHeads, petNames |
| Chat.lua | chatNames, publicChannels, instChat, whispers, cleanOld, channels, timestamps, bubbles |
| Social.lua | friends, bnToasts, whoList, roster, news, guildName, mail, groupFinder, calendar |
| Windows.lua | popups, readyCheck, menus, trade, loot, meter, professions, scoreboard |
| World.lua | questText, tooltips, craftedBy, zoneText, coords, zonePopups, clock, worldMap, gold |
| Window.lua | The settings window (the approved mockup: pages, ticks, choices, Overview with your name, made-up BattleTag and made-up guild boxes, the eye's and the minimap button's ticks, the be right back screen's message box and Show button, preview (with your own tooltip and its guild line, and the be right back screen in small), footer notes, credit; Reset all settings at the bottom right of the Overview) |
| Eye.lua | The small eye at the top of the screen while private (hidden during screenshots), with the inbox's count beside it |
| MinimapButton.lua | The minimap button (below): private mode on/off, the window, dragged round the minimap, hidden during screenshots; the inbox's count, shift-click opens the inbox |
| BeRightBack.lua | The be right back screen (below): a full-screen card with your message and how long you've been away, its key, Escape through a stand-in on the game's list |
| Inbox.lua | The whisper inbox (below): whispers Hide whispers keeps out of chat, kept in the saved settings, a count in chat, its own window to read and reply |
| Bindings.xml | The two key bindings (call `ForeverEnhancedPrivacy_Toggle()` and `ForeverEnhancedPrivacy_BeRightBack()`); loads on its own, not in the TOC |

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
- Your guild becomes (Overview, right under "Your BattleTag becomes" and styled the same; `myGuild`, default
  `""` = as before, added 2026-10-14 for 1.1.0; the user: "can we enter a fake guild name if we wanna show
  our fake name and guild name?"): a made-up guild shown instead of hiding yours, only while private mode is on
  and "Your guild's name" (`guildName`) is ticked (`P:MyGuild()` checks both and returns nil otherwise), and only
  where the addon hides YOUR guild's name: your own tooltip's guild line (World, with Player tooltips ticked:
  `<Made-up Guild>` in the line's own colour, only while `IsInGuild()` plainly says you're in one, so the line
  under your name really is a guild line; the tooltip is yours by token, GUID or the mouseover, the way its name
  line is found), your guild's row in the guild and community list (Social `ClubRow`: only a club the game marks
  `isClub`, never another guild's invitation, ticket or guild finder invitation) and your own /who row's guild
  (Social `WhoGuild`, under whoList: our own text laid over the hidden column in the column's colour, never
  rewritten; Social's Apply re-labels the whoList lists when guildName changes, `ALSO`). Tidied by `P:CleanGuild`
  (as `P:CleanName`, plus "<" and ">" dropped since the tooltip adds its own; at most `P.GUILD_MAX` = 24 letters),
  checked and tidied again at load, in `P.NAME_KEYS`. Never above your head (the game draws that: ownHead hides
  only), never for other players (their tooltips' guild lines stay blank; the inspect tab is always someone
  else's guild, so it stays "Guild"), never coloured (the Name colour plays no part). The Hidden style leaves a
  typed guild. A tooltip line is only ever changed, never added, so in no guild there's no line to put it on.
  Windows.lua has nothing to swap: the guild invite's leave warning is already the game's generic one (no guild
  named), and charters are guilds not formed yet. The window grew 62 (580 to 642 high) for the box; the preview
  grew with it and gained a card for your own tooltip between the party and the chat (your name, and under it
  your real guild from `GetGuildInfo("player")`, blank while private hides it, or the made-up one).
- Name colour (Overview, under "Your name becomes", "Your BattleTag becomes" and "Your guild becomes" (which it
  never colours); `myColour`, default `game`,
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
  `ForeverEnhancedPrivacyDB` dropped, so each setting is its default (`P.DEFAULTS`): your name, BattleTag,
  guild and be right back message empty, "With its key", class names, the game's own colour, the eye on, the minimap button
  shown at its first spot,
  every tick and choice as it started.
  Only `wasOn = false` and `cvarBackup` stay: empty, unless a CVar couldn't be put back (in combat), when its
  original waits there and goes back when the fight ends (the usual combat queue), or at the next login. The stores
  stay too (`inbox`, the kept whispers: yours, not options; Reset's note says "Your key bindings and kept whispers stay.").
  Listeners hear "reset" (the window refreshes every control and the preview, the eye hides, a showing be right back
  screen says "Be right back" again but stays up: it isn't a setting), and chat says
  "Forever Enhanced Privacy: Settings reset." once. The key binding is the game's (Key Bindings), so it stays.
- Nothing does work while private mode has never been on this session: modules are set up lazily, apart
  from the registrations the feasibility check says to make at load (tooltip post-calls, menu callbacks)
  and mixin hooks, which all return at once while off.

## The minimap button

MinimapButton.lua, added 2026-10-11 (the user: "after this push can you make a button for the privacy one").
`ForeverEnhancedPrivacyMinimapButton` on `Minimap`, made at PLAYER_LOGIN. Named so EraUI's Clean Minimap can list
it later (EraUI not changed for it).

- The siblings' look (the cooldown manager's, cooldown pulse's, cursor's and Clam Opener's buttons): 32 wide, a dark
  circle (TempPortraitAlphaMask), the minimap's gold ring (MiniMap-TrackingBorder), the zoom button's highlight. Inside,
  this addon's eye (Media/Eye.tga, cropped as Eye.lua does, 16 by 10): in the accent while private mode is on, the
  window's soft grey while off. It hears every listener notice (private, reset, any setting), so the key, the big
  button, /privacy on and Reset all show on it at once.
- Left-click: `P:SetPrivate(not P:Private(), "minimap")`, as the big button: quiet (no chat line), kept over a /reload.
  Right-click: `P.ToggleWindow()`. A click within .2 s of letting go of a drag is the drag's, so ignored. Shift-click
  (either button, 1.1.0): the whisper inbox, private mode left alone. While whispers wait, a count at its top right and
  two more hover lines (see "The whisper inbox"); made only once there are any, so the button's own look is unchanged.
- Drag (left button): follows the cursor round the minimap's edge (`isMoving` set meanwhile, so minimap tidiers don't
  fade it), saved once let go as `minimapAngle`: degrees anticlockwise from the right, whole numbers, default 165
  (`P.MINIMAP_ANGLE`: the left edge a little above the middle, clear of the siblings: Clam Opener 200, the cooldown
  manager 225, the cursor 255, cooldown pulse 285; a button spans about 25 degrees there). Checked at load: a
  number from 0 up to 360, else the default. A circle (radius: the minimap's width / 2 + 4), as the siblings have it;
  square minimaps aren't handled (none of the siblings does). `Minimap:HookScript("OnSizeChanged")` keeps it on the edge.
  Hidden mid-drag (a screenshot), it lets go where it was. Only reads (`GetWidth`, `GetCenter`, `GetEffectiveScale`,
  `GetFrameLevel`) and that one HookScript on `Minimap`.
- Hover: a box of its own (the window's dark fill edged in the accent, strata TOOLTIP, never the game's tooltip): the
  addon's name, "Private mode: on" (on in the accent) or "off", "Left-click: turn it on" (or off), "Right-click:
  settings", "Drag: move it round the minimap". Fixed words only: never a name, your typed name or BattleTag. It opens
  toward the middle of the screen, follows a click while hovered, and goes on a drag or when the button hides.
- Screenshots: hidden from SCREENSHOT_STARTED to SCREENSHOT_SUCCEEDED / SCREENSHOT_FAILED in every mode, as the eye, so a
  picture never shows it (with "For screenshots" it's gone before private mode comes on). A screenshot never brings it
  back when its tick is off.
- Setting `minimap` (default on): the Overview's Extras tick "Show a minimap button", beside the eye's. The column had
  no room for another row above the key note, and the eye's old label ("Show a small eye while it's on") left no room
  for a second tick in one row, so the eye's is now "Show a small eye" (when it shows moved into its note). Each tick
  is as wide as its box and label need (measured as it's built, so in game by the game's font), the room left shared;
  together they fill the column. `/privacy minimap` flips it and says so in chat (hidden: how to bring it back).
  Reset all settings brings it back at its first spot.
- Rules: apart from Window.lua, only MinimapButton.lua (`minimapAngle`, on letting go) and the core's `/privacy
  minimap` (`minimap`) call `P:Set`; TestRules allows exactly those two keys there and still refuses any other (its own
  self-check feeds it made-up lines to prove that).
- The hover box's words are checked to fit it (TestMinimap, at the harness's six units a letter); the cursor's sibling
  shows the same "Drag: move it round the minimap" in a box as wide, so it fits in game too.

## The be right back screen

BeRightBack.lua, added 2026-10-14 for 1.1.0 (the user picked it from three ideas on 2026-10-11: one key binding, a
full-screen card with their own text, default "Be right back"). Test: `Tools/TestBeRightBack.lua`.

- `ForeverEnhancedPrivacyBeRightBack`, our own frame, made the first time it's asked for: a child of `UIParent`, all points
  on it (and sized from it as it's made), strata TOOLTIP (the top one) at level 5000, so it sits over the game's windows, the
  game menu, pop-ups (DIALOG), toasts, the low health glow (`LowHealthFrame`, FULLSCREEN_DIALOG and toplevel on Forever) and
  the game's frames at TOOLTIP that stay up without the mouse: an item link window opened from chat (`ItemRefTooltip`), the
  Lua error window (`ScriptErrorsFrame`) and the queue status box (`QueueStatusFrame`), all TOOLTIP in the forever branch's
  XML. It was FULLSCREEN_DIALOG until review (2026-10-14) found those three drawn over it. Our own frame, so its strata
  is safe to set in a fight. The window's dark fill, solid, edge to edge; the window's accent line
  along the top; the eye (Media/Eye.tga, cropped as Eye.lua does, 64 by 40, in the accent) above the middle; your message
  under it in the game's font at 40 (GameFontNormalHuge's file, `SetFont`), centred, wrapping 80 in from each side; under that
  "Away for 12 sec" / "3 min" / "1 hr" / "1 hr 5 min" in the window's soft grey, counted from when it came up
  (`GetTime()`), redrawn once a second by the card's own OnUpdate (so only while it shows). A click shows "Press Escape to
  come back." at the bottom for 4 seconds (the card says nothing about controls otherwise: stream viewers see it).
- The message: `brbText` (default `""` = "Be right back", `P:BrbText()`), the Overview's box, tidied by `P:CleanBrb`
  (`P:CleanName` at `P.BRB_MAX` = 40 letters), checked and tidied again at load. Not a name key: no module hears of it. A
  change shows on a showing card at once (it's a listener). Reset empties it; the card itself isn't a setting, so it stays.
- Brought up and taken down by its key (Key Bindings > AddOns > "Toggle be right back screen", `FEPRIVACY_BRB`, no heading
  of its own so the game lists the addon's heading once), `/privacy brb` (quiet, as the key) and the Overview's Show button
  (Escape or the key takes it down). Private mode on or off, never changed by it. Session only: a /reload drops it.
- Mouse yes, keyboard never: `EnableMouse` and `EnableMouseWheel`, so clicks and the wheel stop at it; no `EnableKeyboard` or
  `SetPropagateKeyboardInput` (TestRules now refuses both anywhere): every key reaches the game, so moving, chat and
  abilities still work under it, and Escape stays the game's. Taking keys was the other choice ("any key closes it"): on
  Forever `EnableKeyboard` is a protected function and `SetPropagateKeyboardInput` is restricted (its own API docs,
  SimpleFrameAPIDocumentation), a frame that takes keys can swallow Escape, and a cat on the keyboard would drop the cover.
- Escape: Forever's Escape is `ToggleGameMenu` (Blizzard_GameMenuEsc, read from the Gethe forever branch): prioritised
  handlers, pop-ups first, then the game menu, ..., then `CloseAllWindows` (AddOnPost), which hides every frame named in
  `UISpecialFrames`; if nothing took the key, the game menu opens. The card itself isn't on that list: `CloseAllWindows`
  also runs at PLAYER_CONTROL_LOST (a stun or fear, not a taxi), PLAYER_ENTERING_WORLD (every loading screen), PLAYER_DEAD,
  when the UI comes back after Alt+Z and when a full-screen panel opens, which would drop the cover mid-break. A stand-in
  goes on the list instead: `ForeverEnhancedPrivacyBeRightBackEscape`, an empty 1 by 1 frame under the card, shown while
  the card is. When it's hidden (`OnHide`), `dropped` is set; `hooksecurefunc("ToggleGameMenu")` runs right after, and if
  `dropped` it was Escape: the card goes. Anything else: next frame (`C_Timer.After(0)`) the stand-in is shown again, the
  card never left. Closing the card takes the stand-in off the list too, so a later Escape opens the game menu as ever.
  `RegisterGameMenuEscHandler` (Forever's own way to add an Escape step) was left alone: our entry would sit in Blizzard's
  handler table and taint every later Escape press.
- The game menu is never under it: `GameMenuFrame:HookScript("OnShow")` takes the card down whenever the game menu shows.
  Brought up while the game menu is already open, the card covers it; Escape then closes the menu first (the game's own
  order), the card with the next. A pop-up under the card closes first too, as Escape always does.
- Escape also closes every other listed window at the same press (bags, the settings window: the Show button's window goes
  too). That's `CloseAllWindows`, as for any listed window.
- Screenshots: nothing. Shown, it's in the picture on purpose (the point while streaming); "For screenshots" turns private mode
  on and off for the picture but never brings the card up. The eye and minimap button still step aside as before (they're
  under the card anyway).
- Both hooks go in when the card is first made, never at load; each through `P:Guard` with its own ending, as is its
  listener (an error is said once as "The be right back screen part hit an error, so Escape may not take it down. Its key
  still does." / "so it may stay over the game menu. Escape or its key still take it down." / "so it may not show a new
  message at once."), never the core's "so it may miss some names.", since this part has no names.
- The Overview: under Extras' ticks, heading "Be right back screen" at 476, its box at 494 (260 wide, placeholder "Leave
  empty for "Be right back"", at most 40 letters, saved like the name boxes) with a Show button (80 wide, the window's
  button look) at the column's right edge; the key note moved to 536 and now reads "Set both keys in the game's Key
  Bindings, under AddOns." The window grew 62 again (642 to 704 high), the left column 500 to 562, the preview 416 to 478 with a small card at its foot (the accent line,
  the eye, your message on one line, "Away for 3 min"), whatever private mode is doing. Show saves a message being typed
  first. Reset's note now says "every box on the Overview is emptied ... Your key bindings stay."
- The window fits any UI scale (Window.lua's `Fit`, on every OnShow): 768 is the screen's height at a UI scale of 100%,
  not the largest. Forever's UI scale slider goes from 65% to 115% (Blizzard_SettingsDefinitions_Shared/Graphics.lua on the
  forever branch), and at 115% the screen is 768 / 1.15, about 668 high, so from about 109% up a 704 window (642 at 115%
  just fitted) would lose its footer, where every help line shows; `SetClampedToScreen` can't help with a frame taller
  than the screen. So when the screen is under the window plus 8 each side, the window takes `SetScale` (our own frame
  only; the game's UI scale is only read, through `UIParent:GetWidth()` / `GetHeight()`) to fit both ways (a 5:4 screen
  at 115% is about 835 across, under 900), never below .5. At 115% it comes out at about .93. A UI scale changed while it's
  open fits the next time it opens. Review (2026-10-14) caught the old "704 fits the 768 of the largest UI scale" here.
- Known limits: Alt+Z hides it with the rest of the UI (it's a child of UIParent; a frame outside UIParent wouldn't follow
  the UI scale), and the first Escape after Alt+Z brings the UI back and takes the card down together. It covers what the
  game draws as UI; check in game that nothing of the world (the minimap's arrow, damage numbers) shows through. The Lua
  error window and the item link window are toplevel at TOOLTIP: one that shows (or is clicked) while the card is up
  might be raised over it; unproven, the in-game checks have a step for it.

## The whisper inbox

Inbox.lua, added 2026-10-14 for 1.1.0 (the user's agreed design: whispers hidden by Hide whispers go into a private inbox
instead of being lost). Test: `Tools/TestInbox.lua`.

- What's kept: while private mode is on, `whispers` (Hide whispers) is ticked and `whisperInbox` ("Keep hidden whispers in
  an inbox", Chat's row under Hide whispers on the Chat page, on by default: it only keeps what's already hidden), each
  CHAT_MSG_WHISPER and CHAT_MSG_BN_WHISPER, read from our own event frame (never the chat frames), registered the first
  time private mode is on this session. Never kept: a GM's whisper (flags "GM": Forever's chat handler sends those to its GM
  chat before any filter, so they're never hidden; Blizzard_ChatFrameBase/Mainline/ChatFrameOverrides.lua on the forever
  branch), one the game shows nowhere (the 16th value, hide sender in letterbox), your own (by name or GUID), your whispers
  out (WHISPER_INFORM), away and busy replies, and Battle.net's offline notice.
- Locked whispers (secret values, in dungeons, raids, battlegrounds): Forever skips addon filters when any value can't be
  read (`canaccessvalue(...)` in ChatFrameFilters.lua), and Chat's OnEvent hook takes the line out with Hide whispers. Kept
  as an entry with its time and "(hidden)" for whatever the game wouldn't say (sender, words or both), because skipping it
  would lose even the fact that someone whispered; a readable part is kept (a sender alone can still be answered). Nothing
  secret is read, compared, joined or kept. Not kept while private mode is on only for a screenshot (Chat leaves locked lines
  in chat then), unless Clean lines already in chat is ticked: Chat's own `OneWayAllowed` rule.
- An entry: `at` (`time()`), `from` (the sender as the event names them, "First Surname"; never with a "|"), `to` (the
  character it came to, "First Surname", player whispers only), `class` (`GetPlayerInfoByGUID`, for the window's colour),
  `text`, `bn`, `read`. Battle.net: the sender is a protected `|K` string that only works this session, so it's held in a
  weak table in memory with the account id (the 13th value) and never saved; after a /reload the entry shows "Battle.net
  friend" (no "battle.net" tag after it) and can't be answered here. At most 50 (`MOST`) for the whole account: the oldest
  read one goes first, else the oldest. Saved through the core's store (`P:Store("inbox")`, `ForeverEnhancedPrivacyDB.inbox`),
  checked at PLAYER_LOGIN (`Clean`: only the fields above, right types and sizes, no "|" in a name or `to`, a class like
  "WARRIOR"; a player's whisper with no `to` dropped; then `Tidy` drops the read ones and cuts to 50).
- "Kept until read" (the agreed design; review 2026-10-14): a read whisper lasts the session it was read in and goes at the
  next login or /reload; unread ones are kept by /reload and Reset all settings. The saved settings file (WTF) holds real
  names and words until then.
- Each character its own (review 2026-10-14): the saved variables are account-wide, so a player's whisper keeps `to` and is
  only listed, counted (chat's line, the eye, the minimap button), chosen, answered, marked read, deleted or cleared on that
  character (`Mine`, used by `Count`, `Unread`, `Entries`, `Target`, `Find`, `MarkAllRead`, `Clear`). A reply from another
  character would tie it to the first: that was the review's major finding. Battle.net whispers have no `to` and show on
  any character (they came to the account; after a relog they're "Battle.net friend" with no reply anyway). Clear all only
  takes what this character sees; another character's whispers wait for it. Your name (`P:MyNames()`'s full name) is asked
  at login and kept for the session (`Me`); a whisper kept before the game says it is this session's (`unsure`, a weak
  table), given `to` once the name is known, else dropped at the next login (never shown on another character). A renamed
  character's old whispers stay hidden until the cap drops them.
- Chat says only a count: "2 whispers waiting. Type /privacy inbox to read them." (or "1 whisper waiting. ... read it."),
  through `P:Print`: 2 seconds after the first of a burst, then at most one line a minute (`BURST`, `GAP`), nothing while the
  window is open or once they're all read; at login (a /reload too) once if any are unread. Never a name or a word.
- Counts: the minimap button (top right, 14) and the eye (beside it, 12) show the unread count (`T:Badge`: an accent dot,
  1 to 9 then "9+"), made the first time there are any; both are hidden in screenshots with their parents. The minimap
  button's hover box gains "N whispers waiting" (unread) and "Shift-click: whisper inbox" (any kept), its height following
  its lines; a shift-click (either button) opens or closes the inbox.
- Listeners hear "inbox" (`P:Notify`) on every change, so the eye, the minimap button and both windows follow.
- The window (`ForeverEnhancedPrivacyInbox`, 440 by 480, DIALOG, toplevel, movable, on `UISpecialFrames` for Escape): made
  the first time it opens (`/privacy inbox`, the Chat page's "Open the whisper inbox" button under the inbox tick, or a
  shift-click on the minimap button). "Whisper inbox", "Real names show here, so open it off stream." in gold, the unread
  count, then rows newest first: sender in their class colour (a quiet "battle.net" after a friend), the time ("14:32"
  today, "13 Oct, 14:32" before: your clock, off stream), the words wrapped, an accent mark while unread. Click one: read,
  its edge in the accent, "Reply to Name" and a reply box (focused); Enter sends, Escape lets go of the box. The reply line
  is one line (no wrap, 404 wide), so each of its texts must fit (TestInbox checks them): "Click a whisper to reply to it.",
  "Reply to Name", "After a /reload, reply to this one from your friends list." (Battle.net after a reload), "The game hid
  who sent this one, so it can't be answered here." Mark all read, Delete (the chosen one), Clear all (asks first, "Clear
  every whisper?", Clear ignores clicks for half a second as Reset); all three only this character's. The empty note: "No
  whispers kept for this character. ... Read ones go at your next login or /reload." Hidden by alpha from
  SCREENSHOT_STARTED to the end (it shows real names), as the eye steps aside.
- Replies: from our own box, the way Forever's chat box sends (ChatFrameEditBox.lua `SendText`): `C_ChatInfo.SendChatMessage
  (text, "WHISPER", nil, sender)` or `C_BattleNet.SendWhisper(accountId, text)`. Never the game's chat box: Forever's own
  helpers (`ChatFrameUtil.SendTell`, `SendBNetTell`, `OpenChat`) would set its tell target, chat type and text from our code,
  which the rules forbid (the chat box is security-sensitive). While `C_ChatInfo.InChatMessagingLockdown()` says the game
  blocks addon chat, nothing is sent and the window says to reply from chat; a refused send says so too. A reply's own echo
  is Hide whispers' as ever. This also answers the old known cost that a hidden whisper doesn't set R.
- The preview has no incoming whisper to show it on, so it doesn't.

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
  - `Apply(true, key)` with a key in `P.NAME_KEYS` (`nameStyle`, `myName`, `myColour`, `myTag`, `myGuild`): sent
    to every module: re-label what's showing. (`myTag` only shows in Social's headers, `myGuild` in Social's
    lists and World's tooltips (from the next tooltip); the others re-label anyway or, like Chat, skip it,
    which writes nothing new.)
  - Apply must be safe to run twice in a row (idempotent).
- While private mode is off, every hook, filter and post-call returns at once:
  `if not P:IsOn(KEY) then return end` first (a chat filter returns nothing, which means unchanged).
  Wrap each in `P:Guard(M, fn)` so an error is said once and swallowed.

### Settings

- `P:Private()`: private mode is on.
- `P:IsOn(key)`: private mode is on and the row is ticked; for a choice row, its value isn't `"leave"`.
- `P:Get(key)`: a setting's value (`"names"|"chat"|"leave"` for instChat, `"hide"|"leave"` for worldMap,
  `"class"|"player"|"hidden"` for nameStyle, the typed `myName`, `myTag` and `myGuild`, `"game"|"accent"|"class"|"white"`
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

- `P:Guard(M, fn [, tail])`: a safe copy of fn: an error is said once ("The <Module> part hit an error, so it may
  miss some names. <error>") and swallowed (returns nothing); answers pass through, nils included. `tail` replaces
  "so it may miss some names." for a part that isn't about names (the be right back screen).
- `P:OnAddOnLoaded(name, fn, M)`: runs fn once Blizzard's load-on-demand addon `name` has loaded
  (now, if it has). Errors are said once against M.
- `P:InCombat()`, `P.IsSecret(value)` (safe when the game has no `issecretvalue`).
- `P:Print(text)`: chat, prefixed with the addon's name. `P:Say(text)`: the window's footer if open,
  else chat. Modules never call `print` or `AddMessage` themselves (TestRules).
- `P:Store(name [, make])`: a saved table that isn't a setting (only `inbox` so far), made when first asked for (`make`
  false: only looked for); kept by Reset all settings, dropped at load if it isn't a table. `P:Notify(what)`: every
  listener hears `what` (the inbox's "inbox"). Neither is for the modules.

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
- `P:MyGuild()`: your made-up guild (`myGuild`), plain (no colour), while private mode is on and `guildName`
  is ticked; else nil (nothing typed, or the tick off). Only for where your own guild's name is hidden.
- `P:GuildLine(guild)`: a guild's name as a tooltip's guild line, `<Guild>`.
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
  regions that aren't protected; `SetTextInsets` only on the chat edit box, where its typed text starts, as the
  game sets it). Never replace a Blizzard function, never write a key on a Blizzard
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
  (`opts.reload` for a /reload, `opts.beforeLogin` to stop after ADDON_LOADED). Returns P. Every game has `UIParent`,
  `Minimap` (sealed, 140 across, so every test makes the minimap button at PLAYER_LOGIN; TestMinimap gives it a
  `GetCenter` with `rawset` for dragging, and a `GetCursorPosition`), `ChatFrame1` and `GameTooltip`.
- Blizzard's objects are sealed: a key written on one, a method other than a read (`Get`, `Is`, `Has`,
  `Can`, `Enumerate`, `Num`, `Does`), `HookScript`, a cosmetic setter (`SetTextInsets` among them, on what isn't
  protected; every object has text insets to read back) or a chat history edit
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
  TestMinimap, TestBeRightBack, TestInbox, each module's Test<Module>.lua)
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
  (the eye's and the minimap button's ticks side by side) below it, the key note clear of the footer. Type a made-up BattleTag (with a "#" and a number) while
  private: both friends windows' headers show it at once (Game's own: the number darker, like the real
  one; each other colour: all of it). 24 letters fit the older window's box and don't run over the newer
  header's status menu. Clicking the copy button's spot copies nothing (no "copied" line in chat). Emptied:
  your typed name, else "Battle.net"; private off or friends unticked: the real BattleTag and the copy
  button back.
- Your guild becomes (1.1.0): the window, now 642 high, fits on screen at your UI scale; the box sits under
  "Your BattleTag becomes" and looks the same, Name colour, Extras and the key note below it, clear of the
  footer; the preview's tooltip card sits between the party and the chat, and the chat lines still wrap
  inside their box. Hover yourself while private (Player tooltips and Your guild's name ticked, in a guild):
  the line under your name reads `<Made-up Guild>` in the game's guild-line colour; someone else's guild line
  stays blank. Whether Forever's own guild line really is `<Guild>` (compare with private off). The guild
  window's list shows the made-up guild on your guild's row only. /who yourself: the made-up guild in the guild
  column, right-click still works. Emptied, or Your guild's name unticked: as before. No Lua errors with
  `/console taintLog 0` while hovering yourself in and out of combat.
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
- The minimap button: where 165 lands on Forever's minimap (clear of the tracking, mail and zoom buttons and the
  clock?); the ring lines up as on the siblings; the eye reads clearly purple (on) and grey (off) at that size.
  Left-click turns private mode on and off (and the big button, key and /privacy on change the eye at once),
  right-click opens and closes the window, a drag goes round the edge and the spot is kept after a /reload. The hover
  box: its four lines fit 220 wide, it opens below left of the button, and says on/off right after a click. Print Screen
  with private mode on and off: the button isn't in the picture (as the eye; check the picture itself). The Extras row:
  "Show a small eye" and "Show a minimap button" side by side, each label inside its tick, clear of the preview; untick
  hides the button, `/privacy minimap` brings it back. No errors clicking it in combat (`/console taintLog 0`). Once
  EraUI's Clean Minimap lists it (not yet), it fades with the others but never mid-drag.
- The be right back screen (1.1.0): Key Bindings > AddOns lists "Toggle be right back screen" under the addon's one
  heading. The window, now 704 high, fits at your UI scale, and at 115% (Options > System > Graphics, UI Scale ticked) it shrinks a little
  so its whole footer still shows; the box and Show button sit under the Extras' ticks, the key
  note under them, clear of the footer; the preview's small card at its foot. Show, the key and `/privacy brb`: the card
  covers everything (action bars, chat, minimap, the eye, nameplates, the world; check the minimap's arrow and damage
  numbers don't show through); the message is big and centred; "Away for" counts each second, then minutes. Clicks and the
  wheel do nothing under it; a click shows "Press Escape to come back." for a moment. W still walks you forward. Escape
  takes it down with no game menu; the next Escape opens the menu. Bags open, then the card, then Escape: both close. Get
  stunned or die with it up (a loading screen too): it stays, and Escape still takes it down. Print Screen with it up: it's
  in the picture; with "For screenshots" and it down: never in the picture. In combat with `/console taintLog 0`: up, down,
  Escape, the game menu: no Lua errors or blocked actions. An item link window opened from chat before it comes up stays
  under it. With Lua errors shown, `/run error("test")` typed while it's up: does the error window come up over it or stay
  under (toplevel raising at TOOLTIP is unproven)?
- The whisper inbox (1.1.0): the Chat page's tick under Hide whispers and the button under it; with Hide whispers ticked and
  private on, a whisper and a Battle.net whisper stay out of chat and the count line comes once ("2 whispers waiting...", no
  names); the minimap button's and the eye's counts sit well at their size; the hover box's extra lines fit; shift-click opens
  the inbox; rows, colours, times and wrapping; a reply reaches them (and a Battle.net one); a /reload keeps the unread
  whispers and drops the read ones (a friend's then "Battle.net friend", its reply line in full); another character on the
  account sees none of the first one's player whispers (no count, no row), only Battle.net ones; in a dungeon, a whisper becomes a "(hidden)" entry with no Lua errors, and whether
  `C_ChatInfo.InChatMessagingLockdown()` is true there; whether the window is out of a Print Screen picture; no errors with
  `/console taintLog 0`, and slash commands from the chat box still work after replying from the inbox.
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

Chat.lua owns chatNames, publicChannels, instChat, whispers, whisperInbox, cleanOld, channels, timestamps and bubbles
(whisperInbox's work is Inbox.lua's, "The whisper inbox" above: Chat has nothing to apply or put back for it). It also does the
chat side of rows owned elsewhere: loot and roll lines follow `loot`, ready check lines follow `chatNames`
(and `instChat` in dungeons), the guild message of the day in chat follows `news`, and Battle.net
came-online lines follow `chatNames` or `bnToasts`. Test: `Tools/TestChat.lua` (Blizzard's chat stood in for inside the test file:
chat frames with their history and the secure mixin's TransformMessages / RemoveMessagesByPredicate, the
message handler (as Forever's: only players' lines keep their event and the event's own values; the game's own
lines, joins and /chatlist are added bare), edit box headers (sized to their text, cut to half the box with "..." after, the
typed text started past them as Forever's UpdateHeader does), whisper windows; the harness gained only text insets for it,
SetTextInsets allowed on what isn't protected).

| Surface | How | Key |
| --- | --- | --- |
| Sender names (say, party, guild, channels, whispers, emotes, achievements) | `ChatFrameUtil.AddSenderNameFilter`: the class label by the sender's GUID (noted with `P:Learn`), you by name or GUID, Battle.net senders "Player". The link keeps the real name, so whisper and invite still work | chatNames |
| Names in text, NPC lines (`$N`), system lines, rolls, joins, duels, ready checks | `AddMessageEventFilter` on each event: the game's own lines matched against their global strings (templates, `%1$s` order kept, only the values that are names, a capture must look like "First" or "First Surname"); player links show a label (data kept); `P:ReplaceNames` for known names; `\|K...\|k` Battle.net names | chatNames |
| Public channels: General, Trade (and its Services and Local channels) and LookingForGroup | With the tick on, other players' names there are left as the game sends them (the sender filter returns nothing for them, the text and /chatlist swap only your name: `SwapMine`, `P:ReplaceNames(..., mineOnly)`, `SwapList(list, true)`, join notices only yours); your own name is still swapped (you talking, your name or a link to you in their lines; someone noted whose full name starts with your first name is left whole), and Battle.net `\|K` names (your friends') still hidden. Senders are still noted (`P:Learn`), so their names stay hidden where chat stays private. Told apart by the event's own values, never by the name shown: the channel id (arg7, zoneChannelID, never secret) in `PUBLIC_IDS`, else, when the id is 0 or missing, the base name (arg9) in `PUBLIC_NAMES`. Ids from the game's ChatChannels table (wago.tools, 2026-10-11): `wow_classic_beta` (Forever's client folder): General 1, Trade 2, LocalDefense 22, LookingForGroup 26, Newcomer Chat 32, Trade (Services) 42, HardcoreDeaths 44, Trade (Local) 46; Classic Era: LookingForGroup 24, GuildRecruitment 25, Services 45. Public: 1, 2, 24, 26, 42, 45, 46. Custom channels (id 0, a name of their own), LocalDefense, Newcomer Chat and every other channel stay private. Channel names still follow `channels`; nothing changes with chatNames off | publicChannels (off by default; only with chatNames) |
| Loot and roll lines (CHAT_MSG_LOOT) | the same, templates for LOOT_ITEM, LOOT_ROLL_*, CREATED_ITEM | loot (Windows' row) |
| Whispers, Battle.net whispers, AFK/DND replies | dropped by the filter; locked ones (dungeons) taken out by the OnEvent hook. Whispers and Battle.net whispers you get go into the whisper inbox (Inbox.lua) with whisperInbox ticked | whispers |
| Battle.net "came online/offline", removed, broadcast lines | dropped (the game builds the name from the account itself, so it can't be swapped); the window's preview shows the line gone | chatNames or bnToasts |
| Guild message of the day (printed straight into chat by ChatFrameUtil.DisplayGMOTD, no chat event, no filter) | the OnEvent hook after GUILD_MOTD / UPDATE_CHAT_WINDOWS, and at turn-on: `TransformMessages` makes it "Guild Message of the Day: (hidden)". One way | news (Social's row) |
| Channel names, "Changed Channel" notice, /chatlist, join/leave notices | arg4 "1. General - Zone" to "1. General" (the number must stay: the game needs it). LocalDefense lines are dropped (they say where you are) | channels |
| Dungeons, raids, battlegrounds | the game makes those lines secret and skips addon filters. `HookScript("OnEvent")` on each chat frame: after an event with a secret value, `TransformMessages` swaps every secret line in that frame (the whole line, older ones too: the game can't say which is new) for "[Party] (hidden)" (Hide names) or `RemoveMessagesByPredicate` takes them out (Hide chat). Only `issecretvalue` is asked of them. One way, and never while `P:ShotOnly()` | instChat |
| Lines already in chat | when private turns on (or the tick goes on while private): names, links and channel zones cleaned, locked lines hidden (instChat), old whispers taken out (with Hide whispers). With publicChannels ticked, a public channel's old line is cleaned as a new one is (only your name, the zone still stripped), told apart by the event and its values the game keeps with a player's line (`GetMessageInfo`'s 8th and 9th: `event`, `eventArgs`, a `SafePack` of the event's own values, only read; checked in Forever's ChatFrameOverrides). Join and /chatlist lines are added bare (no event, no values), so an old one in a public channel is cleaned in full (its channel is only known by the translated name shown). One way; nothing of this happens without the tick | cleanOld |
| Edit box header ("Tell Name:", your name on /e, "[1. General - Zone]:") | `hooksecurefunc(header, "SetFormattedText")` on each ChatFrameNEditBoxHeader: our text is in before UpdateHeader measures it. The text is worked out from the box's GetChatType / GetTellTarget / GetChannelTarget, never from the header. Who you whisper (1.1.0, see below): "Tell Mage: ", "Tell Player: ", "Tell Friend: " for a Battle.net whisper, "Tell: " under Hidden | whispers or chatNames (who you whisper), chatNames (/e), channels |
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
  columns fill row by row, so the rows are in the order chatNames, whispers, publicChannels, whisperInbox (under
  Hide whispers, 1.1.0), cleanOld, the inbox's "Open the whisper inbox" button (a row with `run`, no key: under the
  inbox tick, beside cleanOld), then the instChat choice on its own row (moved below them on 2026-10-11 so the new tick
  could sit under chatNames). The preview's General line follows it (the sample sender's real name, the zone still gone).
- Who you whisper in the edit box header (1.1.0, the user's "To Name:" ask; Forever's header is "Tell %s: " for both
  CHAT_WHISPER_SEND and CHAT_BN_WHISPER_SEND, wago GlobalStrings 1.60.1.70374; "To %s: " is the line printed after you
  send, CHAT_WHISPER_INFORM_GET, which the sender filter already labels and Hide whispers drops). Forever's
  `ChatFrameEditBoxMixin:UpdateHeader` (Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua): `header:SetWidth(0)`,
  `SetFormattedText(CHAT_WHISPER_SEND, tellTarget)`, measures it (longer than half the box: cut to that, HeaderSuffix "..."
  shown), then `SetTextInsets(15 + header:GetWidth() + suffix + language, 13, 0, 0)`.
  - Ticks: `WhisperKey()` is whispers if ticked, else chatNames (the same rule whisper tabs already had; `TabKey` is now that
    function). Hide whispers keeps the whole conversation private, so the tab and the header both stay swapped with it alone.
    /e stays chatNames only, channel headers channels only.
  - Label: their class when the addon knows it (`ClassFor`: noted, or in your group by name), else "Player"; you: your
    label; a Battle.net whisper "Friend" (as Social's account label; never read: the target is the account's |K name);
    Hidden: blank, the space before it dropped too ("Tell: "). Plain, so the header keeps the whisper colour. A name typed in
    another case than the game's ("/w brannoc") isn't found, so it shows "Player".
  - Typed text kept clear of the header: inside UpdateHeader the game measures our text itself. When ours goes in or comes off
    outside it (private mode, a tick or the name style changing with the box open), `FitBox` sets the box's text insets the
    game's way (15 + the header's width + the shown suffix's + the language tag's; right, top and bottom read and kept), only
    while the box and header show, never with a secret, and only when the left inset really changes. Restores: the header's
    `P:OnRestore` (filed under the same key, run after the core puts the game's text back). `SetTextInsets` is the only call on
    the box itself (the harness allows it on what isn't protected, as SetWidth); its text, tell target, chat type and
    attributes are only read.
  - Known costs: the letters typed after /w (and the names the game suggests, which it also fills into the box) show until the
    header switches (the user accepted this, 2026-10-11: the box's text is security-sensitive, and the mail To box stays
    readable too); Good to know says so, with how to skip typing (click their name in chat, or Whisper on a right-click menu:
    both reach the header with no typed name). A header the game cut short (a name over half the box) keeps the game's cut
    width with our label in it until the game's next update, and a long real name put back shows in full, the typed text past
    it, until the game cuts it again: cosmetic only.
  - The preview: the chat card's foot is the chat box, "Tell Brannoc Stonehelm: on my way" in the whisper pink, swapped with
    either tick ("Tell: " under Hidden). The card grew 4 (140 to 144; the line above the box at 26 from its foot) so every
    chat line still has room for two rows; where you are still sits 8 below it.
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
  so a faded line can show again for a moment; a hidden whisper doesn't set the reply target (R: the whisper inbox
  can answer it instead); with Hide
  whispers, a whisper still opens its own (empty) tab when whispers pop out (FloatingChatFrameManager opens
  it before any filter; the whispers description says so).
- "For screenshots": nothing one-way happens during the shot (old lines, locked lines and the message of
  the day stay as they are), so chat history survives every screenshot; cleanOld opts in.

Needs an in-game check:

- In a dungeon: `/dump C_ChatInfo.InChatMessagingLockdown()`; party lines show "[Party] (hidden)" with Hide
  names, vanish with Hide chat, stay with Leave as is. No taint or Lua errors from the OnEvent hook.
- The edit box: /w, /e and /1 show the swapped header with no big gap, and slash commands and macros typed in
  chat still work afterwards (the edit box is security-sensitive).
- Who you whisper (1.1.0): "Tell Mage:" after /w and a name, R, a click on a name in chat, Whisper on a right-click menu and a
  Battle.net friend ("Tell Friend:"); with only Hide whispers ticked too. Private mode turned on and off with a whisper open:
  the typed text moves up to the label and back past the real name at once, never under the header. The whisper still goes to
  the right person, Tab still cycles who you whisper, no Lua errors or blocked actions with `/console taintLog 0`, in and out
  of combat.
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
| whoList | /who rows (covered; your own row's zone and guild hidden, or with guildName ticked your made-up guild laid over the guild column), ignore and block list, recent players; the newer window's ignore list and recent allies | mixins above, `IgnoreList_InitButton`; the newer window's hooks below |
| roster | Roster names (you: your label), notes, your zone; details panel name, both notes, your zone; guild event log hidden | mixins above, `CommunitiesFrame.GuildMemberDetailFrame` DisplayMember |
| news | News rows ("Warrior obtained [item]"), the news feed's MOTD row, the Info tab's MOTD and guild info (hidden) | `GuildNewsButton_SetNews`, `GuildNewsButton_SetMOTD` |
| guildName | Guild and community list ("Guild" / "Community"; your own guild, the club marked `isClub`, shows your made-up guild if typed), the inspect window's guild tab (always someone else's: "Guild") | `CommunitiesListEntryMixin.Init`, `InspectGuildFrame_Update` |
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
| tooltips | Unit tooltips: the name line (title and all) becomes the label in its colour; the type-None lines right under a player's or pet's name (the guild line) go blank (on your own tooltip, while you're in a guild and guildName is ticked, the first becomes your made-up guild, `<Guild>`, in the line's own colour); "Name's Pet" owner lines and any known name in other lines (party quest progress) are swapped. Corpse tooltips ("Corpse of Name"; a secret name line becomes "Corpse"). Minimap dot hovers (known names). Hovering a player notes their name (`P:Learn`). World map and zone map group dots are left alone: their hover is built outside the post-calls (a hook on each pin plus `GetOwner` on the game's tooltip), so they're on Good to know instead. | TooltipDataProcessor post-calls (Unit, Corpse, MinimapMouseover), registered once at load; lines set with `P:SetTransient` (nothing recorded: the lines are reused by every later tooltip). |
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
