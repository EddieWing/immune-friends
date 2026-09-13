# Microcosm — Immune Friends

Godot game prototype: build an immune defence under a microscope, connect cells and survive automatic infection waves. Cells have animated faces and hold hands along physical bonds.

This is a reconstruction inspired by observed Auto Immune gameplay, with provisional mechanics documented in `game/data/assumptions.json`. Original game artwork is not included in the build.

## Play locally

- Desktop: `Launch-Game.cmd`.
- Browser: run `Build-Web.cmd`, then `Launch-Web.cmd` and open http://127.0.0.1:8060.
- Editor: import `game/project.godot` in Godot 4.7.2.
- Before the first web build, run `node download-web-template.mjs` (Node.js 22 or newer). The script retrieves only the web release template from the official Godot archive.

Windows launch scripts use the engine installed in `D:\Create\Godot`. Adjust that path on another computer. Close the local server window to stop serving the browser build. Browser saves are separate from desktop saves.

## Camera and speed

Use the mouse wheel to zoom; the left gauge shows the current zoom position from 0% to 100%. The top ×1, ×2 and ×5 buttons control battle playback speed. Preparation remains untimed.

## Graphics

The game uses simple cell and virus graphics.

## Parameter admin

Open `/admin/` on the published site. Save writes staged values to `admin/settings.json` through GitHub Contents API with a fine-grained token scoped to this repository (Contents: read and write). The token is held only in page memory. The game never reads staged settings. Import them only when explicitly requested by the owner. Saves do not trigger a game deployment.

The admin includes all values currently externalized in `game/data/assumptions.json` and `game/data/cells.json`; constants embedded in scripts are not editable here. `admin/defaults.json` is the initial snapshot, not a live connection to game data.

## GitHub Pages

The workflow `.github/workflows/deploy.yml` checks the game, exports it from source, and deploys the `web` artifact on each push to `main`. In repository Settings → Pages, select **GitHub Actions** as the build source before the first deployment. Repository/account must support Pages. The successful deployment exposes its URL in the Actions run and repository environment.

Generated web output, export templates, editor caches and test captures are excluded from Git. No hosting credentials belong in source control. The workflow uses GitHub's scoped automatic token.

The browser build is single-threaded and uses relative asset paths, allowing deployment under a repository subpath. Gameplay currently targets mouse and keyboard. Browser interaction QA remains incomplete. Drag offers onto the field to buy cells; drag cells to reposition them, use the rotation handle to turn them, and click the large shop arrow to start a battle.
