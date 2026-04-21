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
;; - DEFAULT-PREFIX  Either a string or a list (STRING BOOL).
;;                   As a string (e.g. "C-c"): ctrl-on defaults to t
;;                   (auto-add C- to subsequent keys).
;;                   As a list (e.g. ("C-c" nil)): ctrl-on defaults
;;                   to the specified BOOL value.
;; - DISPATCH-ENTRY  An alist entry (CHAR . TARGET) that overrides
;;                   the default prefix for a specific first keystroke.
;;
;; Example -- single leader with ctrl-on=t (default):
;;
;;   (setq leader-keys
;;       '(("<SPC>" "C-c"    ; ctrl-on=t, SPC f -> C-c C-f, SPC SPC f -> C-c f
;;          (?h . "C-h")     ; SPC h f -> C-h C-f, SPC h SPC f -> C-h f
;;          (?x . "C-x"))))  ; SPC x f -> C-x C-f, SPC x SPC f -> C-x f
;;
;; Example -- single leader with ctrl-on=nil:
;;
;;   (setq leader-keys
;;    '(("<SPC>" ("C-c" nil)    ; ctrl-on=nil, SPC f->C-c f, SPC SPC f->C-c C-f
;;     (?h . ("C-h" . nil))    ; SPC h a -> C-h a, SPC h SPC a -> C-h C-a
;;     (?\s . "C-")            ; SPC SPC toggles ctrl-on
;;     (?x . ("C-x" . t)))))   ; SPC x f -> C-x C-f, SPC x SPC f -> C-x f
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
;; 3a.  Prefix switch  --  (CHAR . "C-x")  or  (CHAR . ("C-x" . BOOL))
;;
;;   Replaces the default prefix entirely.
;;
;;   Simple form -- ctrl-on resets to ctrl-default after dispatch:
;;     (?x . "C-x")    SPC x f   -> C-x C-f  (if ctrl-default=t)
;;     (?h . "C-h")    SPC h k   -> C-h k    (if ctrl-default=t,
;;                                             but C-h C-k has no binding)
;;
;;   Extended form -- ctrl-on is set to the specified value:
;;     (?x . ("C-x" . t))      SPC x f   -> C-x C-f  (ctrl-on forced to t)
;;     (?h . ("C-h" . nil))    SPC h k   -> C-h k    (ctrl-on forced to nil,
;;                                                     plain key preferred)
;;
;;   This is useful when different prefixes have different conventions:
;;   C-x typically uses C-<key> (e.g. C-x C-f, C-x C-s), so force t.
;;   C-h typically uses plain keys (e.g. C-h k, C-h f), so force nil.
;;
;; 3b.  Modifier prefix  --  (CHAR . "M-")   (value ends with "-")
;;
;;   Reads one more key and prepends the modifier.
;;
;;     (?r . "M-")     SPC r x   -> M-x      (execute-extended-command)
;;     (?e . "C-M-")   SPC e f   -> C-M-f    (forward-sexp)
;;
;; 3c.  Control toggle  --  (CHAR . "C-")  or implicit via leader key
;;
;;   Pressing a key dispatched to "C-", or pressing the leader key
;;   itself when it has no dispatch entry, toggles ctrl-on to the
;;   OPPOSITE of ctrl-default.  This means the leader key always
;;   doubles as a "C-" toggle without explicit configuration.
;;
;;   ctrl-default is determined by the DEFAULT-PREFIX configuration:
;;
;;   ┌──────────────────────────────┬────────────────────────┐
;;   │ DEFAULT-PREFIX               │ ctrl-default           │
;;   ├──────────────────────────────┼────────────────────────┤
;;   │ "C-c"  (plain string)       │ t   (add C-)           │
;;   │ ("C-c" t)                   │ t   (add C-)           │
;;   │ ("C-c" nil)                 │ nil (no C-)            │
;;   └──────────────────────────────┴────────────────────────┘
;;
;;   However, if the key sequence keys + leader-char already has a
;;   command binding (e.g. C-c SPC), that binding is used directly
;;   instead of toggling.
;;
;;   In both cases, if the preferred form has no binding, it falls
;;   back to the opposite form automatically.
;;
;;   You can still explicitly add (?\s . "C-") to the dispatch alist
;;   if you want, but it is no longer required -- the leader key does
;;   this automatically when it has no other dispatch entry.
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 4.  Detailed examples of the "C-" toggle
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; ── Example A: DEFAULT-PREFIX = "C-c" (ctrl-default=t, add C-) ──
;;
;;   (setq leader-keys
;;         '(("<SPC>" "C-c"
;;            (?h . "C-h")
;;            (?x . "C-x"))))
;;
;;   ctrl-default = t (plain string DEFAULT-PREFIX).
;;   Ordinary keys are wrapped with C- first; if no binding, fall back
;;   to plain key.
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c C-f            ctrl-on=t, try C-c C-f first
;;   SPC f  (no C-c C-f binding)
;;                      C-c f              fallback to plain f
;;   SPC x f            C-x C-f            dispatch x->C-x, then C-f
;;   SPC h k            C-h k              dispatch h->C-h, k is plain
;;                                         (ctrl-on=t, but C-h C-k has
;;                                         no binding -> fall back C-h k)
;;
;; ── Example B: DEFAULT-PREFIX = ("C-c" nil) (ctrl-default=nil) ──
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?h . ("C-h" . nil))
;;            (?x . ("C-x" . t)))))
;;
;;   ctrl-default = nil.  Ordinary keys are used plain first; if no
;;   binding, fall back to C-<key>.
;;   SPC itself is not in dispatch, so pressing SPC acts as implicit
;;   "C-" toggle (sets ctrl-on=t).
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c f              ctrl-on=nil, try C-c f first
;;   SPC f  (no C-c f binding)
;;                      C-c C-f            fallback to C-c C-f
;;   SPC SPC f          C-c C-f            SPC = implicit "C-" toggle,
;;                                         ctrl-on=t, then f -> C-c C-f
;;   SPC SPC SPC f      C-c C-f            second SPC toggles again,
;;                                         ctrl-on=t (same direction)
;;   SPC x f            C-x C-f            x->("C-x".t) -> ctrl-on=t
;;   SPC h k            C-h k              h->("C-h".nil) -> ctrl-on=nil
;;
;; ── Example C: "," as a second leader ──────────────────────────
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?h . ("C-h" . nil))
;;            (?\s . "C-")
;;            (?x . ("C-x" . t)))
;;           ("," "M-o")))
;;
;;   The "," leader uses plain string "M-o", so ctrl-default = t.
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   , a                M-o C-a            ctrl-on=t -> try M-o C-a
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
;; step, and ctrl-on resets to ctrl-default after each ordinary key.
;;
;; Example (with ctrl-default=nil, DEFAULT-PREFIX = ("C-c" nil)):
;;
;;   SPC x is dispatched to C-x (a prefix keymap).
;;   Next key f:  ctrl-on=nil -> try C-x f, no binding -> C-x C-f
;;   C-x C-f is `find-file' (a command) -> done.
;;
;; Example (continuation with "C-" toggle):
;;
;;   Suppose C-c C-a is a prefix keymap with sub-bindings C-c C-a b
;;   and C-c C-a C-c.
;;
;;   SPC SPC a      -> C-c C-a (ctrl-on toggled to t by SPC dispatch)
;;   C-c C-a is a prefix, continue reading:
;;     ctrl-on resets to nil (ctrl-default).
;;     Next key b:  try C-c C-a b -> bound! -> done.
;;
;;   SPC SPC a SPC c -> C-c C-a C-c
;;     After C-c C-a, ctrl-on resets to nil.
;;     SPC dispatches "C-" -> ctrl-on=t.
;;     c -> try C-c C-a C-c -> bound! -> done.
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 7.  Per-prefix ctrl-on override
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; By default, after a prefix switch dispatch, ctrl-on resets to
;; ctrl-default.  The extended dispatch form lets you override this
;; per prefix:
;;
;;   (?x . ("C-x" . t))     ; after C-x, prefer C-<key>
;;   (?h . ("C-h" . nil))   ; after C-h, prefer plain <key>
;;   (?c . "C-c")           ; after C-c, reset to ctrl-default
;;
;; Example with ctrl-default=nil (because DEFAULT-PREFIX is ("C-c" nil)):
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?x . ("C-x" . t))          ; force ctrl-on=t after C-x
;;            (?h . ("C-h" . nil)))))      ; force ctrl-on=nil after C-h
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c f              ctrl-default=nil -> plain f
;;   SPC SPC f          C-c C-f            "C-" toggle -> ctrl-on=t
;;   SPC x f            C-x C-f            x->("C-x".t) -> ctrl-on=t
;;   SPC x SPC f        C-x SPC C-f        after C-x, ctrl-on=t already,
;;                                         SPC is plain (C-x C-SPC has
;;                                         no binding -> C-x SPC prefix),
;;                                         then f with ctrl-on=t -> C-f
;;   SPC h k            C-h k              h->("C-h".nil) -> ctrl-on=nil
;;   SPC h C-k          C-h C-k            (actual C-k typed by user)
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 8.  Full configuration example
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;;   (setq leader-keys
;;         '(("<SPC>" ("C-c" nil)
;;            (?h . ("C-h" . nil))     ; SPC h -> C-h prefix, no auto C-
;;            (?x . ("C-x" . t))      ; SPC x -> C-x prefix, force C-
;;            (?c . "C-c")            ; SPC c -> C-c prefix (uses ctrl-default)
;;            (?r . "M-")            ; SPC r x -> M-x
;;            (?e . "C-M-"))         ; SPC e f -> C-M-f
;;           ("," "M-o")))           ; , -> M-o prefix (ctrl-default=t)
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
     (?h . ("C-h" . nil))               ;spc h k=C-h k (no auto C-)
     (?c . "C-c")
     (?x . ("C-x" . t))))              ;spc x f=C-x C-f (force C-)
  "List of leader key configurations.
Each element is a list (LEADER-KEY DEFAULT-PREFIX . DISPATCH-ALIST).
LEADER-KEY is a key description string for `keymap-set'.
DEFAULT-PREFIX specifies the prefix and default ctrl-on behaviour.
  It can be either:
  - A string \"C-c\": ctrl-on defaults to t (auto-add C- to keys).
  - A list (\"C-c\" BOOL): ctrl-on defaults to BOOL.
    t means subsequent keys prefer C-<key>, nil means prefer plain key.
DISPATCH-ALIST is an alist mapping characters to dispatch targets.

Each dispatch target can be either:
- A string: e.g. \"C-x\", \"M-\", \"C-\"
  After dispatching, ctrl-on resets to ctrl-default.
- A cons (STRING . BOOL): e.g. (\"C-x\" . t), (\"C-h\" . nil)
  After dispatching, ctrl-on is set to the specified BOOL value.
  t means subsequent keys prefer C-<key>, nil means prefer plain key.

If a dispatch value (or its car) ends with \"-\" (e.g. \"M-\"),
a second key is read and combined with the modifier.

The special target \"C-\" toggles the ctrl-on state between
ctrl-default and its opposite."
  :group 'leader
  :type '(repeat
          (list (string :tag "Leader key")
                (choice (string :tag "Default prefix")
                        (list (string :tag "Default prefix")
                              (boolean :tag "Default ctrl-on")))
                (repeat :inline t
                        (cons (character :tag "From key")
                              (choice (string :tag "Target sequence")
                                      (cons (string :tag "Target sequence")
                                            (boolean :tag "Force ctrl-on"))))))))

(defcustom leader-pass-through-predicates '(isearch-mode minibufferp)
  "List of predicates controlling when the leader key passes through.
Each element is either:
- A function (or lambda): called with no arguments, pass through if non-nil.
- A symbol naming a variable: pass through if the variable is bound and non-nil."
  :group 'leader
  :type '(repeat (choice function symbol)))

(defvar leader--active-keys nil
  "List of leader key strings currently registered in `key-translation-map'.")

(defun leader--pass-through-p ()
  "Return non-nil if the leader key should pass through as a normal key."
  (seq-some
   (lambda (pred)
     (cond
      ((symbolp pred) (and (boundp pred) (symbol-value pred)))
      ((functionp pred) (funcall pred))
      (t nil)))
   leader-pass-through-predicates))

(defun leader--parse-dispatch (val)
  "Parse a dispatch VAL into (TARGET . CTRL-OVERRIDE).
VAL can be:
- A string like \"C-x\":       returns (\"C-x\" . default)
- A cons (\"C-x\" . t):        returns (\"C-x\" . t)
- A cons (\"C-x\" . nil):      returns (\"C-x\" . nil)
The cdr of the return value is the symbol `default' when no
ctrl-on override is specified, or a boolean (t/nil) when
explicitly set."
  (if (consp val)
      (cons (car val) (cdr val))
    (cons val 'default)))

(defun leader--make-handler (default-prefix ctrl-default dispatch-alist)
  "Return a key-translation-map handler for a leader key.
DEFAULT-PREFIX is the fallback prefix string.
CTRL-DEFAULT is the default value of ctrl-on (t or nil).
DISPATCH-ALIST maps characters to dispatch targets.
If a dispatch target is \"C-\", pressing that key toggles ctrl-on
between CTRL-DEFAULT and its opposite.
When the leader char itself is not in DISPATCH-ALIST, pressing it
acts as an implicit \"C-\" toggle.

Each dispatch entry value can be:
- A string: e.g. \"C-x\", \"M-\", \"C-\"
- A cons (STRING . BOOL): e.g. (\"C-x\" . t) to force ctrl-on=t
  after switching to the C-x prefix."
  (lambda (_)
    (let* ((vkeys (this-command-keys-vector))
           (len (length vkeys))
           (leader (aref vkeys (1- len))))
      (cond
       ((leader--pass-through-p)
        (vector leader))
       ((= len 1)
        (let* ((ctrl-on ctrl-default)
               (keys default-prefix)
               (which-key-this-command-keys-function (lambda () (kbd keys)))
               (need-read t)
               char raw-val parsed target ctrl-override binding char2)
          ;; Unified read-and-dispatch loop.
          ;; First iteration reads the first char after leader;
          ;; subsequent iterations read continuation chars for prefix keys.
          (while need-read
            (setq char (read-event keys))
            (setq raw-val (alist-get char dispatch-alist))
            (setq parsed (leader--parse-dispatch raw-val))
            (setq target (car parsed))
            (setq ctrl-override (cdr parsed))
            (cond
             ;; "C-" dispatch: if keys + char is a command, use it;
             ;; otherwise toggle ctrl-on and read next char
             ((and target (string= target "C-"))
              (let* ((desc (single-key-description char))
                     (char-key (concat keys " " desc))
                     (char-binding (key-binding (kbd char-key))))
                (if (commandp char-binding t)
                    (progn (setq keys char-key)
                           (setq need-read nil))
                  (setq ctrl-on (not ctrl-default)))))
             ;; Modifier prefix ending with "-" (like "M-"): read second key and combine
             ((and target (string-suffix-p "-" target))
              (let* ((parts (split-string target " "))
                     (prefix (when (cdr parts)
                               (string-join (butlast parts) " "))))
                (when prefix
                  (setq keys (if (string= keys default-prefix)
                                 prefix
                               (concat keys " " prefix)))))
              (setq char2 (read-event target))
              (setq keys (if (string= keys default-prefix)
                             (concat target (single-key-description char2))
                           (concat keys " " target (single-key-description char2))))
              (setq ctrl-on (if (eq ctrl-override 'default) ctrl-default ctrl-override))
              (setq need-read nil))
             ;; Direct match for sequences like "C-x"
             (target
              (setq keys (if (string= keys default-prefix)
                             (concat target)
                           (concat keys " " target)))
              (setq ctrl-on (if (eq ctrl-override 'default) ctrl-default ctrl-override))
              (setq need-read nil))
             ;; No dispatch match: if leader char pressed, implicit "C-" toggle
             ;; (check command binding first, then toggle ctrl-on)
             ((and (null target) (eq char leader))
              (let* ((desc (single-key-description char))
                     (char-key (concat keys " " desc))
                     (char-binding (key-binding (kbd char-key))))
                (if (commandp char-binding t)
                    (progn (setq keys char-key)
                           (setq need-read nil))
                  (setq ctrl-on (not ctrl-default)))))
             ;; No dispatch match: apply ctrl-on logic
             (t
              (let* ((desc (single-key-description char))
                     (c-key (concat keys " C-" desc))
                     (plain-key (concat keys " " desc)))
                (if ctrl-on
                    (if (key-binding (kbd c-key))
                        (setq keys c-key)
                      (setq keys plain-key))
                  (if (key-binding (kbd plain-key))
                      (setq keys plain-key)
                    (setq keys c-key))))
              (setq ctrl-on ctrl-default)
              (setq need-read nil))))
          ;; Continue reading while binding is a prefix key (keymap)
          (setq binding (key-binding (kbd keys)))
          (while (not (or (commandp binding t) (null binding)))
            (setq need-read t)
            (while need-read
              (setq char (read-event keys))
              (setq raw-val (alist-get char dispatch-alist))
              (setq parsed (leader--parse-dispatch raw-val))
              (setq target (car parsed))
              (setq ctrl-override (cdr parsed))
              (cond
               ;; "C-" dispatch: if keys + char is a command, use it;
               ;; otherwise toggle ctrl-on and read next char
               ((and target (string= target "C-"))
                (let* ((desc (single-key-description char))
                       (char-key (concat keys " " desc))
                       (char-binding (key-binding (kbd char-key))))
                  (if (commandp char-binding t)
                      (progn (setq keys char-key)
                             (setq need-read nil))
                    (setq ctrl-on (not ctrl-default)))))
               ;; Modifier prefix ending with "-" (like "M-")
               ((and target (string-suffix-p "-" target))
                (let* ((parts (split-string target " "))
                       (prefix (when (cdr parts)
                                 (string-join (butlast parts) " "))))
                  (setq keys (concat keys " " (or prefix "")))
                  (setq char2 (read-event (concat keys (car (last parts))))))
                (setq keys (concat keys " " target (single-key-description char2)))
                (setq ctrl-on (if (eq ctrl-override 'default) ctrl-default ctrl-override))
                (setq need-read nil))
               ;; Direct match in dispatch
               (target
                (setq keys (concat keys " " target))
                (setq ctrl-on (if (eq ctrl-override 'default) ctrl-default ctrl-override))
                (setq need-read nil))
               ;; No dispatch match: if leader char pressed, implicit "C-" toggle
               ((and (null target) (eq char leader))
                (let* ((desc (single-key-description char))
                       (char-key (concat keys " " desc))
                       (char-binding (key-binding (kbd char-key))))
                  (if (commandp char-binding t)
                      (progn (setq keys char-key)
                             (setq need-read nil))
                    (setq ctrl-on (not ctrl-default)))))
               ;; No dispatch match: apply ctrl-on logic
               (t
                (let* ((desc (single-key-description char))
                       (c-key (concat keys " C-" desc))
                       (plain-key (concat keys " " desc)))
                  (if ctrl-on
                      (if (key-binding (kbd c-key))
                          (setq keys c-key)
                        (setq keys plain-key))
                    (if (key-binding (kbd plain-key))
                        (setq keys plain-key)
                      (setq keys c-key))))
                (setq ctrl-on ctrl-default)
                (setq need-read nil))))
            (setq binding (key-binding (kbd keys))))
          (kbd keys)))
       (t
        (vector leader))))))

(defun leader--install ()
  "Install all leader key handlers into `key-translation-map'."
  (leader--uninstall)
  (dolist (entry leader-keys)
    (let* ((leader-key (car entry))
           (prefix-spec (cadr entry))
           (default-prefix (if (consp prefix-spec) (car prefix-spec) prefix-spec))
           (ctrl-default (if (consp prefix-spec) (cadr prefix-spec) t))
           (dispatch-alist (cddr entry))
           (handler (leader--make-handler default-prefix ctrl-default dispatch-alist)))
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
