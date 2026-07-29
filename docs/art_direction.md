# Art Direction

The project uses a readable pixel-art tactical style.

## Shared rules

- UI icons use hard pixel edges, transparent background, high contrast, and no gradients.
- Profession icons are `64x64` with a dark square frame and a single accent color per role.
- Tool icons are `32x32` and use the same metal, gold, cyan, and red palette.
- Character and enemy sprite sheets keep their existing `32x32` frame grid so animation regions stay stable.
- Gameplay readability is more important than detail. A unit should be identifiable at HUD-card size and in the battlefield camera view.

## Role colors

- Vanguard: gold
- Warrior: red
- Defender: blue
- Sniper: green
- Caster: purple
- Medic: cyan/green

## Do not

- Mix rendered/3D icon styles with pixel UI icons.
- Add soft shadows or antialiased painterly edges to UI icons.
- Change sprite sheet frame sizes without updating every scene region.
- Reuse a role color for a different role unless the silhouette is clearly different.
