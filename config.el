;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; General settings
(setq user-full-name "Pavel Pletnev"
      user-mail-address "pletnev.pg@gmail.com"

      doom-theme 'doom-molokai

      display-line-numbers-type nil

      doom-font (font-spec :family "monospace" :size 13)

      ;; Modeline settings
      doom-modeline-lsp nil
      doom-modeline-buffer-encoding nil
      )

;; smooth(er) scrolling
(setq mouse-wheel-scroll-amount '(1 ((shift) . 1)) ;; one line at a time
      mouse-wheel-progressive-speed t ;; accelerate scrolling
      mouse-wheel-follow-mouse 't) ;; scroll window under mouse

;; Enable mouse support in terminal
(unless window-system
  (require 'mouse)
  (xterm-mouse-mode t)
  (defun track-mouse (e))
  (setq mouse-sel-mode t)
  (global-set-key (kbd "<mouse-5>") 'scroll-up-line)
  (global-set-key (kbd "<mouse-4>") 'scroll-down-line)
  )

(after! magit
  (setq magit-repository-directories '(("~/projects" . 2))))

(after! writeroom-mode
  (setq
   ;; Use the same font size for Zen mode
   +zen-text-scale 0
   ;; Increase default line width for Zen mode
   writeroom-width 120))

(after! flycheck-mode
  (setq flycheck-checker-error-threshold 1000
        ;; Check files only on save and mode enable
        flycheck-check-syntax-automatically '(save mode-enabled)))

(after! lsp-mode
  (setq lsp-idle-delay 1.0
        lsp-lens-enable nil
        lsp-enable-symbol-highlighting nil))

(after! lsp-ui
  (setq lsp-ui-sideline-enable nil)
  (setq lsp-ui-doc-position 'top)
  )

;; Increase delay to reduce fp popups
(after! which-key
  (setq which-key-idle-delay 2.0))

;; Do not hide non-active #ifdefs
(after! ccls
  (setq ccls-enable-skipped-ranges nil))

;; POPUP RULES
(after! rustic
  (setq rustic-lsp-server 'rust-analyzer)
  (set-popup-rule! "^\\*rustic-compilation" :height 0.4))

;; Try to get rid of screen flickering
(add-to-list 'default-frame-alist '(inhibit-double-buffering . t))

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org")

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

(use-package! rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package! company-prescient
  :hook (prog-mode . company-prescient-mode))

;; Replace stupid FALSE comparisons with human-readable ones
;; fuck you Fabian
(add-to-list 'font-lock-extra-managed-props 'display)
(add-hook
 'c-mode-hook
 (lambda ()
   (font-lock-add-keywords nil
                           '(
                             ("\\(FALSE !=\\)" 1 '(face nil display "TRUE =="))
                             ("\\(FALSE!=\\)" 1 '(face nil display "TRUE =="))
                             ("\\(!=FALSE\\)" 1 '(face nil display "== TRUE"))
                             ("\\(!= FALSE\\)" 1 '(face nil display "== TRUE"))
                             )
                           )
   )
 )
