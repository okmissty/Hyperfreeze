# Hyperfreeze
<img width="794" height="385" alt="image" src="https://github.com/user-attachments/assets/5df91d8f-9616-4e99-b932-662c763f43c0" />

A Papa's Freezeria-style time-management game set in a cosmic café on a space station. Godot 4.3, GDScript, 2D.

This build covers milestones **M0–M8** from the design doc: the full loop from taking an order to serving and grading it, a day cycle with saving, a shop, sound and music, and export presets. The cups, all 25 ingredients, the three skies, all four stations and the UI kit now use Ty's drawn art. Customers, the food critic, lobby decor, badge medals and some upgrade icons are still placeholders drawn in code, and audio is synthesized.

## Open the project

1. Install **Godot 4.3** or newer (standard build, not .NET).
2. In the Godot Project Manager click **Import** and pick the zip (or unzip it and pick `project.godot`), then **Import & Edit**.
3. Press **F5** (or the ▶ button) to play. The game starts at the title screen.

## How to play

**Title screen.** **Continue** picks up from the last saved day. **New Game** starts over (tap twice if you already have a save). **Settings** and **Badges** work here too.

**Order.** Customers beam in and line up. Click **Take Order**: the customer shows what they want, a ticket prints and flies to the rail, and they move to the lobby. Patience bars show how long they've waited; they never walk out, but a long wait lowers the grade.

**Tickets.** Switch stations with the bottom tabs (or keys **1–4**). Tap a rail ticket to clip it to the station you're on, or drag it onto the slot or onto a tab. A ticket only clips at the station its cup is at (Build before a cup exists); anywhere else it wiggles and tells you where it belongs. Compact tickets show where their cup is (BUILD, ZAP, TOP, READY).

**Build.** Clip a ticket, pick the cup size, then **hold a base tap** to pour up to the yellow fill line. Tap mix-in bins to add or remove them. **Send to Zap** moves the cup on, and the ticket follows it.

**Zap.** Tap a waiting cup to load the Hyperfreeze Blender. Pick the zap level from the ticket (Asteroid, Comet or Supernova), then **hold to zap** and let go when the needle is in the middle of that band.

**Top.** Tap a waiting cup to put it on the counter, pick a tool on the right and apply it:
- **Nebula Cream:** hold and sweep across the top.
- **Sauce:** swipe across the top.
- **Sprinkles:** tap the cup.
- **Toppers:** tap a slot, or drag the topper onto one. With no tool selected, tap a topper to remove it.

**Finish** marks the treat ready.

**Serve.** On the Order Station, tap the READY ticket on the rail (or drag it onto the Order tab or anywhere on the Order Station). The customer walks up and the **score card** shows what they ordered next to what you made. You get four grades (waiting, build, zap, top), the total, your tip and XP. Score 90+ three times for the same customer to earn their **gold star**; gold-star regulars tip 25% more.

**Trash cup** at Build or Top throws the cup away so you can start that order over.

**Days.** The shop closes to new customers at 6:00 PM, and the day ends once the last customer has been served. The day-end report shows orders served, average score, tips, XP and rank progress. Ranking up adds new ingredients and new regulars, and existing regulars start ordering the new items. **Next Day** saves your progress and opens the café again.

**Shop.** Open it any time from the HUD's **Shop** button, the pause menu or the day-end report. The café pauses while it's open. Three tabs:

*Upgrades*
| Upgrade | Price | Effect |
| --- | --- | --- |
| Comfy Lobby Pods | $25 | Customers wait 25% longer before patience slips |
| Turbo Taps | $30 | Base taps pour 40% faster |
| Whip Cannon | $35 | Each cream sweep covers three strips of the dome |
| Hyper Motor | $40 | The Hyperfreeze zaps 25% faster |
| Cosmic Tip Jar | $50 | Every customer tips 10% more |
| Steady Gauge | $55 | Zap target bands are 30% wider |
| Deluxe Lobby Pods | $60 | Patience lasts another 20% longer (needs Comfy Lobby Pods) |
| Neon Billboard | $90 | More customers every day |

*Decor:* lobby pieces in four spots (wall, corner, floor, counter). One piece per spot is on display, and each one on display makes customers a little more patient (+4%, badge pieces +6%). Buy, display or take down from the Decor tab.

| Spot | Shop decor | Badge-only decor |
| --- | --- | --- |
| Wall | Nebula Poster $20, Retro Rocket Poster $25 | Critic's Plaque |
| Corner | Moon Fern $20, Crystal Cactus $30 | Star Captain Statue |
| Floor | Space Jelly Tank $45, Arcade Cabinet $55, Jukebox $60 | Disco Orb |
| Counter | Lava Lamp $25 | Golden Cone Trophy |

The **Jukebox** adds a second café song; tap it in the lobby to switch tracks.

*Themes:* Sunburst and Aurora are $15 each. Midnight, Cotton Candy and Starlight Silver can only be earned from badges. Switch freely between any you own.

**Food critics.** From day 3 a critic sometimes walks in (always within three days of the last one). Their ticket has a pink **CRITIC** tag. Serve them well: they give 1–5 stars based on the score, and the score card shows their review. Your **café rating** (shown in the HUD) is the average of the last five reviews and starts at 3.0. Above 3 stars customers tip more and arrive more often; below 3 they tip less and come less often.

**Badges.** 26 badges for serving, quality, zapping, tips, regulars, critics, progress and the café. Each pays coins when earned, and seven unlock decor or themes you can't buy in the shop. A banner drops in when you earn one. See them all, with progress, from the pause menu or the title screen.

**Pacing.** Day 1 is a relaxed 8-minute shift with at most 3 customers in the café. It gets busier each day until day 4, when the shift is 7 minutes and the full rush applies. Whenever you have nothing left to do, the next customer arrives within a few seconds. The HUD's shift bar shows how far through the day you are (9 AM to 6 PM) and roughly how many real minutes are left.

**Pause and settings.** The **II** button (or **Esc**) pauses everything:
- **Follow the cup** (on by default): when you send a cup on, it jumps you to the next station, loads the cup into the free machine, and serves finished treats for you. Turn it off to juggle stations yourself.
- **Fullscreen**, also **F11**.
- **Music** and **sound effects** volume.
- **Shop** and **Badges.**
- **Quit to Title.** Progress saves at the end of each day, so quitting mid-shift restarts that day.

Settings are saved between sessions.

**Debug keys** (only when running from the editor): **F2** brings in a customer now, **F3** toggles 4× speed.
<img width="794" height="446" alt="image" src="https://github.com/user-attachments/assets/a0220a4e-6246-4c51-b1c8-f8cd77c6532a" />
<img width="794" height="391" alt="image" src="https://github.com/user-attachments/assets/a3d3c81d-5a40-4ad8-8f20-dedb98bf0766" />





## What's in M0–M8

| Milestone | What works |
| --- | --- |
| M0 Skeleton | Autoloads, main scene, four stations with tab switching, rail, HUD, theme |
| M1 Data layer | `IngredientData`, `CustomerData`, `RankTable`, `Order`, `CupState`, `Catalog`, `OrderGenerator`; 25 ingredients, 11 customers, 10 ranks as `.tres` files |
| M2 Order Station | Arrivals on a rush curve, counter queue, patience bars, ticket printing, lobby, rail, drag-and-drop and tap-to-move |
| M3 Build Station | Cup sizes, hold-to-pour with a fill line, mix-in bins, trash, send to Zap |
| M4 Zap Station | Waiting shelf, Hyperfreeze Blender, 3 zap bands, hold-and-release meter |
| M5 Top Station | Cream sweep with partial coverage, sauce swipe, sprinkles, 4 topper slots (tap or drag) |
| M6 Serve and score | Serving from the rail or Order tab, `Scorer` with 4 station grades, animated score card, tips, XP, reactions, gold-star loyalty |
| M7 Day cycle | Day ends when closed and empty, day-end report, rank-ups with unlocks, regulars learn new items, save/load, title screen |
| M8 Polish | Upgrade shop, café themes, generated sound effects and music, volume settings, coin and star effects, fades, export presets |

## Update 7: goals and café life (this build)

- **Bigger shop:** six new upgrades, a Decor tab with 12 lobby pieces, and tabs for Upgrades / Decor / Themes.
- **Second Hyperfreeze removed.** Zapping is hold-to-blend, so a second machine never saved time. Saves that bought it get the $45 back on load, with a message.
- **Food critics** and a **café rating** that changes tips and traffic.
- **Badges** that pay coins, with badge-only decor and themes.
- **Calmer music:** the old upbeat track is now the title music. Gameplay uses a new slow café loop (68 BPM), and the Jukebox adds a lo-fi jazz track (74 BPM).
- **Title screen:** the character parade is gone.
- **Character customization** is planned but not built yet. Saves already keep an empty `worker` slot so it can be added without breaking old saves.
- **Placeholder art to replace** (drop files in with these names and they're used automatically):
  - Decor: `assets/art/decor/<id>.png`, e.g. `decor_jelly_tank.png` (12 ids in `scripts/core/upgrades.gd`).
  - Badge medals: `assets/art/ui/badges/badge_<id>.png`, e.g. `badge_zap_master.png` (26 ids in `scripts/core/badges.gd`).
  - Upgrade icons: `assets/art/ui/icon_up_<id>.png` for the new upgrades (whip_cannon, hyper_motor, tip_jar, steady_gauge, comfy_pods_2, neon_billboard).
  - The critic is drawn in code in `scenes/entities/customer.gd` until customer art exists.

## Art pass 1


- **Cup:** glass back and front layers, a white swirl texture tinted to each flavour, and a whipped-cream dome that fills in strip by strip as you sweep.
- **Ingredients:** all 25 icons on station buttons, tickets and drag previews. Mix-ins show as drawn chunks in the ice cream, sauces as drizzles, sprinkles over the cream, and toppers as their small versions.
- **Shapes come from the art.** The fill mask sets where ice cream can show, and the cream's outline sets where toppers and sauce sit. A redrawn cup lines up with no code changes.
- **Drop-in art by file name.** `Art.ingredient(id, part)` looks up `assets/art/ingredients/ing_<id>[_part].png`. Anything missing falls back to the code-drawn placeholder.

## Playtest fixes 1

- **Bigger treats:** Build and Zap size the cup to fill the space (cream room is only kept at Top). Small and Medium are now 82% and 91% of Large, down from 72% and 86%.
- **New station layouts:**
  - Build: taps on the left, the cup in the middle with the size cards beside it, mix-ins on the right.
  - Zap: a larger jar, and two blenders get their own spaced columns with icon zap buttons.
  - Top: a narrower shelf and a compact two-column tool grid that fits without scrolling.
- **UI fixes:**
  - Disabled buttons fade instead of turning flat grey.
  - Size-card labels are readable.
  - The ticket slot uses a clean dark frame.
  - The lobby caption is gone, and the idle hint sits above the counter with an outline.
  - Rail, HUD and tab bar use the dark-glass frame.
- **Themes recolour the café:** each theme colour-grades the painted stations and title screen, washes them with its light, and tints the UI frames. The shop previews show a mini café in each theme.
- **Shop any time:** use the Shop button in the HUD or in the pause menu. The café pauses while it's open, and upgrades apply straight away (a second blender joins as soon as both machines are idle).
- **Sharper art:** every sprite cut from the sheets was upscaled 4x with Real-ESRGAN (anime model). Backgrounds keep the 4x copy; sprites are stored at 2x; 9-slice UI pieces keep a 4x copy in `assets/art/ui/hires/` that the game shrinks to size. This is a stopgap: full-size exports from the source files with the same names will replace them with no code changes.

## Art pass 3: UI kit

- **Applied at startup** by `UiSkin.apply()` (scripts/core/ui_skin.gd), which swaps the project theme's flat styles for 9-slice art. Anything not drawn keeps the old style.
- **Buttons:** big, primary, secondary, tool and tab buttons in all states. The sheet's mock text (PLAY / OK / CANCEL / ORDERS) was painted out so the game's own labels sit on top.
- **Panels:** work panels and modals use your frames with a darkened inside, so the light text stays readable. `ui_panel_light` / `ui_modal_light` keep the original light glass.
- **HUD:** day, clock and coin icons, drawn pause button, moon shift bar, spinning coins for tips.
- **Tabs:** your tab art with the order, build, zap and top icons.
- **Tickets:** rail bar, clip on each rail ticket, glass ticket-slot frame (glows while dragging a ticket over it).
- **Screens:** score bars and 5 rating stars on the score card, rank badge and bar at day end, upgrade icons and theme frames in the shop, toggles and sliders in settings, toast banner, custom cursors, and the title painting.
- **Not used:** the ticket paper art (no room for order details), the HUD panel, tab bar and bell badge (mock text and icons are baked in), and the drawn logo on the title (the title painting's café sign already shows the name).
- `_build_tools/slice_ui.py` cuts the UI sheets, including the text clean-up.

## Art pass 2

- **Skies:** Nebula, Sunburst and Aurora paintings on the title screen and in the shop's theme previews, with a few code stars twinkling on top.
- **Station backgrounds** fill the whole screen behind each station. On Build, Zap and Top they're dimmed slightly and the work panel is see-through, so the controls stay readable.
- **Order Station:** neon sign (switches off at closing), airlock door that opens for each arrival, lobby rug, counter and ticket printer.
- **Build Station:** cup-size cards (normal / hover / picked), coin backdrops on the flavour taps and gem backdrops on the mix-in bins.
- **Zap Station:** blender base (lights up while zapping), glass jar over the cup (swirling while blending), framed meter, band cards, needle, and zap-level icons on the buttons.
- **Top Station:** tool icons beside each section and on the cream button, and ring markers for topper slots.
- **Not used yet:** the shelf cards (they have a cup painted in, which would double up with the real cup drawn on them).
- `_build_tools/slice_stations.py` and `slice_sheets.py` cut the sheets into these PNGs.

## Project layout

```
autoload/      Events (signal bus), GameState (progress, saving, settings),
               DayManager (clock, customers, tickets, cups, serving), AudioManager
scripts/
  resources/   IngredientData, CustomerData, RankTable
  core/        Order, CupState, Scorer, ZapBands, Catalog, OrderGenerator, Upgrades, StationIds,
               Art (sprite lookup), CupArt (cup layers + shapes read from the art)
data/          ingredients/*.tres, customers/*.tres, ranks.tres
scenes/
  menus/       title_screen.tscn (the game starts here)
  main/        main.tscn: the café screen
  stations/    order, build, zap (+ blender.gd), top (+ top_work_area.gd), base_station.gd
  ui/          rail, tickets, slot, tabs, HUD, cup painter/view/icon, score card,
               day-end screen, shop, pause menu, starfield, buttons
  entities/    customer.tscn (aliens drawn in code)
themes/        cafe_theme.tres (colours, fonts, button styles)
assets/art/    cups/ (cup layers), ingredients/ (icons, pieces, drizzles, scatters,
               toppers), stations/ (backgrounds + props), skies/; cut from Ty's sheets
assets/fonts/  Fredoka (SIL Open Font License, see OFL.txt)
assets/audio/  21 sound effects (.wav) and 2 music loops (.ogg), all synthesized
docs/          ASSETS.md: the art and audio to make next
```

## How the code fits together

- **State lives in autoloads, scenes only display it.** Tickets move only through `DayManager.move_ticket()` and cups only through `DayManager.move_cup()`; both announce changes on `Events`.
- **Scenes talk through `Events`**, never by reaching into each other. Even sound is driven by events (`AudioManager` listens for orders, cups, serves and rank-ups).
- **Stations stay loaded.** Switching tabs only hides and shows them, so half-made treats survive.
- **Each order owns its cup.** `order.cup` is a `CupState` recording what you actually made and where it is.
- **Grading is pure logic.** `Scorer` compares `CupState` against `Order`, so tuning the difficulty means editing numbers in one file.
- **One cup painter.** `CupPainter` draws every cup, from ticket icons (the perfect cup) to station cups (yours). Swapping in real art means changing one file.
- **Saving.** `GameState.save_game()` writes `user://save.json` (day, money, XP, favourites, loyalty, upgrades, theme) at the end of each day.

## Adding content without code

- **New ingredient:** right-click `data/ingredients` → *New Resource* → `IngredientData`. Set id, name, category, colour and unlock rank.
- **New customer:** same, in `data/customers` with `CustomerData`. Species sets the look; the habit fields shape their favourite order.
- **Rank thresholds:** edit `data/ranks.tres`.
- **Upgrades and prices:** edit `scripts/core/upgrades.gd`.
- **Art:** drop a PNG with the right name into `assets/art/` (see Art pass 1 above and `docs/ASSETS.md`). Turn on *Mipmaps → Generate* in the Import tab for new art, so it stays smooth when shrunk onto tickets.
- **Sounds:** drop a file with the same name into `assets/audio` (for example `serve.wav`, `music_cafe.ogg`).

## Exporting

Install the export templates first (*Editor → Manage Export Templates → Download and Install*), then *Project → Export*. Presets are included for **Android**, **iOS**, **Windows** and **macOS**:

- **Android:** set up the Android SDK and a debug keystore under *Editor Settings → Export → Android*, and change the package name (`com.example.hyperfreeze`) to your own.
- **iOS:** needs a Mac with Xcode and your Apple team ID in the preset.
- **Desktop:** exports straight away once the templates are installed.

The build uses the Compatibility renderer, so it runs on older phones and computers too.
