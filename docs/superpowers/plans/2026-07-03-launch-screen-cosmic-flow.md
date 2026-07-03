# Pecker Cosmic Flow Launch Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Pecker's narrow timeline launch artwork with the approved A3 cosmic-flow composition while preserving the existing static iOS launch-screen integration.

**Architecture:** Keep `UILaunchScreen` and the named launch background unchanged. Generate one transparent 3x master artwork, derive the 2x and 1x renditions from it, and validate the asset catalog before simulator builds and cold-launch screenshots.

**Tech Stack:** Xcode asset catalogs, PNG with alpha, `sips`, `plutil`, `xcodebuild`, iOS Simulator

---

## File Structure

- `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png`: 780 × 1560 transparent master rendition.
- `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@2x.png`: 520 × 1040 rendition derived from the master.
- `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline.png`: 260 × 520 rendition derived from the master.
- `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/Contents.json`: existing scale-to-file mapping; verify without changing unless validation exposes drift.
- `Pecker/Resources/Assets.xcassets/PeckerLaunchBackground.colorset/Contents.json`: existing near-black navy field; change only if a visible seam appears during simulator verification.
- `Pecker/Resources/Info.plist`: existing `UILaunchScreen` configuration; verify without changing.
- `docs/verification/launch-screen-cosmic-flow-compact.png`: compact-iPhone cold-launch evidence.
- `docs/verification/launch-screen-cosmic-flow-large.png`: large-iPhone cold-launch evidence.

### Task 1: Generate the approved transparent artwork

**Files:**
- Modify: `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png`

- [ ] **Step 1: Record the current asset contract**

Run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png
```

Expected: `pixelWidth: 780`, `pixelHeight: 1560`, and `hasAlpha: yes`.

- [ ] **Step 2: Generate the A3 artwork**

Use the image-generation workflow with the approved A3 visual constraints:

```text
Create a 1:2 portrait transparent-background launch-screen artwork. No text, no logo
tile, no frame, no literal stars, planets, orbital diagram, or photographic space.
One very thin vertical cyan-blue time axis fades before the top and bottom. Slightly
above center, a small fluorescent yellow-green current-time node glows softly.
Three broad, translucent cyan-to-violet energy ribbons cross the node. The negative
space between the ribbons only subtly suggests a woodpecker head, long beak, and
wings; there must be no closed bird silhouette, solid body, realistic feathers, or
separate bird colors. Add only three or four nearly invisible energy particles and
soft refracted haze. Generous transparent empty space surrounds the central artwork.
The first glance reads as time-flow light; the second glance reveals the bird.
Refined, calm, premium iOS visual, crisp at small size.
```

Expected: the generated image follows the approved A3 hierarchy and has transparent outer space. Save the returned PNG as `/tmp/pecker-launch-cosmic-flow-source.png`.

- [ ] **Step 3: Inspect the generated master**

Open the generated image at full resolution and verify:

```text
1. The first read is a light flow crossing a time node.
2. The bird appears through negative space on a second read.
3. No literal star field, planet, orbit, text, or solid bird body is present.
4. The yellow-green accent appears only at the current-time node.
5. The outer quarter of every edge is predominantly transparent.
```

Expected: all five checks pass; regenerate once with a tightened prompt if any check fails.

- [ ] **Step 4: Normalize the master rendition**

Run:

```bash
sips -z 1560 780 /tmp/pecker-launch-cosmic-flow-source.png \
  --out Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png
```

Expected: `pecker-launch-timeline@3x.png` is replaced with a 780 × 1560 PNG.

- [ ] **Step 5: Verify the master contract**

Run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png
```

Expected: `pixelWidth: 780`, `pixelHeight: 1560`, and `hasAlpha: yes`.

### Task 2: Derive and validate all asset renditions

**Files:**
- Modify: `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@2x.png`
- Modify: `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline.png`
- Verify: `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/Contents.json`
- Verify: `Pecker/Resources/Info.plist`

- [ ] **Step 1: Derive the 2x rendition from the 3x master**

Run:

```bash
sips -z 1040 520 \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png \
  --out Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@2x.png
```

Expected: a 520 × 1040 PNG is written.

- [ ] **Step 2: Derive the 1x rendition from the 3x master**

Run:

```bash
sips -z 520 260 \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png \
  --out Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline.png
```

Expected: a 260 × 520 PNG is written.

- [ ] **Step 3: Verify all dimensions and alpha channels**

Run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline.png \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@2x.png \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png
```

Expected:

```text
1x: 260 × 520, hasAlpha: yes
2x: 520 × 1040, hasAlpha: yes
3x: 780 × 1560, hasAlpha: yes
```

- [ ] **Step 4: Verify the image-set mapping**

Run:

```bash
jq empty Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/Contents.json
rg -n '"filename"|"scale"' \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/Contents.json
```

Expected: `jq` exits successfully, with one filename mapped to each of `1x`, `2x`, and `3x`.

- [ ] **Step 5: Verify the static launch-screen configuration**

Run:

```bash
plutil -extract UILaunchScreen xml1 -o - Pecker/Resources/Info.plist
```

Expected: `UIImageName` remains `PeckerLaunchTimeline`, `UIColorName` remains `PeckerLaunchBackground`, and `UIImageRespectsSafeAreaInsets` remains true.

### Task 3: Build and visually verify cold launches

**Files:**
- Create: `docs/verification/launch-screen-cosmic-flow-compact.png`
- Create: `docs/verification/launch-screen-cosmic-flow-large.png`
- Modify only if required by evidence: `Pecker/Resources/Assets.xcassets/PeckerLaunchBackground.colorset/Contents.json`

- [ ] **Step 1: Build the simulator app**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath DerivedData/LaunchScreen \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Cold-launch on a compact iPhone simulator**

Boot an available compact iPhone simulator, install
`DerivedData/LaunchScreen/Build/Products/Debug-iphonesimulator/Pecker.app`, terminate
the app if already running, launch it, and capture the launch frame as:

```text
docs/verification/launch-screen-cosmic-flow-compact.png
```

Expected: the focal artwork remains centered, unclipped, and surrounded by generous empty space.

- [ ] **Step 3: Cold-launch on a large iPhone simulator**

Repeat the install, terminate, launch, and capture workflow on an available large
iPhone simulator, saving:

```text
docs/verification/launch-screen-cosmic-flow-large.png
```

Expected: the same focal hierarchy is preserved without stretching or unsafe-area drift.

- [ ] **Step 4: Inspect both screenshots side by side**

Verify:

```text
1. No seam exists between artwork transparency and PeckerLaunchBackground.
2. No edge is clipped on either device.
3. The node remains slightly above visual center.
4. The bird remains suggestive rather than literal.
5. Transitioning to the first app screen does not expose a bright background flash.
```

Expected: all checks pass. If only a background seam fails, adjust
`PeckerLaunchBackground.colorset/Contents.json` to the artwork's sampled edge color,
rebuild, and repeat both cold-launch captures.

- [ ] **Step 5: Review the focused diff**

Run:

```bash
git status --short
git diff --stat -- \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset \
  Pecker/Resources/Assets.xcassets/PeckerLaunchBackground.colorset \
  docs/verification/launch-screen-cosmic-flow-compact.png \
  docs/verification/launch-screen-cosmic-flow-large.png
```

Expected: only the three launch PNG renditions, any evidence-driven background color adjustment, and the two verification screenshots appear in the focused change set.

### Task 4: Final verification and commit

**Files:**
- Verify: `Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/*`
- Verify: `Pecker/Resources/Assets.xcassets/PeckerLaunchBackground.colorset/Contents.json`
- Verify: `Pecker/Resources/Info.plist`
- Verify: `docs/verification/launch-screen-cosmic-flow-compact.png`
- Verify: `docs/verification/launch-screen-cosmic-flow-large.png`

- [ ] **Step 1: Run the final asset and project checks**

Run:

```bash
plutil -lint Pecker/Resources/Info.plist
jq empty Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/Contents.json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Pecker.xcodeproj -scheme Pecker \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath DerivedData/LaunchScreen \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: the plist and JSON checks succeed and the build reports `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Commit only the launch-screen implementation**

Run:

```bash
git add \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline.png \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@2x.png \
  Pecker/Resources/Assets.xcassets/PeckerLaunchTimeline.imageset/pecker-launch-timeline@3x.png \
  Pecker/Resources/Assets.xcassets/PeckerLaunchBackground.colorset/Contents.json \
  docs/verification/launch-screen-cosmic-flow-compact.png \
  docs/verification/launch-screen-cosmic-flow-large.png
git commit -m "feat: redesign cosmic flow launch screen"
```

Expected: one focused implementation commit without unrelated existing workspace changes.
