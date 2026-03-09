;; Minimal, inspectable Emacs config for containerized OpenCode development.
(require 'package)
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(dolist (pkg '(use-package lsp-mode lsp-pyright magit gptel typescript-mode json-mode solidity-mode))
  (unless (package-installed-p pkg)
    (package-install pkg)))

(eval-when-compile
  (require 'use-package))
(setq use-package-always-ensure t)

(use-package python
  :mode ("\\.py\\'" . python-mode)
  :hook (python-mode . lsp-deferred))

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
  :after lsp-mode
  :custom (lsp-pyright-langserver-command "pyright-langserver"))

(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :custom
  (lsp-keymap-prefix "C-c l")
  (lsp-enable-snippet t)
  (lsp-headerline-breadcrumb-enable nil)
  :config
  (add-to-list 'lsp-language-id-configuration '("\\.tsx\\'" . "typescriptreact")))

(use-package magit :commands magit-status)
(use-package gptel :commands gptel)

;; Bootstraps local overrides without editing this file.
(let ((local-init-dir (expand-file-name "local-init.d" user-emacs-directory)))
  (when (file-directory-p local-init-dir)
    (dolist (f (directory-files local-init-dir t "\\.el\\'"))
      (load f nil 'nomessage))))
