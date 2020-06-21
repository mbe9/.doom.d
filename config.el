;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

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

      ;; Check files only on save and mode enable
      flycheck-check-syntax-automatically '(save mode-enabled)
      ;; Disable max error limit
      flycheck-checker-error-threshold nil

      ;; Use the same font size for Zen mode
      +zen-text-scale 0
      ;; Increase default line width for Zen mode
      writeroom-width 120

      magit-repository-directories '(("~/projects" . 2))
      )

;; Do not hide non-active #ifdefs
(after! emacs-ccls
  (setq ccls-enable-skipped-ranges nil))

;; POPUP RULES
(after! rustic
  (set-popup-rule! "^\\*rustic-compilation" :height 0.4))

;; Try to get rid of screen flickering
(add-to-list 'default-frame-alist '(inhibit-double-buffering . t))

;; Prefer opening popup windows to the side, not at the bottom
;; (plist-put +popup-defaults :side 'right)
;; (plist-put +popup-defaults :width 0.5)


;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Start Emacs frame maximized
(add-hook `window-setup-hook `toggle-frame-maximized t)

;; Enable relative line number when there is only one active window
;; When more windows are added, disable line numbers everywhere
;; This is done mainly for performance since Emacs is abysmally slow with line numbers
;; on multiple windows (but one window is ok because logic)
;; (add-hook `window-configuration-change-hook
;;           (lambda () (if (and (derived-mode-p 'prog-mode) (one-window-p))
;;                          (global-display-line-numbers-mode +1)
;;                        (global-display-line-numbers-mode -1))))

;; (use-package aggressive-indent
;;   :hook (prog-mode . aggressive-indent-mode))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(cond
 ((eq (system-name) "Archie")
  (setq doom-font (font-spec :family "monospace" :size 12)))
 (t
  (setq doom-font (font-spec :family "monospace" :size 14)))
 )
