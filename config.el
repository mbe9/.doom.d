;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; General settings
(setq user-full-name "Pavel Pletnev"
      user-mail-address "pletnev.pg@gmail.com"

      ;; doom-theme 'doom-solarized-light
      doom-theme 'doom-monokai-classic

      display-line-numbers-type nil

      doom-font (font-spec :family "monospace" :size 11.0)

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

(setq auth-sources '("~/.authinfo"))
(after! forge
  (add-to-list 'forge-alist
               '("gitlab.nartis.ru"
                 "gitlab.nartis.ru/api/v4"
                 "gitlab.nartis.ru"
                 forge-gitlab-repository)))

;;; Disable LSP file watchers everywhere.
;;; On large C/C++ trees (module_mms is ~19k sources plus generated out/ dirs)
;;; lsp-mode registers thousands of watches at session start and stalls the UI.
(after! lsp-mode
  (setq lsp-enable-file-watchers nil)
  ;; Safety net for any client that re-enables them.
  (setq lsp-file-watch-threshold 1000)
  (dolist (dir '("[/\\\\]out\\'"
                 "[/\\\\]build\\'"
                 "[/\\\\]libraries\\'"))
    (add-to-list 'lsp-file-watch-ignored-directories dir)))

;;; FIX: Emacs 31.1 regression -- `delete-process' on a subprocess that's
;;; killed while mid-write of multi-byte UTF-8 output throws "Attempt to
;;; store non-ASCII char into multibyte string" from inside Emacs's own C
;;; process-cleanup code, with zero package code involved (reproduced with a
;;; bare `make-process' + `delete-process', no diff-hl/consult/etc in the
;;; call stack at all). Any package that cancels an in-flight async
;;; subprocess -- diff-hl-flydiff-mode re-diffing on every edit,
;;; consult-ripgrep restarting the search on every keystroke, presumably
;;; more -- hits this whenever the killed process's output happens to
;;; contain non-ASCII text, which shows up as a bare "Error running timer"
;;; with no useful context. Since the OS-level process is already dead by
;;; the time this throws, the failed "flush trailing output" is safe to
;;; discard; only its exception needs stopping. Confirmed with a 40-run
;;; race (kill timed at 1-15ms into a `rg` search over multi-byte content):
;;; 38/40 failures before this advice, 0/40 after, for both diff-hl (with
;;; Doom's default async settings, unmodified) and raw ripgrep processes.
(defadvice! +fix-emacs31-nonascii-delete-process-a (orig-fn proc &rest args)
  :around #'delete-process
  (condition-case err
      (apply orig-fn proc args)
    (error
     (if (equal (error-message-string err)
                "Attempt to store non-ASCII char into multibyte string")
         nil
       (signal (car err) (cdr err))))))

(after! writeroom-mode
  (setq
   ;; Use the same font size for Zen mode
   +zen-text-scale 0
   ;; Increase default line width for Zen mode
   writeroom-width 120))

(after! flycheck
  (setq flycheck-checker-error-threshold 1000
        ;; Check files only on save and mode enable
        flycheck-check-syntax-automatically '(save mode-enabled)))

(after! lsp-mode
  (add-to-list 'lsp-disabled-clients 'ccls-tramp)
  ;; Each of these issues an LSP request on cursor movement or on idle, which
  ;; is the bulk of lsp-mode's latency relative to nvim. nvim's LazyVim setup
  ;; has no codelens and no code-action polling at all.
  (setq lsp-enable-symbol-highlighting nil    ; documentHighlight per move
        lsp-lens-enable nil                   ; codeLens requests + refresh
        lsp-modeline-code-actions-enable nil  ; codeAction at point, per move
        lsp-eldoc-enable-hover nil            ; hover via eldoc, per move
        lsp-idle-delay 0.75))

  ;; (setq lsp-idle-delay 1.0
  ;;       lsp-lens-enable 't
  ;;       lsp-enable-symbol-highlighting 't))

(custom-set-variables
 '(hcl-indent-level 4))

(after! lsp-ui
  (setq lsp-ui-sideline-enable nil)
  (setq lsp-ui-sideline-show-hover 't)
  (setq lsp-ui-doc-enable 't)
  ;; Off: fires textDocument/hover + a child-frame render on every point
  ;; move, which is the main source of lsp-mode input latency.
  (setq lsp-ui-doc-show-with-cursor nil)
  (setq lsp-ui-doc-show-with-mouse 't)
  (setq lsp-ui-doc-position 'top)
  (setq lsp-ui-doc-delay 0.5)
  (setq lsp-ui-doc-max-width 50)
  (setq lsp-ui-doc-max-height 10)
  )

(after! projectile
  (setq projectile-indexing-method 'native)
  ;; Auto-register every repo under ~/projects. Depth 1 means "check each
  ;; subdirectory of ~/projects", which picks up the 73 top-level repos and
  ;; deliberately stops short of the ~135 git submodules nested inside them.
  ;; `projectile-discover-projects-in-search-path' runs automatically when
  ;; projectile-mode is enabled, so no manual discovery step is needed.
  (setq projectile-project-search-path '(("~/projects" . 1))))
;; Increase delay to reduce fp popups
(after! which-key
  (setq which-key-idle-delay 2.0))

;; Do not hide non-active #ifdefs
(after! ccls
  (setq ccls-enable-skipped-ranges nil))

;;; C/C++ indentation under tree-sitter.
;;; c++-ts-mode ignores `c-basic-offset' (which Doom sets from `tab-width');
;;; it uses these two instead, defaulting to 2 and the GNU style. 'bsd matches
;;; the project's .clang-format (BraceWrapping: AfterFunction/AfterClass/
;;; AfterControlStatement all true, IndentBraces false = Allman).
(after! c-ts-mode
  (setq c-ts-mode-indent-offset 4
        c-ts-mode-indent-style 'bsd))

;;; Run clang-format on save in C/C++ buffers only.
;;; apheleia (from :editor format) invokes the clang-format binary directly
;;; with -assume-filename, so the nearest .clang-format is picked up.
(add-hook! '(c-mode-hook c++-mode-hook c-ts-mode-hook c++-ts-mode-hook objc-mode-hook)
           #'apheleia-mode)

;; POPUP RULES
(after! rustic
  (setq rustic-lsp-server 'rust-analyzer)
  (set-popup-rule! "^\\*rustic-compilation" :height 0.4))

;;; GitLab CI: validate against the real instance.
;;; yaml-language-server checks the static SchemaStore schema, which tracks
;;; gitlab.com. `glab ci lint' asks the actual server (e.g. gitlab.nartis.ru),
;;; so it resolves `include:' and reflects that instance's GitLab version.
(defun +gitlab/ci-lint (&optional dry-run)
  "Lint the current buffer's GitLab CI file with `glab ci lint'.
With prefix arg DRY-RUN, also simulate pipeline creation."
  (interactive "P")
  (unless (executable-find "glab")
    (user-error "glab not found in PATH"))
  (let ((file (or buffer-file-name
                  (user-error "Buffer is not visiting a file")))
        (default-directory (or (doom-project-root) default-directory)))
    (compile (format "glab ci lint %s%s"
                     (shell-quote-argument file)
                     (if dry-run " --dry-run --include-jobs" "")))))

(after! yaml-mode
  (map! :localleader
        :map yaml-mode-map
        :desc "GitLab CI lint" "l" #'+gitlab/ci-lint))

(after! yaml-ts-mode
  (map! :localleader
        :map yaml-ts-mode-map
        :desc "GitLab CI lint" "l" #'+gitlab/ci-lint))

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

;;; Restore full chroma to the tree-sitter font-lock faces.
;;; doom-themes-base.el defines these as `doom-blend'-ed toward `fg', e.g.
;;; punctuation keeps only ~26% of its CIELAB chroma (#F92660 -> #F8C3CD).
;;; Under c++-ts-mode these faces cover ~9k chars that cc-mode left plain, so
;;; the blending is what makes tree-sitter buffers look washed out.
;;; `doom-color' is resolved on each theme load, so this survives a theme swap.
;;; Not touched: `font-lock-variable-use-face' (variables = fg here, so the
;;; blend is a no-op) and `font-lock-operator-face' (no blend to begin with).
(custom-set-faces!
  ;; was (doom-blend 'functions 'fg 0.7) + :slant italic
  `(font-lock-function-call-face :foreground ,(doom-color 'functions) :slant normal)
  ;; was (doom-blend 'keywords 'fg 0.6); -use-face inherits this
  `(font-lock-property-name-face :foreground ,(doom-color 'keywords) :weight bold)
  ;; was (doom-blend 'operators 'fg 0.25); delimiter/bracket/misc inherit this
  `(font-lock-punctuation-face   :foreground ,(doom-color 'operators)))

;;; vim-vinegar style: `-' opens dired in the current file's directory,
;;; i.e. the same command `SPC o -' runs (+evil-bindings.el:696).
;;; Evil's default `-' (`evil-previous-line-first-non-blank') lives in
;;; `evil-motion-state-map', which normal state inherits, so this normal-state
;;; binding takes precedence over it. Dired itself is unaffected:
;;; evil-collection already binds `-' there to `dired-up-directory', and a
;;; mode map wins over a global one.
(map! :n "-" #'dired-jump)
