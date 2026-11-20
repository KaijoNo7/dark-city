# Graphics

Everything visual in Dark City comes from one Craftpix pixel-art pack in `asset/`, plus a few
effects drawn by code (gradient sky, stars, rain, sparks). This section explains how the raw images
become animated characters, a collidable tileset, a layered night street and a UI.

| Document | Contents |
|---|---|
| [01 — The art pack](01-art-pack.md) | Inventory of `asset/`, what is used and what isn't, licence |
| [02 — Sprites & animation](02-sprites-and-animation.md) | Sprite sheets → `SpriteFrames`, every animation and its FPS, anchoring, flipping, 2× bosses, hit flash |
| [03 — Tiles & level art](03-tiles-and-level-art.md) | The 480×480 tilesheet, `TileSet` collision, ground and platforms, buildings, props, parallax, draw order |
| [04 — UI, effects & palette](04-ui-effects-palette.md) | The UI kit, HUD layout, title screen, particles, tweens, screen shake, colour palette |

## Visual style in one paragraph

A **384 × 216 pixel canvas** scaled by whole numbers, **nearest-neighbour** filtering, **pixel
snapping**, 16 px tiles and 32 px characters. Night is suggested by layering: a purple gradient sky
with a moon and twinkling stars, two dark silhouette skylines that scroll slowly (parallax), lit shop
fronts, a cool `CanvasModulate` tint over the whole world, and slanted rain on top. Feedback is
loud and readable: white hit flashes, screen shake, sparks, big 64 px explosions and bosses at
double size.
