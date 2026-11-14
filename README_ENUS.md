# Companion source code — Godot 4 + Rust: Build a 2D Snake Step by Step

**Author:** Elliot Veyran · **Imprint:** As Vezes  
**Edition:** US English · The Rust/Godot source code is shared with the Brazilian Portuguese edition.

This repository contains **16 independent chapter checkpoints**, **six transition patches**, the optional **Rust R1/R2 practice laboratory**, and verification helpers. These are **source files**, not precompiled games, Godot installers, or a substitute for the book's step-by-step lessons.

## Download and verify

Use **Code → Download ZIP** on this repository's main page (or clone it with Git), then extract the folder without changing its internal paths. Open [MANIFEST.json](MANIFEST.json) to inspect the versioned file inventory and each file's Git blob identifier; it is an inventory, not a cryptographic release signature. Read [LICENSE.txt](LICENSE.txt) for the original source code's MIT license.

The checkpoint folder slugs remain in Portuguese because **the actual folder names are shared between both language editions**. Keep them unchanged when using terminal commands from the English chapters.

## Build one game instead of swapping projects

**Your working directory is `my-snake/`**, not `codigo/checkpoints/`.

1. **Chapter 1:** create a new Godot project in `my-snake/godot/`. Build the `Board`, `Status`, and `Help` scene nodes yourself; compare with [checkpoint 01](codigo/checkpoints/01-cenas-e-nos/) only when needed.
2. **Chapter 2:** return to **the same** `my-snake/godot/` and add `Board.gd`, a drawn grid and a timer. Checkpoint 02 is another reference, not a replacement.
3. **Chapter 3 onward:** add `my-snake/rust/` alongside `godot/`, then build your own native crate. Keep each chapter's crate name and all six library paths in `godot/Snake.gdextension` consistent with the current step.
4. **Chapter 8:** add `my-snake/tools/` for the optional Python runner and its tests. This does not replace Godot or Rust as the game's programming languages.
5. **Chapter 9 onward:** keep `my-snake/godot/project.godot` and its `config/name` unchanged. Renaming the project can redirect the `user://` location and make the player's saved high score or SQLite history appear missing.
6. **Chapters 10–12:** use schema migrations and verify persistence on **disposable copies** of SQLite data, never on your only copy of an important score history.
7. **Chapters 13–16:** refine the same game with borrowed Rust views, signals/HUD, performance experiments, and native packaging helpers. Do not copy the finished checkpoint over your project.

Each checkpoint is a separate standalone **reference**. It can be built for diagnosis or comparison, but it does **not automatically implement the next chapter in your own game**.

## Optional source patches

Available patches: `02-03`, `04-05`, `05-06`, `09-10`, `10-11`, and `11-12`. Other transitions are taught manually in the eBook.

If you have Git installed and your own sources still match the preceding checkpoint, run from **inside `my-snake/`**:

```sh
PATCH="/absolute/path/to/codigo/transicoes/10-11.patch"
git apply --check --exclude=godot/project.godot "$PATCH"
```

**Only if that check succeeds**, apply the exact same exclusion:

```sh
git apply --exclude=godot/project.godot "$PATCH"
```

The `--exclude` protects your Godot project identity; the example checkpoint's `project.godot` carries its own chapter name. For Windows PowerShell, see Appendix C of the English edition. If the check fails or you customized code, **do not force the patch**. Use the manual chapter instructions and preserve your changes.

## Verify the *reference* checkpoints separately

Install matching versions of Godot 4, stable Rust/Cargo, platform toolchain/linker, and optionally Python 3.10+. The reference GDExtension uses the pinned `godot` crate and configured Godot API; compatibility with every future engine release or OS is not guaranteed.

From the directory **containing `codigo/`**, you may run the optional reference-checkpoint orchestrator:

```sh
python3 codigo/tools/book_checkpoints.py --stages 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16 --timeout-seconds 1800 --report snake-reference-checks.json
```

A passing reference checkpoint test does **not** prove that your personalized `my-snake/` runs. Test your own project separately. Rust unit tests, a Godot headless smoke, an actual windowed gameplay session, and data surviving a process restart each answer **different questions**. Never claim one has passed based only on another. Cargo.lock is not versioned in every early checkpoint: don't use `--locked` indiscriminately.

## Third-party licenses and limitations

The author's **original source code** is covered by [MIT](LICENSE). Godot Engine, godot-rust, rusqlite, SQLite and any other third-party software remain subject to their respective licenses and terms. The source package does not include Godot Engine executables or vendored Cargo dependencies. Source licensing does **not** grant rights to reproduce the book text or cover art.

For problems, record your OS/CPU architecture, Rust/Cargo and Godot versions, command and exit code, the checkpoint/source revision, and the actual error. Compare each layer separately: build, native loading, game state, rendering, input, and storage.
