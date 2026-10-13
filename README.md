# WizPetRings

<img src="artwork/WizPetRings-icon-512.png" alt="WizPetRings WPR icon" width="144" height="144">

Pet command and care rings for **Hunters in WoW Forever**. Hold a key, flick toward an icon, and release to execute an action. Release in the centre to cancel.

Maintained by **wizdevproj** under **Wiz-Addons**. WizPetRings is standalone and requires no external libraries.

## Features

- **Pet Commands:** Attack, Follow, Passive, Defensive, Assist, Aggressive, Move To.
- **Pet Care:** Dismiss Pet, Revive Pet, Call Pet / Call Bear, Feed Pet.
- Separate held keys, size controls, and adjustable action order for each ring.
- Hunter-only activation. Non-Hunters do not create rings or receive addon key overrides.
- Settings saved per character.

## Installation

1. Download the release ZIP.
2. Extract its **WizPetRings** folder into your WoW Forever installation's `Interface/AddOns` folder.
3. Restart WoW for a first installation, then enable **WizPetRings** in the addon list.
4. On your Hunter, open `/wizpetrings` (or the compatible aliases `/petrings` and `/prings`) to configure the rings.

The correct folder layout is `Interface/AddOns/WizPetRings/WizPetRings_Camelot.toc`. Avoid nesting another WizPetRings folder inside it.

For an update, replace the addon files and use `/reload` out of combat. Character settings remain in `PetRingsDB`, the retained storage name used for compatibility with earlier builds.

## Controls and settings

Hold the configured ring key to open a ring at your cursor. Move toward an icon and release the key to execute it. Let go inside the centre to cancel.

Choose **Pet Commands** or **Pet Care** in the settings sidebar. Click a key button and press your chosen key; Escape or right-click clears it. Mouse buttons 3–5 are supported. Use different keys for the two rings.

The game's **Key Bindings → WizPetRings** category also provides both bindings. A key set inside WizPetRings is applied as a character-specific override, and does not replace your normal saved game binding. If you use WoW's binding screen for a ring, enable **Character Specific Key Bindings** to keep an account-wide ring binding from reserving that key on other characters.

Use each ring's size slider to resize it. Click a direction button to cycle its action; the selected action swaps positions with the action already there. **Reset layout** restores the default order.

The optional **Call Pet spell ID** field is on the Pet Care page. Leave it blank for automatic detection. Use it only if a learned family summon spell cannot be detected automatically.

## Action behavior

- Attack uses your current living hostile target.
- Stances use the pet bar's secure actions when available. **Aggressive must be present on the pet bar.**
- Move To opens the ground-targeting cursor; click the destination.
- Call Pet casts the detected spell ID directly, including Call Bear and other family names.
- Feed Pet opens the food-targeting cursor; click suitable food in your bags.
- Unlearned care spells are unavailable. The game enforces spell requirements and combat restrictions.

Changes to keys, sizes, and layouts made in combat apply when combat ends. A reload during combat defers protected ring creation until combat ends.

## Compatibility and testing

This release targets **WoW Forever / Camelot**, interface version **16001**. Other WoW game versions are not supported by this release.

The secure picker and settings have Lua 5.1 regression coverage for press/release selection, cancellation, direct summon and stance actions, combat deferral, key capture, layout changes, class guards, and saved setting compatibility. The addon has also received in-game testing during development. Further beta client changes may require compatibility updates.

For a bug report, include the output of `/wizpetrings version`, your client build, character class, the steps to reproduce it, and the newest Lua error message if one appears.

## Building a release

With Python 3 installed, run:

```sh
python tools/build_release.py
```

The script writes `dist/WizPetRings-1.0.0.zip`, containing the addon in a correctly named WizPetRings folder. No third-party Python packages are needed.

## License and credits

WizPetRings is distributed under the **WTFPL v2**. See [LICENSE](LICENSE).

The settings use built-in WoW parchment and fonts. See [ATTRIBUTION.md](ATTRIBUTION.md) for author credits and asset provenance.

## Repository

GitHub repository: `Wiz-Addons/WizPetRings`.

## Automated compatibility checks

GitHub Actions runs the Lua regression checks and builds an installable ZIP on pushes, pull requests, and manual runs.

The **Forever compatibility watch** checks the `forever` branch of `Gethe/wow-ui-source` daily and can also be run manually. When that source advances, it prepares a draft pull request recording the new baseline and updating TOC interface metadata if needed. The pull request lists potentially relevant API/source changes. The workflow checks the candidate before opening it and avoids duplicate reviews of the same source commit.

This monitors a community mirror of Blizzard's UI source; it may lag the live patch. Mock tests cannot prove compatibility inside a new game client. Lua API changes still need review and in-game testing. The workflow never merges updates or publishes releases automatically. Repository Actions settings must allow GitHub Actions to create pull requests. Pull requests created with GITHUB_TOKEN do not automatically trigger other workflows; rerun Addon checks manually on a candidate branch after editing it.
