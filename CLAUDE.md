# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Doom Emacs private config directory (`$DOOMDIR`, i.e. `~/.doom.d`). It is *not* an Emacs Lisp package: there is no build, no test suite, and no entry point of its own. Doom (installed separately at `~/.emacs.d`, version `3.0.0-pre`) loads these four files at startup. Emacs here is 30.2, but some workarounds target 31.1 — do not assume the config only ever runs on the local version.

## Applying changes

`doom` is not on `PATH`; invoke it as `~/.emacs.d/bin/doom`.

- After editing `init.el` or `packages.el` (module list / package list): `~/.emacs.d/bin/doom sync` — mandatory, then restart Emacs.
- After editing `config.el` only: `M-x doom/reload` in a running Emacs, or just restart. No sync needed.
- Sanity-check a config change without touching the running session: `emacs --debug-init` (or `~/.emacs.d/bin/doom doctor` for environment/dependency problems).
- Byte-compile/native-compile warnings for changed files surface during `doom sync`; there is no separate lint step.

There is nothing to "test" in the unit sense — verification means starting Emacs and exercising the affected mode.

## File roles

- `init.el` — the `doom!` block: which Doom modules and flags are enabled. Editing this is how you add language support, completion frameworks, etc. Keep Doom's commented-out module lines intact; they are the menu of available options and Doom's own docs bindings (`K` on a module) depend on them.
- `packages.el` — `package!` declarations for packages Doom doesn't ship (currently: `evil-terminal-cursor-changer`, `company-prescient`, `bazel`, `just-mode`, `hcl-mode`, `rainbow-delimiters`, `majutsu`). Declaring here only makes the package available; it still needs a `use-package!`/`after!` block in `config.el` to be activated.
- `config.el` — all actual configuration. Loaded after Doom's modules, so nearly everything is wrapped in `after!` (or `use-package!` for packages from `packages.el`) rather than set at top level.
- `custom.el` — Doom's `custom-file`, written by the Customize UI and by `safe-local-variable-values` prompts. **Machine-local and deliberately untracked** (it contains absolute paths and accepted `.dir-locals.el` payloads). Never hand-edit it or commit it; if a setting belongs in version control, put it in `config.el` instead. Note `hcl-indent-level` is currently set in both files — `config.el` is the authoritative copy.

## Conventions in `config.el`

The dominant convention is that **every non-obvious setting carries a comment explaining the mechanism and the evidence**, not just the intent. Existing blocks cite reproduction counts (e.g. "38/40 failures before this advice, 0/40 after"), the specific LSP request each disabled option triggers, file:line references into Doom's own source (`+evil-bindings.el:696`), and why the obvious alternative was rejected. Match this density when adding to it; a bare `setq` with no rationale is out of place here.

Two recurring themes drive most of the file:

1. **Input latency.** A large block of `lsp-mode`/`lsp-ui` settings exists specifically to remove per-cursor-movement LSP round-trips (`lsp-enable-symbol-highlighting`, `lsp-lens-enable`, `lsp-modeline-code-actions-enable`, `lsp-eldoc-enable-hover`, `lsp-ui-doc-show-with-cursor` are all off on purpose, benchmarked against nvim/LazyVim). File watchers are disabled globally because large C/C++ trees stall the UI at session start. Re-enabling any of these is a regression, not a cleanup.
2. **Upstream bug workarounds.** E.g. `+fix-emacs31-nonascii-delete-process-a` advises `delete-process` to swallow one specific Emacs 31.1 C-level error, and `ccls-tramp` is in `lsp-disabled-clients`. These are load-bearing; check git log before removing anything that reads like dead weight.

## Environment this config assumes

- Projects live under `~/projects` — both `projectile-project-search-path` (depth 1, intentionally excluding nested submodules) and `magit-repository-directories` (depth 2) are keyed to it.
- A self-hosted GitLab at `gitlab.nartis.ru` is registered in `forge-alist`; credentials come from `~/.authinfo`.
- C/C++ is the main workload: tree-sitter modes with `c-ts-mode-indent-offset` 4 and `'bsd` style to match project `.clang-format` files, `apheleia-mode` hooked onto C/C++ buffers only (not globally), and per-project `clangd` wrapper scripts (`.clangd.sh`) registered via `.dir-locals.el` eval forms.
- `glab` (GitLab CLI) is expected on `PATH` for `+gitlab/ci-lint`, bound to `<localleader> l` in YAML buffers.
- Terminal Emacs is a supported target, not an afterthought — the `:os tty` module is on and `config.el` has an explicit `(unless window-system ...)` mouse-support block.
