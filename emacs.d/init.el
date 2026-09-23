;; Minimal, inspectable Emacs config for containerized OpenCode development.
(require 'package)
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(defvar eoc-package-archives-refreshed-after-error nil
  "Non-nil after retrying an install with refreshed package metadata.")

(defun eoc-package-install (pkg)
  "Install PKG, refreshing stale archive metadata once if installation fails."
  (unless (package-installed-p pkg)
    (condition-case install-error
        (package-install pkg)
      (error
       (if eoc-package-archives-refreshed-after-error
           (signal (car install-error) (cdr install-error))
         (setq eoc-package-archives-refreshed-after-error t)
         (message "Package install failed for %s; refreshing archives and retrying" pkg)
         (package-refresh-contents)
         (package-install pkg))))))

(dolist (pkg '(use-package lsp-mode lsp-pyright magit gptel typescript-mode json-mode solidity-mode company yasnippet markdown-mode plz plz-media-type plz-event-source transient websocket vterm))
  (eoc-package-install pkg))

(eval-when-compile
  (require 'use-package))
(setq use-package-always-ensure t)


;; Reduce warning noise from third-party packages we do not maintain in this repo.
;; Keep startup diagnostics useful while avoiding repeated native-comp/docstring churn.
(setq warning-suppress-types
      '((comp)
        (lsp-mode)))
(when (boundp 'native-comp-async-report-warnings-errors)
  (setq native-comp-async-report-warnings-errors 'silent))


;; Clean up stale lsp-mode npm cache from old pyright installer attempts.
(let ((stale-pyright-dir (expand-file-name ".cache/lsp/npm/pyright-langserver" user-emacs-directory)))
  (when (file-directory-p stale-pyright-dir)
    (delete-directory stale-pyright-dir t)))

(use-package python
  :mode ("\\.py\\'" . python-mode)
  :hook (python-mode . (lambda ()
                         ;; lsp-mode registers its own Flymake backend.
                         ;; Clear built-in python backends that emit checker/init warnings.
                         (setq-local flymake-diagnostic-functions nil)
                         (require 'lsp-pyright)
                         (lsp-deferred))))

(use-package typescript-mode
  :mode (("\\.ts\\'" . typescript-mode)
         ("\\.tsx\\'" . typescript-mode))
  :hook (typescript-mode . lsp-deferred)
  :custom (typescript-indent-level 2))

(use-package js
  :mode ("\\.json\\'" . js-json-mode)
  :hook (js-json-mode . lsp-deferred))

(use-package solidity-mode
  :mode "\\.sol\\'"
  :hook (solidity-mode . lsp-deferred))


(use-package lsp-pyright
  :after lsp-mode)

(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :custom
  ;; Avoid repeated "no automatic installation" prompts for optional Python servers.
  (lsp-disabled-clients '(semgrep-ls ruff ruff-ls ty-ls pylsp pyls))
  (lsp-keymap-prefix "C-c l")
  (lsp-enable-snippet nil)
  (lsp-headerline-breadcrumb-enable nil)
  :config
  (add-to-list 'lsp-language-id-configuration '("\\.tsx\\'" . "typescriptreact")))


(use-package company
  :init
  (global-company-mode 1))

(use-package yasnippet
  :init
  (yas-global-mode 1))

(use-package magit :commands magit-status)
(use-package gptel :commands gptel)

;; claude-code-ide.el provides a native Emacs interface to the Claude Code CLI,
;; including project-aware terminals, diffs, file context, and its command menu.
(let* ((container-claude-code-ide-dir "/opt/elisp-helpers/claude-code-ide.el")
       (repo-claude-code-ide-dir
        (expand-file-name ".devcontainer/elisp-helpers/claude-code-ide.el"
                          (file-name-directory (directory-file-name default-directory))))
       (claude-code-ide-dir
        (cond
         ((file-directory-p container-claude-code-ide-dir)
          container-claude-code-ide-dir)
         ((file-directory-p repo-claude-code-ide-dir)
          repo-claude-code-ide-dir)
         (t nil))))
  (when claude-code-ide-dir
    (add-to-list 'load-path claude-code-ide-dir)
    (require 'claude-code-ide)
    (claude-code-ide-emacs-tools-setup)
    (global-set-key (kbd "C-c C-'") #'claude-code-ide-menu)))

;; Load opencode.el following README.org Manual installation pattern:
;;   (add-to-list 'load-path "/path/to/opencode.el")
;;   (require 'opencode)
(let* ((container-opencode-dir "/opt/elisp-helpers/opencode.el")
       (repo-opencode-dir (expand-file-name ".devcontainer/elisp-helpers/opencode.el"
                                            (file-name-directory (directory-file-name default-directory))))
       (opencode-dir (cond
                      ((file-directory-p container-opencode-dir) container-opencode-dir)
                      ((file-directory-p repo-opencode-dir) repo-opencode-dir)
                      (t nil))))
  (when opencode-dir
    (add-to-list 'load-path opencode-dir)
    (require 'opencode)))

;; Bootstraps local overrides without editing this file.
(let ((local-init-dir (expand-file-name "local-init.d" user-emacs-directory)))
  (when (file-directory-p local-init-dir)
    (dolist (f (directory-files local-init-dir t "\\.el\\'"))
      (load f nil 'nomessage))))
