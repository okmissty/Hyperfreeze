# Asset list

Nothing here is needed to run the game: every visual is drawn in code, and every sound in `assets/audio` is synthesized. Each item notes where it plugs in, so assets can be swapped in one at a time. For audio, save your file over the placeholder with the same name (`serve.wav`, `music_cafe.ogg` and so on).

**General specs:** PNG with transparency, drawn at 2× the listed size for crisp mobile screens. The game renders at 1920×1080. Palette: navy `#0B0D2A`, nebula purple `#6B3FA0`, neon cyan `#3EE6F0`, soft pink `#FF7EB6`, star yellow `#FFD95A`.

## Characters (M2, replaces code-drawn aliens)

| Asset | Count | Size | Notes |
| --- | --- | --- | --- |
| Customer body per species | 5 | 220×320 | Blorb, Zip-Zap, Lumen, Graviton, Captain Nova; feet at bottom centre |
| Colour variants | 11 | — | One per named customer, or one greyscale body tinted in code |
| Expressions | 3 per species | — | Happy, neutral, upset (driven by patience) |
| Walk cycle | 4–6 frames per species | — | Optional; a bob tween works until then |

## Ingredients (M3–M5, `IngredientData.icon`)

| Asset | Count | Size |
| --- | --- | --- |
| Base flavour (liquid colour or swatch) | 6 | 64×64 |
| Mix-in pieces | 6 | 48×48 |
| Sauce drizzle | 4 | 256×64 |
| Sprinkles | 3 | 128×128 tile |
| Toppers | 6 | 96×96 |
| Nebula Cream swirl | 1 | 256×160 |

## Stations

| Asset | Milestone | Size |
| --- | --- | --- |
| Order Station backdrop (counter, window, airlock door, lobby) | M2 | 1920×700 |
| Ticket printer | M2 | 170×92 |
| Cups: small, medium, large (empty, plus a fill mask) | M3 | about 200×260 |
| Base dispenser and mix-in bins | M3 | — |
| Hyperfreeze Blender + zap meter | M4 | — |
| Topping counter, sauce bottles, sprinkle shakers, 4 topper slots | M5 | — |
| Build, Zap, Top backdrops | M3–M5 | 1920×700 |

## UI

| Asset | Notes |
| --- | --- |
| Ticket paper | 9-slice, cream with a torn top edge |
| Rail and clip | Repeating rail plus one clip sprite |
| Tab icons | Order, Build, Zap, Top; 64×64 |
| Buttons | 9-slice pink, plus pressed state |
| Star burst, score stars | M6 grading popups |
| App icon | 1024×1024 (a placeholder `icon.svg` is included) |

## Audio (placeholders included)

| File(s) | Used for |
| --- | --- |
| `music_title.ogg`, `music_cafe.ogg` | Title screen and café music (looping) |
| `airlock`, `print`, `clip`, `bloop` | Customer arrives, ticket prints, ticket clipped, cup finished |
| `plunk`, `pour_loop`, `whoosh_send`, `trash` | Cup placed / mix-in, pouring (loop), cup sent on, cup trashed |
| `blend_loop`, `zap_ding` | Blender running (loop), zap released |
| `cream`, `sauce`, `sprinkle`, `plop` | Top Station tools |
| `serve`, `coins`, `rank_up`, `day_end`, `buy` | Serving, tips, rank up, day over, shop purchase |
| `click`, `wrong` | Buttons, "belongs at another station" hints |
