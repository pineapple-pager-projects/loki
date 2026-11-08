# Loki asset sources (optional — not needed to run Loki)

This folder holds the **theme source images, source fonts, and the asset build
script**. You do **not** need any of it to run Loki: the deployable payload under
`payloads/user/reconnaissance/loki/` already ships with the pre-rendered runtime
assets (`.fatlas` glyph atlases, `.r565` images, and `prewarm/` `.nbg`/`.nspr`
blobs). The Pager has no image/font libraries, so assets are pre-rendered here on
a workstation and committed ready-to-use — copy the payload straight to the Pager.

Keep this folder out of what you deploy to the Pager; only `payloads/` is needed
there.

## When you need it

Only when you **edit a theme** (new background, new status art, new font) or add a
theme. Then regenerate the runtime assets and copy them into the payload tree.

## Regenerate

Requires Python 3 + Pillow + numpy on your workstation (not on the Pager):

```bash
cd sources
python3 build_assets.py            # fonts -> .fatlas, images -> .r565
python3 build_assets.py --prewarm  # backgrounds + status art -> prewarm .nbg/.nspr
```

Generated files land next to their sources here under `sources/`. Copy them into
the payload tree (same relative paths):

```bash
rsync -a --prune-empty-dirs \
  --include '*/' \
  --include '*.fatlas' --include '*.r565' --include '*.nbg' --include '*.nspr' \
  --exclude '*' \
  themes/ ../payloads/user/reconnaissance/loki/themes/
rsync -a --prune-empty-dirs \
  --include '*/' --include '*.fatlas' --include '*.r565' --exclude '*' \
  resources/ ../payloads/user/reconnaissance/loki/resources/
```
