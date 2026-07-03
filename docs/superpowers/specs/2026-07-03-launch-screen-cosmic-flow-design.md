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

The launch artwork is full bleed. The image scales proportionally until it covers
the entire display, and the system may crop its outer edges on compact or unusually
tall devices.

- A one-pixel vertical time axis runs through the current-time node and fades before
  reaching either screen edge.
- The current-time node sits slightly above the screen's vertical midpoint.
- Three broad translucent ribbons cross the node area. Their negative space suggests
  the woodpecker's head, beak, and wings.
- The inferred bird occupies about 80% of the visible screen width.
- Fine light trails extend away from the inferred beak and dissolve into the
  background.
- No app name, tagline, loading label, progress indicator, or NASA attribution is
  displayed.

The node, bird head, beak, and primary ribbons remain inside the central safe
composition zone. Only peripheral stars, haze, and ribbon tails may be cropped.

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

Implementation uses a static launch storyboard backed by the existing asset catalog:

- Add `Pecker/Resources/LaunchScreen.storyboard`.
- Place a single image view on the storyboard and constrain all four edges to the
  root view, not the safe area.
- Set the image view content mode to Aspect Fill and enable clipping.
- Use `PeckerLaunchTimeline` as the image and `PeckerLaunchBackground` as the root
  view background color.
- Retain `PeckerLaunchBackground.colorset`, adjusting its color only if needed to
  blend seamlessly with the new artwork.
- Replace the existing `UILaunchScreen` dictionary in
  `Pecker/Resources/Info.plist` with `UILaunchStoryboardName = LaunchScreen`.
- Do not add runtime animation, a SwiftUI launch overlay, or an artificial startup
  delay.

The storyboard supplies deterministic Aspect Fill behavior on every iPhone size.
Cropping is accepted by design and must never remove the focal composition.

## Asset Requirements

- Generate 260 × 520, 520 × 1040, and 780 × 1560 PNG renditions for 1x, 2x,
  and 3x with identical visual alignment.
- Keep the deep-space background full frame and match its outer edge color to
  `PeckerLaunchBackground`.
- Avoid fine features that disappear at 1x or bloom into solid shapes at 3x.
- Keep the focal node and inferred bird readable at normal device viewing distance.
- Do not use an external astronomy photograph, dense star field, or recognizable
  constellation; retain only the approved sparse synthetic stars and haze.

## Verification

- Validate asset-catalog metadata and image dimensions.
- Build the app for an iOS simulator with code signing disabled.
- Capture cold-launch screenshots on at least one compact and one large iPhone
  simulator.
- Confirm there are no uncovered bars or visible seams at any display edge.
- Confirm the artwork fills the screen without stretching.
- Confirm compact-device cropping removes only peripheral background details.
- Confirm the inferred bird occupies approximately 80% of the visible screen width.
- Confirm the first rendered app screen does not produce a jarring background-color
  flash after the launch screen.

## Out of Scope

- Animated launch sequences.
- Introductory copy or onboarding content.
- Changes to the app icon.
- Changes to the main Today, Timeline, or Onboarding screens.
