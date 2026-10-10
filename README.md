# xonellines

FFXII-inspired glowing zone-line indicators for **Final Fantasy XI**, built for
**Ashita v4** with zone data matched to **Phoenix XI**.

Version: **0.4.14**  
Author: **Zarianna (100% Vibe coded)**

## Install

1. Extract the `xonellines` folder into your Ashita `addons` folder.
2. Confirm the file is at `addons/xonellines/xonellines.lua`.
3. In game, run:

   ```text
   /addon load xonellines
   ```

For an update, replace the addon files and run `/addon reload xonellines`.
To load automatically, add `/addon load xonellines` to your Ashita startup script.
No separate images, Python installation, or extra plugin are needed.

## Configure

Run `/xl config` to open settings. A temporary row near your character lets you
preview appearance changes live. Closing the window removes that preview.

- Adjust orb spacing, size, opacity, brightness, color, and center color/size.
- Change global vertical and horizontal offsets.
- Search zone names or IDs to adjust individual zones.
- Toggle player and NPC occlusion independently; both default to enabled.

Settings save automatically. The default visibility range is **30 yalms**.
Rows brighten as you approach, shrink with distance, and remain level.
Horizontal adjustments add to a built-in **1.15-yalm** shift toward the inferred
playable side where a direction is available.

## Ground alignment

Collision samples provide an averaged ground height for **830 of 843 exits** in
the dataset, with opening trimming on **625** of those rows. Each aligned row
uses one height, plus your vertical adjustments. The other exits retain their
original placement. The config shows coverage for your current zone.

Ground heights and opening limits are precomputed. Large horizontal changes,
custom game geometry, or unusual multilevel areas may need manual adjustment.
Player/NPC occlusion uses estimated silhouettes. With Terrain occlusion off, walls do not dynamically hide
orbs; opening trimming uses precomputed collision samples. The optional scene-depth
mode can occlude markers behind world geometry.

## Commands

| Command | Action |
| --- | --- |
| `/xl config` | Open or close settings |
| `/xl on` / `/xl off` | Show or hide zone markers |
| `/xl range 30` | Set visibility range |
| `/xl status` | Show addon status |
| `/xl list` | Show current-zone marker information |
| `/xl start` | Record a manual row's first endpoint |
| `/xl end Name` | Record its second endpoint and save |
| `/xl remove ID` | Remove a manual marker listed by `/xl list` |

## Credits

See [SOURCES.md](SOURCES.md) for data provenance and attribution, and
[DATA-LICENSE.txt](DATA-LICENSE.txt) for the included GPL-3.0 license text.
This addon is not affiliated with Square Enix or the Final Fantasy XII team.

## Individual exit overrides

Under **Per-zone offset tuning**, search/select a zone, then select its exit by
**destination name [exit ID]**. Set **Exit vertical adjustment**, **Exit horizontal
adjustment**, or **Show this exit**. These add to the existing Global and Zone
adjustments. **Reset this exit** clears only that exit's adjustments.

Horizontal controls require an inferred inward direction. Duplicate destinations
have separate IDs and separate settings. These controls affect actual exits;
the nearby appearance preview is independent. Existing v033.lua settings are
preserved and gain a nested exitOverrides table keyed by zone and exit ID.

## Occlusion

- **Terrain occlusion:** Hides orbs behind walls and terrain. Orbs look more solid
  with this enabled; turn it off for a softer glow. Lowering opacity makes orbs
  smaller in this mode. Off by default.
- **Player occlusion:** Hides orbs behind players, including your character.
- **NPC occlusion:** Hides orbs behind NPCs.

Player and NPC options default to on. Their coverage is approximate, including
mounted characters. To show orbs through characters, turn off Terrain occlusion
as well as the matching Player or NPC option.

If terrain rendering fails, the addon returns to the normal soft glow.

## Additional averaged heights

Existing local-collision averages are retained. Matching ZoneLines edge samples
supply 197 previously missing averages, raising coverage to 830/843. Samples
are matched by zone, exit ID and position, and checked for finite values,
coverage, elevation spread and distance from the original reference height.
Each accepted set becomes one arithmetic mean for the entire row; dots do not
follow individual terrain samples.

For exits with both sources, **Use alternate averaged ground height** lets you
compare the ZoneLines average against our local-collision average. New height
coverage does not add new width trimming: existing verified spans are retained.
Large horizontal changes may still need manual vertical adjustments.

Local validation covers individual override isolation/reset, uniform averaged
rows, 830/843 data coverage, second-pass scheduling, scene graphics-state
restoration on failure, and texture generation. In-game comparison remains
necessary for the optional scene mode.

## Height and opening coverage

Rechecked all 843 exits across 198 zones against local collision geometry.
Updated 274 per-exit averages using samples inside the retained opening.
Coverage remains 633 local averages plus 197 supplemental averages; 13 exits
retain their original fallback placement. All 830 aligned rows remain level.
Manual global, per-zone, and per-exit adjustments are preserved.

Verified opening limits now leave room for the orb radius. This does not establish
walkability for every exit: collision ground can extend underneath walls, and
supplemental heights do not supply verified opening widths. Some overextended
rows may still require specific exit corrections.

Actor masks use camera-space depth and rounded body coverage including feet.
They remain estimates, not exact model silhouettes.

The local player mask expands while the Mounted buff is active and returns to
standing dimensions after dismounting. Mounted coverage is an approximation.

Player masks use detected race and model scale, with per-entity riding animation detection and a local Mounted-buff fallback.
Race dimensions are estimates; rounded ends stay inside projected bounds.

Nearby mounted players now use mounted proportions based on their own animation
state. This is not extraction of the rider/chocobo mesh; coverage remains approximate.
