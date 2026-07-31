# App Icon Specification

- **Canvas:** 1024 × 1024 RGB PNG in `Assets.xcassets/AppIcon.appiconset`.
- **Composition:** midnight navy field, cyan target ring centered at 50%/50%, bright target arc around 12 o'clock, and a white needle aligned exactly through the arc.
- **Palette:** `#030718`, `#00DCFF`, `#41F5FF`, `#FFFFFF`.
- **Safe margin:** keep critical geometry at least 14% from every edge; do not pre-round corners or include text.
- **Replacement:** export one opaque 1024 × 1024 image, replace `AppIcon-1024.png`, then let Xcode generate required device variants. Confirm alpha is absent and inspect 20 pt, 29 pt, 40 pt, 60 pt, and App Store previews.
- **Launch:** the same mark is exported to `LaunchLogo.imageset` over `LaunchBackground`.

Run `python3 Scripts/generate-assets.py` to regenerate the included original placeholder artwork.
