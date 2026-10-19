# Poses and photo studio (shelved)

The `photo` branch is shelved: it works in game, but it is not ready for release.
It is based on 1.10.0. To pick it up again, merge `main` into `photo`, test it in game,
then bump VERSION to the next minor version and add a CHANGELOG entry.

## What works (last tested build: 1.11.0-photo-test12/14)
- Pose panel next to the preview, with 16 poses and a "weapons sheathed" option.
  The panel stays open, and emotes loop instead of freezing on the last frame.
- Pause button (icon) to freeze the model on a frame.
- Photo studio: the game UI is hidden and a full-screen model scene is shown.
  The camera angle is widened so the model keeps its usual size.
  - Backgrounds: "Where you stand" is the default (Narcissus-style). It hides your
    own character with `showPlayer`, lowers the camera and turns off unit names,
    then restores everything on exit or logout. Other backgrounds: dark, gradient,
    light, green screen.
  - Light presets with an optional vignette.
  - Framing: full, waist and portrait (raises the camera target by the model's bounding box).
  - Caption on/off and a screenshot button.
- A class-styled entrance (class animation plus spell visual kits) that plays once and
  then settles into a plain stand.

## Tried and dropped
- Class poses as menu items. They now exist only as the entrance.
- Loading-screen pictures as backgrounds: they looked bad.
- The class fitting-room atlas as a background: it is low-res and blurry full-screen.
- An "animation number" box: unclear for players.
- Opening the pose list in a Blizzard context menu: it covered the model and closed
  after each pick.

## Open questions
- The user wasn't fully happy with the overall feel. Revisit the UX before release.
- `showPlayer` state after /reload while in the studio has not been verified.
