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
;; - DEFAULT-PREFIX  The Emacs key prefix that the leader maps to by
;;                   default (e.g. "C-c", "M-o").
;; - DISPATCH-ENTRY  An alist entry (CHAR . TARGET) that overrides
;;                   the default prefix for a specific first keystroke.
;;
;; Example -- single leader:
;;
;;   (setq leader-keys
;;         '(("<SPC>" "C-c"
;;            (?h . "C-h")       ; SPC h ... -> C-h ...
;;            (?c . "C-c")       ; SPC c ... -> C-c ...
;;            (?x . "C-x"))))    ; SPC x ... -> C-x ...
;;
;; Example -- multiple leaders:
;;
;;   (setq leader-keys
;;         '(("<SPC>" "C-c"
;;            (?h . "C-h")
;;            (?c . "C-c")
;;            (?x . "C-x"))
;;           ("," "M-o")))       ; , ... -> M-o ...
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 3.  Dispatch entry types
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; 3a.  Prefix switch  --  (CHAR . "C-x")
;;
;;   Replaces the default prefix entirely.
;;
;;     (?x . "C-x")    SPC x f   -> C-x C-f  (find-file)
;;     (?h . "C-h")    SPC h k   -> C-h k    (describe-key)
;;
;; 3b.  Modifier prefix  --  (CHAR . "M-")   (value ends with "-")
;;
;;   Reads one more key and prepends the modifier.
;;
;;     (?r . "M-")     SPC r x   -> M-x      (execute-extended-command)
;;     (?e . "C-M-")   SPC e f   -> C-M-f    (forward-sexp)
;;
;; 3c.  Control toggle  --  (CHAR . "C-")
;;
;;   This is the special "C-" dispatch value.  It controls whether
;;   subsequent ordinary keys (those without a dispatch match) are
;;   automatically wrapped with the Control modifier.
;;
;;   The automatic-C- behaviour depends on whether the leader key
;;   itself has a "C-" entry in the dispatch alist:
;;
;;   ┌────────────────────────────────────┬────────────────────────┐
;;   │ Configuration                      │ Default behaviour      │
;;   ├────────────────────────────────────┼────────────────────────┤
;;   │ Leader char NOT in dispatch as "C-"│ ctrl-on = t  (add C-) │
;;   │ Leader char IS in dispatch as "C-" │ ctrl-on = nil (no C-) │
;;   └────────────────────────────────────┴────────────────────────┘
;;
;;   Pressing a key that dispatches to "C-" sets ctrl-on to the
;;   OPPOSITE of the default, so it acts as a toggle.
;;
;;   In both cases, if the preferred form has no binding, it falls
;;   back to the opposite form automatically.
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; 4.  Detailed examples of the "C-" toggle
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; ── Example A: leader char NOT mapped to "C-" (default: add C-) ──
;;
;;   (setq leader-keys
;;         '(("<SPC>" "C-c"
;;            (?h . "C-h")
;;            (?x . "C-x"))))
;;
;;   Here SPC (?\s) is NOT in the dispatch alist, so ctrl-default = t.
;;   Ordinary keys are wrapped with C- first; if no binding, fall back
;;   to plain key.
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c C-f            ctrl-on=t, try C-c C-f first
;;   SPC f  (no C-c C-f binding)
;;                      C-c f              fallback to plain f
;;   SPC x f            C-x C-f            dispatch x->C-x, then C-f
;;   SPC x SPC f        C-x f              SPC has no dispatch, so
;;                                         treated as normal key;
;;                                         ctrl-on=t -> try C-x C-SPC,
;;                                         no binding -> C-x SPC,
;;                                         that's a prefix -> read f,
;;                                         ctrl-on=t -> C-x SPC C-f,
;;                                         ... (depends on bindings)
;;   SPC h k            C-h k              dispatch h->C-h, k is plain
;;                                         (ctrl-on=t, but C-h C-k has
;;                                         no binding -> fall back C-h k)
;;
;; ── Example B: leader char mapped to "C-" (default: no C-) ─────
;;
;;   (setq leader-keys
;;         '(("<SPC>" "C-c"
;;            (?h . "C-h")
;;            (?\s . "C-")         ; <-- SPC mapped to "C-"
;;            (?x . "C-x"))))
;;
;;   Here SPC (?\s) IS in the dispatch alist as "C-", so
;;   ctrl-default = nil.  Ordinary keys are used plain first; if no
;;   binding, fall back to C-<key>.
;;
;;   Keystrokes         Translation        Explanation
;;   ─────────────────  ─────────────────  ──────────────────────────
;;   SPC f              C-c f              ctrl-on=nil, try C-c f first
;;   SPC f  (no C-c f binding)
;;                      C-c C-f            fallback to C-c C-f
;;   SPC SPC f          C-c C-f            SPC dispatches "C-", sets
;;                                         ctrl-on=t, then f -> C-c C-f
;;   SPC SPC SPC f      C-c C-f            second SPC dispatches "C-"
;;                                         again, ctrl-on=t (same dir)
;;   SPC SPC f SPC g    C-c C-f g          after C-f resolves to prefix,
;;                                         ctrl-on resets to nil (default),
;;                                         SPC dispatches "C-" -> ctrl-on=t,
;;                                         but wait, SPC itself triggers "C-"
;;                                         so read g -> C-c C-f C-g
;;                                         ... (depends on bindings)
;;   SPC x f            C-x C-f            dispatch x->C-x, then ctrl-on
;;                                         resets to nil (default=nil),
;;                                         try C-x f first, no binding ->
;;                                         fall back to C-x C-f
;;   SPC h k            C-h k              dispatch h->C-h, then k plain
;;
;; ── Example C: "," as a second leader ──────────────────────────
;;
;;   (setq leader-keys
;;         '(("<SPC>" "C-c"
;;            (?h . "C-h")
;;            (?\s . "C-")
;;            (?x . "C-x"))
;;           ("," "M-o")))
;;
;;   The "," leader has no dispatch alist at all, so ctrl-default = t.
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
;; Example (with default config, ctrl-default=nil because ?\s->"C-"):
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
;; 7.  Full configuration example
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;;   (setq leader-keys
;;         '(("<SPC>" "C-c"
;;            (?h . "C-h")          ; SPC h -> C-h prefix
;;            (?x . "C-x")          ; SPC x -> C-x prefix
;;            (?c . "C-c")          ; SPC c -> C-c prefix (explicit)
;;            (?\s . "C-")          ; SPC SPC -> toggle C- on
;;            (?r . "M-")           ; SPC r x -> M-x
;;            (?e . "C-M-"))        ; SPC e f -> C-M-f
;;           ("," "M-o")))          ; , -> M-o prefix
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
  '(("<SPC>" "C-c"
     (?\s . "C-")                       ;leader = "C-"
     (?e . "C-M-")
     (?m . "M-")                        ;spc m a=M-a
     (?h . "C-h")                       ;spc h =C-h
     (?c . "C-c")
     (?x . "C-x")))
  "List of leader key configurations.
Each element is a list (LEADER-KEY DEFAULT-PREFIX . DISPATCH-ALIST).
LEADER-KEY is a key description string for `keymap-set'.
DEFAULT-PREFIX is the prefix used when no dispatch match is found.
DISPATCH-ALIST is an alist mapping characters to key sequence strings.
If a dispatch value ends with \"-\" (e.g. \"M-\"), a second key is read
and combined with the prefix."
  :group 'leader
  :type '(repeat
          (list (string :tag "Leader key")
                (string :tag "Default prefix")
                (repeat :inline t
                        (cons (character :tag "From key")
                              (string :tag "To sequence"))))))

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

(defun leader--make-handler (default-prefix dispatch-alist)
  "Return a key-translation-map handler for a leader key.
DEFAULT-PREFIX is the fallback prefix string.
DISPATCH-ALIST maps characters to key sequence strings.
If a dispatch value is \"C-\", pressing that key toggles whether
subsequent keys are automatically combined with Control.
When no \"C-\" dispatch exists for the leader key, C- is added by default;
when it does exist, C- is not added by default."
  (lambda (_)
    (let* ((vkeys (this-command-keys-vector))
           (len (length vkeys))
           (leader (aref vkeys (1- len))))
      (cond
       ((leader--pass-through-p)
        (vector leader))
       ((= len 1)
        (let* ((ctrl-default (not (string= "C-" (alist-get leader dispatch-alist))))
               (ctrl-on ctrl-default)
               (keys default-prefix)
               (which-key-this-command-keys-function (lambda () (kbd keys)))
               (need-read t)
               char val binding char2)
          ;; Unified read-and-dispatch loop.
          ;; First iteration reads the first char after leader;
          ;; subsequent iterations read continuation chars for prefix keys.
          (while need-read
            (setq char (read-event keys))
            (setq val (alist-get char dispatch-alist))
            (cond
             ;; "C-" dispatch: if keys + char is a command, use it;
             ;; otherwise toggle ctrl-on and read next char
             ((and val (string= val "C-"))
              (let* ((desc (single-key-description char))
                     (char-key (concat keys " " desc))
                     (char-binding (key-binding (kbd char-key))))
                (if (commandp char-binding t)
                    (progn (setq keys char-key)
                           (setq need-read nil))
                  (setq ctrl-on (not ctrl-default)))))
             ;; Modifier prefix ending with "-" (like "M-"): read second key and combine
             ((and val (string-suffix-p "-" val))
              (let* ((parts (split-string val " "))
                     (prefix (when (cdr parts)
                               (string-join (butlast parts) " "))))
                (when prefix
                  (setq keys (if (string= keys default-prefix)
                                 prefix
                               (concat keys " " prefix)))))
              (setq char2 (read-event val))
              (setq keys (if (string= keys default-prefix)
                             (concat val (single-key-description char2))
                           (concat keys " " val (single-key-description char2))))
              (setq ctrl-on ctrl-default)
              (setq need-read nil))
             ;; Direct match for sequences like "C-x"
             (val
              (setq keys (if (string= keys default-prefix)
                             (concat val)
                           (concat keys " " val)))
              (setq ctrl-on ctrl-default)
              (setq need-read nil))
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
              (setq val (alist-get char dispatch-alist))
              (cond
               ;; "C-" dispatch: if keys + char is a command, use it;
               ;; otherwise toggle ctrl-on and read next char
               ((and val (string= val "C-"))
                (let* ((desc (single-key-description char))
                       (char-key (concat keys " " desc))
                       (char-binding (key-binding (kbd char-key))))
                  (if (commandp char-binding t)
                      (progn (setq keys char-key)
                             (setq need-read nil))
                    (setq ctrl-on (not ctrl-default)))))
               ;; Modifier prefix ending with "-" (like "M-")
               ((and val (string-suffix-p "-" val))
                (let* ((parts (split-string val " "))
                       (prefix (when (cdr parts)
                                 (string-join (butlast parts) " "))))
                  (setq keys (concat keys " " (or prefix "")))
                  (setq char2 (read-event (concat keys (car (last parts))))))
                (setq keys (concat keys " " val (single-key-description char2)))
                (setq ctrl-on ctrl-default)
                (setq need-read nil))
               ;; Direct match in dispatch
               (val
                (setq keys (concat keys " " val))
                (setq ctrl-on ctrl-default)
                (setq need-read nil))
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
           (default-prefix (cadr entry))
           (dispatch-alist (cddr entry))
           (handler (leader--make-handler default-prefix dispatch-alist)))
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
