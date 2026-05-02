;;; leader.el --- Leader key configuration -*- lexical-binding: t; -*-

;; Author: jixiuf
;; Keywords: convenience
;; Version: 0.2
;; URL: https://github.com/jixiuf/leader
;; Package-Requires: ((emacs "30.1"))

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

;; leader.el — a modal leader-key package for Emacs.
;;
;; It intercepts one or more "leader keys" via `key-translation-map' and
;; translates subsequent keystrokes into standard Emacs key sequences.
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;  Quick start
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;;   (require 'leader)
;;   (leader-mode 1)
;;
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;  Configuration (keyword format)
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;;   (setq leader-keys
;;    '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
;;       :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-"))
;;                  (?h . (:prefix "C-h" :modifier nil  :fallback "C-"))
;;                  (?m . (:prefix nil  :modifier "M-" :fallback nil))))
;;      (:key "," :prefix nil :modifier "C-M-" :fallback nil)))
;;
;; Each entry is a plist:
;;   :key       - leader key string ("<SPC>", ",")
;;   :prefix    - target prefix string ("C-c", "C-x", nil for modifier-only)
;;   :modifier  - default modifier ("C-", "M-", nil)
;;   :fallback  - fallback modifier (nil = plain only)
;;   :toggle    - toggle target modifier (default: inferred)
;;   :dispatch  - alist (CHAR . PLIST) or (CHAR . :toggle)
;;   :pass-through-predicates - per-key override, nil = use global

;;; Code:

(require 'cl-lib)

(defgroup leader nil
  "Leader key configuration."
  :group 'convenience)

(defcustom leader-keys nil
  "List of leader key configurations.
Each element is a plist — see file commentary for keys."
  :type '(repeat sexp)
  :group 'leader
  :set (lambda (sym val)
         (set-default sym val)
         (when (and (bound-and-true-p leader-mode)
                    (fboundp 'leader--normalize-config))
           (leader--install))))

(defcustom leader-pass-through-predicates '(minibufferp isearch-mode)
  "Predicates determining when the leader key passes through as is.
Each element can be:
- A function (or lambda): called with no arguments, pass-through if non-nil.
- A symbol: checked in order:
  1. Variable binding (boundp) → non-nil value.
  2. If commandp and matches major-mode → t.
  3. If fboundp and NOT commandp → funcall.
  Commands are never called (avoids accidentally toggling modes)."
  :type '(repeat (choice function symbol))
  :group 'leader)

(defcustom leader-dispatch-priority nil
  "How to resolve dispatch vs. bound-command conflicts.
nil      — dispatch entries always win.
t        — bound commands always win (including fallback matches).
:primary — bound commands win only for primary matches (not fallback)."
  :type '(choice (const :tag "Dispatch wins" nil)
                 (const :tag "Command wins" t)
                 (const :tag "Command wins (primary only)" :primary))
  :group 'leader)

(defcustom leader-toggle-priority nil
  "How to resolve toggle vs. bound-command conflicts.
nil      — toggle always wins (default).
t        — bound command wins over toggle.
:primary — primary command wins over toggle, fallback toggle wins."
  :type '(choice (const :tag "Toggle wins" nil)
                 (const :tag "Command wins" t)
                 (const :tag "Command wins (primary only)" :primary))
  :group 'leader)


;;; Internal state

(defvar leader--event-reader #'read-event
  "Function to read events.  Override for testing.")

(defvar leader--key-lookup-fn nil
  "If non-nil, a function (KEY-STRING) used instead of `key-binding'/`kbd'.")

(defvar leader--which-key-show-fn nil
  "Hook set by `leader-which-key' to show which-key popup for a prefix.")

(defvar leader--which-key-modifier-read-fn nil
  "Hook set by `leader-which-key' to read a key with modifier-filtered popup.")

(defvar leader--which-key-read-event-fn nil
  "Hook set by `leader-which-key' to read an event with paging support.
Called as (PROMPT-FN) where PROMPT-FN returns the echo-area prompt.
Should return the event character.")

(defvar leader--normalized-config nil
  "Cached normalized configuration.")

(defvar leader--installed nil
  "Non-nil when leader key handlers are installed in `key-translation-map'.")


;;; Data structures

(cl-defstruct leader-context
  "Normalized context for a leader key or dispatch entry.
All fields are fully resolved at config-normalize time; no runtime
default-filling or conditional logic is needed."
  prefix                        ; "C-x", "C-c", nil (modifier-only)
  modifier                      ; "C-", "M-", nil
  fallback                      ; "C-", nil (always explicit)
  toggle-target                 ; "C-", nil
  dispatch-alist                ; ((char . leader-context) ...)  ; root-level
  local-dispatch-alist          ; ((char . leader-context) ...)  ; cont-only, nil=use root
  leader-char                   ; integer: leader key event
  pass-through-predicates)      ; nil=use global, list=per-key override


;;; Normalization

(defun leader--infer-toggle (modifier fallback)
  "Infer toggle target from MODIFIER and FALLBACK.
If FALLBACK differs from MODIFIER, toggle to FALLBACK.
Otherwise, toggle MODIFIER on/off (non-nil → nil, nil → \"C-\")."
  (cond ((and fallback (not (equal modifier fallback))) fallback)
        (modifier nil)
        (t "C-")))

(defun leader--normalize-prefix-plist (plist)
  "Normalize a prefix PLIST into (PREFIX MODIFIER FALLBACK TOGGLE LOCAL-DISPATCH)."
  (let* ((prefix (plist-get plist :prefix))
         (modifier (plist-get plist :modifier))
         (fallback (plist-get plist :fallback))
         (has-fb (plist-member plist :fallback))
         (toggle (plist-get plist :toggle))
         (local-dispatch (plist-get plist :dispatch)))
    ;; Normalize empty-string to nil
    (when (and prefix (string-empty-p prefix))
      (setq prefix nil))
    (when (and modifier (string-empty-p modifier))
      (setq modifier nil))
    (when (and fallback (string-empty-p fallback))
      (setq fallback nil))
    (when (and toggle (string-empty-p toggle))
      (setq toggle nil))
    (list prefix
          modifier
          (if has-fb fallback
            (if (null prefix) nil modifier))
          (or toggle (leader--infer-toggle modifier fallback))
          local-dispatch)))

(defun leader--normalize-dispatch (alist)
  "Normalize dispatch ALIST into ((CHAR . leader-context) ...)."
  (mapcar
   (lambda (entry)
     (let ((char (car entry))
           (val (cdr entry)))
       (cond
        ((eq val :toggle)
         (cons char (make-leader-context
                     :prefix nil :modifier nil :fallback nil
                     :toggle-target "C-"
                     :dispatch-alist nil
                     :local-dispatch-alist nil
                     :pass-through-predicates nil)))
        ((and (consp val) (keywordp (car val)))
         (let* ((norm (leader--normalize-prefix-plist val))
                (prefix (nth 0 norm))
                (modifier (nth 1 norm))
                (fallback (nth 2 norm))
                (toggle (nth 3 norm))
                (local-dispatch
                 (let ((sub (nth 4 norm)))
                   (when sub (leader--normalize-dispatch sub)))))
           (cons char (make-leader-context
                       :prefix prefix :modifier modifier
                       :fallback fallback :toggle-target toggle
                       :dispatch-alist nil
                       :local-dispatch-alist local-dispatch
                       :pass-through-predicates
                       (plist-get val :pass-through-predicates)))))
        (t (error "Invalid dispatch value: %S" val)))))
   alist))

(defun leader--normalize-config ()
  "Normalize `leader-keys' into a list of `leader-context' structs."
  (setq leader--normalized-config
        (mapcar
         (lambda (entry)
           (let* ((key-str (plist-get entry :key))
                  (prefix-plist
                   (list :prefix (plist-get entry :prefix)
                         :modifier (plist-get entry :modifier)
                         :fallback (plist-get entry :fallback)
                         :toggle (plist-get entry :toggle)))
                  (norm (leader--normalize-prefix-plist prefix-plist))
                  (prefix (nth 0 norm))
                  (modifier (nth 1 norm))
                  (fallback (nth 2 norm))
                  (toggle (nth 3 norm))
                  (disp (leader--normalize-dispatch
                         (plist-get entry :dispatch))))
             (make-leader-context
              :prefix prefix
              :modifier modifier
              :fallback fallback
              :toggle-target toggle
              :dispatch-alist disp
              :local-dispatch-alist nil
              :leader-char (aref (kbd key-str) 0)
              :pass-through-predicates
              (plist-get entry :pass-through-predicates))))
         leader-keys)))


;;; Key building

(defun leader--empty-p (s)
  "Return non-nil if S is nil or the empty string."
  (or (null s) (string-empty-p s)))

(defun leader--lookup-key (keystr)
  "Look up KEYSTR.  Uses `leader--key-lookup-fn' if set."
  (if leader--key-lookup-fn
      (funcall leader--key-lookup-fn keystr)
    (key-binding (kbd keystr))))

(defun leader--resolve-key (prefix modifier fallback char)
  "Resolve CHAR to (KEY-STRING . FALLBACK-P) using PREFIX, MODIFIER, and FALLBACK.
Resolution order:
- modifier non-nil: try MODIFIER+CHAR, else plain CHAR.
- modifier nil: try plain CHAR, else FALLBACK+CHAR."
  (let* ((desc (single-key-description char))
         (plain-key (concat prefix " " desc))
         (mod-key (when modifier (concat prefix " " modifier desc)))
         (fb-key (when fallback (concat prefix " " fallback desc))))
    (cond ((and modifier mod-key (leader--lookup-key mod-key))
           (cons mod-key nil))
          (modifier (cons plain-key t))
          ((leader--lookup-key plain-key) (cons plain-key nil))
          ((and fb-key (leader--lookup-key fb-key)) (cons fb-key t))
          (t (cons plain-key t)))))

(defun leader--binding-is-prefix-keymap-p (binding)
  "Non-nil if BINDING is a prefix keymap.
Handles keymap objects and symbol variables holding keymaps."
  (or (keymapp binding)
      (and (symbolp binding)
            (boundp binding)
            (keymapp (symbol-value binding)))))

(defun leader--binding-sort (a b)
  "Sort A and B: plain before angle-bracket, shorter first, alphabetical."
  (let* ((ka (car a)) (kb (car b))
         (ba (if (string-match-p "[<>]" ka) 1 0))
         (bb (if (string-match-p "[<>]" kb) 1 0)))
    (or (< ba bb)
        (and (= ba bb) (< (string-width ka) (string-width kb)))
        (and (= ba bb) (= (string-width ka) (string-width kb))
             (string< ka kb)))))

(defun leader--collect-modifier-bindings (target)
  "Collect bindings from all active keymaps matching TARGET modifier prefix."
  (let ((bindings nil)
        (seen (make-hash-table :test 'equal)))
    (cl-flet ((push-binding
                (desc def)
                (when (and (string-prefix-p target desc)
                           (not (eq def 'undefined))
                           (not (gethash desc seen)))
                  (let ((rest (substring desc (length target))))
                    (when (and (not (string-match-p "[ACHMSs]-" rest))
                               (not (and (member target '("M-" "C-M-"))
                                         (string-match-p "\\`[1-9]\\'" rest)
                                         (eq def 'digit-argument))))
                      (puthash desc t seen)
                      (push (cons desc
                                  (cond ((keymapp def) "prefix")
                                        ((symbolp def) (symbol-name def))
                                        (t (format "%s" def))))
                            bindings))))))
      (dolist (map (current-active-maps t))
        (map-keymap
         (lambda (ev def)
           (cond
            ((eq ev 27)
             (when (keymapp def)
               (map-keymap
                (lambda (sub-ev sub-def)
                  (cond
                   ((integerp sub-ev)
                    (let* ((meta-ev (event-apply-modifier sub-ev 'meta 27 "M-"))
                           (desc (key-description (vector meta-ev))))
                      (push-binding desc sub-def)))
                   ((consp sub-ev)
                    (cl-loop for i from (car sub-ev) to (cdr sub-ev)
                             for meta-ev = (event-apply-modifier i 'meta 27 "M-")
                             for desc = (key-description (vector meta-ev))
                             do (push-binding desc sub-def)))))
                def)))
            (t
             (let ((desc (key-description (vector ev))))
               (push-binding desc def)))))
         map)))
    (sort (nreverse bindings) #'leader--binding-sort)))

(defun leader--modifier-has-completions-p (prefix target)
  "Non-nil if TARGET has modifier-prefix completions under PREFIX.
Iterates active keymaps directly and returns on first match."
  (catch 'found
    (dolist (map (current-active-maps t))
      (map-keymap
       (lambda (ev def)
         (when (and (not (eq def 'undefined)) (not (eq ev 'which-key)))
           (let ((desc (key-description (vector ev))))
             (when (string-prefix-p target desc)
               (when (leader--lookup-key (concat prefix " " desc))
                 (throw 'found t))))
           (when (eq ev 27)
             (when (keymapp def)
               (map-keymap
                (lambda (sub-ev _)
                  (cond
                   ((integerp sub-ev)
                    (let* ((meta-ev (event-apply-modifier sub-ev 'meta 27 "M-"))
                           (desc (key-description (vector meta-ev))))
                      (when (string-prefix-p target desc)
                        (when (leader--lookup-key (concat prefix " " desc))
                          (throw 'found t)))))
                   ((consp sub-ev)
                    (cl-loop for i from (car sub-ev) to (cdr sub-ev)
                             for meta-ev = (event-apply-modifier i 'meta 27 "M-")
                             for desc = (key-description (vector meta-ev))
                             when (string-prefix-p target desc)
                             when (leader--lookup-key (concat prefix " " desc))
                             do (throw 'found t)))))
                def)))))
       map))
    nil))

(defun leader--pass-through-p (&optional predicates)
  "Return non-nil if the leader key should pass through.
Uses PREDICATES if non-nil, otherwise `leader-pass-through-predicates'."
  (cl-some
   (lambda (pred)
     (cond
      ((symbolp pred)
       (cond ((boundp pred) (symbol-value pred))
             ((and (commandp pred) (eq major-mode pred)) t)
             ((and (fboundp pred) (not (commandp pred))) (funcall pred))
             (t nil)))
      ((functionp pred) (funcall pred))
      (t nil)))
   (or predicates leader-pass-through-predicates)))


;;; Prompt

(defun leader--prompt (keys modifier)
  "Build echo-area prompt string from KEYS and MODIFIER."
  (if modifier
      (format "%s [%s]-" keys modifier)
    (format "%s -" keys)))

(defun leader--modifier-prefix-prompt (target prefix)
  "Build prompt for TARGET modifier-prefix reading with PREFIX."
  (concat (if (and prefix (not (string-empty-p prefix)))
              (concat prefix " ") "")
          target "-"))


;;; Event reading

(defun leader--read-event-with-which-key (prompt modifier prefix)
  "Read an event with PROMPT, optionally showing which-key popup.
When `leader--which-key-read-event-fn' is set, delegates event
reading to it for paging support (C-h n/p). MODIFIER and PREFIX are
passed to the which-key show function."
  (when leader--which-key-show-fn
    (funcall leader--which-key-show-fn prefix modifier))
  (if leader--which-key-read-event-fn
      (funcall leader--which-key-read-event-fn (lambda () prompt))
    (funcall leader--event-reader prompt)))

(defun leader--read-modifier-event (target prefix)
  "Read a second key after a TARGET modifier-prefix dispatch with PREFIX."
  ;; Temporarily override which-key's command-keys tracking during
  ;; modifier-prefix read so it doesn't show the old C-c bindings.
  (with-no-warnings
    (let ((which-key-this-command-keys-function (lambda () [])))
      (if leader--which-key-modifier-read-fn
          (funcall leader--which-key-modifier-read-fn target prefix)
        (progn
          (message "%s" (leader--modifier-prefix-prompt target prefix))
          (funcall leader--event-reader
                   (leader--modifier-prefix-prompt target prefix)))))))


;;; Core handler

(defun leader--command-wins-p (priority fallback-p)
  "Return non-nil if a bound command should win under PRIORITY with FALLBACK-P."
  (cond ((null priority) nil)
        ((eq priority :primary) (not fallback-p))
        (t t)))

(defun leader--process-char (ctx char prefix-keys continuation-p)
  "Process CHAR in CTX, mutating CTX and PREFIX-KEYS in place.
CTX is a `leader-context', PREFIX-KEYS is (ACCUMULATED . MODIFIER).
CONTINUATION-P is non-nil inside a prefix keymap continuation.
Returns :done, :continue, or nil (toggle, re-read)."
  (cl-block leader--process-char
    (let* ((acc (car prefix-keys))
           (current-modifier (cdr prefix-keys))
           ;; In continuation prefer local dispatch, fall back to root
           (alist (if continuation-p
                      (or (leader-context-local-dispatch-alist ctx)
                          (leader-context-dispatch-alist ctx))
                    (leader-context-dispatch-alist ctx)))
           (dispatch (assq char alist))
           (dispatch-ctx (cdr dispatch))
           (is-toggle-dispatch
            (and dispatch
                 (leader--empty-p (leader-context-prefix dispatch-ctx))
                 (null (leader-context-modifier dispatch-ctx))
                 (leader-context-toggle-target dispatch-ctx)))
           (is-direct-dispatch
            (and dispatch (not is-toggle-dispatch)
                 (not (leader--empty-p (leader-context-prefix dispatch-ctx)))))
           (is-modifier-dispatch
            (and dispatch (not is-toggle-dispatch) (not is-direct-dispatch)
                 (leader--empty-p (leader-context-prefix dispatch-ctx))
                 (leader-context-modifier dispatch-ctx)))
           (suppressed (and continuation-p is-direct-dispatch)))

      (when suppressed
        (setq dispatch nil dispatch-ctx nil
              is-toggle-dispatch nil is-direct-dispatch nil
              is-modifier-dispatch nil))

      ;; Prefer-command: check if bound command should win over dispatch
      (let ((cmd-result
             (and dispatch (not is-toggle-dispatch)
                  (not (eq leader-dispatch-priority nil))
                  (let* ((resolved (leader--resolve-key
                                    acc current-modifier
                                    (leader-context-fallback ctx) char))
                         (key-str (car resolved))
                         (fallback-p (cdr resolved)))
                    (when (and (leader--lookup-key key-str)
                               (commandp (leader--lookup-key key-str) t)
                               (leader--command-wins-p
                                leader-dispatch-priority fallback-p))
                      (cons key-str
                            (if (and (not (string-empty-p key-str))
                                     (leader--binding-is-prefix-keymap-p
                                      (leader--lookup-key key-str)))
                                :continue :done)))))))
        (when cmd-result
          (setcar prefix-keys (car cmd-result))
          (setcdr prefix-keys (leader-context-modifier ctx))
          (cl-return-from leader--process-char (cdr cmd-result))))

      (cond
       ;; Toggle
       ((or is-toggle-dispatch
            (and (null dispatch) (eq char (leader-context-leader-char ctx))))
        (when (not (eq leader-toggle-priority nil))
          (let* ((resolved (leader--resolve-key
                            acc current-modifier
                            (leader-context-fallback ctx) char))
                 (key-str (car resolved))
                 (fallback-p (cdr resolved)))
            (when (and (leader--lookup-key key-str)
                       (commandp (leader--lookup-key key-str) t)
                       (leader--command-wins-p
                        leader-toggle-priority fallback-p))
              (setcar prefix-keys key-str)
              (setcdr prefix-keys (leader-context-modifier ctx))
              (cl-return-from leader--process-char :done))))
        (let ((target (if (and is-toggle-dispatch dispatch-ctx)
                          (leader-context-toggle-target dispatch-ctx)
                        (leader-context-toggle-target ctx))))
          (setcdr prefix-keys (if current-modifier nil target)))
        nil)

       ;; Modifier-prefix dispatch: read second key
       (is-modifier-dispatch
        (let* ((new-modifier (leader-context-modifier dispatch-ctx))
               (new-fallback (leader-context-fallback dispatch-ctx))
               (new-toggle (leader-context-toggle-target dispatch-ctx))
               (target (or new-modifier ""))
               (char2 nil))
          (if (and continuation-p
                   (not (leader--modifier-has-completions-p acc target)))
              (let ((resolved (leader--resolve-key
                               acc current-modifier
                               (leader-context-fallback ctx) char)))
                (setcar prefix-keys (car resolved))
                (setcdr prefix-keys (leader-context-modifier ctx))
                (cl-return-from leader--process-char :done))
            (setq char2 (leader--read-modifier-event
                         target (if continuation-p acc "")))
            (setcar prefix-keys
                    (if continuation-p
                        (concat acc " " target (single-key-description char2))
                      (concat target (single-key-description char2))))
            (setcdr prefix-keys (leader-context-modifier ctx))
            (setf (leader-context-fallback ctx) new-fallback
                  (leader-context-modifier ctx) new-modifier
                  (leader-context-toggle-target ctx) new-toggle))
          :done))

       ;; Direct dispatch (prefix switch) or no dispatch
       (t
        (if dispatch-ctx
            (let ((new-prefix (leader-context-prefix dispatch-ctx))
                  (new-modifier (leader-context-modifier dispatch-ctx))
                  (new-fallback (leader-context-fallback dispatch-ctx))
                  (new-toggle (leader-context-toggle-target dispatch-ctx))
                  (new-local-dispatch
                   (leader-context-local-dispatch-alist dispatch-ctx)))
              (setcar prefix-keys new-prefix)
              (setcdr prefix-keys new-modifier)
              (setf (leader-context-fallback ctx) new-fallback
                    (leader-context-modifier ctx) new-modifier
                    (leader-context-prefix ctx) new-prefix
                    (leader-context-toggle-target ctx) new-toggle
                    (leader-context-local-dispatch-alist ctx)
                    new-local-dispatch))
          (let ((resolved (leader--resolve-key
                           acc current-modifier
                           (leader-context-fallback ctx) char)))
            (setcar prefix-keys (car resolved))
            (setcdr prefix-keys (leader-context-modifier ctx))))
        (let* ((resolved-key (car prefix-keys))
               (binding (leader--lookup-key resolved-key)))
          (if (and (not (string-empty-p resolved-key))
                   (leader--binding-is-prefix-keymap-p binding))
              :continue :done)))))))

(defun leader--run-handler (vkeys ctx)
  "Process leader key event VKEYS using CTX, return translated key vector."
  (let* ((len (length vkeys))
         (leader (aref vkeys (1- len))))
    (setf (leader-context-leader-char ctx) leader)
    (cond
     ((leader--pass-through-p (leader-context-pass-through-predicates ctx))
      (vector leader))
     ((= len 1)
      (with-no-warnings
        (let ((which-key-inhibit t))
          (condition-case nil
              (let* ((prefix-keys (cons (leader-context-prefix ctx)
                                        (leader-context-modifier ctx)))
                     (continuation-p nil)
                     (state :read)
                     (which-key-this-command-keys-function
                      (lambda () (kbd (car prefix-keys)))))
                (while (not (eq state :done))
                  (let ((char (leader--read-event-with-which-key
                               (leader--prompt (car prefix-keys)
                                               (cdr prefix-keys))
                               (cdr prefix-keys) (car prefix-keys))))
                    (setq state (leader--process-char
                                 ctx char prefix-keys continuation-p))
                    (when (eq state :continue)
                      (setq continuation-p t state :read))))
                (kbd (car prefix-keys)))
            (quit
             (when (fboundp 'which-key--hide-popup)
               (ignore-errors (which-key--hide-popup)))
             (setq which-key--pages-obj nil)
             nil)))))
     (t (vector leader)))))

(defun leader--make-handler (ctx)
  "Return a `key-translation-map' handler closure for CTX."
  (lambda (_)
    (leader--run-handler (this-command-keys-vector) (copy-leader-context ctx))))


;;; Install / uninstall

(defun leader--uninstall ()
  "Remove all leader key handlers from `key-translation-map'."
  (when leader--installed
    (dolist (ctx leader--normalized-config)
      (let ((kv (kbd (key-description (vector (leader-context-leader-char ctx))))))
        (define-key key-translation-map kv nil))))
  (setq leader--installed nil))

(defun leader--install ()
  "Install all leader key handlers into `key-translation-map'."
  (leader--uninstall)
  (leader--normalize-config)
  (dolist (ctx leader--normalized-config)
    (define-key key-translation-map
                (kbd (key-description (vector (leader-context-leader-char ctx))))
                (leader--make-handler ctx)))
  (setq leader--installed t))

;;;###autoload
(define-minor-mode leader-mode
  "Global minor mode for leader key support.
When enabled, leader keys defined in `leader-keys' are activated
in `key-translation-map'."
  :global t
  :group 'leader
  (if leader-mode (leader--install) (leader--uninstall)))

(provide 'leader)

;; Local Variables:
;; coding: utf-8
;; End:
;;; leader.el ends here
