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

;;; FIX: Emacs 31.1 + non-English gettext fallback breaks all process-death
;;; handling. process.c `status_message' takes the localized strsignal()
;;; text, decodes it to multibyte and `aset's a downcased first letter into
;;; it; 31.1's `aset' (data.c:2668) now refuses non-ASCII into a multibyte
;;; string. LANG is en_US.UTF-8 but LANGUAGE=en_US:en_GB:ru, and glibc ships
;;; no en_US/en_GB catalog, so strsignal(9) = "Убито", strsignal(13) =
;;; "Обрыв канала". Every C path that formats a dead process's status then
;;; signals "Attempt to store non-ASCII char into multibyte string":
;;; - `process-send-string' to a dead process (send_process, process.c:6728)
;;;   -- seen as "LSP :: Sending to process failed ..." after rust-analyzer
;;;   was SIGKILLed;
;;; - `delete-process' on a killed subprocess (diff-hl, consult-ripgrep);
;;; - status_notify (process.c:7916), so sentinels never run and lsp-mode
;;;   never learns its server died.
;;; glibc ignores LANGUAGE when the LC_MESSAGES category is "C", and Emacs
;;; applies this variable via setlocale(LC_MESSAGES) before strsignal().
;;; Verified in `emacs -Q --batch' with LANGUAGE=en_US:en_GB:ru: SIGKILLed
;;; `sleep' -> sentinel never called + aset error from process-send-string;
;;; with this setq -> sentinel gets "killed", send errors normally; the
;;; delete-process-mid-output race fails 3/3 without it, 0/5 with it. This
;;; replaces an earlier `delete-process' advice that only swallowed one of
;;; the symptoms.
(setq system-messages-locale "C")

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
        lsp-idle-delay 0.75)

  ;;; Indent with tree-sitter, not with clangd.
  ;;; With this on, lsp-mode does
  ;;;   (add-function :override (local 'indent-region-function) #'lsp-format-region)
  ;;; (lsp-mode.el:4353), replacing `treesit-indent-region' with a *synchronous*
  ;;; textDocument/rangeFormatting round-trip. Measured against the running
  ;;; clangd on a 40-line region: 2ms, 28ms and 48ms in three live buffers --
  ;;; and here that round-trip goes through `.clangd.sh' into a docker
  ;;; container, so it is a process hop, not an in-Emacs call. Everything
  ;;; routed through `indent-region' pays it: evil's `=' operator, `==', `=ap',
  ;;; reindent-on-paste, `indent-region' itself.
  ;;; Turning it off also removes a contradiction: `c-ts-mode-indent-offset' 4
  ;;; and `c-ts-mode-indent-style' 'bsd are set below to match the projects'
  ;;; .clang-format, and clangd-side formatting was overriding them.
  ;;; `SPC c f' (`+format/region-or-buffer') still formats via apheleia and
  ;;; clang-format, which is where whole-file formatting belongs.
  (setq lsp-enable-indentation nil))

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

;;; Double-buffering stays ON.
;;; `inhibit-double-buffering' was set here to stop screen flickering, which is
;;; backwards: PROBLEMS documents it as the workaround for scroll artifacts on
;;; *X-based* systems and warns it "will cause flickering of the display in
;;; some situations". This frame is pgtk on GdkWaylandDisplay, so the problem
;;; it addresses cannot occur here, and it costs measurable redisplay time --
;;; timing 120 scroll+redisplay cycles in a live frame gave 1.83ms per
;;; redisplay with it set against 1.24ms without.

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

;;; Stop evil-goggles blocking the UI before an operation.
;;; `:ui ophints' is evil-goggles, and its *blocking* hints work by drawing the
;;; highlight, calling (sit-for DUR), and only then running the command --
;;; `evil-goggles--show-blocking-hint', evil-goggles.el:232, with DUR from
;;; (or evil-goggles-blocking-duration evil-goggles-duration) = 0.1.
;;; So every delete/change waits 100ms before the edit happens; measured
;;; directly, that call takes 100.4ms. Nothing in nvim does this, which is
;;; exactly where the "editing feels sluggish next to nvim" gap comes from.
;;; Note a keyboard-macro benchmark cannot see this: `sit-for' returns
;;; immediately while `executing-kbd-macro' is non-nil, so the cost only
;;; appears in real interactive use (and `sit-for' does cut it short if you
;;; type through it).
;;; 0 keeps the hint -- it is drawn, then redisplayed without the wait -- and
;;; leaves the async hints (yank, paste) alone, since those never blocked.
(after! evil-goggles
  (setq evil-goggles-blocking-duration 0))

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
      ;; `lsp-clients--clangd-library-folders-fn' does not exist in lsp-mode --
      ;; the .dir-locals.el this client was lifted from named a function that
      ;; was never defined, so `lsp--try-open-in-library-workspace' hit
      ;; "void-function" whenever a file outside the project root was visited
      ;; (a system header jumped to from a definition, typically), leaving the
      ;; buffer with no xref backend. This is the form clangd's own client uses
      ;; (lsp-clangd.el:256): treat `lsp-clients-clangd-library-directories'
      ;; (default '("/usr")) as library rather than project files, so opening a
      ;; header under it reuses the running workspace instead of starting one.
      :library-folders-fn (lambda (_workspace) lsp-clients-clangd-library-directories))))

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

;;; Profile-driven fixes for C++ editing latency.
;;; A 6878-sample CPU profile (1ms sampling) taken while editing C++ put 30.6%
;;; of the time in `redisplay_internal' itself -- C drawing, no elisp under it --
;;; and the rest in a handful of things that run on every command. These two are
;;; the ones with no behavioural downside; see below for the ones that trade
;;; something off.

;;; doom-modeline re-walks the filesystem on every modeline render.
;;; `doom-modeline--in-git-worktree-p' (doom-modeline-segments.el:689) calls
;;; `locate-dominating-file' + `file-regular-p' with no caching, and the vcs
;;; segment calls it at :771 on every render, i.e. every command. It accounted
;;; for 95 of the profile's 97 `locate-dominating-file' samples (1.4% of total).
;;; Note doom-modeline's own `doom-modeline--vcs' cache does not cover this call.
;;; Whether a file sits in a git worktree cannot change for the life of the
;;; buffer short of the file moving, so cache it per buffer.
(after! doom-modeline
  (defvar-local +doom-modeline--worktree-cache 'unset)
  (defadvice! +doom-modeline/cache-worktree-check-a (orig-fn)
    :around #'doom-modeline--in-git-worktree-p
    (if (eq +doom-modeline--worktree-cache 'unset)
        (setq +doom-modeline--worktree-cache (funcall orig-fn))
      +doom-modeline--worktree-cache))
  ;; Drop the cache if the buffer starts pointing at a different file.
  (add-hook! 'after-set-visited-file-name-hook
    (defun +doom-modeline/reset-worktree-cache-h ()
      (setq +doom-modeline--worktree-cache 'unset))))

;;; Show flycheck errors in the echo area, not in a popup.
;;; `flycheck-display-errors-function' was `flycheck-popup-tip-show-popup',
;;; which builds a popup overlay via `popup-create' every time point lands on a
;;; diagnostic -- 151 samples, 2.2% of the profile, and it forces a redisplay on
;;; top. With clangd diagnostics in C++ that fires constantly while moving
;;; through code. The echo-area function conveys the same text for free;
;;; `SPC c x' (`flycheck-list-errors') still gives the full list.
(after! flycheck
  (setq flycheck-display-errors-function
        #'flycheck-display-error-messages-unless-error-list))
