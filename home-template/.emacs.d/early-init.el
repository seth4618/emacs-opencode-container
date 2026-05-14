;;; Common home early init entrypoint for emacs-opencode-container.

(defvar common-repo-emacs-early-init
  (expand-file-name "../repo-emacs.d/early-init.el" user-emacs-directory)
  "Symlink path to repository-managed early-init.el.")

(when (file-exists-p common-repo-emacs-early-init)
  (load-file common-repo-emacs-early-init))

(let ((local-early-init (expand-file-name "early-init.local.el" user-emacs-directory)))
  (when (file-exists-p local-early-init)
    (load-file local-early-init)))
