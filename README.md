# EllesmereUI-Quest_Tracker_Buttons_Map

<img width="1310" height="947" alt="{04557B2A-04B7-421C-ACE6-813CAB19433A}" src="https://github.com/user-attachments/assets/2931c9e2-721e-4a8b-b69b-bf2378ac23cb" />
<img width="739" height="648" alt="{CC022652-A336-49DB-AAA3-C6C925DEFA47}" src="https://github.com/user-attachments/assets/8f1dc9e2-567d-433d-b32c-c8b409d278fc" />

<a href="https://www.youtube.com/watch?v=xVuClmygLWo">How it works ingame</a> 

Two small, standalone add-ons that extend the **EllesmereUI** quest tracker and world map quest log on **WoW Forever** (beta, Interface 16001).

| Add-on | What it does |
|---|---|
| **EllesmereUIQuestLogTrack** | Track / Untrack buttons for each zone, an *Untrack All* button, and *Elite* / *Dungeon* buttons in the world map quest log. |
| **EllesmereUI_QTBackgroundFix** | Fixes the EllesmereUI Quest Tracker background that sometimes stays on screen, empty, after the last quest is untracked or after a zone change. |

Neither add-on modifies any EllesmereUI file, so updating EllesmereUI won't overwrite them.

---

## EllesmereUIQuestLogTrack

### Features

- **Track / Untrack per zone**
  A small button on every zone header in the world map quest log.
  - **Track** (accent color): tracks every quest in that zone.
  - **Untrack** (red): shown when every quest in the zone is already tracked; untracks them all.
  - Works on collapsed zones too.
- **Untrack All**
  Removes every quest from the quest tracker. It sits in the title bar next to the settings (gear) button.
- **Elite / Dungeon**
  Two buttons next to *Untrack All*. They change only what is tracked; the quest log list itself is never filtered.
  - **Click:** tracks every Elite (or Dungeon) quest in your log. If they are all tracked already, it untracks them.
  - **Shift-click:** tracks *only* that kind and untracks every other quest.
  - **Button color:** accent = the next click tracks, red = the next click untracks, grey = no such quest in your log.
  - **Tooltip:** shows how many of those quests are tracked.
- Button colors follow the EllesmereUI **UI Accent Color** (Global Settings).

### How quests are classified

The add-on reads the same tags you see in the quest log:

| Kind | Recognized by |
|---|---|
| Elite | `(Elite)` after the quest name, **or** a `+` level marker such as `[30+]` |
| Dungeon | `(Dungeon)` after the quest name |

- **Visible quests:** if a quest has a row in the quest log, only the row's visible text counts.
- **Collapsed zones:** quests in a collapsed zone have no row. For those the game's quest tag data is used, and only an explicit `Elite` or `Dungeon` tag counts. For the most accurate result, expand your zones before using the buttons.

### Settings

**EllesmereUI → Quest Tracker → EXTRAS → "Quest Log Track Buttons"**
Turns all of this add-on's buttons on or off. The setting is saved in your EllesmereUI Quest Tracker profile.

### Slash commands

| Command | Description |
|---|---|
| `/qltrack on` / `/qltrack off` | Show or hide the buttons (same as the setting above). |
| `/qltrack` | Toggle the buttons. |
| `/qltrack kinds` | Lists every quest in your log with its classification (`E` = elite, `D` = dungeon) and where it came from (`row` = quest log text, `api` = game data). |
| `/qltrack debug` | Prints diagnostics for the options-panel toggle. |

---

## EllesmereUI_QTBackgroundFix

### The problem

EllesmereUI draws its own dark background behind the quest tracker. In EllesmereUI 9.4 and 9.5.4 that background can get stuck on screen with nothing in it:

- **Last quest untracked:** the background never disappears after the last quest is untracked.
- **Zone change:** after a zone change or loading screen, the background comes back even though nothing is tracked.

In both cases it only disappeared when something unrelated, such as targeting a mob, made EllesmereUI re-check it.

### The fix

The add-on watches EllesmereUI's background frame from the outside:

- **When it checks:** whenever the background is shown, once a second while it stays visible, and shortly after every zone change.
- **If there's nothing to show:** when the tracker has no content for a quarter of a second, the background is hidden.
- **If content changed:** when the tracker's content changed underneath it, EllesmereUI's own resize routine is asked to re-fit it.

There are no settings: install it and it works. If EllesmereUI ever fixes the bug itself, or renames the frames this add-on relies on, it simply does nothing.

---

## Requirements

- WoW Forever (beta client, Interface 16001)
- EllesmereUI — tested with **9.5.4**
  - **EllesmereUI_QTBackgroundFix:** requires EllesmereUI and its Quest Tracker module.
  - **EllesmereUIQuestLogTrack:** loads without EllesmereUI, but the options toggle needs EllesmereUI Quest Tracker.

## Installation

1. Download or clone this repository.
2. Copy one or both add-on folders into your add-ons directory:
   ```
   World of Warcraft\_classic_beta_\Interface\AddOns\
   ```
   The result should look like this:
   ```
   Interface\AddOns\EllesmereUIQuestLogTrack\EllesmereUIQuestLogTrack.toc
   Interface\AddOns\EllesmereUIQuestLogTrack\EllesmereUIQuestLogTrack.lua
   Interface\AddOns\EllesmereUI_QTBackgroundFix\EllesmereUI_QTBackgroundFix.toc
   Interface\AddOns\EllesmereUI_QTBackgroundFix\QTBackgroundFix.lua
   ```
3. **Fully restart the game.** WoW does not detect new add-on folders on `/reload`.
4. Make sure both add-ons are enabled in the AddOn List on the character select screen.

The two add-ons are independent: you can install just one of them.

## Compatibility notes

- **Map add-ons:** built and tested together with **Leatrix Maps** (the buttons sit in its map title bar) and EllesmereUI's Blizzard Skins. Without Leatrix Maps, the buttons are placed above the quest list.
- **Options toggle:** EllesmereUI 9.5.4 asks other add-ons to put their settings in their own sidebar section instead of adding rows to EllesmereUI's pages. A future EllesmereUI version may stop the toggle from appearing on the Quest Tracker page. The buttons keep working (they are on by default), and `/qltrack on|off` still works.
- **Taint:** the add-ons only post-hook Blizzard functions (`hooksecurefunc`) and never replace them.

## Known limitations

- Zone Track / Untrack, Elite and Dungeon act on all matching quests in your log, not only the ones currently scrolled into view.
- Elite / Dungeon classification for quests in collapsed zones depends on the game's quest tag data, which is less reliable than the quest log text.

