---
name: add-assets
description: Add an image asset to the correct module's Asset Catalog with validated @1x/2x/3x scales (or vector source) and a typed accessor. Use for "/add-assets <name>" or "add this icon/image to the app".
---

# /add-assets `[--module <M>] <name>`

## Precondition

Check for `ios-skeleton.config.json` first. Missing → refuse: *"This project
hasn't been initialized yet — run `/start` first."*

## Steps

1. **Resolve the destination module** per the topology branch (§4): explicit
   `--module` → config's default → **stop and ask** if ambiguous. Shared
   iconography belongs in the shared module; brand art belongs in an app.
2. **Accept the source.** Either one vector file (PDF/SVG, "preserve vector
   data") or three raster files explicitly labeled 1x/2x/3x.
3. **Validate scale.** For raster input, use `sips -g pixelWidth -g
   pixelHeight` on each file and confirm 2x/3x are exact 2×/3× the 1x
   dimensions. **Refuse rather than silently accepting a mismatched scale
   set** — report the actual dimensions found.
4. **Write the imageset.** Create
   `<resolved-module>/.../Assets.xcassets/<Name>.imageset/` with the correct
   filenames and a `Contents.json` listing all three scales (or the single
   vector entry with "preserves vector data" set).
5. **Generate/update the typed accessor** (e.g.
   `DesignSystem/Assets/ImageAssets.swift`) so features reference `Image.<name>`
   instead of a magic string. If the destination is a framework or package,
   the accessor must resolve through **that module's own bundle**
   (`Bundle.module`/`Bundle(for:)`), never `Bundle.main` — otherwise the image
   compiles fine and is `nil` at runtime in the consuming app (§3.11).

## What NOT to do

- Don't add the asset to more than one module "just in case" — pick the
  correct owner per step 1.
- Don't skip the scale validation because "it's probably fine" — a mismatched
  scale set is exactly the kind of bug that only shows up on a specific device
  density.
