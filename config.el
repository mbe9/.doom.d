;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; General settings
(setq user-full-name "Pavel Pletnev"
      user-mail-address "pletnev.pg@gmail.com"

      ;; doom-theme 'doom-solarized-light
      doom-theme 'doom-monokai-classic

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


(after! tramp
  (setq tramp-use-connection-share nil)
  (setq tramp-verbose 1)
  )

;;; Disable LSP on remote files
(after! lsp-mode
  ;; Only disable for remote files
  (add-hook 'find-file-hook
            (lambda ()
              (when (file-remote-p default-directory)
                (setq-local lsp-enable-file-watchers nil)))))

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
  (add-to-list 'lsp-disabled-clients 'ccls-tramp))

  ;; (setq lsp-idle-delay 1.0
  ;;       lsp-lens-enable 't
  ;;       lsp-enable-symbol-highlighting 't))

(custom-set-variables
 '(hcl-indent-level 4))

(after! lsp-ui
  (setq lsp-ui-sideline-enable nil)
  (setq lsp-ui-sideline-show-hover 't)
  (setq lsp-ui-doc-enable 't)
  (setq lsp-ui-doc-show-with-cursor 't)
  (setq lsp-ui-doc-show-with-mouse 't)
  (setq lsp-ui-doc-position 'top)
  (setq lsp-ui-doc-delay 0.5)
  (setq lsp-ui-doc-max-width 150)
  (setq lsp-ui-doc-max-height 60)
  )

(after! projectile-mode
  (setq projectile-indexing-method 'native)
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
