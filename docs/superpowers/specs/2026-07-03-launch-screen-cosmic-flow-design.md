# Pecker Cosmic Flow Launch Screen Design

## Goal

Replace the current narrow, literal timeline launch artwork with a more distinctive
brand moment. The new launch screen should feel spacious and refined while still
communicating Pecker's relationship with time.

## Approved Direction

Use the approved **A3 — Time Flow Revelation** concept:

- Keep the existing deep navy visual field.
- Remove literal planets, orbital diagrams, dense star fields, and photographic
  space imagery.
- Use only a few subtle energy particles and soft refracted haze to suggest depth.
- Build the timeline, motion trails, and bird from one shared blue-violet light-flow
  material.
- Let the woodpecker appear through negative space and selective highlights rather
  than through a closed, fully rendered silhouette.
- Use Pecker's yellow-green accent only for the current-time node.

The first glance should read as a luminous flow crossing a point in time. The bird
should become apparent only on a second look.

## Composition

The launch artwork is centered in the safe visual area and occupies roughly the
middle third of the screen height.

- A one-pixel vertical time axis runs through the current-time node and fades before
  reaching either screen edge.
- The current-time node sits slightly above the screen's vertical midpoint.
- Three broad translucent ribbons cross the node area. Their negative space suggests
  the woodpecker's head, beak, and wings.
- Fine light trails extend away from the inferred beak and dissolve into the
  background.
- No app name, tagline, loading label, progress indicator, or NASA attribution is
  displayed.

The composition must preserve generous empty space so it remains calm on both compact
and large iPhone displays.

## Color and Material

- Background: near-black navy derived from the existing
  `PeckerLaunchBackground`.
- Primary flow: cyan-blue with restrained violet at the fading edges.
- Highlight flow: pale ice blue at no more than moderate opacity.
- Current-time accent: the existing fluorescent yellow-green.
- Grain and particles: extremely low contrast and sparse enough that the background
  never reads as a literal star field.

All flow elements share soft bloom and partial transparency. The bird must not use
separate solid colors, realistic feathers, or a discrete body layer.

## iOS Implementation

iOS launch screens are static, so motion is implied through tapered trails,
asymmetric flow, blur, and fading opacity.

Implementation remains asset-catalog based:

- Replace the raster renditions inside
  `PeckerLaunchTimeline.imageset` with the approved cosmic-flow artwork.
- Retain `PeckerLaunchBackground.colorset`, adjusting its color only if needed to
  blend seamlessly with the new artwork.
- Keep the existing `UILaunchScreen` configuration and safe-area behavior in
  `Pecker/Resources/Info.plist`.
- Do not add a launch storyboard, runtime animation, SwiftUI launch overlay, or
  artificial startup delay.

The raster asset must use transparency around the central artwork so the named launch
background can fill every screen ratio without cropping the focal composition.

## Asset Requirements

- Generate 260 × 520, 520 × 1040, and 780 × 1560 PNG renditions for 1x, 2x,
  and 3x with identical visual alignment.
- Preserve transparency outside the artwork.
- Avoid fine features that disappear at 1x or bloom into solid shapes at 3x.
- Keep the focal node and inferred bird readable at normal device viewing distance.
- Do not use an external astronomy photograph or a literal star-field background.

## Verification

- Validate asset-catalog metadata and image dimensions.
- Build the app for an iOS simulator with code signing disabled.
- Capture cold-launch screenshots on at least one compact and one large iPhone
  simulator.
- Confirm there are no visible seams between the transparent artwork and launch
  background.
- Confirm the artwork does not clip, stretch, or shift away from the safe visual area.
- Confirm the first rendered app screen does not produce a jarring background-color
  flash after the launch screen.

## Out of Scope

- Animated launch sequences.
- Introductory copy or onboarding content.
- Changes to the app icon.
- Changes to the main Today, Timeline, or Onboarding screens.
