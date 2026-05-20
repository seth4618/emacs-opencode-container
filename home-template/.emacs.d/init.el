;;; Common home entrypoint for emacs-opencode-container.

;; Keep Emacs Customize output out of repo-managed init files.
(setq custom-file (expand-file-name "init.local.el" user-emacs-directory))

(defvar common-repo-emacs-init
  (expand-file-name "repo-emacs.d/init.el" user-emacs-directory)
  "Symlink path to repository-managed init.el.")

(when (file-exists-p common-repo-emacs-init)
  (load-file common-repo-emacs-init))

(let* ((init-file-dir (file-name-directory (file-truename (or load-file-name user-init-file))))
       (repo-root (expand-file-name ".." (directory-file-name init-file-dir)))
       (env-candidates (list (expand-file-name ".devcontainer/.env" repo-root)
                             (expand-file-name ".devcontainer/.env" default-directory)
                             (expand-file-name ".devcontainer/.env" (getenv "HOME"))))
       (compose-project-name (or (getenv "COMPOSE_PROJECT_NAME")
                                 (catch 'found
                                   (dolist (env-file env-candidates)
                                     (when (file-readable-p env-file)
                                       (with-temp-buffer
                                         (insert-file-contents env-file)
                                         (goto-char (point-min))
                                         (when (re-search-forward "^COMPOSE_PROJECT_NAME=\(.+\)$" nil t)
                                           (throw 'found (match-string 1))))))
                                   nil)
                                 "unknown")))
  (setq frame-title-format (format "Container: %s" compose-project-name)))

(when (file-exists-p custom-file)
  (load-file custom-file))
