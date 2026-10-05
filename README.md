# Xonellines

FFXII-inspired glowing zone-line indicators for Final Fantasy XI, built for

<img width="1898" height="1193" alt="image" src="https://github.com/user-attachments/assets/285b8330-cbd7-489c-b806-2a340c038e4b" />

**Ashita v4** with zone data matched to Phoenix XI.

Version: 0.3.7
Author: Zarianna (100% Vibe coded)

  ##Install

1. Extract the `xonellines` folder into your Ashita `addons` folder.
2. Confirm the file is at `addons/xonellines/xonellines.lua`.
3. In game, run:

   
   /addon load xonellines

 3. In Phoenix Launcher, toggle the addon on:


  ## Configure

In game type `/xl config` to open settings. A temporary row near your character lets you
preview appearance changes live. Closing the window removes that preview.

- Adjust orb spacing, size, opacity, brightness, color, and center color/size.
- Change global vertical and horizontal offsets.
- Search zone names or IDs to adjust individual zones.
- Toggle player and NPC occlusion independently; both default to enabled.

Settings save automatically. The default visibility range is *30 yalms*.
Rows brighten as you approach, shrink with distance, and remain level.
Horizontal adjustments add to a built-in *1.15-yalm* shift toward the inferred
playable side where a direction is available.


  ## Commands

| Command | Action |
| --- | --- |
| `/xl config` | Open or close settings |
| `/xl on` / `/xl off` | Show or hide zone markers |


