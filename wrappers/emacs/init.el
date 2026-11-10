;;; init.el --- Emacs configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Built into Emacs as default.el by wrappers/emacs/default.nix.  Nix
;; installs every package a `use-package' form below names; built-in
;; features are switched on with plain calls instead.  To try a change
;; before deploying, edit this file in the checkout and M-x eval-buffer.

;;; Code:

;;;; Files Emacs writes

;; This file is read-only once built, so M-x customize saves here instead.
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)

;;;; Look

;; fixed-pitch and variable-pitch would otherwise fall back to other fonts in
;; the tab bar, help and manuals.
(dolist (face '(default fixed-pitch variable-pitch))
  (set-face-attribute face nil :family "CaskaydiaMono Nerd Font Mono"))
(set-face-attribute 'default nil :height 110 :weight 'semibold)

(use-package doom-themes
  :config
  (load-theme 'doom-tokyo-night t)
  (dolist (face '(default fringe line-number line-number-current-line))
    (set-face-attribute face nil :background "#000000")))

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(setq scroll-conservatively most-positive-fixnum
      scroll-margin 2
      scroll-preserve-screen-position t)
(pixel-scroll-precision-mode 1)

;;;; Behavior

;; Agents edit files behind your back; show their changes.
(setq global-auto-revert-non-file-buffers t
      auto-revert-verbose nil)
(global-auto-revert-mode 1)

(which-key-mode 1)

;;;; Completion

(use-package vertico
  :config (vertico-mode 1))

(use-package marginalia
  :config (marginalia-mode 1))

(use-package orderless
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion)))))

(use-package consult
  :bind (("C-x b" . consult-buffer)
         ("M-s l" . consult-line)
         ("M-s r" . consult-ripgrep)))

;;;; Windows and tabs

(windmove-default-keybindings)
(winner-mode 1)
(repeat-mode 1)
(setopt tab-bar-show 1)          ; tab bar appears with the second tab
(tab-bar-mode 1)

;;;; Terminal

(use-package ghostel
  :hook (after-init . ghostel-status-indicator-mode)
  :bind (("C-c t" . ghostel)
         ("C-c a" . ghostel-status-next))
  :custom
  ;; The defaults plus S-<arrow>, so window moves work from a terminal.
  (ghostel-keymap-exceptions
   '("C-c" "C-x" "C-u" "C-h" "M-x" "M-:" "C-\\"
     "S-<left>" "S-<right>" "S-<up>" "S-<down>")))

(with-eval-after-load 'project
  (keymap-set project-prefix-map "t" #'ghostel-project)
  (add-to-list 'project-switch-commands '(ghostel-project "Terminal") t))

;;;; Sessions that outlive Emacs

(use-package term-sessions
  :bind (("C-c s" . term-sessions-open)
         ("C-c S" . term-sessions-list))
  :custom
  (term-sessions-preferred-frontend 'ghostel)
  :init
  ;; Shells read EMACS_GHOSTEL_PATH to find ghostel's shell integration, but
  ;; sessions start through `ghostel-exec', which doesn't set it.
  (setenv "EMACS_GHOSTEL_PATH"
          (file-name-directory (locate-library "ghostel"))))

;;;; Git

(use-package magit
  :bind (("C-x g" . magit-status)))

;;; init.el ends here
