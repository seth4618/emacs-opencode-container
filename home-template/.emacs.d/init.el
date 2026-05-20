;;; Common home entrypoint for emacs-opencode-container.

;; Keep Emacs Customize output out of repo-managed init files.
(setq custom-file (expand-file-name "init.local.el" user-emacs-directory))

(defvar common-repo-emacs-init
  (expand-file-name "repo-emacs.d/init.el" user-emacs-directory)
  "Symlink path to repository-managed init.el.")

(when (file-exists-p common-repo-emacs-init)
  (load-file common-repo-emacs-init))

(let ((compose-project-name (or (getenv "COMPOSE_PROJECT_NAME") "unknown")))
  (setq frame-title-format (format "Container: %s" compose-project-name)))

(when (file-exists-p custom-file)
  (load-file custom-file))
