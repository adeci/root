;;; init.el --- Alex's Emacs -*- lexical-binding: t; -*-

;;; Commentary:

;; Built into Emacs as default.el by packages/emacs/default.nix.  Nix
;; installs every package a `use-package' form below names; built-in
;; features are switched on with plain calls instead.  To try a change
;; before deploying, edit this file in the checkout and M-x eval-buffer.
;;
;; New to Emacs?  C-h t is the built-in tutorial, C-h k KEY says what a key
;; does, and C-g cancels whatever is half-typed.

;;; Code:

;;;; Files Emacs writes

;; This file is read-only once built, so M-x customize saves here instead.
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)

;;;; Look

;; One monospace font everywhere.  fixed-pitch and variable-pitch would
;; otherwise fall back to other fonts in the tab bar, help and manuals.
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

;; Pausing after a prefix key (C-x, C-c, ...) lists what can follow.
(which-key-mode 1)

;;;; Completion

;; Prompts (M-x, C-x C-f, C-x b, ...) list matches vertically (vertico),
;; match space-separated words in any order (orderless), and annotate each
;; match (marginalia).  consult adds the search commands below.
;;
;;   C-x b  buffers, recent files, bookmarks   M-s l  lines in this buffer
;;   M-s r  ripgrep in the project
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

;; Emacs words: a frame is an OS window, a window is a pane, a tab is a
;; saved layout of windows, and a buffer is what a window shows (a file, a
;; terminal).  Closing a window never kills its buffer.
;;
;;   C-x 2 / C-x 3  split below / right     C-x 0       close this window
;;   C-x o          next window             C-x 1       only this window
;;   S-<arrow>      window in that direction C-c <left>  undo layout change
;;   C-x b          show another buffer     C-x k       kill a buffer
;;   C-x t 2        new tab                 C-x t 0     close tab
;;   C-x t RET      switch tab by name      C-x t r     rename tab

(windmove-default-keybindings)   ; S-<arrow>
(winner-mode 1)                  ; C-c <left> / C-c <right>
(repeat-mode 1)                  ; C-x o o o, C-x } } }, C-x t o o
(setopt tab-bar-show 1)          ; tab bar appears with the second tab
(tab-bar-mode 1)

;;;; Terminal

;; In a ghostel buffer most keys go to the program.  C-c, C-x, C-u, C-h,
;; M-x, M-: and C-\ stay with Emacs, so C-x works like a tmux prefix.
;;
;;   C-c C-c  send Ctrl-C              C-c C-t  copy mode: select, M-w copies
;;   C-c C-l  line mode: edit a line, RET sends it
;;   C-c M-d  char mode: every key to the program, M-RET leaves
;;
;; Agents that report their state (working, blocked, done) show in every
;; mode line; C-c a jumps to the one that needs you most, again for the next.
(use-package ghostel
  :hook (after-init . ghostel-status-indicator-mode)
  :bind (("C-c t" . ghostel)
         ("C-c a" . ghostel-status-next))
  :custom
  ;; The defaults plus S-<arrow>, so window moves work from a terminal.
  (ghostel-keymap-exceptions
   '("C-c" "C-x" "C-u" "C-h" "M-x" "M-:" "C-\\"
     "S-<left>" "S-<right>" "S-<up>" "S-<down>")))

;; C-x p t: a terminal at the current project's root.
(with-eval-after-load 'project
  (keymap-set project-prefix-map "t" #'ghostel-project)
  (add-to-list 'project-switch-commands '(ghostel-project "Terminal") t))

;;;; Sessions that outlive Emacs

;; zmx keeps each shell in a small background process of its own, and
;; term-sessions opens it in ghostel by name.  Restart Emacs, open the same
;; name, and the shell is still there with whatever was running in it.
;;
;;   C-c s  open a session by name (a new name creates it)
;;   C-c S  list sessions
(use-package term-sessions
  :bind (("C-c s" . term-sessions-open)
         ("C-c S" . term-sessions-list))
  :custom
  (term-sessions-preferred-frontend 'ghostel)
  :init
  ;; Sessions start through `ghostel-exec', which doesn't set this, so zsh in
  ;; a session couldn't find ghostel's integration (see zshrc).
  (setenv "EMACS_GHOSTEL_PATH"
          (file-name-directory (locate-library "ghostel"))))

;;;; Git

(use-package magit
  :bind (("C-x g" . magit-status)))

;;; init.el ends here
