;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; General settings
(setq user-full-name "Pavel Pletnev"
      user-mail-address "pletnev.pg@gmail.com"

      ;; doom-theme 'doom-solarized-light
      doom-theme 'doom-monokai-classic

      display-line-numbers-type nil

      doom-font (font-spec :family "monospace" :size 10.0)

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
;;; registering thousands of watches at session start stalls the UI.
;;; Eglot has no `lsp-enable-file-watchers' equivalent: it implements
;;; `workspace/didChangeWatchedFiles' with `file-notify-add-watch', driven by
;;; the server's *dynamic registration*, and clangd does register it.
;;; `eglot-ignored-server-capabilities' does not cover this -- it filters
;;; server capabilities, and this is a client one. So refuse it at the source:
;;; eglot's default `eglot-client-capabilities' advertises
;;; (:didChangeWatchedFiles (:dynamicRegistration t)) for non-TRAMP servers,
;;; and answering :json-false instead is the protocol-correct way to tell the
;;; server not to ask. No registration arrives, so nothing needs intercepting.
(after! eglot
  (defadvice! +eglot/refuse-file-watchers-a (caps)
    :filter-return #'eglot-client-capabilities
    (when-let* ((workspace (plist-get caps :workspace)))
      ;; The key already exists, so `plist-put' mutates this freshly-consed
      ;; plist in place rather than returning a new head.
      (plist-put workspace :didChangeWatchedFiles
                 '(:dynamicRegistration :json-false)))
    caps))

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

;;; Same latency policy as under lsp-mode: nothing that issues an LSP request
;;; on cursor movement. nvim's LazyVim setup has no codelens and no
;;; code-action polling either, which is the bar this is measured against.
;;; Declining a *server* capability is eglot's supported off switch, and it
;;; also stops the corresponding request being sent at all.
(after! eglot
  (setq eglot-ignored-server-capabilities
        '(:documentHighlightProvider   ; documentHighlight per move
          :codeLensProvider            ; codeLens requests + refresh
          :inlayHintProvider))         ; inlay hints re-render on every change

  ;; Hover is the `lsp-eldoc-enable-hover nil' equivalent. Eglot routes hover
  ;; through eldoc, so dropping its eldoc function stops the per-move
  ;; textDocument/hover without declining :hoverProvider outright -- `K'
  ;; (`+lookup/documentation') issues its own request and still works.
  (add-hook! 'eglot-managed-mode-hook
    (defun +eglot/no-hover-on-idle-h ()
      (remove-hook 'eldoc-documentation-functions
                   #'eglot-hover-eldoc-function t)))

  ;; lsp-mode's `lsp-idle-delay' 0.75 analogue: how long after a keystroke the
  ;; buffer's changes are flushed to the server. Eglot's default is 0.5.
  (setq eglot-send-changes-idle-time 0.75))

(custom-set-variables
 '(hcl-indent-level 4))

;;; lsp-ui has no eglot counterpart and is gone with lsp-mode. What it was
;;; providing here was already only the on-demand paths: the sideline and both
;;; automatic doc-frame triggers (cursor and mouse) were off for latency.
;;; `K' (`+lookup/documentation') is wired to `+eglot-lookup-documentation' by
;;; Doom's lsp module and covers the remaining use.
;;; Dropping it also retires the `track-mouse' problem outright rather than
;;; working around it: that was `lsp-ui-doc--make-request' on
;;; `post-command-hook' forcing (setq-local track-mouse t), which turned every
;;; pixel of pointer motion into a full command-loop iteration. Eglot puts
;;; nothing equivalent on `post-command-hook'.

(after! projectile
  ;;; Leave `projectile-indexing-method' at Doom's `hybrid'.
  ;;; It was set to 'native here (7336a34, "Lsp tweaks"), which is a pure-elisp
  ;;; recursive walk that ignores .gitignore entirely -- only projectile's own
  ;;; `projectile-globally-ignored-*' lists apply. On these trees that means the
  ;;; generated out/ dirs get indexed: the cached listing for
  ;;; module_coordinator_access held 21837 entries, 21689 of them under out/,
  ;;; where fd sees 100 real files. `hybrid' runs Doom's fd command (which does
  ;;; read .gitignore) and then applies projectile's ignore lists on top:
  ;;; 1111 files in 23ms for module_mms vs. a 20706-entry walk for 'native.
  ;;; Note `projectile-enable-caching' is 'persistent in Doom, so a bad listing
  ;;; is written to ~/.emacs.d/.local/cache/projectile/ and reused indefinitely;
  ;;; `SPC p i' (`projectile-invalidate-cache') is the only thing that clears it
  ;;; when a project's layout changes.
  ;; Auto-register every repo under ~/projects. Depth 1 means "check each
  ;; subdirectory of ~/projects", which picks up the 73 top-level repos and
  ;; deliberately stops short of the ~135 git submodules nested inside them.
  ;; `projectile-discover-projects-in-search-path' runs automatically when
  ;; projectile-mode is enabled, so no manual discovery step is needed.
  (setq projectile-project-search-path '(("~/projects" . 1))))
;; Increase delay to reduce fp popups
(after! which-key
  (setq which-key-idle-delay 2.0))

;;; `ccls' and `lsp-disabled-clients' were lsp-mode-only and are gone with it.
;;; The #ifdef-dimming they disabled was a ccls feature; clangd (what
;;; `.clangd.sh' actually runs) has no equivalent, so there is nothing to turn
;;; off under eglot.

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

;;; GC pauses landing in the middle of editing.
;;; Doom sets `gcmh-idle-delay' to 'auto with `gcmh-auto-idle-delay-factor' 10
;;; (doom-start.el:90), so the idle delay is recomputed as 10x the duration of
;;; the previous collection. On a session with a grown heap that feedback loop
;;; settles somewhere useless: measured here at 85MB of Lisp heap, a full
;;; `garbage-collect' takes 81-96ms, which schedules the next GC 0.81-0.96s
;;; after the last command. Every pause longer than about a second -- i.e. every
;;; time you stop to read a line before moving on -- is followed by a ~90ms
;;; freeze, and it lands exactly when you resume typing. Note `gcmh-register-
;;; idle-gc' uses `run-with-timer', not `run-with-idle-timer', so this fires on
;;; wall-clock time since the last command, not on genuine idleness.
;;; 15s is gcmh's own default and keeps collections inside real breaks
;;; (switching windows, reading, thinking) rather than inside typing bursts.
;;; `gcmh-high-cons-threshold' stays at Doom's 128MB, so the heap is still
;;; bounded between idle collections.
(setq gcmh-idle-delay 15)

;;; clangd wrapper: one client, path resolved per connection.
;;; Each C/C++ project's `.dir-locals.el' used to register an lsp-mode client
;;; itself, guarded by (unless (gethash 'clangd-wrapper lsp-clients) ...) with
;;; the command closed over a `wrapper-path' computed at *registration* time --
;;; so the first project opened in a session captured the path for every later
;;; one, and a nil `projectile-project-root' captured the bare relative string
;;; ".clangd.sh". Eglot removes that failure mode structurally: a
;;; `eglot-server-programs' CONTACT may be a function, and eglot funcalls it at
;;; *connect* time (eglot.el:1551), so the path is recomputed per connection
;;; and there is no registration-time state to go stale.
;;; Eglot also binds `default-directory' to the project root before spawning
;;; (eglot.el:1542) and refuses to connect if that directory is missing
;;; (:1546), which is what `lsp-use-workspace-root-for-server-default-directory'
;;; had to be turned on for -- `.clangd.sh' passes a *relative*
;;; --arg-file=.project_settings.json and only works with the root as cwd.
(after! eglot
  (defun +clangd/wrapper-path (&optional project)
    "Absolute path to PROJECT's `.clangd.sh' (default: this buffer's project)."
    (when-let* ((root (or (and project (project-root project))
                          (doom-project-root)
                          default-directory)))
      (expand-file-name ".clangd.sh" root)))

  ;; Signature is eglot's: a CONTACT function is called with (INTERACTIVE
  ;; PROJECT), and PROJECT is the project eglot resolved for this connection --
  ;; more direct than asking `project-current' again from whatever buffer
  ;; happens to be current.
  (defun +clangd/contact (&optional _interactive project)
    "Command for eglot to run, chosen per connection.
Falls back to plain clangd in projects that have no wrapper -- the case
lsp-mode's hardcoded (lambda () t) availability check made undetectable."
    (let ((wrapper (+clangd/wrapper-path project)))
      (if (and wrapper (file-executable-p wrapper))
          (list wrapper)
        '("clangd"))))

  (set-eglot-client! '(c-mode c-ts-mode c++-mode c++-ts-mode objc-mode)
                     #'+clangd/contact))


;;; Let the clangd wrapper stop its container before it is killed.
;;; `.clangd.sh' execs `spin', which starts a docker container; the container
;;; is owned by dockerd, so anything that kills spin without letting it run its
;;; cleanup leaks a running container with clangd inside it. Eglot is politer
;;; than lsp-mode here but not politer enough: `eglot-shutdown' sends :shutdown
;;; (1.5s timeout) and :exit, then hands off to `jsonrpc-shutdown', whose loop
;;; grants exactly one `(accept-process-output nil 0.1)' before it warns
;;; "Sentinel ... still hasn't run, deleting it!" and calls `delete-process'
;;; -- i.e. ~100ms, then SIGKILL. Stopping a container does not fit in 100ms.
;;; Note `spin' has no `down'/`stop' subcommand, so the process's own exit path
;;; is the only thing that removes the container.
;;; Matching is on the command rather than the process name: eglot names its
;;; processes "EGLOT (project/mode)", so the name says nothing about clangd.
(after! eglot
  (defvar +clangd/wrapper-shutdown-grace 10
    "Seconds to wait, at most, for `.clangd.sh' to stop its container.
A cap rather than a fixed delay -- the wait ends as soon as the process exits.")

  (defun +clangd/wrapper-process-p (process)
    (and (processp process)
         (seq-some (lambda (arg) (string-suffix-p ".clangd.sh" arg))
                   (process-command process))))

  (defun +clangd/stop-wrapper (process)
    "Ask PROCESS to exit, and wait for it so the sentinel runs.
Signals the negated pid: Emacs puts every subprocess in its own process group
\(verified pid == pgid), so this reaches the docker client too. Returning only
once the process is gone is the point -- `jsonrpc-shutdown' then finds the
sentinel already run and skips its `delete-process'."
    (let ((pid (process-id process))
          (deadline (+ (float-time) +clangd/wrapper-shutdown-grace)))
      ;; EOF on stdin is what the profile's `attach_stdin' unit watches for.
      (ignore-errors (process-send-eof process))
      (when pid (ignore-errors (signal-process (- pid) 'TERM)))
      (while (and (process-live-p process) (< (float-time) deadline))
        (accept-process-output process 0.05))))

  (defadvice! +clangd/graceful-jsonrpc-shutdown-a (orig-fn conn &rest args)
    "Give the clangd wrapper a chance to stop its container."
    :around #'jsonrpc-shutdown
    (when-let* ((proc (ignore-errors (jsonrpc--process conn))))
      (when (and (+clangd/wrapper-process-p proc) (process-live-p proc))
        (+clangd/stop-wrapper proc)))
    (apply orig-fn conn args))

  ;; Emacs exiting kills subprocesses outright, so the same signal needs a
  ;; bounded wait here or the container is orphaned on quit.
  (defun +clangd/stop-wrappers-on-exit ()
    (dolist (p (seq-filter (lambda (p)
                             (and (+clangd/wrapper-process-p p)
                                  (process-live-p p)))
                           (process-list)))
      (let ((+clangd/wrapper-shutdown-grace 5))
        (+clangd/stop-wrapper p))))
  (add-hook 'kill-emacs-hook #'+clangd/stop-wrappers-on-exit))
