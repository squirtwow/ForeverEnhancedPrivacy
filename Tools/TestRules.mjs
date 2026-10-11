// The addon's rules, checked straight from its source: the TOC lists every
// Lua file once, in the harness's order; the key binding is wired up; no em
// dash anywhere (player text included, even as an escape); no runtime key
// binding changes; CVars only through the core's helper; GameTooltip never
// named; no text run as code; no Blizzard window opened or closed and no
// Blizzard function of the "Name_Update" kind called by the addon; Blizzard's
// frames named in the code never shown, hidden, moved, scripted or written
// on; chat output only through the core; every module file registers itself
// and its header names every setting it owns; British spelling in player
// text; and no other addon named.
// Run with: node --test Tools/TestRules.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const read = name => readFile(new URL(name, root), 'utf8');

async function rootFiles(pattern) {
  return (await readdir(root, { withFileTypes: true }))
    .filter(entry => entry.isFile() && pattern.test(entry.name)).map(entry => entry.name).sort();
}

// Lua with its comments and strings blanked out (lines kept), so only code
// is checked.
function codeOnly(lua) {
  let out = '';
  let i = 0;
  const blank = text => text.replace(/[^\n]/g, ' ');
  while (i < lua.length) {
    const rest = lua.slice(i);
    let match;
    if ((match = rest.match(/^--\[(=*)\[[\s\S]*?\]\1\]/)) || (match = rest.match(/^--[^\n]*/))) {
      out += blank(match[0]);
    } else if ((match = rest.match(/^\[(=*)\[[\s\S]*?\]\1\]/))) {
      out += '""' + blank(match[0].slice(2));
    } else if ((match = rest.match(/^"(?:[^"\\\n]|\\.)*"/)) || (match = rest.match(/^'(?:[^'\\\n]|\\.)*'/))) {
      out += '""' + blank(match[0].slice(2));
    } else {
      match = [lua[i]];
      out += lua[i];
    }
    i += match[0].length;
  }
  return out;
}

// The text in a Lua file's strings (comments left out).
function literals(lua) {
  const found = [];
  let i = 0;
  while (i < lua.length) {
    const rest = lua.slice(i);
    let match;
    if ((match = rest.match(/^--\[(=*)\[[\s\S]*?\]\1\]/)) || (match = rest.match(/^--[^\n]*/))) {
      // a comment
    } else if ((match = rest.match(/^\[(=*)\[([\s\S]*?)\]\1\]/))) {
      found.push({ text: match[2], index: i });
    } else if ((match = rest.match(/^"((?:[^"\\\n]|\\.)*)"/)) || (match = rest.match(/^'((?:[^'\\\n]|\\.)*)'/))) {
      found.push({ text: match[1], index: i });
    } else {
      match = [lua[i]];
    }
    i += match[0].length;
  }
  return found;
}

const lineOf = (text, index) => text.slice(0, index).split('\n').length;

async function addonCode() {
  const files = await rootFiles(/\.lua$/i);
  assert.ok(files.length >= 10, 'the addon files found');
  return Promise.all(files.map(async name => {
    const source = await read(name);
    return { name, source, code: codeOnly(source) };
  }));
}

const MODULES = ['UnitFrames', 'Chat', 'Social', 'Windows', 'World'];

test('the TOC: the right fields, and every Lua file once, in the harness\'s order', async () => {
  const toc = await read('ForeverEnhancedPrivacy.toc');
  assert.match(toc, /^## Interface: 16001\r?$/m);
  assert.match(toc, /^## Title: Forever Enhanced Privacy\r?$/m);
  assert.match(toc, /^## Author: Squirt\r?$/m);
  assert.match(toc, /^## Version: 0\.1\.0\r?$/m);
  assert.match(toc, /^## SavedVariables: ForeverEnhancedPrivacyDB\r?$/m);
  const icon = toc.match(/^## IconTexture: Interface\\AddOns\\ForeverEnhancedPrivacy\\(.+?)\r?$/m);
  assert.ok(icon, 'an icon');
  assert.ok((await stat(new URL(icon[1].replace(/\\/g, '/'), root))).isFile(), 'and its file is there');
  const listed = toc.split(/\r?\n/).map(line => line.trim()).filter(line => line && !line.startsWith('#'));
  assert.deepEqual([...listed].sort(), await rootFiles(/\.lua$/i), 'every Lua file at the root, once, and nothing else');
  const harness = await read('Tools/Harness.lua');
  const files = harness.match(/H\.FILES = \{([\s\S]*?)\}/)[1].match(/"[^"]+"/g).map(name => name.slice(1, -1));
  assert.deepEqual(listed, files, 'the harness loads them in the TOC\'s order');
  assert.deepEqual(listed.slice(0, 3), ['Core.lua', 'Theme.lua', 'Names.lua'], 'the core first');
  assert.deepEqual(listed.slice(3, 8), MODULES.map(name => name + '.lua'), 'then the five modules');
  assert.deepEqual(listed.slice(8), ['Window.lua', 'Eye.lua'], 'then the window and the eye');
});

test('the key binding: Bindings.xml calls the core\'s global, under AddOns', async () => {
  const xml = await read('Bindings.xml');
  assert.match(xml, /<Binding name="FEPRIVACY_TOGGLE" header="FEPRIVACY" category="ADDONS">\s*ForeverEnhancedPrivacy_Toggle\(\)\s*<\/Binding>/);
  const core = await read('Core.lua');
  assert.match(core, /^BINDING_HEADER_FEPRIVACY = P\.TITLE\r?$/m);
  assert.match(core, /^BINDING_NAME_FEPRIVACY_TOGGLE = "Toggle private mode"\r?$/m);
  assert.match(core, /^function ForeverEnhancedPrivacy_Toggle\(\)\r?$/m);
  const toc = await read('ForeverEnhancedPrivacy.toc');
  assert.doesNotMatch(toc, /Bindings\.xml\s*$/m, 'Bindings.xml loads on its own, never from the TOC');
});

test('no em dash anywhere, even as an escape', async () => {
  const names = [...await rootFiles(/\.(lua|xml|toc|txt|md)$/i), 'Tools/Notes.md', 'Tools/Harness.lua', 'Tools/TestCore.lua',
    'Tools/TestWindow.lua'];
  const found = [];
  for (const name of names) {
    let text;
    try { text = await read(name) } catch { continue }
    text.split('\n').forEach((line, i) => {
      if (/—|\\226\\128\\148|\\u\{2014\}|&mdash;/.test(line)) found.push(`${name}:${i + 1}`);
    });
  }
  assert.deepEqual(found, []);
});

test('no key binding is ever changed by the addon\'s code', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(/\b(SetOverrideBinding\w*|ClearOverrideBindings|SetBinding\w*|SaveBindings|LoadBindings)\b/g)) {
      found.push(`${name}:${lineOf(code, match.index)} ${match[1]}`);
    }
  }
  assert.deepEqual(found, []);
});

test('CVars change only through the core\'s helper (P:SetCVar), which saves the originals', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(/(?<![\w])(SetCVar|SetCVarBitfield|ConsoleExec)\b/g)) {
      const before = code.slice(Math.max(0, match.index - 3), match.index);
      if (before.endsWith('P:')) continue; // the helper, called
      if (name === 'Core.lua') continue;
      found.push(`${name}:${lineOf(code, match.index)} ${match[1]}`);
    }
  }
  assert.deepEqual(found, []);
});

test('GameTooltip is never named: tooltips change only through TooltipDataProcessor\'s tooltip', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(/\bGameTooltip\w*/g)) found.push(`${name}:${lineOf(code, match.index)} ${match[0]}`);
    for (const { text, index } of literals(await read(name))) {
      if (/^GameTooltip/.test(text)) found.push(`${name}:${lineOf(code, index)} "${text}"`);
    }
  }
  assert.deepEqual(found, []);
});

// The function a position in Lua code sits in: the nearest "function Name(" before it.
function enclosing(code, index) {
  const before = code.slice(0, index);
  const all = [...before.matchAll(/function\s+([\w.:]+)\s*\(/g)];
  return all.length ? all[all.length - 1][1].replace(/^.*[.:]/, '') : '';
}

// A tooltip handed to the addon (a post-call's or a hook's argument) is only
// ever asked for its lines, by TipLine; its lines change only inside the
// post-calls, never from a hook of another kind (GetOwner is how such a hook
// would find it).
test('a tooltip argument is only asked for its lines, and only by TipLine', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(/\btooltip\s*:\s*(\w+)\s*\(/g)) {
      const where = enclosing(code, match.index);
      if (!['GetLeftLine', 'GetName'].includes(match[1]) || where !== 'TipLine') {
        found.push(`${name}:${lineOf(code, match.index)} tooltip:${match[1]} in ${where || 'the file'}`);
      }
    }
    for (const match of code.matchAll(/:\s*GetOwner\s*\(/g)) found.push(`${name}:${lineOf(code, match.index)} GetOwner`);
    if (name !== 'World.lua') continue;
    // World's tooltip lines: reached only by SwapLine, which writes nothing to put back.
    for (const match of code.matchAll(/(?<!function\s+)\bTipLine\s*\(/g)) {
      const where = enclosing(code, match.index);
      if (where !== 'SwapLine') found.push(`${name}:${lineOf(code, match.index)} TipLine in ${where}`);
    }
    const swapLine = code.match(/local function SwapLine\([^)]*\)\s*\n([\s\S]*?)\nend/);
    assert.ok(swapLine && /P:SetTransient\(/.test(swapLine[1]) && !/P:SwapText\(/.test(swapLine[1]),
      'SwapLine sets tooltip lines through P:SetTransient, never the recorded P:SwapText');
  }
  assert.deepEqual(found, []);
});

// CVars the game caches (CVarCallbackRegistry:SetCVarCachable and
// CombatTextCachableCVars in Forever's own code; regenerate with a search for
// both). An addon's change taints the cached copy until the next change, and
// the game's own code that reads it then fails on secret values.
const CACHABLE = [
  'countdownForCooldowns', 'buffDurations', 'consolidateBuffs', 'collapseExpandBuffs', 'displayTemporaryEnchantIcon',
  'GamepadShowAutoAuraTooltip', 'externalDefensivesEnabled', 'cooldownViewerEnabled', 'cooldownViewerShowUnlearned',
  'damageMeterEnabled', 'showArenaEnemyPets', 'showCastableBuffs', 'showDispelDebuffs', 'rotateMinimap',
  'disableSuggestedLevelActivityFilter', 'colorblindMode', 'showSwingTimer', 'pvpFramesDisplayClassColor',
  'spellDiminishPVPEnemiesEnabled', 'showTargetOfTarget', 'threatShowNumeric', 'showPartyPets', 'noBuffDebuffFilterOnTarget',
  'movePadLocked', 'movePadInPressAndHoldMode',
  'floatingCombatTextLowManaHealth_v2', 'floatingCombatTextAuras_v2', 'floatingCombatTextCombatState_v2',
  'floatingCombatTextDodgeParryMiss_v2', 'floatingCombatTextDamageReduction_v2', 'floatingCombatTextRepChanges_v2',
  'floatingCombatTextReactives_v2', 'floatingCombatTextFriendlyHealers_v2', 'floatingCombatTextComboPoints_v2',
  'floatingCombatTextEnergyGains_v2', 'floatingCombatTextPeriodicEnergyGains_v2', 'floatingCombatTextFloatMode_v2',
  'floatingCombatTextHonorGains_v2',
  'nameplateForceShowUnitName', 'nameplateInfoDisplay', 'nameplateCastBarDisplay', 'nameplateThreatDisplay',
  'nameplateEnemyNpcAuraDisplay', 'nameplateEnemyPlayerAuraDisplay', 'nameplateFriendlyPlayerAuraDisplay',
  'nameplateShowDebuffsOnFriendly', 'nameplateDebuffPadding', 'nameplateAuraScale', 'nameplateSize', 'nameplateStyle',
  'nameplateSimplifiedTypes', 'nameplateShowFriendlyNpcs', 'nameplateShowOnlyNameForFriendlyPlayerUnits',
  'nameplateUseClassColorForFriendlyPlayerUnitNames', 'nameplateShowAllPersonalAuras', 'SoftTargetNameplateSize',
  'SoftTargetIconEnemy', 'SoftTargetIconFriend', 'SoftTargetIconInteract',
  'encounterTimelineEnabled', 'encounterTimelineIconographyEnabled', 'encounterTimelineIconographyHiddenMask',
  'encounterTimelineHighlightDuration', 'combatWarningsEnabled', 'encounterWarningsEnabled', 'encounterWarningsLevel',
  'accessibilityScreenNarrationEnabled', 'accessibilityScreenNarrationVoice', 'accessibilityScreenNarrationSpeechRate',
  'accessibilityScreenNarrationSpeechVolume',
  'GamepadActionBarLeftRightDelay', 'GamepadActionBarTopBottomDelay', 'GamepadTargetingModifierVisualDelay',
  'GamepadCompassCustomFilterFriendly', 'GamepadCompassCustomFilterEnemy', 'GamepadCompassCustomFilterBoss',
  'GamepadCompassCustomFilterParty', 'GamepadCompassCustomFilterCritter', 'GamepadHudModifierUsesToggle',
  'GamepadSwapTargetModifiers', 'GamepadTargetingMode', 'GamepadSwapFriendlyTargetActions', 'GamepadSwapHostileTargetActions',
  'GamepadTabHostileTargetAction', 'GamepadTabFriendlyTargetAction',
];

test('CVars the game caches are on the core\'s refusal list, and no module names one', async () => {
  const core = await read('Core.lua');
  const list = core.match(/P\.CACHABLE_CVARS = \{\}\s*for _, name in ipairs\(\{([\s\S]*?)\}\) do/);
  assert.ok(list, 'the core keeps its list');
  const refused = new Set(list[1].match(/"[^"]+"/g).map(name => name.slice(1, -1)));
  assert.deepEqual(CACHABLE.filter(name => !refused.has(name)), [], 'every one refused by P:SetCVar');
  assert.match(core, /function P:SetCVar\(key, name, value\)\r?\n\s*if [^\n]*Cachable\(name\)/, 'P:SetCVar asks first');
  const cachable = new Set(CACHABLE);
  const found = [];
  for (const name of await rootFiles(/\.lua$/i)) {
    if (name === 'Core.lua') continue;
    for (const { text, index } of literals(await read(name))) {
      if (cachable.has(text)) found.push(`${name}:${lineOf(await read(name), index)} ${text}`);
    }
  }
  assert.deepEqual(found, []);
});

const RUN = ['loadstring', 'load', 'loadfile', 'dofile', 'RunScript', 'RunMacroText', 'RunMacro', 'setfenv', 'getfenv', 'rawset',
  'securecall', 'ReloadUI', 'ShowUIPanel', 'HideUIPanel', 'ToggleWorldMap', 'OpenWorldMap', 'CloseAllWindows', 'CloseWindows'];
test('no text run as code, no rules got round, no Blizzard window opened or closed', async () => {
  const found = [];
  const named = new RegExp(String.raw`(?<![\w.:])(${RUN.join('|')})(?![\w])`, 'g');
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(named)) found.push(`${name}:${lineOf(code, match.index)} ${match[1]}`);
  }
  assert.deepEqual(found, []);
});

// Blizzard's functions of the "Name_Update" kind are its own to call: the
// addon hooks them (by name, in a string), never calls one itself.
test('no Blizzard function of the Name_Update kind called by the addon', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(/(?<![\w.:])([A-Z][A-Za-z0-9]*_[A-Za-z0-9_]+)\s*\(/g)) {
      if (match[1] === 'ForeverEnhancedPrivacy_Toggle') continue;
      found.push(`${name}:${lineOf(code, match.index)} ${match[1]}`);
    }
  }
  assert.deepEqual(found, []);
});

// Blizzard's frames the modules might reach by name.
const BLIZZARD = String.raw`(?:UIParent|WorldFrame|Minimap|MinimapCluster|PlayerFrame|TargetFrame|TargetFrameToT|FocusFrame|`
  + String.raw`FocusFrameToT|PetFrame|PartyFrame|CompactPartyFrame|CompactRaidFrameContainer|RaidFrame|DEFAULT_CHAT_FRAME|`
  + String.raw`ChatFrame\d+|ChatFrame\d+EditBox|FriendsFrame|FriendsTooltip|CommunitiesFrame|WorldMapFrame|CharacterFrame|`
  + String.raw`InspectFrame|TradeFrame|MailFrame|InboxFrame|OpenMailFrame|SendMailFrame|ReadyCheckFrame|ReadyCheckListenerFrame|`
  + String.raw`StaticPopup\d|ItemRefTooltip|LootFrame|MasterLooterFrame|GroupLootHistoryFrame|ProfessionsFrame|PVPMatchScoreboard|`
  + String.raw`PVPMatchResults|BNToastFrame|QuickJoinToastButton|TimeManagerClockButton|ZoneTextFrame|SubZoneTextFrame|`
  + String.raw`GossipFrame|QuestFrame|PetitionFrame|GuildInviteFrame|LFGInvitePopup|SettingsPanel|BattlefieldMapFrame|`
  + String.raw`RaidWarningFrame|CalendarFrame|LFGParentFrame|LFGBrowseFrame|DamageMeter|SocialUIFrame|ChannelFrame|GameMenuFrame)`;
const CHAIN = String.raw`((?:\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\n]*\]))*)`;
const FORBIDDEN = new Set(['Show', 'Hide', 'SetShown', 'SetScale', 'SetSize', 'SetWidth', 'SetHeight', 'SetPoint',
  'ClearAllPoints', 'ClearPoint', 'SetAllPoints', 'SetParent', 'SetScript', 'SetFrameStrata', 'SetFrameLevel',
  'EnableMouse', 'SetAttribute', 'RegisterEvent', 'RegisterUnitEvent', 'UnregisterEvent', 'UnregisterAllEvents',
  'SetMovable', 'StartMoving', 'StopMovingOrSizing', 'SetClampedToScreen', 'SetUserPlaced', 'SetToplevel', 'Raise', 'Lower',
  'SetID', 'Enable', 'Disable', 'Click', 'SetForbidden']);

test('Blizzard\'s frames named in the code are never shown, hidden, moved, scripted or registered', async () => {
  const found = [];
  const call = new RegExp(String.raw`(?<![\w.:])(${BLIZZARD})${CHAIN}\s*:\s*([A-Za-z_]\w*)\s*\(`, 'g');
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(call)) {
      if (FORBIDDEN.has(match[3])) found.push(`${name}:${lineOf(code, match.index)} ${match[1]}${match[2]}:${match[3]}`);
    }
  }
  assert.deepEqual(found, []);
});

test('no key written on a Blizzard frame named in the code', async () => {
  const found = [];
  const write = new RegExp(String.raw`(?<![\w.:])(${BLIZZARD})((?:\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\n]*\]))+)\s*=(?!=)`, 'g');
  for (const { name, code } of await addonCode()) {
    for (const match of code.matchAll(write)) found.push(`${name}:${lineOf(code, match.index)} ${match[1]}${match[2]} =`);
  }
  assert.deepEqual(found, []);
});

test('chat output only through the core (P:Print, P:Say)', async () => {
  const found = [];
  for (const { name, code } of await addonCode()) {
    if (name === 'Core.lua') continue;
    for (const match of code.matchAll(/(?<![\w.:])print\s*\(|:\s*AddMessage\s*\(/g)) found.push(`${name}:${lineOf(code, match.index)}`);
  }
  assert.deepEqual(found, []);
});

test('every module registers itself, and its header names every setting it owns', async () => {
  const core = await read('Core.lua');
  const owned = {};
  for (const match of core.matchAll(/\{ key = "(\w+)", owner = "(\w+)"/g)) {
    (owned[match[2]] = owned[match[2]] || []).push(match[1]);
  }
  assert.deepEqual(Object.keys(owned).sort(), [...MODULES].sort(), 'the rows belong to the five modules');
  assert.equal(Object.values(owned).flat().length, 41, 'all 41 rows');
  for (const module of MODULES) {
    const source = await read(module + '.lua');
    const header = source.match(/^(?:--[^\n]*\n)+/);
    assert.ok(header, `${module}.lua starts with its header`);
    for (const key of owned[module]) assert.match(header[0], new RegExp(String.raw`\b${key}\b`), `${module}.lua's header names ${key}`);
    assert.match(source, new RegExp(`^local M = P:Module\\("${module}"\\)\\r?$`, 'm'), `${module}.lua registers with the core as ${module}`);
    assert.match(source, /^local _, P = \.\.\.\r?$/m, `${module}.lua takes the addon's namespace`);
  }
});

test('player text in British spelling', async () => {
  const found = [];
  for (const { name, source } of await addonCode()) {
    for (const { text, index } of literals(source)) {
      const match = text.match(/\b(color|colors|colored|favorite|center|centered|gray|behavior|realize|organize|customize)\b/);
      if (match) found.push(`${name}:${lineOf(source, index)} ${match[1]}`);
    }
  }
  assert.deepEqual(found, []);
});

test('no other addon named', async () => {
  const found = [];
  const others = /\b(ElvUI|Tukui|Questie|WeakAuras|Plater|Bartender|Dominos|Prat|Chatter|Chattynator|VuhDo|Grid2|Details!|Skada|Recount|BigWigs|DBM|Deadly Boss Mods|Leatrix|Bagnon|AdiBags)\b/;
  for (const name of await rootFiles(/\.(lua|xml|toc)$/i)) {
    (await read(name)).split('\n').forEach((line, i) => {
      const match = line.match(others);
      if (match) found.push(`${name}:${i + 1} ${match[1]}`);
    });
  }
  assert.deepEqual(found, []);
});

test('the licence, and the art the code names', async () => {
  assert.match(await read('LICENSE.txt'), /Copyright \(c\) 2026 Squirt\. All rights reserved\./);
  for (const art of ['Heart.tga', 'Eye.tga', 'Icon.tga']) {
    const file = await readFile(new URL('Media/' + art, root));
    assert.equal(file[2], 2, `${art}: uncompressed true colour`);
    assert.equal(file[16], 32, `${art}: 32-bit`);
    assert.equal(file.length, 18 + file.readUInt16LE(12) * file.readUInt16LE(14) * 4, `${art}: whole`);
  }
});
