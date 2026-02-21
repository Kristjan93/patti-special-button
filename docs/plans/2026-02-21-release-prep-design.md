# Release Prep — v1.0 (Local Distribution)

## Distribution: Local / Friends
Ad-hoc signing, no notarization, shared as .app in a DMG.

## License: MIT
MIT License for the code. CC BY 4.0 attribution maintained for Pablo Stanley's butt art.

## Checklist

### 1. App Display Name
- Set `INFOPLIST_KEY_CFBundleDisplayName = "PattiSpecialButton"` in pbxproj (both Debug and Release)

### 2. App Icon
- Source: `scripts/fractured-but-whole/asynchronous-butt.gif` first frame (512x512)
- Generate all required macOS sizes: 16, 32, 128, 256, 512 at 1x and 2x
- Use Original mode processing (composite on white) for a clean standalone icon
- Place PNGs in `Assets.xcassets/AppIcon.appiconset/` with updated Contents.json

### 3. Info.plist Polish
- `NSHumanReadableCopyright`: "© 2026 pattiVoice. Butt art by Pablo Stanley (CC BY 4.0)"
- `LSApplicationCategoryType`: `public.app-category.entertainment`
- Version 1.0 build 1 already set

### 4. Code Cleanup
- Remove empty test target boilerplate files

### 5. Add MIT LICENSE file
- Add LICENSE to repo root

### 6. Version & Git Tag
- Tag release commit as `v1.0`

### 7. DMG Packaging
- Shell script (`scripts/create-dmg.sh`) using `hdiutil`
- Drag-to-Applications layout with symlink

### 8. Smoke Test Checklist
- [ ] App launches from anywhere
- [ ] Menu bar icon appears and animates continuously
- [ ] Left-click plays selected sound to completion
- [ ] Right-click opens context menu with all items
- [ ] Change Icon: popover opens, arrow keys preview, Enter selects, Escape reverts
- [ ] Change Sound: popover opens, Space previews, Enter selects, Escape closes
- [ ] Display modes: Fill, Original, Outline all render correctly
- [ ] Icon sizes: Fun Size, Regular Rump, Badonkadonk all work
- [ ] Credits opens buttsss.com in default browser
- [ ] Quit exits cleanly
- [ ] Preferences persist after relaunch
- [ ] No Dock icon appears
- [ ] Works without Xcode on target machine

---

## Future: Public Release TODO

### Sound Licensing (CRITICAL — 6 of 12 sounds flagged)

**Safe (freesound.org — verify specific CC license for each):**
- `556505__jixolros__small-realpoots105-110.wav` — freesound #556505
- `27136__zippi1__fart3.wav` — freesound #27136
- `391468__stereostory__quack_fart_noise_44k.wav` — freesound #391468
- `326143__mackaffee__fart.mp3` — freesound #326143
- `104183__ekokubza123__punch.wav` — freesound #104183
- `204805__ezcah__spanking.wav` — freesound #204805

**FLAGGED — no verifiable license, must replace or clear before public release:**
- `dramatic-fart_f8Sw6fv.mp3` — unknown source
- `dry-fart.mp3` — unknown source
- `fart-meme-sound.mp3` — unknown source
- `perfect-fart.mp3` — unknown source
- `maro-jump-sound-effect_1.mp3` — likely game SFX rip
- `studio-audience-awwww-sound-fx.mp3` — unknown source

### Other Public Release Items
- Notarize with Developer ID (or Mac App Store submission)
- Proper code signing certificate
- Add `license` field to sounds-manifest.json entries
- README with screenshots and install instructions
- GitHub release with tagged version and DMG artifact
