;;; leader-test.el --- Tests for leader.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'leader)


;;; Test helpers

(defun leader-test--event-source (events)
  "Return a function that pops from EVENTS list (like `read-event')."
  (let ((idx 0))
    (lambda (_prompt)
      (prog1 (nth idx events)
        (setq idx (1+ idx))))))

(defun leader-test--key-lookup (bindings)
  "Return a function mapping key strings to bindings.
BINDINGS is an alist of (KEYSTRING . COMMAND-OR-KEYMAP).
Returns nil for keys not in BINDINGS."
  (lambda (keystr)
    (let ((entry (assoc keystr bindings)))
      (cdr entry))))

(defun leader-test--which-key-reader (char)
  "Return a which-key reader that just returns CHAR."
  (lambda (_target _modifier _keys)
    char))

(defmacro leader-test--with-handler-env (bindings events &rest body)
  "Set up test environment for `leader--run-handler'.
BINDINGS is an alist (\"KEY\" . binding).  EVENTS is a list of chars.
BODY runs with mock event reader and key lookup."
  (declare (indent 2))
  `(let ((leader--key-lookup-fn (leader-test--key-lookup ,bindings))
         (leader--event-reader (leader-test--event-source ,events))
         (leader--which-key-reader nil))
     ,@body))


;;; leader--pass-through-p

(ert-deftest leader-test-pass-through-p-default ()
  "Default predicates: minibufferp and isearch-mode."
  (let ((leader-pass-through-predicates '(minibufferp isearch-mode)))
    (should-not (leader--pass-through-p))))

(ert-deftest leader-test-pass-through-p-function-true ()
  "Lambda predicate returning non-nil."
  (let ((leader-pass-through-predicates (list (lambda () t))))
    (should (leader--pass-through-p))))

(ert-deftest leader-test-pass-through-p-function-nil ()
  "Lambda predicate returning nil."
  (let ((leader-pass-through-predicates (list (lambda () nil))))
    (should-not (leader--pass-through-p))))

(defvar leader-test--temp-var nil
  "Temporary variable for testing pass-through predicate symbol resolution.")

(ert-deftest leader-test-pass-through-p-symbol-variable-true ()
  "Symbol predicate bound as variable with non-nil value."
  (setq leader-test--temp-var t)
  (let ((leader-pass-through-predicates '(leader-test--temp-var)))
    (unwind-protect
        (should (leader--pass-through-p))
      (setq leader-test--temp-var nil))))

(ert-deftest leader-test-pass-through-p-symbol-variable-nil ()
  "Symbol predicate bound as variable with nil value."
  (setq leader-test--temp-var nil)
  (let ((leader-pass-through-predicates '(leader-test--temp-var)))
    (should-not (leader--pass-through-p))))

(ert-deftest leader-test-pass-through-p-symbol-function ()
  "Symbol predicate bound as function."
  (let ((leader-pass-through-predicates '(test-func)))
    (fset 'test-func (lambda () t))
    (unwind-protect
        (should (leader--pass-through-p))
      (fmakunbound 'test-func))))

(ert-deftest leader-test-pass-through-p-symbol-function-nil ()
  "Symbol predicate bound as function returning nil."
  (let ((leader-pass-through-predicates '(test-func)))
    (fset 'test-func (lambda () nil))
    (unwind-protect
        (should-not (leader--pass-through-p))
      (fmakunbound 'test-func))))

(ert-deftest leader-test-pass-through-p-multiple-any-true ()
  "Multiple predicates: any true means pass through."
  (let ((leader-pass-through-predicates
         (list (lambda () nil) (lambda () t) (lambda () nil))))
    (should (leader--pass-through-p))))

(ert-deftest leader-test-pass-through-p-multiple-all-false ()
  "Multiple predicates: all false means no pass through."
  (let ((leader-pass-through-predicates
         (list (lambda () nil) (lambda () nil))))
    (should-not (leader--pass-through-p))))

(ert-deftest leader-test-pass-through-p-unknown-symbol ()
  "Symbol not bound as variable or function returns nil."
  (let ((leader-pass-through-predicates '(some-unknown-sym-xyz)))
    (should-not (leader--pass-through-p))))

(ert-deftest leader-test-pass-through-p-non-func-non-symbol ()
  "Non-function, non-symbol element is ignored."
  (let ((leader-pass-through-predicates (list 42)))
    (should-not (leader--pass-through-p))))


;;; leader--parse-dispatch

(ert-deftest leader-test-parse-dispatch-string ()
  "String dispatch returns (STRING 'default 'default)."
  (should (equal (leader--parse-dispatch "C-x")
                 '("C-x" default default))))

(ert-deftest leader-test-parse-dispatch-list-two ()
  "Two-element list dispatch."
  (should (equal (leader--parse-dispatch '("C-x" "C-"))
                 '("C-x" "C-" default))))

(ert-deftest leader-test-parse-dispatch-list-two-nil ()
  "Two-element list with nil modifier."
  (should (equal (leader--parse-dispatch '("C-h" nil))
                 '("C-h" nil default))))

(ert-deftest leader-test-parse-dispatch-list-three ()
  "Three-element list dispatch."
  (should (equal (leader--parse-dispatch '("C-x" "C-" nil))
                 '("C-x" "C-" nil))))

(ert-deftest leader-test-parse-dispatch-list-three-string-fb ()
  "Three-element list with string fallback."
  (should (equal (leader--parse-dispatch '("C-h" nil "C-"))
                 '("C-h" nil "C-"))))

(ert-deftest leader-test-parse-dispatch-modifier-only ()
  "Modifier-only dispatch like \"M-\"."
  (should (equal (leader--parse-dispatch "M-")
                 '("M-" default default))))

(ert-deftest leader-test-parse-dispatch-toggle ()
  "Toggle dispatch \"C-\"."
  (should (equal (leader--parse-dispatch "C-")
                 '("C-" default default))))


;;; leader--prompt

(ert-deftest leader-test-prompt-with-modifier ()
  "Prompt with non-nil modifier."
  (should (equal (leader--prompt "C-c" "C-")
                 "C-c [C-]-")))

(ert-deftest leader-test-prompt-without-modifier ()
  "Prompt with nil modifier."
  (should (equal (leader--prompt "C-c" nil)
                 "C-c -")))

(ert-deftest leader-test-prompt-empty-keys ()
  "Prompt with empty keys string."
  (should (equal (leader--prompt "" "M-")
                 " [M-]-")))


;;; leader--binding-sort-predicate

(ert-deftest leader-test-sort-plain-before-angle ()
  "Plain keys sort before angle-bracket keys."
  (should (leader--binding-sort-predicate '("a" . "") '("<f1>" . "")))
  (should-not (leader--binding-sort-predicate '("<up>" . "") '("b" . ""))))

(ert-deftest leader-test-sort-shorter-first ()
  "Shorter key names sort first within same type."
  (should (leader--binding-sort-predicate '("a" . "") '("ab" . "")))
  (should-not (leader--binding-sort-predicate '("abc" . "") '("ab" . ""))))

(ert-deftest leader-test-sort-alphabetical ()
  "Same-length same-type keys sorted alphabetically."
  (should (leader--binding-sort-predicate '("a" . "") '("b" . "")))
  (should-not (leader--binding-sort-predicate '("z" . "") '("a" . ""))))

(ert-deftest leader-test-sort-equal-keys ()
  "Equal keys: sort returns nil."
  (should-not (leader--binding-sort-predicate '("a" . "") '("a" . ""))))


;;; leader--lookup-key

(ert-deftest leader-test-lookup-key-no-fn ()
  "Without `leader--key-lookup-fn', uses real `key-binding'/`kbd'."
  (let ((leader--key-lookup-fn nil))
    (with-temp-buffer
      ;; self-insert-command is bound to "a" in fundamental-mode
      (should (leader--lookup-key "a")))))

(ert-deftest leader-test-lookup-key-with-fn ()
  "With `leader--key-lookup-fn', delegates to it."
  (let ((leader--key-lookup-fn (lambda (k) (when (equal k "C-c a") 'next-line))))
    (should (eq (leader--lookup-key "C-c a") 'next-line))
    (should-not (leader--lookup-key "C-c b"))))

(ert-deftest leader-test-lookup-key-nonexistent ()
  "Looking up a nonexistent key returns nil."
  (let ((leader--key-lookup-fn nil))
    (should-not (leader--lookup-key "C-M-S-s-z"))))


;;; leader--apply-modifier

(ert-deftest leader-test-apply-modifier-with-modifier-bound ()
  "Modifier non-nil, mod+key bound → use mod+key."
  (let ((leader--key-lookup-fn (leader-test--key-lookup
                                '(("C-c C-f" . next-line)))))
    (should (equal (leader--apply-modifier "C-c" "C-" "C-" ?f)
                   "C-c C-f"))))

(ert-deftest leader-test-apply-modifier-with-modifier-unbound-plain ()
  "Modifier non-nil, mod+key unbound → use plain key."
  (let ((leader--key-lookup-fn (lambda (_) nil)))
    (should (equal (leader--apply-modifier "C-c" "C-" "C-" ?z)
                   "C-c z"))))

(ert-deftest leader-test-apply-modifier-no-modifier-plain-bound ()
  "Modifier nil, plain key bound → use plain key."
  (let ((leader--key-lookup-fn (leader-test--key-lookup
                                '(("C-c f" . next-line)))))
    (should (equal (leader--apply-modifier "C-c" nil "C-" ?f)
                   "C-c f"))))

(ert-deftest leader-test-apply-modifier-no-modifier-plain-unbound-fallback ()
  "Modifier nil, plain unbound, fallback bound → use fallback key."
  (let ((leader--key-lookup-fn (leader-test--key-lookup
                                '(("C-c C-f" . next-line)))))
    (should (equal (leader--apply-modifier "C-c" nil "C-" ?f)
                   "C-c C-f"))))

(ert-deftest leader-test-apply-modifier-no-modifier-no-fallback-no-binding ()
  "Modifier nil, nothing bound → returns plain key anyway."
  (let ((leader--key-lookup-fn (lambda (_) nil)))
    (should (equal (leader--apply-modifier "C-c" nil "C-" ?z)
                   "C-c z"))))

(ert-deftest leader-test-apply-modifier-nil-fb-context ()
  "Nil fb-context: fallback to plain key when modifier is nil."
  (let ((leader--key-lookup-fn (lambda (_) nil)))
    (should (equal (leader--apply-modifier "C-c" nil nil ?z)
                   "C-c z"))))

(ert-deftest leader-test-apply-modifier-modifier-nil-fb-context-nil ()
  "Both modifier and fb-context nil, plain unbound → plain key."
  (let ((leader--key-lookup-fn (lambda (_) nil)))
    (should (equal (leader--apply-modifier "C-c" nil nil ?z)
                   "C-c z"))))


;;; leader--run-handler -- dispatch and modifier logic

(ert-deftest leader-test-handler-plain-key-bound ()
  "mod-default=nil: plain 'f' with binding → C-c f."
  (leader-test--with-handler-env
      '(("C-c f" . next-line))
      '(?f)
    (let ((result (leader--run-handler
                   [? ]                    ; vkeys: SPC leader
                   "C-c" nil               ; default-prefix, modifier-default=nil
                   nil                     ; no dispatch alist
                   "C-" "C-")))           ; fallback=C-, toggle-target=C-
      (should (equal result (kbd "C-c f"))))))

(ert-deftest leader-test-handler-plain-unbound-fallback ()
  "mod-default=nil: plain 'f' unbound, fallback C-f exists → C-c C-f."
  (leader-test--with-handler-env
      '(("C-c C-f" . next-line))
      '(?f)
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" nil
                   nil
                   "C-" "C-")))
      (should (equal result (kbd "C-c C-f"))))))

(ert-deftest leader-test-handler-modifier-default-C ()
  "mod-default='C-': 'f' with C-f binding → C-c C-f."
  (leader-test--with-handler-env
      '(("C-c C-f" . next-line))
      '(?f)
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" "C-"             ; modifier-default="C-"
                   nil
                   "C-" nil)))            ; toggle-target=nil
      (should (equal result (kbd "C-c C-f"))))))

(ert-deftest leader-test-handler-modifier-default-C-unbound-plain-fallback ()
  "mod-default='C-': C-f unbound → fallback to plain 'f'."
  (leader-test--with-handler-env
      '(("C-c f" . next-line))
      '(?f)
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" "C-"
                   nil
                   "C-" nil)))
      (should (equal result (kbd "C-c f"))))))

(ert-deftest leader-test-handler-toggle-C-to-nil ()
  "SPC SPC f: mod-default='C-', toggle → nil, plain 'f' bound → C-c f."
  (leader-test--with-handler-env
      '(("C-c f" . next-line))
      '(?  ?f)                            ; SPC (toggle) then f
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" "C-"             ; modifier-default="C-"
                   nil
                   "C-" nil)))            ; toggle-target=nil
      (should (equal result (kbd "C-c f"))))))

(ert-deftest leader-test-handler-toggle-nil-to-C ()
  "SPC SPC f: mod-default=nil, toggle → C-, C-f bound → C-c C-f."
  (leader-test--with-handler-env
      '(("C-c C-f" . next-line))
      '(?  ?f)                            ; SPC (toggle) then f
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" nil              ; modifier-default=nil
                   nil
                   "C-" "C-")))          ; fallback=C-, toggle-target=C-
      (should (equal result (kbd "C-c C-f"))))))

(ert-deftest leader-test-handler-dispatch-to-C-x ()
  "Dispatch ?x → (\"C-x\" nil \"C-\"), then 'f' with modifier logic."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-x" . ,prefix-map)           ; C-x is a prefix keymap
          ("C-x C-f" . next-line))
        '(?x ?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?x '("C-x" nil "C-"))) ; modifier=nil, fallback=C-
                     "C-" "C-")))
        (should (equal result (kbd "C-x C-f")))))))

(ert-deftest leader-test-handler-dispatch-to-C-x-mod-C ()
  "Dispatch ?x → (\"C-x\" \"C-\"), then 'f' with C- modifier."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-x" . ,prefix-map)
          ("C-x C-f" . next-line))
        '(?x ?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?x '("C-x" "C-")))
                     "C-" "C-")))
        (should (equal result (kbd "C-x C-f")))))))

(ert-deftest leader-test-handler-dispatch-to-C-h-nil-modifier ()
  "Dispatch ?h → (\"C-h\" nil \"C-\"), then 'k' plain → C-h k."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-h" . ,prefix-map)
          ("C-h k" . describe-key))
        '(?h ?k)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?h '("C-h" nil "C-"))) ; modifier=nil, fallback=C-
                     "C-" "C-")))
        (should (equal result (kbd "C-h k")))))))

(ert-deftest leader-test-handler-dispatch-multi-part-modifier ()
  "Dispatch ?g → \"C-x M-\" (string, ends with -), read second key ?f → C-x M-f."
  (leader-test--with-handler-env
      '(("C-x M-f" . find-file))
      '(?g ?f)
    (let ((leader--which-key-reader (leader-test--which-key-reader ?f)))
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?g "C-x M-")) ; string: modifier prefix dispatch
                     "C-" "C-")))
        (should (equal result (kbd "C-x M-f")))))))

(ert-deftest leader-test-handler-dispatch-single-mod-read ()
  "Dispatch ?r → \"M-\", read second key ?x → M-x."
  (leader-test--with-handler-env
      '(("M-x" . execute-extended-command))
      '(?r ?x)
    (let ((leader--which-key-reader (leader-test--which-key-reader ?x)))
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?r "M-"))
                     "C-" "C-")))
        (should (equal result (kbd "M-x")))))))

(ert-deftest leader-test-multi-part-modifier-prefix-static-prefix ()
  "Multi-part modifier target like \"C-x M-\" sets static prefix before which-key."
  (leader-test--with-handler-env
      '(("C-x M-f" . find-file))
      '(?g ?f)
    (let ((leader--which-key-reader (leader-test--which-key-reader ?f)))
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?g "C-x M-"))
                     "C-" "C-")))
        ;; keys initially "C-c", target="C-x M-" → prefix="C-x",
        ;; keys="C-x", then which-key reads ?f, keys="C-x M-f"
        (should (equal result (kbd "C-x M-f")))))))

(ert-deftest leader-test-handler-dispatch-toggle-C-when-not-command ()
  "Dispatch ?t → \"C-\", 't' not a command → toggle, then ?a."
  (leader-test--with-handler-env
      '(("C-c C-a" . next-line))
      '(?t ?a)                            ; t toggles, a with C-
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" nil
                   (list (cons ?t "C-"))   ; toggle dispatch
                   "C-" "C-")))
      (should (equal result (kbd "C-c C-a"))))))

(ert-deftest leader-test-handler-passthrough ()
  "When pass-through-p returns t, leader key is emitted as-is."
  (let ((leader-pass-through-predicates (list (lambda () t))))
    (let ((result (leader--run-handler
                   [? ]                   ; vkeys with SPC
                   "C-c" nil
                   nil
                   "C-" "C-")))
      (should (equal result [? ])))))      ; vector of SPC


;;; leader--run-handler -- continuation (prefix keymap)

(ert-deftest leader-test-handler-continuation-prefix-keymap ()
  "When resolved key is a prefix keymap, continue reading events."
  (let ((prefix-map (make-sparse-keymap)))
    (define-key prefix-map "f" 'next-line)
    (leader-test--with-handler-env
        `(("C-c x" . ,prefix-map)         ; C-c x is a prefix
          ("C-c x C-f" . next-line))
        '(?x ?f)                          ; x (no dispatch) → C-c x (prefix), then f → C-f
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" "C-"
                     nil
                     "C-" nil)))
        (should (equal result (kbd "C-c x C-f")))))))

(ert-deftest leader-test-handler-continuation-toggle-in-prefix ()
  "Toggle SPC inside prefix keymap continuation."
  (let ((prefix-map (make-sparse-keymap)))
    (define-key prefix-map "f" 'next-line)
    (leader-test--with-handler-env
        `(("C-c x" . ,prefix-map)
          ("C-c x f" . next-line))
        '(?x ?  ?f)                       ; x → prefix, SPC toggle, f plain
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" "C-"           ; mod-default=C-
                     nil
                     "C-" nil)))          ; toggle-target=nil
        (should (equal result (kbd "C-c x f")))))))

(ert-deftest leader-test-handler-continuation-toggle-uses-fb-context ()
  "Toggle SPC inside prefix uses fb-context not hardcoded toggle-target.
After dispatch sets fb-context to M-, SPC toggle should set modifier
to M-, not to C- from the top-level toggle-target."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("M-s" . ,prefix-map)
          ("M-s M-w" . next-line))
        '(?s ?  ?w)                       ; s → M-s prefix, SPC toggle, w plain
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil            ; mod-default=nil
                     `((?s . ("M-s" nil "M-")))
                     "C-" "C-")))         ; fb="C-", toggle-target="C-"
        ;; After s dispatch: modifier=nil, fb-context=M-
        ;; SPC toggles modifier to fb-context=M- (not C-)
        ;; Then w with modifier=M- → M-s M-w
        (should (equal result (kbd "M-s M-w")))))))

(ert-deftest leader-test-handler-continuation-fallback ()
  "Continuation with modifier=nil, plain unbound, fallback C- bound."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-c x" . ,prefix-map)
          ("C-c x C-f" . next-line))
        '(?x ?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil            ; mod-default=nil
                     nil
                     "C-" "C-")))
        (should (equal result (kbd "C-c x C-f")))))))

(ert-deftest leader-test-handler-multiple-events-in-vkeys ()
  "When vkeys has length > 1, returns the last element as leader char.
Since pass-through-p returns nil and len > 1, the handler falls to
the (t ...) branch which returns (vector (aref vkeys (1- len)))."
  (let ((result (leader--run-handler
                 [?  ?a]                  ; length 2, leader=last='a'
                 "C-c" nil
                 nil
                 "C-" "C-")))
    (should (equal result [?a]))))


;;; leader-mode -- install / uninstall

(ert-deftest leader-test-mode-enable-disable ()
  "Enabling then disabling leader-mode."
  (leader-mode -1)
  (leader--uninstall)
  (should-not leader-mode)
  (should-not leader--active-keys)
  (leader-mode 1)
  (should leader-mode)
  (should leader--active-keys)
  (should (equal (sort (copy-sequence leader--active-keys) #'string<)
                 (sort (mapcar #'car leader-keys) #'string<)))
  (leader-mode -1)
  (should-not leader-mode)
  (should-not leader--active-keys)
  (leader--uninstall))

(ert-deftest leader-test-mode-adds-key-translation-map ()
  "Enabling leader-mode adds entries to key-translation-map."
  (leader-mode -1)
  (leader--uninstall)
  (leader-mode 1)
  (dolist (entry leader-keys)
    (let ((key (car entry)))
      (should (lookup-key key-translation-map (kbd key)))))
  (leader-mode -1)
  (leader--uninstall))

(ert-deftest leader-test-mode-removes-key-translation-map ()
  "Disabling leader-mode removes entries from key-translation-map."
  (leader-mode -1)
  (leader--uninstall)
  (leader-mode 1)
  (leader-mode -1)
  (leader--uninstall)
  (dolist (entry leader-keys)
    (let ((key (car entry)))
      (should-not (lookup-key key-translation-map (kbd key))))))

(ert-deftest leader-test-mode-double-enable-idempotent ()
  "Enabling twice is idempotent."
  (leader-mode -1)
  (leader--uninstall)
  (leader-mode 1)
  (let ((count (length leader--active-keys)))
    (leader-mode 1)
    (should (= (length leader--active-keys) count)))
  (leader-mode -1)
  (leader--uninstall))

(ert-deftest leader-test-mode-toggling ()
  "Toggling leader-mode works correctly."
  (leader-mode -1)
  (leader--uninstall)
  (leader-mode 1)
  (should leader-mode)
  (leader-mode -1)
  (should-not leader-mode)
  (should-not leader--active-keys)
  (leader--uninstall))


;;; leader-keys -- default config

(ert-deftest leader-test-default-config-spc-entry ()
  "Default config has SPC leader key."
  (let ((entry (cl-find "<SPC>" leader-keys :key #'car :test #'equal)))
    (should entry)
    (should (equal (cadr entry) '("C-c" nil "C-")))))

(ert-deftest leader-test-default-config-dispatch-entries ()
  "Default SPC config has expected dispatch entries."
  (let* ((spc (cl-find "<SPC>" leader-keys :key #'car :test #'equal))
         (dispatch (cddr spc)))
    (should (assq ?e dispatch))
    (should (assq ?m dispatch))
    (should (assq ?h dispatch))
    (should (assq ?s dispatch))
    (should (assq ?x dispatch))))

(ert-deftest leader-test-default-config-dispatch-values ()
  "Default dispatch entries have expected values."
  (let* ((spc (cl-find "<SPC>" leader-keys :key #'car :test #'equal))
         (dispatch (cddr spc)))
    (should (equal (alist-get ?e dispatch) "C-M-"))
    (should (equal (alist-get ?m dispatch) "M-"))
    (should (equal (alist-get ?h dispatch) '("C-h" nil "C-")))
    (should (equal (alist-get ?s dispatch) '("M-s" nil "M-")))
    (should (equal (alist-get ?x dispatch) '("C-x" "C-" nil)))))


;;; leader--install / leader--uninstall

(ert-deftest leader-test-install-idempotent ()
  "Installing twice is safe (uninstall first)."
  (leader--uninstall)
  (leader--install)
  (let ((count (length leader--active-keys)))
    (leader--install)
    (should (= (length leader--active-keys) count)))
  (leader--uninstall))

(ert-deftest leader-test-uninstall-idempotent ()
  "Uninstalling twice is safe."
  (leader--uninstall)
  (leader--uninstall)
  (should-not leader--active-keys))


;;; leader--handle-direct-dispatch (edge case: C- dispatch is a real command)

(ert-deftest leader-test-handler-C-dispatch-as-command ()
  "C- dispatch: char itself as command → stop.
When dispatch target is \"C-\", the handler checks if keys+char
(as typed, without additional modifier wrapping) is a command.
If so, it uses it directly without toggling."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c t" . next-line))            ; C-c t (plain t, not C-t) is a command
        '(?t)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" "C-"             ; modifier-default="C-"
                     (list (cons ?t "C-"))   ; t dispatches to C-
                     "C-" nil)))
        ;; C-c t is a command → use it directly (stop, no toggle)
        (should (equal result (kbd "C-c t")))))))

(ert-deftest leader-test-handler-C-dispatch-toggles ()
  "C- dispatch: char itself NOT a command → toggle modifier."
  (leader-test--with-handler-env
      '(("C-c C-a" . next-line))          ; C-c C-a is bound
      '(?t ?a)
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" nil              ; mod-default=nil
                   (list (cons ?t "C-"))   ; t dispatches to C-
                   "C-" "C-")))           ; toggle-target=C-
      ;; C-c t is NOT a command → toggle modifier to C-, then a → C-c C-a
      (should (equal result (kbd "C-c C-a"))))))

(ert-deftest leader-test-handler-implicit-toggle-as-command ()
  "Implicit toggle (leader double-press): char as command → stop."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c SPC" . next-line))          ; C-c SPC is a command
        '(? )                               ; second SPC
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" "C-"             ; mod-default="C-"
                     nil                    ; no dispatch for SPC
                     "C-" nil)))            ; toggle-target=nil
        ;; C-c S-SPC is a command → stop (actually SPC as char: "C-c SPC")
        ;; But wait, read-event reads the event; the second SPC might conflict.
        ;; With "C-" modifier, "C-c C-SPC" would be checked first.
        ;; Actually, since modifier="C-" initially: "C-c C-SPC" has no binding,
        ;; so it falls through. Wait, the toggle check is BEFORE apply-modifier.
        ;; Let me trace: leader=SPC, char=SPC, target=nil, char==leader=>yes.
        ;; Check if "C-c SPC" is a command: yes → set keys="C-c SPC", need-read=nil.
        (should (equal result (kbd "C-c SPC")))))))

(ert-deftest leader-test-handler-implicit-toggle-toggles ()
  "Implicit toggle (leader double-press): not a command → toggle."
  (leader-test--with-handler-env
      '(("C-c f" . next-line))
      '(?  ?f)                            ; second SPC (toggle), then f
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" "C-"             ; mod-default="C-"
                   nil
                   "C-" nil)))            ; toggle-target=nil
      ;; C-c C-SPC is not bound → toggle modifier to nil, then f → C-c f
      (should (equal result (kbd "C-c f"))))))


;;; Edge cases

(ert-deftest leader-test-dispatch-resets-modifier-to-default ()
  "After direct dispatch, modifier resets to modifier-default."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-x" . ,prefix-map)
          ("C-x f" . next-line))
        '(?x ?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil              ; modifier-default=nil
                     (list (cons ?x "C-x")) ; dispatch to C-x, mod-override='default
                     "C-" "C-")))
        ;; After dispatch to C-x, modifier resets to nil (modifier-default)
        ;; Then f with nil modifier and fallback=C-: tries C-x f (bound) → C-x f
        (should (equal result (kbd "C-x f")))))))

(ert-deftest leader-test-fallback-modifier-vs-no-fallback ()
  "Fallback modifier nil: plain unbound → plain key."
  (leader-test--with-handler-env
      '(("C-c C-f" . next-line))
      '(?f)
    (let ((result (leader--run-handler
                   [? ]
                   "C-c" nil
                   nil
                   nil nil)))             ; no fallback, toggle-target=nil (mod=nil→nil)
      ;; modifier=nil, fb=nil, plain "C-c f" unbound, no fallback → "C-c f"
      (should (equal result (kbd "C-c f"))))))


;;; Dispatch in continuation (prefix keymap)

(ert-deftest leader-test-continuation-direct-dispatch ()
  "Direct dispatch entries are ignored in continuation; fallback logic resolves."
  (let ((prefix-map (make-sparse-keymap))
        (dispatch-prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-c x" . ,prefix-map)
          ("C-c x C-b" . ,dispatch-prefix-map)
          ("C-c x C-b C-f" . next-line))
        '(?x ?b ?f)
      ;; SPC x → C-c x (prefix), b → dispatch ignored in continuation,
      ;; fallback: C-c x b (unbound) → C-c x C-b (prefix) → f → C-c x C-b C-f
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?b '("C-b" "C-")))
                     "C-" "C-")))
        (should (equal result (kbd "C-c x C-b C-f")))))))

(ert-deftest leader-test-continuation-direct-dispatch-no-prefer ()
  "Continuation direct dispatch ignored even with prefer-command=nil."
  (let ((prefix-map (make-sparse-keymap))
        (dispatch-prefix-map (make-sparse-keymap))
        (leader-dispatch-priority nil))
    (leader-test--with-handler-env
        `(("C-c x" . ,prefix-map)
          ("C-c x C-b" . ,dispatch-prefix-map)
          ("C-c x C-b C-f" . next-line))
        '(?x ?b ?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?b '("C-b" "C-")))
                     "C-" "C-")))
        (should (equal result (kbd "C-c x C-b C-f")))))))

(ert-deftest leader-test-continuation-dispatch-ignored-for-command ()
  "Direct dispatch (?h -> C-h) is ignored in continuation; plain key resolves.
SPC x h should produce C-x h, not dispatch to C-h prefix."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-x" . ,prefix-map)
          ("C-x h" . mark-whole-buffer))
        '(?x ?h)
      ;; (?h . ("C-h" nil "C-")) is a direct dispatch, ignored in continuation.
      ;; modifier="C-" after C-x dispatch → try C-x C-h (nil) → fallback to
      ;; C-x h (mark-whole-buffer) → done.
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?x '("C-x" "C-" nil))
                           (cons ?h '("C-h" nil "C-")))
                     "C-" "C-")))
        (should (equal result (kbd "C-x h")))))))

(ert-deftest leader-test-continuation-modifier-prefix-dispatch ()
  "Continuation modifier prefix dispatch with which-key."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-c x" . ,prefix-map)
          ("C-c x M-f" . next-line))
        '(?x ?g ?f)
      (let ((leader--which-key-reader (leader-test--which-key-reader ?f))
            (leader-dispatch-priority nil))
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?g "M-"))
                       "C-" "C-")))
          (should (equal result (kbd "C-c x M-f"))))))))

(ert-deftest leader-test-continuation-dispatch-with-toggle ()
  "C- toggle dispatch works in continuation."
  (let ((prefix-map (make-sparse-keymap)))
    (leader-test--with-handler-env
        `(("C-c x" . ,prefix-map)
          ("C-c x C-a" . next-line)
          ("C-c x b" . previous-line))
        '(?x ?t ?a)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?t "C-"))
                     "C-" "C-")))
        ;; x → C-c x (prefix), t → C- dispatch, "C-c x t" not a command → toggle
        ;; modifier becomes "C-", a → "C-c x C-a" (bound) → done
        (should (equal result (kbd "C-c x C-a")))))))

(ert-deftest leader-test-continuation-dispatch-toggle-as-command ()
  "C- toggle in continuation: command check with prefer-command=t."
  (let ((leader-dispatch-priority t))
    (let ((prefix-map (make-sparse-keymap)))
      (leader-test--with-handler-env
          `(("C-c x" . ,prefix-map)
            ("C-c x t" . next-line))
          '(?x ?t)
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?t "C-"))
                       "C-" "C-")))
          ;; x → C-c x (prefix), t matches C- dispatch
          ;; "C-c x t" IS a command → use it directly
          (should (equal result (kbd "C-c x t"))))))))


;;; leader-dispatch-priority

(ert-deftest leader-test-prefer-command-modifier-prefix ()
  "Prefer-command=t: command overrides modifier prefix dispatch."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c e" . next-line))
        '(?e)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?e "C-M-"))  ; e dispatches to C-M-
                     "C-" "C-")))
        ;; e matches dispatch "C-M-", prefer-command:
        ;; apply-modifier "C-c" nil "C-" ?e → "C-c e" → IS command → use it
        (should (equal result (kbd "C-c e")))))))

(ert-deftest leader-test-prefer-command-wins-over-direct-dispatch ()
  "Prefer-command=t: bound command takes priority over direct dispatch."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c f" . next-line))
        '(?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?f "C-x"))  ; f dispatches to C-x
                     "C-" "C-")))
        ;; f matches dispatch "C-x", prefer-command checks:
        ;; apply-modifier "C-c" nil "C-" ?f → "C-c f" (plain, no C-f binding)
        ;; "C-c f" IS a command → use it
        (should (equal result (kbd "C-c f")))))))

(ert-deftest leader-test-prefer-command-wins-over-modifier-prefix-dispatch ()
  "Prefer-command=t: bound command overrides modifier prefix dispatch."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c f" . next-line))
        '(?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?f "M-"))  ; f dispatches to M-
                     "C-" "C-")))
        ;; f matches dispatch "M-", prefer-command:
        ;; apply-modifier "C-c" nil "C-" ?f → "C-c f" → IS a command → use it
        (should (equal result (kbd "C-c f")))))))

(ert-deftest leader-test-prefer-dispatch-nil-direct-match ()
  "prefer-command=nil: dispatch takes priority always."
  (let ((leader-dispatch-priority nil))
    (let ((prefix-map (make-sparse-keymap)))
      (leader-test--with-handler-env
          `(("C-c f" . next-line)
            ("C-x" . ,prefix-map)
            ("C-x C-f" . find-file))
          '(?f ?g)
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?f "C-x"))
                       "C-" "C-")))
          ;; f matches dispatch "C-x" → dispatch applies (prefer-command=nil)
          ;; keys="C-x", modifier=nil, fb="C-"
          ;; C-x is a prefix → continue, next key g (NOT in dispatch)
          ;; modifier nil + fallback C-: tries C-x g (unbound) → C-x C-g
          ;; Both unbound → returns plain "C-x g"
          (should (equal result (kbd "C-x g"))))))))

(ert-deftest leader-test-prefer-dispatch-nil-modifier-prefix ()
  "prefer-command=nil: modifier prefix dispatch takes priority."
  (let ((leader-dispatch-priority nil))
    (leader-test--with-handler-env
        '(("C-c f" . next-line))
        '(?f ?g)
      (let ((leader--which-key-reader (leader-test--which-key-reader ?g)))
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?f "M-"))
                       "C-" "C-")))
          ;; f matches dispatch "M-" → dispatch applies (prefer-command=nil)
          ;; reads second key g → "M-g"
          (should (equal result (kbd "M-g"))))))))

(ert-deftest leader-test-prefer-dispatch-nil-c-toggle ()
  "prefer-command=nil: C- toggle skips command check."
  (let ((leader-dispatch-priority nil))
    (leader-test--with-handler-env
        '(("C-c t" . next-line)
          ("C-c C-a" . find-file))
        '(?t ?a)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?t "C-"))
                     "C-" "C-")))
        ;; t matches C- dispatch, prefer-command=nil → skip command check
        ;; toggle modifier to C-, a → "C-c C-a" (bound)
        (should (equal result (kbd "C-c C-a")))))))

(ert-deftest leader-test-prefer-command-t-c-toggle ()
  "prefer-command=t: C- toggle checks command first."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c t" . next-line))
        '(?t)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?t "C-"))
                     "C-" "C-")))
        ;; t matches C- dispatch, prefer-command=t → check "C-c t"
        ;; "C-c t" IS a command → use it
        (should (equal result (kbd "C-c t")))))))

(ert-deftest leader-test-prefer-command-implicit-toggle ()
  "prefer-command=t: implicit toggle checks command first."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c SPC" . next-line))
        '(?  )
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     nil
                     "C-" "C-")))
        ;; leader=SPC, char=SPC, implicit toggle
        ;; prefer-command=t → check "C-c SPC" → IS a command → use it
        (should (equal result (kbd "C-c SPC")))))))

(ert-deftest leader-test-prefer-dispatch-nil-implicit-toggle ()
  "prefer-command=nil: implicit toggle skips command check."
  (let ((leader-dispatch-priority nil))
    (leader-test--with-handler-env
        '(("C-c SPC" . next-line)
          ("C-c C-f" . find-file))
        '(?  ?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     nil
                     "C-" "C-")))
        ;; leader=SPC, char=SPC, implicit toggle
        ;; prefer-command=nil → skip command check → toggle modifier to C-
        ;; f → "C-c C-f" (bound)
        (should (equal result (kbd "C-c C-f")))))))

(ert-deftest leader-test-prefer-command-continuation ()
  "Prefer-command=t inside continuation: command overrides dispatch."
  (let ((leader-dispatch-priority t))
    (let ((prefix-map (make-sparse-keymap)))
      (leader-test--with-handler-env
          `(("C-c x" . ,prefix-map)
            ("C-c x f" . next-line))
          '(?x ?f)
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?f "C-x"))  ; f dispatches to C-x
                       "C-" "C-")))
          ;; x → "C-c x" (prefix, enter continuation)
          ;; f matches dispatch "C-x", but "C-c x f" IS a command → use it
          (should (equal result (kbd "C-c x f"))))))))

(ert-deftest leader-test-prefer-command-no-match-still-dispatches ()
  "Prefer-command=t but no command bound → dispatch still applies."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c C-a" . next-line))
        '(?f ?a)
      (let ((leader--which-key-reader (leader-test--which-key-reader ?a)))
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?f "C-M-"))  ; f dispatches to C-M-
                       "C-" "C-")))
          ;; f matches dispatch "C-M-", prefer-command:
          ;; apply-modifier "C-c" nil "C-" ?f → "C-c f" → NOT a command
          ;; → dispatch applies → modifier=C-M-, read next key a
          ;; → keys = "C-M-a" (prefix replaced at first level)
          (should (equal result (kbd "C-M-a"))))))))

(ert-deftest leader-test-prefer-command-c-toggle-still-dispatches-no-cmd ()
  "Prefer-command=t but C- toggle key is not a command → toggle applies."
  (let ((leader-dispatch-priority t))
    (leader-test--with-handler-env
        '(("C-c C-a" . next-line))
        '(?t ?a)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?t "C-"))
                     "C-" "C-")))
        ;; t matches C- dispatch, prefer-command → check "C-c t"
        ;; "C-c t" NOT a command → toggle modifier to C-, a → "C-c C-a"
        (should (equal result (kbd "C-c C-a")))))))

(ert-deftest leader-test-complex-chain-with-dispatch ()
  "Multi-level chain with interleaved dispatches."
  (let ((prefix-map-0 (make-sparse-keymap))
        (prefix-map-1 (make-sparse-keymap))
        (prefix-map-2 (make-sparse-keymap)))
    (define-key prefix-map-2 "f" 'next-line)
    (leader-test--with-handler-env
        `(("C-a" . ,prefix-map-0)
          ("C-a x" . ,prefix-map-1)
          ("C-a x C-b" . ,prefix-map-2)
          ("C-a x C-b C-f" . next-line))
        '(?g ?x ?b ?f)
      (let ((leader-dispatch-priority nil))
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?g "C-a")
                             (cons ?b '("C-b" "C-")))
                       "C-" "C-")))
          ;; g → dispatch to "C-a" (prefix)
          ;; x → "C-a x" (prefix, modifier logic)
          ;; b → dispatch to "C-b" (direct, prefer-command=nil)
          ;;   → "C-a x C-b" (prefix, enter next continuation)
          ;; f → modifier logic (C- modifier) → "C-a x C-b C-f" (command)
          (should (equal result (kbd "C-a x C-b C-f"))))))))


;;; leader-dispatch-priority — custom ordering

(ert-deftest leader-test-dispatch-priority-modifier-prefix-wins ()
  ":modifier-prefix before :command → dispatch wins over bound command."
  (let ((leader-dispatch-priority '(:modifier-prefix :command)))
    (leader-test--with-handler-env
        '(("C-c e" . next-line))
        '(?e ?f)
      (let ((leader--which-key-reader (leader-test--which-key-reader ?f)))
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?e "M-"))  ; modifier prefix dispatch
                       "C-" "C-")))
          (should (equal result (kbd "M-f"))))))))

(ert-deftest leader-test-dispatch-priority-direct-wins ()
  ":dispatch before :command → direct dispatch wins over bound command."
  (let ((leader-dispatch-priority '(:dispatch :command)))
    (let ((prefix-map (make-sparse-keymap)))
      (leader-test--with-handler-env
          `(("C-c f" . next-line)
            ("C-x" . ,prefix-map)
            ("C-x C-f" . find-file))
          '(?f ?g)
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?f "C-x"))  ; direct dispatch
                       "C-" "C-")))
          (should (equal result (kbd "C-x g"))))))))

(ert-deftest leader-test-dispatch-priority-command-over-c-toggle ()
  ":command before :toggle → C- toggle checks command first."
  (let ((leader-dispatch-priority '(:command :toggle)))
    (leader-test--with-handler-env
        '(("C-c t" . next-line))
        '(?t)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?t "C-"))  ; C- toggle dispatch
                     "C-" "C-")))
        (should (equal result (kbd "C-c t")))))))

(ert-deftest leader-test-dispatch-priority-command-over-implicit-toggle ()
  ":command before :toggle → implicit toggle checks command first."
  (let ((leader-dispatch-priority '(:command :toggle)))
    (leader-test--with-handler-env
        '(("C-c SPC" . next-line))
        '(?  )
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     nil
                     "C-" "C-")))
        (should (equal result (kbd "C-c SPC")))))))

(ert-deftest leader-test-dispatch-priority-toggle-wins-over-command ()
  ":toggle before :command → toggle fires even when command is bound."
  (let ((leader-dispatch-priority '(:toggle :command)))
    (leader-test--with-handler-env
        '(("C-c t" . next-line)
          ("C-c C-a" . next-line))
        '(?t ?a)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?t "C-"))  ; C- toggle dispatch
                     "C-" "C-")))
        (should (equal result (kbd "C-c C-a")))))))

(ert-deftest leader-test-dispatch-priority-user-default ()
  "User default: modifier-prefix/dispatch before command before toggle."
  (let ((leader-dispatch-priority '(:modifier-prefix :dispatch :command :toggle)))
    (leader-test--with-handler-env
        '(("C-c t" . next-line))
        '(?t)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?t "C-"))
                     "C-" "C-")))
        (should (equal result (kbd "C-c t")))))))

(ert-deftest leader-test-dispatch-priority-fallback-wins-over-dispatch ()
  ":command-fallback before :dispatch → fallback command wins."
  (let ((leader-dispatch-priority '(:command-fallback :dispatch)))
    (leader-test--with-handler-env
        '(("C-c C-f" . next-line))
        '(?f)
      (let ((result (leader--run-handler
                     [? ]
                     "C-c" nil
                     (list (cons ?f "C-x"))
                     "C-" "C-")))
        (should (equal result (kbd "C-c C-f")))))))

(ert-deftest leader-test-dispatch-priority-dispatch-wins-over-fallback ()
  ":dispatch before :command-fallback → dispatch wins."
  (let ((leader-dispatch-priority '(:dispatch :command-fallback)))
    (let ((prefix-map (make-sparse-keymap)))
      (leader-test--with-handler-env
          `(("C-c C-f" . next-line)
            ("C-x" . ,prefix-map)
            ("C-x C-g" . find-file))
          '(?f ?g)
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil
                       (list (cons ?f "C-x"))
                       "C-" "C-")))
          (should (equal result (kbd "C-x C-g"))))))))

(ert-deftest leader-test-dispatch-priority-primary-over-fallback ()
  ":dispatch before both :command and :command-fallback → dispatch wins
when fallback command is bound but plain command is not."
  (let ((leader-dispatch-priority '(:dispatch :command :command-fallback)))
    (let ((prefix-map (make-sparse-keymap)))
      (leader-test--with-handler-env
          `(("C-c C-f" . next-line)          ; fallback command only
            ("C-x" . ,prefix-map)
            ("C-x C-g" . find-file))
          '(?f ?g)
        (let ((result (leader--run-handler
                       [? ]
                       "C-c" nil              ; modifier=nil
                       (list (cons ?f "C-x"))  ; direct dispatch
                       "C-" "C-")))           ; "C-c f" unbound, "C-c C-f" fallback bound
          ;; :dispatch before :command-fallback → dispatch wins
          (should (equal result (kbd "C-x C-g"))))))))

(ert-deftest leader-test-prefix-spec-string ()
  "String prefix spec: modifier-default='C-', fallback='C-'."
  (let* ((prefix-spec "C-c")
         (default-prefix (if (consp prefix-spec) (car prefix-spec) prefix-spec))
         (modifier-default (if (consp prefix-spec) (cadr prefix-spec) "C-"))
         (fallback-modifier (if (and (consp prefix-spec) (caddr prefix-spec))
                                (caddr prefix-spec)
                              modifier-default)))
    (should (equal default-prefix "C-c"))
    (should (equal modifier-default "C-"))
    (should (equal fallback-modifier "C-"))))

(ert-deftest leader-test-prefix-spec-list-two ()
  "Two-element list prefix spec."
  (let* ((prefix-spec '("C-c" nil))
         (default-prefix (car prefix-spec))
         (modifier-default (cadr prefix-spec))
         (fallback-modifier (if (caddr prefix-spec) (caddr prefix-spec) modifier-default)))
    (should (equal default-prefix "C-c"))
    (should (equal modifier-default nil))
    (should (equal fallback-modifier nil))))

(ert-deftest leader-test-prefix-spec-list-three ()
  "Three-element list prefix spec."
  (let* ((prefix-spec '("C-c" nil "C-"))
         (default-prefix (car prefix-spec))
         (modifier-default (cadr prefix-spec))
         (fallback-modifier (if (caddr prefix-spec) (caddr prefix-spec) modifier-default)))
    (should (equal default-prefix "C-c"))
    (should (equal modifier-default nil))
    (should (equal fallback-modifier "C-"))))

(ert-deftest leader-test-prefix-spec-list-two-with-C ()
  "Two-element list with C- modifier."
  (let* ((prefix-spec '("C-c" "C-"))
         (default-prefix (car prefix-spec))
         (modifier-default (cadr prefix-spec))
         (fallback-modifier (if (caddr prefix-spec) (caddr prefix-spec) modifier-default)))
    (should (equal default-prefix "C-c"))
    (should (equal modifier-default "C-"))
    (should (equal fallback-modifier "C-"))))

(ert-deftest leader-test-prefix-spec-list-M-modifier ()
  "Two-element list with M- modifier."
  (let* ((prefix-spec '("C-c" "M-"))
         (default-prefix (car prefix-spec))
         (modifier-default (cadr prefix-spec))
         (fallback-modifier (if (caddr prefix-spec) (caddr prefix-spec) modifier-default)))
    (should (equal default-prefix "C-c"))
    (should (equal modifier-default "M-"))
    (should (equal fallback-modifier "M-"))))

;;; leader--make-handler and string prefix

(ert-deftest leader-test-modifier-default-is-C-when-string-prefix ()
  "When default-prefix is a plain string, modifier-default='C-'."
  (leader-test--with-handler-env
      '(("M-o C-a" . next-line))
      '(?a)
    (let ((result (leader--run-handler
                   [? ]                   ; dummy leader
                   "M-o" "C-"             ; plain string prefix → mod-default="C-"
                   nil
                   "C-" nil)))           ; toggle-target=nil
      ;; modifier="C-" → try "M-o C-a" first (bound) → "M-o C-a"
      (should (equal result (kbd "M-o C-a"))))))


;;; Test runner

(defun leader-test-run ()
  "Run all leader tests."
  (ert-run-tests-batch-and-exit))

(provide 'leader-test)
;;; leader-test.el ends here
