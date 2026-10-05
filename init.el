;;; init.el --- Prelude's configuration entry point.
;;
;; Copyright (c) 2011-2026 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.com>
;; URL: https://github.com/bbatsov/prelude
;; Version: 1.1.0
;; Keywords: convenience

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This file simply sets up the default load path and requires
;; the various modules defined within Emacs Prelude.

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.
                                        ;(package-initialize)

(defvar prelude-user
  (getenv
   (if (equal system-type 'windows-nt) "USERNAME" "USER")))

(message "[Prelude] Prelude is powering up... Be patient, Master %s!" prelude-user)

(when (version< emacs-version "29.1")
  (error "[Prelude] Prelude requires GNU Emacs 29.1 or newer, but you're running %s" emacs-version))

;; Always load newest byte code
(setq load-prefer-newer t)

;; Define Prelude's directory structure
(defvar prelude-dir (file-name-directory load-file-name)
  "The root dir of the Emacs Prelude distribution.")
(defvar prelude-core-dir (expand-file-name "core" prelude-dir)
  "The home of Prelude's core functionality.")
(defvar prelude-modules-dir (expand-file-name  "modules" prelude-dir)
  "This directory houses all of the built-in Prelude modules.")
(defvar prelude-personal-dir (expand-file-name "personal" prelude-dir)
  "This directory is for your personal configuration.

Users of Emacs Prelude are encouraged to keep their personal configuration
changes in this directory.  All Emacs Lisp files there are loaded automatically
by Prelude.")
(defvar prelude-personal-preload-dir (expand-file-name "preload" prelude-personal-dir)
  "This directory is for your personal configuration, that you want loaded before Prelude.")
(defvar prelude-vendor-dir (expand-file-name "vendor" prelude-dir)
  "This directory houses packages that are not yet available in ELPA (or MELPA).")
(defvar prelude-savefile-dir (expand-file-name "savefile" user-emacs-directory)
  "This folder stores all the automatically generated save/history-files.")
(defvar prelude-modules-file (expand-file-name "prelude-modules.el" prelude-personal-dir)
  "This file contains a list of modules that will be loaded by Prelude.")
(defvar prelude-override-package-user-dir t
  "By default prelude installs downloaded packages in <prelude-dir>/elpa.
   Set to nil to override this behaviour")

(unless (file-exists-p prelude-savefile-dir)
  (make-directory prelude-savefile-dir))

(defun prelude-add-subfolders-to-load-path (parent-dir)
  "Add all level PARENT-DIR subdirs to the `load-path'."
  (dolist (f (directory-files parent-dir))
    (let ((name (expand-file-name f parent-dir)))
      (when (and (file-directory-p name)
                 (not (string-prefix-p "." f)))
        (add-to-list 'load-path name)
        (prelude-add-subfolders-to-load-path name)))))

;; add Prelude's directories to Emacs's `load-path'
(add-to-list 'load-path prelude-core-dir)
(add-to-list 'load-path prelude-modules-dir)
(add-to-list 'load-path prelude-vendor-dir)
(prelude-add-subfolders-to-load-path prelude-vendor-dir)

;; reduce the frequency of garbage collection by making it happen on
;; each 50MB of allocated data (the default is on every 0.76MB)
(setq gc-cons-threshold 50000000)

;; warn when opening files bigger than 100MB
(setq large-file-warning-threshold 100000000)

;; preload the personal settings from `prelude-personal-preload-dir'
(when (file-directory-p prelude-personal-preload-dir)
  (message "[Prelude] Loading personal configuration files from files and directories in %s..." prelude-personal-preload-dir)
  (mapc 'load (directory-files-recursively prelude-personal-preload-dir "^[^#\.].*el$")))

(message "[Prelude] Loading Prelude's core modules...")

;; Disable Prelude's undo-tree integration before prelude-editor is loaded.
(setq prelude-undo-tree nil)

;; load the core stuff
(require 'prelude-packages)
(require 'prelude-custom)  ;; Needs to be loaded before core, editor and ui
(require 'prelude-ui)
(require 'prelude-core)
(require 'prelude-mode)
(require 'prelude-editor)
(require 'prelude-global-keybindings)

;; macOS specific settings
(when (eq system-type 'darwin)
  (require 'prelude-macos))

;; Linux specific settings
(when (eq system-type 'gnu/linux)
  (require 'prelude-linux))

;; WSL specific setting
(when (and (eq system-type 'gnu/linux) (getenv "WSLENV"))
  (require 'prelude-wsl))

;; Windows specific settings
(when (eq system-type 'windows-nt)
  (require 'prelude-windows))

(message "[Prelude] Loading Prelude's additional modules...")

;; the modules
(if (file-exists-p prelude-modules-file)
    (load prelude-modules-file)
  (message "[Prelude] Missing personal modules file %s" prelude-modules-file)
  (message "[Prelude] Falling back to the bundled example file sample/prelude-modules.el")
  (message "[Prelude] You should copy this file to your personal configuration folder and tweak it to your liking")
  (load (expand-file-name "sample/prelude-modules.el" prelude-dir)))

;; config changes made through the customize UI will be stored here
(setq custom-file (expand-file-name "custom.el" prelude-personal-dir))

;; load the personal settings (this includes `custom-file')
(when (file-exists-p prelude-personal-dir)
  (message "[Prelude] Loading personal configuration files in %s..." prelude-personal-dir)
  (mapc 'load (delete
               prelude-modules-file
               (directory-files prelude-personal-dir 't "^[^#\.].*\\.el$"))))

(message "[Prelude] Prelude is ready to do thy bidding, Master %s!" prelude-user)

(prelude-eval-after-init
 ;; greet the use with some useful tip
 (run-at-time 5 nil 'prelude-tip-of-the-day))

;;; init.el ends here

(guru-mode -1 )
(guru-global-mode -1)

(flyspell-mode -1)
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(hl-line-mode nil)
(flycheck-mode nil)
(remove-hook 'prog-mode  #'flycheck-mode )
(with-eval-after-load 'flycheck
  (setq flycheck-display-errors-function nil))
(global-flycheck-mode -1)
(require 'ob-tangle)
(defun jmd/load-literate-configuration ()
  "Safely tangle and load the personal Org configuration.

The generated Lisp file is replaced only after its complete contents have
been read successfully.  This prevents an interrupted tangle from leaving a
truncated `configuration.el' that breaks the next Emacs startup."
  (let* ((org-file (expand-file-name "configuration.org" user-emacs-directory))
         (el-file (expand-file-name "configuration.el" user-emacs-directory)))
    (when (file-newer-than-file-p org-file el-file)
      (let ((temporary-file
             (make-temp-file
              (expand-file-name ".configuration-" user-emacs-directory)
              nil ".el")))
        (unwind-protect
            (progn
              (org-babel-tangle-file org-file temporary-file "emacs-lisp")
              (with-temp-buffer
                (insert-file-contents temporary-file)
                (goto-char (point-min))
                (while (progn
                         (skip-chars-forward " \t\n\r")
                         (not (eobp)))
                  (read (current-buffer))))
              (rename-file temporary-file el-file t)
              (setq temporary-file nil))
          (when temporary-file
            (delete-file temporary-file)))))
    (load el-file nil nil t)))

(jmd/load-literate-configuration)
(electric-pair-mode -1)
                                        ;()
(setq electric-pair-mode nil)
(smartparens-global-mode -1)
(setq prelude-smartparens nil)


 ;; Disable guru-mode everywhere
 (setq prelude-guru nil)

 (with-eval-after-load 'guru-mode
   (when (fboundp 'guru-mode)
     (guru-mode -1))
   )
(delete-selection-mode -1)
(use-package doom-modeline
  :ensure t
  :init
  (doom-modeline-mode 1)
  )

(setq prelude-clean-whitespace-on-save nil)
(setq prelude-whitespace nil)


(global-unset-key (kbd "S-<left>"))
(global-unset-key (kbd "S-<right>"))
(global-unset-key (kbd "S-<up>"))
(global-unset-key (kbd "S-<down>"))

(with-eval-after-load 'org
  (add-hook 'org-mode-hook
            (lambda ()
              (local-set-key (kbd "S-<left>")  #'org-shiftleft)
              (local-set-key (kbd "S-<right>") #'org-shiftright)
              (local-set-key (kbd "<S-left>")  #'org-shiftleft)
              (local-set-key (kbd "<S-right>") #'org-shiftright))))


(use-package leuven-theme
  :ensure t
  :config
  (load-theme 'leuven-dark t))
; Disable overlines
(with-eval-after-load 'org
  (dolist (face (face-list))
    (when (string-prefix-p "org-" (symbol-name face))
      (set-face-attribute face nil :overline nil))))



;; ~/.emacs.d/init.el
(require 'server)
(unless (server-running-p)
  (server-start))
