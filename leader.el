;;; leader.el --- Leader key configuration -*- lexical-binding: t; -*-

;; Author: jixiuf
;; Keywords: leader
;; URL: https://github.com/jixiuf/leader
;; Package-Requires: ((emacs "28.1"))

;; Copyright (C) 2026, jixiuf, all rights reserved.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; leader.el -- a modal leader-key package for Emacs.
;;
;; It intercepts one or more "leader keys" via `key-translation-map' and
;; translates subsequent keystrokes into standard Emacs key sequences,
;; so you can type `SPC f' instead of `C-c C-f', etc.
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 1.  Quick start
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;;   (require 'leader)
;;   (leader-mode 1)           ; enable
;;   (leader-mode -1)          ; disable
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 2.  `leader-keys' -- configure leader keys
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; `leader-keys' is a list of leader key configurations.  Each element
;; has the form:
;;
;;   (LEADER-KEY DEFAULT-PREFIX [DISPATCH-ENTRY ...])
;;
;; - LEADER-KEY      A key description string (e.g. "<SPC>", ",").
;; - DEFAULT-PREFIX  Either a string or a list.
;;                   As a string (e.g. "C-c"): modifier-default="C-",
;;                   fallback-modifier="C-".
;;                   As a list:
;;                     (PREFIX MODIFIER)          ; 2 elements
;;                       fallback-modifier = MODIFIER.
;;                     (PREFIX MODIFIER FALLBACK) ; 3 elements
;;                       explicit fallback-modifier (used when
;;                       modifier is nil and plain key has no binding).
;;                   Examples:
;;                     "C-c"              mod-default="C-"  fallback="C-"
;;                     ("C-c" nil)        mod-default=nil   fallback=nil
;;                     ("C-c" nil "C-")   mod-default=nil   fallback="C-"
;;                     ("C-c" "C-")       mod-default="C-"  fallback="C-"
;;                     ("C-c" "M-")       mod-default="M-"  fallback="M-"
;; - DISPATCH-ENTRY  An alist entry (CHAR . TARGET) that overrides
;;                   the default prefix for a specific first keystroke.
;;
;; Example -- single leader with modifier-default="C-" (default):
;;
;;   (setq leader-keys
;;       '(("<SPC>" "C-c"    ; modifier="C-", SPC f -> C-c C-f, SPC SPC f -> C-c f
;;          (?h . "C-h")     ; SPC h f -> C-h C-f, SPC h SPC f -> C-h f
;;          (?x . "C-x"))))  ; SPC x f -> C-x C-f, SPC x SPC f -> C-x f
;;
;; Example -- single leader with modifier-default=nil, fallback-modifier="C-":
;;
;;   (setq leader-keys
;;    '(("<SPC>" ("C-c" nil "C-") ; plain f first, fallback to C-f
;;     (?h . ("C-h" nil))       ; SPC h a -> C-h a, SPC h SPC a -> C-h C-a
;;     (?x . ("C-x" "C-")))))   ; SPC x f -> C-x C-f, SPC x SPC f -> C-x f
;;
;; Example -- leader with modifier-default="M-":
;;
;;   (setq leader-keys
;;    '(("<SPC>" ("C-c" "M-")   ; modifier="M-", SPC f -> C-c M-f
;;       (?x . ("C-x" "C-"))))) ; SPC x f -> C-x C-f
;;
;; Example -- multiple leaders:
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil "C-")
;;            (?h . ("C-h" nil))
;;            (?x . ("C-x" "C-")))
;;           ("," "M-o")))
;;
;;   The "," leader uses plain string "M-o", so modifier-default = "C-".
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   , a                M-o C-a            modifier="C-" -> try M-o C-a
;;   , a  (no M-o C-a binding)
;;                      M-o a              fallback to plain a
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 5.  `leader-pass-through-predicates'
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; A list of predicates.  When ANY predicate returns non-nil, the leader
;; key is passed through as its literal character (e.g. SPC inserts a
;; space).  Each predicate is either:
;;
;; - A function (including lambdas): called with no arguments.
;; - A symbol naming a variable: true if `boundp' and non-nil.
;;
;; Default value:  '(isearch-mode minibufferp)
;;
;; Examples:
;;
;;   ;; Also pass through in helix insert state:
;;   (add-to-list 'leader-pass-through-predicates
;;                (lambda () (eq helix--current-state 'insert)))
;;
;;   ;; Also pass through in evil insert state:
;;   (add-to-list 'leader-pass-through-predicates
;;                (lambda () (evil-insert-state-p)))
;;
;;   ;; Pass through when a specific minor mode is active:
;;   (add-to-list 'leader-pass-through-predicates 'my-special-input-mode)
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 6.  Continuation (prefix key) behaviour
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; After the initial dispatch resolves to a key sequence, if that
;; sequence is bound to a prefix keymap (not a command), leader
;; continues reading keys.  The same dispatch rules apply at each
;; step, and modifier resets to modifier-default after each ordinary key.
;;
;; Example (with modifier-default=nil, fallback-modifier="C-"):
;;
;;   SPC x is dispatched to C-x (a prefix keymap).
;;   Next key f:  modifier=nil -> try C-x f, no binding -> fallback to
;;   C-x C-f (via fallback-modifier="C-").  C-x C-f is a command -> done.
;;
;; Example (continuation with "C-" toggle):
;;
;;   Suppose C-c C-a is a prefix keymap with sub-bindings C-c C-a b
;;   and C-c C-a C-c.
;;
;;   SPC SPC a      -> C-c C-a (modifier toggled to "C-" by SPC)
;;   C-c C-a is a prefix, continue reading:
;;     modifier resets to nil (modifier-default).
;;     Next key b:  try C-c C-a b -> no binding ->
;;       fallback to C-c C-a C-b (via fallback-modifier="C-") -> bound! -> done.
;;
;;   SPC SPC a SPC c -> C-c C-a C-c
;;     After C-c C-a, modifier resets to nil.
;;     SPC toggles modifier to "C-".
;;     c -> try C-c C-a C-c -> bound! -> done.
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 7.  Per-prefix modifier override
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; By default, after a prefix switch dispatch, modifier resets to
;; modifier-default.  The extended dispatch form lets you override
;; this per prefix:
;;
;;   (?x . ("C-x" "C-"))       ; after C-x, prefer C-<key>
;;   (?h . ("C-h" nil))        ; after C-h, prefer plain <key>
;;   (?g . ("C-x" "M-"))       ; after C-x, prefer M-<key>
;;   (?c . "C-c")              ; after C-c, reset to modifier-default
;;
;; Example with modifier-default=nil, fallback-modifier="C-":
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil "C-")
;;            (?x . ("C-x" "C-"))            ; modifier="C-" after C-x
;;            (?h . ("C-h" nil)))))           ; modifier=nil after C-h
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c f              modifier-default=nil -> plain f
;;   SPC f (no binding) C-c C-f            fallback to C-f
;;   SPC SPC f          C-c C-f            toggle -> modifier="C-"
;;   SPC x f            C-x C-f            x->("C-x" "C-") -> modifier="C-"
;;   SPC x SPC f        C-x SPC C-f        after C-x, modifier="C-",
;;                                         SPC is plain (C-x C-SPC has
;;                                         no binding -> C-x SPC prefix),
;;                                         then f with modifier="C-" -> C-f
;;   SPC h k            C-h k              h->("C-h" nil) -> modifier=nil
;;   SPC h C-k          C-h C-k            (actual C-k typed by user)
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 8.  Full configuration example
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil "C-") ; prefix, modifier-default, fallback-modifier
;;            (?h . ("C-h" nil))       ; SPC h -> C-h prefix, no modifier
;;            (?x . ("C-x" "C-"))      ; SPC x -> C-x prefix, modifier="C-"
;;            (?c . "C-c")            ; SPC c -> C-c prefix (modifier-default)
;;            (?r . "M-")            ; SPC r x -> M-x
;;            (?e . "C-M-"))         ; SPC e f -> C-M-f
;;           ("," "M-o")))           ; , -> M-o prefix (modifier-default="C-")
;;
;;   (setq leader-pass-through-predicates
;;         '(isearch-mode
;;           minibufferp
;;           (lambda () (bound-and-true-p helix--current-state)
;;                      (eq helix--current-state 'insert))))
;;
;;   (leader-mode 1)

(require 'seq)

;;; Code:

(defgroup leader nil
  "Leader key configuration."
  :group 'convenience)

(defcustom leader-keys
  '(("<SPC>" ("C-c" nil "C-")            ; prefix, modifier-default, fallback-modifier
     (?e . "C-M-")
     (?m . "M-")                        ;spc m a=M-a
     (?h . ("C-h" nil "C-"))             ;spc h k=C-h k (plain first, fallback C-)
     (?c . "C-c")
     (?x . ("C-x" "C-" nil))))           ;spc x f=C-x C-f (C- only, no plain fallback)
  "List of leader key configurations.
Each element is a list (LEADER-KEY DEFAULT-PREFIX . DISPATCH-ALIST).
LEADER-KEY is a key description string for `keymap-set'.
DEFAULT-PREFIX specifies the prefix and default modifier behaviour.
  It can be either:
  - A string \"C-c\": modifier defaults to \"C-\" (auto-add C- to keys),
    and fallback-modifier also defaults to \"C-\".
  - A list (\"C-c\" MODIFIER): modifier defaults to MODIFIER.
  - A list (\"C-c\" MODIFIER FALLBACK): FALLBACK is the modifier
    used when MODIFIER is nil and the plain key has no binding
    (defaults to MODIFIER).
DISPATCH-ALIST is an alist mapping characters to dispatch targets.

Each dispatch target can be either:
- A string: e.g. \"C-x\", \"M-\", \"C-\"
  After dispatching, modifier and fb-context reset to defaults.
- A list (\"C-x\" MODIFIER): e.g. (\"C-x\" \"C-\"), (\"C-h\" nil)
  After dispatching, modifier is set to the specified MODIFIER.
- A list (\"C-x\" MODIFIER FALLBACK): e.g. (\"C-x\" \"C-\" nil)
  After dispatching, modifier=FALLBACK-MODIFIER for the dispatched context.
  FALLBACK defaults to the global `fallback-modifier' if omitted.

If a dispatch value (or its car) ends with \"-\" (e.g. \"M-\"),
a second key is read and combined with the modifier prefix.

The special target \"C-\" toggles the modifier state.
When the leader key itself is not in the dispatch alist, pressing
it also acts as an implicit toggle."
  :group 'leader
  :type '(repeat
          (list (string :tag "Leader key")
                (choice (string :tag "Default prefix (modifier=C-)")
                        (list (string :tag "Default prefix")
                              (choice (string :tag "Default modifier")
                                      (const :tag "No modifier" nil))
                              &optional
                              (choice (const :tag "No fallback modifier" nil)
                                      (string :tag "Fallback modifier"))))
                (repeat :inline t
                        (cons (character :tag "From key")
                              (choice (string :tag "Target sequence")
                                      (list (string :tag "Target sequence")
                                            (choice (string :tag "Modifier override")
                                                    (const :tag "No modifier" nil))
                                            &optional
                                            (choice (const :tag "No fallback override" nil)
                                                    (string :tag "Fallback modifier")))))))))

(defcustom leader-pass-through-predicates nil
  "List of predicates controlling when the leader key passes through.
By default, minibuffer and isearch mode are always checked internally.
This variable is for additional custom predicates.
Each element is either:
- A function (or lambda): called with no arguments, pass through if non-nil.
- A symbol naming a variable: pass through if the variable is bound and non-nil."
  :group 'leader
  :type '(repeat (choice function symbol)))

(defvar leader--active-keys nil
  "List of leader key strings currently registered in `key-translation-map'.")

(defun leader--pass-through-p ()
  "Return non-nil if the leader key should pass through as a normal key.
Checks for active minibuffer, isearch-mode, and custom predicates."
  (or (active-minibuffer-window)
      (bound-and-true-p isearch-mode)
      (seq-some
       (lambda (pred)
         (cond
          ((symbolp pred)
           (and (boundp pred) (symbol-value pred)))
          ((functionp pred) (funcall pred))
          (t nil)))
       leader-pass-through-predicates)))

;; Declare as special (dynamic) variable so `let' binding works with which-key.
;; Do NOT override if which-key already defined it.
(defvar which-key-this-command-keys-function #'this-command-keys
  "Dynamic variable used by which-key to get current key sequence.")

(defun leader--prompt (keys modifier)
  "Build prompt string showing KEYS and current MODIFIER state."
  (if modifier
      (format "%s [%s]-" keys modifier)
    (format "%s -" keys)))

(defun leader--parse-dispatch (val)
  "Parse a dispatch VAL into a list (TARGET MOD-OVERRIDE FB-OVERRIDE).
VAL can be:
- A string like \"C-x\":       returns (\"C-x\" default default)
- A list (\"C-x\" MOD):       returns (\"C-x\" MOD default)
- A list (\"C-x\" MOD FB):    returns (\"C-x\" MOD FB)
MOD-OVERRIDE is the modifier to set after dispatch.  FB-OVERRIDE
is the fallback modifier for the dispatched context.  The symbol
`default' means use the global default value."
  (cond
   ((consp val)
    (list (car val) (cadr val)
          (if (cddr val) (caddr val) 'default)))
   (t (list val 'default 'default))))

(defun leader--make-handler (default-prefix modifier-default dispatch-alist fallback-modifier)
  "Return a key-translation-map handler for a leader key.
DEFAULT-PREFIX is the fallback prefix string.
MODIFIER-DEFAULT is the default modifier string (e.g. \"C-\", \"M-\")
or nil for no modifier.  It controls how subsequent ordinary keys
are wrapped.
DISPATCH-ALIST maps characters to dispatch targets.
FALLBACK-MODIFIER is used when MODIFIER is nil and the plain key
has no binding (e.g. \"C-\").

When MODIFIER is non-nil, keys are tried as MODIFIER+char first,
falling back to plain char if no binding exists.
When MODIFIER is nil, keys are tried as plain char first,
falling back to FALLBACK-MODIFIER+char if set.

The leader key itself (when not in DISPATCH-ALIST) and any dispatch
entry with target \"C-\" act as toggles: they switch MODIFIER between
MODIFIER-DEFAULT and nil (or \"C-\" if MODIFIER-DEFAULT is also nil).

Each dispatch entry value can be:
- A string: e.g. \"C-x\", \"M-\", \"C-\"
- A list (STRING MODIFIER): e.g. (\"C-x\" \"C-\") sets modifier to \"C-\"
  after switching to the C-x prefix.
- A list (STRING MODIFIER FALLBACK): e.g. (\"C-x\" \"C-\" nil) also
  overrides the fallback modifier for the dispatched context.
  FALLBACK defaults to the global `fallback-modifier' if omitted."
  (let ((toggle-target (if modifier-default nil "C-")))
    (lambda (_)
      (let* ((vkeys (this-command-keys-vector))
             (len (length vkeys))
             (leader (aref vkeys (1- len))))
        (cond
         ((leader--pass-through-p)
          (vector leader))
         ((= len 1)
          (let* ((modifier modifier-default)
                 (fb-context fallback-modifier)
                 (keys default-prefix)
                 (which-key-this-command-keys-function (lambda () (kbd keys)))
                 (need-read t)
                 char raw-val parsed target mod-override fb-override binding char2 prompt)
            ;; Unified read-and-dispatch loop.
            (while need-read
              (setq prompt (leader--prompt keys modifier))
              (setq char (read-event prompt))
              (setq raw-val (alist-get char dispatch-alist))
              (setq parsed (leader--parse-dispatch raw-val))
              (setq target (car parsed))
              (setq mod-override (cadr parsed))
              (setq fb-override (caddr parsed))
              (cond
               ;; "C-" dispatch (toggle): if keys + char is a command, use it;
               ;; otherwise toggle modifier and read next char
               ((and target (string= target "C-"))
                (let* ((desc (single-key-description char))
                       (char-key (concat keys " " desc))
                       (char-binding (key-binding (kbd char-key))))
                  (if (commandp char-binding t)
                      (progn (setq keys char-key)
                             (setq need-read nil))
                    (setq modifier toggle-target))))
               ;; Modifier prefix ending with "-" (like "M-"): read second key
               ((and target (string-suffix-p "-" target))
                (let* ((parts (split-string target " "))
                       (prefix (when (cdr parts)
                                 (string-join (butlast parts) " "))))
                  (when prefix
                    (setq keys (if (string= keys default-prefix)
                                   prefix
                                 (concat keys " " prefix)))))
                (setq char2 (read-event (leader--prompt keys modifier)))
                (setq keys (if (string= keys default-prefix)
                               (concat target (single-key-description char2))
                             (concat keys " " target (single-key-description char2))))
                (setq modifier (if (eq mod-override 'default) modifier-default mod-override))
                (setq fb-context (if (eq fb-override 'default) fallback-modifier fb-override))
                (setq need-read nil))
               ;; Direct match for sequences like "C-x"
               (target
                (setq keys (if (string= keys default-prefix)
                               (concat target)
                             (concat keys " " target)))
                (setq modifier (if (eq mod-override 'default) modifier-default mod-override))
                (setq fb-context (if (eq fb-override 'default) fallback-modifier fb-override))
                (setq need-read nil))
               ;; No dispatch match: if leader char pressed, implicit toggle
               ((and (null target) (eq char leader))
                (let* ((desc (single-key-description char))
                       (char-key (concat keys " " desc))
                       (char-binding (key-binding (kbd char-key))))
                  (if (commandp char-binding t)
                      (progn (setq keys char-key)
                             (setq need-read nil))
                    (setq modifier toggle-target))))
               ;; No dispatch match: apply modifier logic
               (t
                (let* ((desc (single-key-description char))
                       (mod-key (when modifier
                                  (concat keys " " modifier desc)))
                       (plain-key (concat keys " " desc)))
                  (if modifier
                      (if (and mod-key (key-binding (kbd mod-key)))
                          (setq keys mod-key)
                        (setq keys plain-key))
                     (if (key-binding (kbd plain-key))
                         (setq keys plain-key)
                       ;; fallback: try fb-context + char
                       (let ((fb-key (when fb-context
                                       (concat keys " " fb-context desc))))
                         (if (and fb-key (key-binding (kbd fb-key)))
                             (setq keys fb-key)
                           (setq keys plain-key))))))
                 (setq modifier modifier-default)
                 (setq fb-context fallback-modifier)
                 (setq need-read nil))))
             ;; Continue reading while binding is a prefix key (keymap)
            (setq binding (key-binding (kbd keys)))
            (while (not (or (commandp binding t) (null binding)))
              (setq need-read t)
              (while need-read
                (setq prompt (leader--prompt keys modifier))
                (setq char (read-event prompt))
                (setq raw-val (alist-get char dispatch-alist))
                (setq parsed (leader--parse-dispatch raw-val))
                (setq target (car parsed))
                (setq mod-override (cadr parsed))
                (setq fb-override (caddr parsed))
                (cond
                 ;; "C-" dispatch (toggle)
                 ((and target (string= target "C-"))
                  (let* ((desc (single-key-description char))
                         (char-key (concat keys " " desc))
                         (char-binding (key-binding (kbd char-key))))
                    (if (commandp char-binding t)
                        (progn (setq keys char-key)
                               (setq need-read nil))
                      (setq modifier toggle-target))))
                 ;; Modifier prefix ending with "-" (like "M-")
                 ((and target (string-suffix-p "-" target))
                  (let* ((parts (split-string target " "))
                         (prefix (when (cdr parts)
                                   (string-join (butlast parts) " "))))
                    (setq keys (concat keys " " (or prefix "")))
                    (setq char2 (read-event (leader--prompt keys modifier))))
                  (setq keys (concat keys " " target (single-key-description char2)))
                  (setq modifier (if (eq mod-override 'default) modifier-default mod-override))
                  (setq fb-context (if (eq fb-override 'default) fallback-modifier fb-override))
                  (setq need-read nil))
                 ;; Direct match in dispatch
                 (target
                  (setq keys (concat keys " " target))
                  (setq modifier (if (eq mod-override 'default) modifier-default mod-override))
                  (setq fb-context (if (eq fb-override 'default) fallback-modifier fb-override))
                  (setq need-read nil))
                 ;; No dispatch match: if leader char pressed, implicit toggle
                 ((and (null target) (eq char leader))
                  (let* ((desc (single-key-description char))
                         (char-key (concat keys " " desc))
                         (char-binding (key-binding (kbd char-key))))
                    (if (commandp char-binding t)
                        (progn (setq keys char-key)
                               (setq need-read nil))
                      (setq modifier toggle-target))))
                 ;; No dispatch match: apply modifier logic
                 (t
                  (let* ((desc (single-key-description char))
                         (mod-key (when modifier
                                    (concat keys " " modifier desc)))
                         (plain-key (concat keys " " desc)))
                    (if modifier
                        (if (and mod-key (key-binding (kbd mod-key)))
                            (setq keys mod-key)
                          (setq keys plain-key))
                      (if (key-binding (kbd plain-key))
                          (setq keys plain-key)
                        (let ((fb-key (when fb-context
                                        (concat keys " " fb-context desc))))
                          (if (and fb-key (key-binding (kbd fb-key)))
                              (setq keys fb-key)
                            (setq keys plain-key))))))
                  (setq modifier modifier-default)
                  (setq fb-context fallback-modifier)
                  (setq need-read nil))))
              (setq binding (key-binding (kbd keys))))
            (kbd keys)))
         (t
          (vector leader)))))))

(defun leader--install ()
  "Install all leader key handlers into `key-translation-map'."
  (leader--uninstall)
  (dolist (entry leader-keys)
    (let* ((leader-key (car entry))
           (prefix-spec (cadr entry))
           (default-prefix (if (consp prefix-spec) (car prefix-spec) prefix-spec))
           (modifier-default (if (consp prefix-spec) (cadr prefix-spec) "C-"))
           (fallback-modifier (if (and (consp prefix-spec) (caddr prefix-spec))
                                  (caddr prefix-spec)
                                modifier-default))
           (dispatch-alist (cddr entry))
           (handler (leader--make-handler default-prefix modifier-default dispatch-alist fallback-modifier)))
      (keymap-set key-translation-map leader-key handler)
      (push leader-key leader--active-keys))))

(defun leader--uninstall ()
  "Remove all leader key handlers from `key-translation-map'."
  (dolist (key leader--active-keys)
    (keymap-set key-translation-map key nil))
  (setq leader--active-keys nil))

;;;###autoload
(define-minor-mode leader-mode
  "Global minor mode for leader key support.
When enabled, leader keys defined in `leader-keys' are activated
in `key-translation-map'."
  :global t
  :group 'leader
  (if leader-mode
      (leader--install)
    (leader--uninstall)))

(provide 'leader)

;; Local Variables:
;; coding: utf-8
;; End:

;;; leader.el ends here.
