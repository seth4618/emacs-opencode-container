;;; Common home entrypoint for emacs-opencode-container.

(defvar common-repo-emacs-init
  (expand-file-name "../repo-emacs.d/init.el" user-emacs-directory)
  "Symlink path to repository-managed init.el.")

(when (file-exists-p common-repo-emacs-init)
  (load-file common-repo-emacs-init))

(let ((local-init (expand-file-name "init.local.el" user-emacs-directory)))
  (when (file-exists-p local-init)
    (load-file local-init)))
