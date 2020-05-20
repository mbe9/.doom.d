;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Pavel Pletnev"
      user-mail-address "pletnev.pg@gmail.com"

      doom-theme 'doom-one

      display-line-numbers-type 'relative

      ;; Increase delay to reduce fp popups
      which-key-idle-delay 2.0

      ;; I can wait, if it means less server crashes
      lsp-idle-delay 2.5
      lsp-ui-sideline-enable nil
      lsp-enable-symbol-highlighting nil

      ;; Use the same font size for Zen mode
      +zen-text-scale 0
      ;; Increase default line width for Zen mode
      writeroom-width 120
      )

;; Prefer opening popup windows to the side, not at the bottom
;; (plist-put +popup-defaults :side 'right)
;; (plist-put +popup-defaults :width 0.5)

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
(setq doom-font (font-spec :family "monospace" :size 14))

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Start Emacs frame maximized
(add-hook `window-setup-hook `toggle-frame-maximized t)

;; Enable relative line number when there is only one active window
;; When more windows are added, disable line numbers everywhere
;; This is done mainly for performance since Emacs is abysmally slow with line numbers
;; on multiple windows (but one window is ok because logic)
(add-hook `window-configuration-change-hook
          (lambda () (if (and (derived-mode-p 'prog-mode) (one-window-p))
                         (global-display-line-numbers-mode +1)
                       (global-display-line-numbers-mode -1))))

;; (use-package aggressive-indent
;;   :hook (prog-mode . aggressive-indent-mode))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c g k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c g d') to jump to their definition and see how
;; they are implemented.
