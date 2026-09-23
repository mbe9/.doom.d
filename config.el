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
  ;; Off for the same reason, plus a worse one: `lsp-ui-doc--make-request'
  ;; runs on `post-command-hook' and unconditionally does
  ;; (setq-local track-mouse t) whenever this is non-nil -- ahead of all its
  ;; other guards, so turning off the cursor path above does not stop it.
  ;; With `track-mouse' set, every pixel of pointer motion over the frame
  ;; becomes a command-loop iteration, and `post-command-hook' in an LSP
  ;; buffer here is 14 functions long (5 from flycheck, plus lsp--post-command,
  ;; company, smartparens, yasnippet, hl-line, and gcmh cancelling and
  ;; rescheduling its timer). Moving the mouse across a window runs thousands
  ;; of those. `K' (`+lookup/documentation') and `lsp-ui-doc-glance' still
  ;; give documentation on demand.
  (setq lsp-ui-doc-show-with-mouse nil)
  (setq lsp-ui-doc-position 'top)
  (setq lsp-ui-doc-delay 0.5)
  (setq lsp-ui-doc-max-width 50)
  (setq lsp-ui-doc-max-height 10)
  )

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

;;; clangd wrapper: resolve `.clangd.sh' per workspace, not once per session.
;;; Each C/C++ project's `.dir-locals.el' registers the `clangd-wrapper' client
;;; itself, but does so inside (unless (gethash 'clangd-wrapper lsp-clients) ...)
;;; with the command closed over a `wrapper-path' computed from
;;; `projectile-project-root' at *registration* time. Dir-locals eval forms run
;;; under lexical binding -- files.el's `hack-one-local-variable' does
;;; (eval val t) -- so that closure captures whichever project was opened first
;;; and keeps it for the rest of the session. Every later project then launches
;;; the first project's script; and when `projectile-project-root' returns nil
;;; at registration, (concat nil ".clangd.sh") captures the *relative* string
;;; ".clangd.sh", which `make-process' resolves against whatever
;;; `default-directory' the connecting timer happens to hold. That is the
;;; (file-missing "Doing vfork" "No such file or directory") that nothing but an
;;; Emacs restart clears -- the restart is simply what empties `lsp-clients'.
;;; Registering here at startup makes the dir-locals `unless' guard find the
;;; client already present and skip its own registration, so the project
;;; .dir-locals.el files need no edit; the `lsp-enabled-clients' setq-local at
;;; the end of those forms sits outside the guard and still applies.
(after! lsp-clangd
  (defun +clangd/wrapper-path ()
    "Absolute path to the current workspace's `.clangd.sh', or nil."
    (when-let* ((root (or (lsp-workspace-root)
                          (doom-project-root)
                          default-directory)))
      (expand-file-name ".clangd.sh" root)))

  (defun +clangd/wrapper-available-p ()
    "Whether this workspace actually has a runnable `.clangd.sh'."
    (when-let* ((path (+clangd/wrapper-path)))
      (file-executable-p path)))

  ;; The dir-locals version passed (lambda () t) as `lsp-stdio-connection's
  ;; TEST-COMMAND to "bypass existence check", which is why a bad path failed
  ;; at vfork instead of lsp-mode reporting the server as unavailable and
  ;; falling back to plain clangd. Check for real.
  (dolist (remote? '(nil t))
    (lsp-register-client
     (make-lsp-client
      :new-connection (lsp-stdio-connection
                       (if remote?
                           (lambda () (list (file-local-name (+clangd/wrapper-path))))
                         (lambda () (list (+clangd/wrapper-path))))
                       #'+clangd/wrapper-available-p)
      :activation-fn (lsp-activate-on "c" "cpp" "objective-c")
      :priority 10
      :remote? remote?
      :server-id (if remote? 'clangd-wrapper-remote 'clangd-wrapper)
      :library-folders-fn #'lsp-clients--clangd-library-folders-fn)))

  ;;; Shut the wrapper down gracefully, or its container outlives it.
  ;;; `lsp-process-kill' is just (kill-process process), i.e. SIGKILL, which
  ;;; cannot be caught -- so `spin' never reaches the cleanup that stops its
  ;;; container, and since the container is owned by dockerd rather than by
  ;;; spin, it keeps running with clangd inside it. Restarting a workspace
  ;;; therefore leaks one container per restart. Neovim does not hit this
  ;;; because it closes the server's stdin and sends SIGTERM, letting the
  ;;; wrapper exit on its own terms; the script is identical, the client's
  ;;; shutdown is not.
  ;;; Note `spin' has no `down'/`stop' subcommand -- the process's own exit
  ;;; path is the only thing that removes the container, so it has to be
  ;;; allowed to run.
  (defvar +clangd/wrapper-shutdown-grace 10
    "Seconds to let `.clangd.sh' stop its container before resorting to SIGKILL.")

  (defun +clangd/wrapper-process-p (process)
    (and (processp process)
         (string-prefix-p "clangd-wrapper" (process-name process))))

  (defun +clangd/terminate-wrapper (process)
    "Ask PROCESS to shut down, escalating to SIGKILL only if it will not.
Signals the negated pid: Emacs puts each subprocess in its own process
group (verified pid == pgid), so this reaches the docker client too."
    (let ((pid (process-id process)))
      ;; EOF on stdin is what the profile's `attach_stdin' unit watches for,
      ;; and what nvim relies on.
      (ignore-errors (process-send-eof process))
      (when pid (ignore-errors (signal-process (- pid) 'TERM)))
      ;; Escalate on a timer rather than blocking: `lsp--restart-if-needed'
      ;; runs from the process sentinel, so a slower exit just defers the
      ;; restart instead of racing the outgoing container.
      (run-at-time
       +clangd/wrapper-shutdown-grace nil
       (lambda ()
         (when (process-live-p process)
           (when pid (ignore-errors (signal-process (- pid) 'KILL)))
           (ignore-errors (kill-process process)))))))

  (defadvice! +clangd/graceful-process-kill-a (orig-fn process)
    "Give the clangd wrapper a chance to stop its container."
    :around #'lsp-process-kill
    (if (and (+clangd/wrapper-process-p process) (process-live-p process))
        (+clangd/terminate-wrapper process)
      (funcall orig-fn process)))

  ;; Emacs exiting kills subprocesses outright, so the same SIGTERM needs a
  ;; bounded wait here -- without it the signal is sent and the container is
  ;; orphaned anyway.
  (defun +clangd/stop-wrappers-on-exit ()
    (let ((procs (seq-filter (lambda (p)
                               (and (+clangd/wrapper-process-p p)
                                    (process-live-p p)))
                             (process-list))))
      (when procs
        (dolist (p procs)
          (ignore-errors (process-send-eof p))
          (when-let* ((pid (process-id p)))
            (ignore-errors (signal-process (- pid) 'TERM))))
        ;; Cap the delay on quitting Emacs; containers usually stop well inside
        ;; this, and anything slower is not worth blocking the user's exit for.
        (let ((deadline (+ (float-time) 5)))
          (while (and (< (float-time) deadline)
                      (seq-some #'process-live-p procs))
            (sleep-for 0.1))))))
  (add-hook 'kill-emacs-hook #'+clangd/stop-wrappers-on-exit))

;;; Start language servers in their own workspace root.
;;; Default is nil, which hands the server process whatever `default-directory'
;;; the current buffer had when the connection was made -- and lsp-mode connects
;;; from timers (`lsp-deferred'), so that buffer is not reliably the one being
;;; opened. `.clangd.sh' cannot tolerate this: it execs
;;;   spin up clangd cdb --clean --raw --arg-file=.project_settings.json
;;; with a *relative* --arg-file, so it only resolves when the process cwd is
;;; the project root. A wrong cwd also turns into
;;; (file-missing "Setting current directory" ...) if that directory has since
;;; been removed (a docker build wiping out/, a branch switch).
;;; Applies to every client, not just clangd; workspace root is the right cwd
;;; for all of them.
(after! lsp-mode
  (setq lsp-use-workspace-root-for-server-default-directory t))
