;; Minimal, inspectable Emacs config for containerized OpenCode development.
(require 'package)
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(dolist (pkg '(use-package lsp-mode lsp-pyright magit gptel typescript-mode json-mode solidity-mode company yasnippet markdown-mode plz plz-media-type plz-event-source))
  (unless (package-installed-p pkg)
    (package-install pkg)))

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


;; Load opencode.el following README.org Manual installation pattern:
;;   (add-to-list 'load-path "/path/to/opencode.el")
;;   (require 'opencode)
(let* ((container-opencode-dir "/opt/elisp-helpers/opencode.el")
       (repo-opencode-dir (expand-file-name "elisp-helpers/opencode.el"
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
