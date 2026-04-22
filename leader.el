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
;; - DEFAULT-PREFIX  Either a string or a list (STRING MODIFIER).
;;                   As a string (e.g. "C-c"): modifier defaults to
;;                   "C-" (auto-add C- to subsequent keys).
;;                   As a list: modifier defaults to MODIFIER, which
;;                   is a string like "C-", "M-", or nil for no modifier.
;;                   Examples:
;;                     "C-c"          modifier-default = "C-"
;;                     ("C-c" nil)    modifier-default = nil
;;                     ("C-c" "C-")   modifier-default = "C-"
;;                     ("C-c" "M-")   modifier-default = "M-"
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
;; Example -- single leader with modifier-default=nil:
;;
;;   (setq leader-keys
;;    '(("<SPC>" ("C-c" nil)    ; modifier=nil, SPC f->C-c f, SPC SPC f->C-c C-f
;;     (?h . ("C-h" . nil))    ; SPC h a -> C-h a, SPC h SPC a -> C-h C-a
;;     (?x . ("C-x" . "C-")))))  ; SPC x f -> C-x C-f, SPC x SPC f -> C-x f
;;
;; Example -- leader with modifier-default="M-":
;;
;;   (setq leader-keys
;;    '(("<SPC>" ("C-c" "M-")   ; modifier="M-", SPC f -> C-c M-f
;;       (?x . ("C-x" . "C-"))))) ; SPC x f -> C-x C-f
;;
;; Example -- multiple leaders:
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?h . ("C-h" . nil))
;;            (?x . ("C-x" . t)))
;;           ("," "M-o")))                 ; , ... -> M-o ...
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 3.  Dispatch entry types
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; 3a.  Prefix switch  --  (CHAR . "C-x")  or  (CHAR . ("C-x" . MODIFIER))
;;
;;   Replaces the default prefix entirely.
;;
;;   Simple form -- modifier resets to modifier-default after dispatch:
;;     (?x . "C-x")    SPC x f   -> C-x C-f  (if modifier-default="C-")
;;     (?h . "C-h")    SPC h k   -> C-h k    (if modifier-default="C-",
;;                                             but C-h C-k has no binding)
;;
;;   Extended form -- modifier is set to the specified value:
;;     (?x . ("C-x" . "C-"))    SPC x f   -> C-x C-f  (modifier forced to "C-")
;;     (?h . ("C-h" . nil))     SPC h k   -> C-h k    (modifier forced to nil,
;;                                                      plain key preferred)
;;     (?g . ("C-x" . "M-"))    SPC g f   -> C-x M-f  (modifier forced to "M-")
;;
;;   This is useful when different prefixes have different conventions:
;;   C-x typically uses C-<key> (e.g. C-x C-f, C-x C-s), so set "C-".
;;   C-h typically uses plain keys (e.g. C-h k, C-h f), so set nil.
;;
;; 3b.  Modifier prefix  --  (CHAR . "M-")   (value ends with "-")
;;
;;   Reads one more key and prepends the modifier.
;;
;;     (?r . "M-")     SPC r x   -> M-x      (execute-extended-command)
;;     (?e . "C-M-")   SPC e f   -> C-M-f    (forward-sexp)
;;
;; 3c.  Modifier toggle  --  (CHAR . "C-")  or implicit via leader key
;;
;;   Pressing a key dispatched to "C-", or pressing the leader key
;;   itself when it has no dispatch entry, toggles the modifier state.
;;
;;   The toggle switches between modifier-default and nil (or "C-"
;;   if modifier-default is also nil):
;;
;;   ┌──────────────────────────────┬─────────────────┬──────────────┐
;;   │ DEFAULT-PREFIX               │ modifier-default│ toggle-target│
;;   ├──────────────────────────────┼─────────────────┼──────────────┤
;;   │ "C-c"  (plain string)       │ "C-"            │ nil          │
;;   │ ("C-c" "C-")                │ "C-"            │ nil          │
;;   │ ("C-c" nil)                 │ nil             │ "C-"         │
;;   │ ("C-c" "M-")                │ "M-"            │ nil          │
;;   └──────────────────────────────┴─────────────────┴──────────────┘
;;
;;   However, if the key sequence keys + leader-char already has a
;;   command binding (e.g. C-c SPC), that binding is used directly
;;   instead of toggling.
;;
;;   When modifier is non-nil, keys are tried as modifier+char first,
;;   falling back to plain char.  When modifier is nil, keys are tried
;;   plain first, falling back to modifier-default+char.
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 4.  Detailed examples of the "C-" toggle
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; ── Example A: DEFAULT-PREFIX = "C-c" (modifier-default="C-") ────
;;
;;   (setq leader-keys
;;         '(("<SPC>" "C-c"
;;            (?h . "C-h")
;;            (?x . "C-x"))))
;;
;;   modifier-default = "C-" (plain string DEFAULT-PREFIX).
;;   Ordinary keys are wrapped with C- first; if no binding, fall back
;;   to plain key.  Pressing SPC toggles modifier to nil.
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c C-f            modifier="C-", try C-c C-f
;;   SPC f  (no C-c C-f binding)
;;                      C-c f              fallback to plain f
;;   SPC SPC f          C-c f              SPC toggles modifier to nil
;;   SPC x f            C-x C-f            dispatch x->C-x, modifier="C-"
;;   SPC h k            C-h k              dispatch h->C-h, C-h C-k has
;;                                         no binding -> fall back C-h k
;;
;; ── Example B: DEFAULT-PREFIX = ("C-c" nil) (modifier-default=nil)─
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?h . ("C-h" . nil))
;;            (?x . ("C-x" . "C-")))))
;;
;;   modifier-default = nil.  Ordinary keys are used plain first; if
;;   no binding, fall back to modifier-default+char (no-op since nil).
;;   Pressing SPC toggles modifier to "C-".
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c f              modifier=nil, plain f
;;   SPC SPC f          C-c C-f            SPC toggles to "C-"
;;   SPC SPC SPC f      C-c C-f            second SPC toggles again,
;;                                         modifier="C-" (same dir)
;;   SPC x f            C-x C-f            x->("C-x"."C-") -> modifier="C-"
;;   SPC h k            C-h k              h->("C-h".nil) -> modifier=nil
;;
;; ── Example C: "," as a second leader ──────────────────────────
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?h . ("C-h" . nil))
;;            (?x . ("C-x" . "C-")))
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
;; Example (with modifier-default=nil, DEFAULT-PREFIX = ("C-c" nil)):
;;
;;   SPC x is dispatched to C-x (a prefix keymap).
;;   Next key f:  modifier=nil -> try C-x f, no binding -> C-x C-f
;;   C-x C-f is `find-file' (a command) -> done.
;;
;; Example (continuation with "C-" toggle):
;;
;;   Suppose C-c C-a is a prefix keymap with sub-bindings C-c C-a b
;;   and C-c C-a C-c.
;;
;;   SPC SPC a      -> C-c C-a (modifier toggled to "C-" by SPC)
;;   C-c C-a is a prefix, continue reading:
;;     modifier resets to nil (modifier-default).
;;     Next key b:  try C-c C-a b -> bound! -> done.
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
;;   (?x . ("C-x" . "C-"))   ; after C-x, prefer C-<key>
;;   (?h . ("C-h" . nil))    ; after C-h, prefer plain <key>
;;   (?g . ("C-x" . "M-"))   ; after C-x, prefer M-<key>
;;   (?c . "C-c")            ; after C-c, reset to modifier-default
;;
;; Example with modifier-default=nil (DEFAULT-PREFIX = ("C-c" nil)):
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?x . ("C-x" . "C-"))        ; modifier="C-" after C-x
;;            (?h . ("C-h" . nil)))))       ; modifier=nil after C-h
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c f              modifier-default=nil -> plain f
;;   SPC SPC f          C-c C-f            toggle -> modifier="C-"
;;   SPC x f            C-x C-f            x->("C-x"."C-") -> modifier="C-"
;;   SPC x SPC f        C-x SPC C-f        after C-x, modifier="C-",
;;                                         SPC is plain (C-x C-SPC has
;;                                         no binding -> C-x SPC prefix),
;;                                         then f with modifier="C-" -> C-f
;;   SPC h k            C-h k              h->("C-h".nil) -> modifier=nil
;;   SPC h C-k          C-h C-k            (actual C-k typed by user)
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 8.  Full configuration example
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?h . ("C-h" . nil))     ; SPC h -> C-h prefix, no modifier
;;            (?x . ("C-x" . "C-"))   ; SPC x -> C-x prefix, modifier="C-"
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
  '(("<SPC>" ("C-c" nil)
     (?e . "C-M-")
     (?m . "M-")                        ;spc m a=M-a
     (?h . ("C-h" . nil))               ;spc h k=C-h k (no modifier)
     (?c . "C-c")
     (?x . ("C-x" . "C-"))))           ;spc x f=C-x C-f (modifier=C-)
  "List of leader key configurations.
Each element is a list (LEADER-KEY DEFAULT-PREFIX . DISPATCH-ALIST).
LEADER-KEY is a key description string for `keymap-set'.
DEFAULT-PREFIX specifies the prefix and default modifier behaviour.
  It can be either:
  - A string \"C-c\": modifier defaults to \"C-\" (auto-add C- to keys).
  - A list (\"C-c\" MODIFIER): modifier defaults to MODIFIER.
    MODIFIER is a string like \"C-\" or \"M-\", or nil for no modifier.
DISPATCH-ALIST is an alist mapping characters to dispatch targets.

Each dispatch target can be either:
- A string: e.g. \"C-x\", \"M-\", \"C-\"
  After dispatching, modifier resets to modifier-default.
- A cons (STRING . MODIFIER): e.g. (\"C-x\" . \"C-\"), (\"C-h\" . nil)
  After dispatching, modifier is set to the specified MODIFIER value.

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
                                      (const :tag "No modifier" nil))))
                (repeat :inline t
                        (cons (character :tag "From key")
                              (choice (string :tag "Target sequence")
                                      (cons (string :tag "Target sequence")
                                            (choice (string :tag "Modifier override")
                                                    (const :tag "No modifier" nil)))))))))

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
  "Parse a dispatch VAL into (TARGET . MODIFIER-OVERRIDE).
VAL can be:
- A string like \"C-x\":       returns (\"C-x\" . default)
- A cons (\"C-x\" . \"C-\"):    returns (\"C-x\" . \"C-\")
- A cons (\"C-x\" . nil):      returns (\"C-x\" . nil)
The cdr of the return value is the symbol `default' when no
modifier override is specified, or a modifier string/nil when
explicitly set."
  (if (consp val)
      (cons (car val) (cdr val))
    (cons val 'default)))

(defun leader--make-handler (default-prefix modifier-default dispatch-alist)
  "Return a key-translation-map handler for a leader key.
DEFAULT-PREFIX is the fallback prefix string.
MODIFIER-DEFAULT is the default modifier string (e.g. \"C-\", \"M-\")
or nil for no modifier.  It controls how subsequent ordinary keys
are wrapped.
DISPATCH-ALIST maps characters to dispatch targets.

When MODIFIER is non-nil, keys are tried as MODIFIER+char first,
falling back to plain char if no binding exists.
When MODIFIER is nil, keys are tried as plain char first,
falling back to MODIFIER-DEFAULT+char.

The leader key itself (when not in DISPATCH-ALIST) and any dispatch
entry with target \"C-\" act as toggles: they switch MODIFIER between
MODIFIER-DEFAULT and nil (or \"C-\" if MODIFIER-DEFAULT is also nil).

Each dispatch entry value can be:
- A string: e.g. \"C-x\", \"M-\", \"C-\"
- A cons (STRING . MODIFIER): e.g. (\"C-x\" . \"C-\") to set modifier
  to \"C-\" after switching to the C-x prefix."
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
                 (keys default-prefix)
                 (which-key-this-command-keys-function (lambda () (kbd keys)))
                 (need-read t)
                 char raw-val parsed target mod-override binding char2 prompt)
            ;; Unified read-and-dispatch loop.
            (while need-read
              (setq prompt (leader--prompt keys modifier))
              (setq char (read-event prompt))
              (setq raw-val (alist-get char dispatch-alist))
              (setq parsed (leader--parse-dispatch raw-val))
              (setq target (car parsed))
              (setq mod-override (cdr parsed))
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
                (setq need-read nil))
               ;; Direct match for sequences like "C-x"
               (target
                (setq keys (if (string= keys default-prefix)
                               (concat target)
                             (concat keys " " target)))
                (setq modifier (if (eq mod-override 'default) modifier-default mod-override))
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
                      ;; fallback: try modifier-default + char
                      (let ((fb-key (when modifier-default
                                      (concat keys " " modifier-default desc))))
                        (if (and fb-key (key-binding (kbd fb-key)))
                            (setq keys fb-key)
                          (setq keys plain-key))))))
                (setq modifier modifier-default)
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
                (setq mod-override (cdr parsed))
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
                  (setq need-read nil))
                 ;; Direct match in dispatch
                 (target
                  (setq keys (concat keys " " target))
                  (setq modifier (if (eq mod-override 'default) modifier-default mod-override))
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
                        (let ((fb-key (when modifier-default
                                        (concat keys " " modifier-default desc))))
                          (if (and fb-key (key-binding (kbd fb-key)))
                              (setq keys fb-key)
                            (setq keys plain-key))))))
                  (setq modifier modifier-default)
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
           (dispatch-alist (cddr entry))
           (handler (leader--make-handler default-prefix modifier-default dispatch-alist)))
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
