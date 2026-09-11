# Microcosm — Immune Friends

Godot game prototype: build an immune defence under a microscope, connect cells and survive automatic infection waves. Cells have animated faces and hold hands along physical bonds.

This is a reconstruction inspired by observed Auto Immune gameplay, with provisional mechanics documented in `game/data/assumptions.json`. Original game artwork is not included in the build.

## Play locally

- Desktop: `Launch-Game.cmd`.
- Browser: run `Build-Web.cmd`, then `Launch-Web.cmd` and open http://127.0.0.1:8060.
- Editor: import `game/project.godot` in Godot 4.7.2.
- Before the first web build, run `node download-web-template.mjs` (Node.js 22 or newer). The script retrieves only the web release template from the official Godot archive.

Windows launch scripts use the engine installed in `D:\Create\Godot`. Adjust that path on another computer. Close the local server window to stop serving the browser build. Browser saves are separate from desktop saves.

## Graphics

Open the gear button → Graphics (Графика клеток) and choose Простая or Рисованная. Both modes share the same game state, animated faces and hand bonds. The selection is saved locally. The microscope background is used in both modes.

## GitHub Pages

The workflow `.github/workflows/deploy.yml` checks the game, exports it from source, and deploys the `web` artifact on each push to `main`. In repository Settings → Pages, select **GitHub Actions** as the build source before the first deployment. Repository/account must support Pages. The successful deployment exposes its URL in the Actions run and repository environment.

Generated web output, export templates, editor caches and test captures are excluded from Git. No hosting credentials belong in source control. The workflow uses GitHub's scoped automatic token.

The browser build is single-threaded and uses relative asset paths, allowing deployment under a repository subpath. Gameplay currently targets mouse and keyboard. Browser interaction QA remains incomplete. Drag offers onto the field to buy cells; drag cells to reposition them, use the rotation handle to turn them, and click the large shop arrow to start a battle.
