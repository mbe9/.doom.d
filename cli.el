;;; cli.el -*- lexical-binding: t; -*-

;; `doom env' snapshots the shell it was run from into `doom-env-file', and
;; Emacs then hands those variables to every subprocess it starts -- including
;; git and git-lfs under magit. Proxy settings belong to the shell that set
;; them, not to a file that outlives it, so keep them out of the snapshot.
;;
;; Covers HTTP(S)_PROXY, ALL_PROXY, NO_PROXY and their lowercase spellings.
;; lisp/cli/env.el is autoloaded, so it is not loaded yet when this file runs.
(with-eval-after-load 'doom-cli-env
  (add-to-list 'doom-env-deny "_[Pp][Rr][Oo][Xx][Yy]$"))
