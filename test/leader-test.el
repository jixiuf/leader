;;; leader-test.el --- Tests for leader.el -*- lexical-binding: t; -*-
(require 'ert)
(require 'leader)

(defvar leader-tt-cx-map (make-sparse-keymap))
(define-key leader-tt-cx-map (kbd "C-f") 'ignore)

(defvar leader-tt-sub-map (make-sparse-keymap))
(define-key leader-tt-sub-map (kbd "C-b") 'ignore)
(define-key leader-tt-sub-map (kbd "b") 'ignore)


;;; Helpers

(defun leader-test--event-source (events)
  (let ((idx 0))
    (lambda (_)
      (prog1 (nth idx events)
        (setq idx (1+ idx))))))

(defun leader-test--key-lookup (bindings)
  (lambda (keystr)
    (cdr (assoc keystr bindings))))

(defun leader-test--do-run (config bindings events)
  (setq leader-keys config)
  (leader--normalize-config)
  (let* ((leader--key-lookup-fn (leader-test--key-lookup bindings))
         (leader--event-reader (leader-test--event-source events))
         (ctx (car leader--normalized-config)))
    (let ((result (leader--run-handler (kbd "<SPC>") ctx)))
      (and result (key-description result)))))

(defun leader-test--context (config)
  (setq leader-keys config)
  (leader--normalize-config)
  (car leader--normalized-config))


;;; pass-through-p

(ert-deftest leader-tt-pass-through--nil-default ()
  "Default predicates evaluate to nil in normal buffers."
  (let ((leader-pass-through-predicates '(minibufferp isearch-mode)))
    (should-not (leader--pass-through-p))))

(ert-deftest leader-tt-pass-through--lambda-t ()
  "Lambda returning t causes pass-through."
  (let ((leader-pass-through-predicates (list (lambda () t))))
    (should (leader--pass-through-p))))

(ert-deftest leader-tt-pass-through--lambda-nil ()
  "Lambda returning nil does not cause pass-through."
  (let ((leader-pass-through-predicates (list (lambda () nil))))
    (should-not (leader--pass-through-p))))

(ert-deftest leader-tt-pass-through--sym-var ()
  "Symbol-as-variable predicate."
  (defvar leader-tt-pt-var t)
  (let ((leader-pass-through-predicates '(leader-tt-pt-var)))
    (should (leader--pass-through-p)))
  (setq leader-tt-pt-var nil))

(ert-deftest leader-tt-pass-through--sym-fn ()
  "Symbol predicate called as function (not command) -> non-nil."
  (let ((leader-pass-through-predicates '(leader-tt-pt-fn)))
    (fset 'leader-tt-pt-fn (lambda () t))
    (unwind-protect
        (should (leader--pass-through-p))
      (fmakunbound 'leader-tt-pt-fn))))

(ert-deftest leader-tt-pass-through--sym-command-major-mode ()
  "Command symbol matching major-mode is t (mode variable void)."
  (let ((leader-pass-through-predicates '(leader-tt-pt-cmd))
        (major-mode 'leader-tt-pt-cmd))
    (defun leader-tt-pt-cmd () (interactive) t)
    (unwind-protect
        (should (leader--pass-through-p))
      (fmakunbound 'leader-tt-pt-cmd))))

(ert-deftest leader-tt-pass-through--sym-command-no-match ()
  "Command symbol not matching major-mode is nil."
  (let ((leader-pass-through-predicates '(leader-tt-pt-cmd))
        (major-mode 'fundamental-mode))
    (defun leader-tt-pt-cmd () (interactive) t)
    (unwind-protect
        (should-not (leader--pass-through-p))
      (fmakunbound 'leader-tt-pt-cmd))))

(ert-deftest leader-tt-pass-through--multiple-any-true ()
  "Multiple predicates — any true means pass through."
  (let ((leader-pass-through-predicates
         (list (lambda () nil) (lambda () t) (lambda () nil))))
    (should (leader--pass-through-p))))


;;; Normalization

(ert-deftest leader-tt-normalize--basic ()
  "Basic keyword format normalization."
  (let* ((ctx (leader-test--context
               '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-")))))
    (should (equal (leader-context-prefix ctx) "C-c"))
    (should (equal (leader-context-modifier ctx) "C-"))
    (should (equal (leader-context-fallback ctx) "C-"))
    (should (eq (leader-context-toggle-target ctx) nil))))

(ert-deftest leader-tt-normalize--modifier-only ()
  "Modifier-only prefix normalization."
  (let* ((ctx (leader-test--context
               '((:key "<SPC>" :prefix "" :modifier "M-" :fallback nil)))))
    (should (eq (leader-context-prefix ctx) nil))
    (should (equal (leader-context-modifier ctx) "M-"))
    (should (eq (leader-context-fallback ctx) nil))))

(ert-deftest leader-tt-normalize--dispatch ()
  "Dispatch entries normalization."
  (let* ((ctx (leader-test--context
               '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                  :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-"))
                             (?e . (:prefix "" :modifier "M-" :fallback nil))))))))
    (should (= (length (leader-context-dispatch-alist ctx)) 2))
    (let ((d (cdr (assq ?x (leader-context-dispatch-alist ctx)))))
      (should (equal (leader-context-prefix d) "C-x"))
      (should (equal (leader-context-modifier d) "C-")))
    (let ((d (cdr (assq ?e (leader-context-dispatch-alist ctx)))))
      (should (eq (leader-context-prefix d) nil))
      (should (equal (leader-context-modifier d) "M-")))))

(ert-deftest leader-tt-normalize--toggle-dispatch ()
  ":toggle dispatch entry."
  (let* ((ctx (leader-test--context
               '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                  :dispatch ((?d . :toggle)))))))
    (let ((d (cdr (assq ?d (leader-context-dispatch-alist ctx)))))
      (should (eq (leader-context-prefix d) nil))
      (should (eq (leader-context-modifier d) nil))
      (should (equal (leader-context-toggle-target d) "C-")))))

(ert-deftest leader-tt-normalize--toggle-inference ()
  "Toggle target inferred from modifier."
  (let* ((ctx (leader-test--context
               '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-")))))
    (should (eq (leader-context-toggle-target ctx) nil)))
  (let* ((ctx (leader-test--context
               '((:key "<SPC>" :prefix "C-c" :modifier nil :fallback "C-")))))
    (should (equal (leader-context-toggle-target ctx) "C-"))))


;;; resolve-key

(ert-deftest leader-tt-resolve--modifier-bound ()
  (let ((leader--key-lookup-fn
         (lambda (k) (when (string= k "C-c C-f") 'ignore))))
    (let ((r (leader--resolve-key "C-c" "C-" "C-" ?f)))
      (should (equal (car r) "C-c C-f"))
      (should-not (cdr r)))))

(ert-deftest leader-tt-resolve--modifier-unbound-fallback-plain ()
  (let ((leader--key-lookup-fn
         (lambda (k) (when (string= k "C-c f") 'ignore))))
    (let ((r (leader--resolve-key "C-c" "C-" "C-" ?f)))
      (should (equal (car r) "C-c f"))
      (should (cdr r)))))

(ert-deftest leader-tt-resolve--plain-bound ()
  (let ((leader--key-lookup-fn
         (lambda (k) (when (string= k "C-c f") 'ignore))))
    (let ((r (leader--resolve-key "C-c" nil "C-" ?f)))
      (should (equal (car r) "C-c f"))
      (should-not (cdr r)))))

(ert-deftest leader-tt-resolve--plain-unbound-fallback ()
  (let ((leader--key-lookup-fn
         (lambda (k) (when (string= k "C-c C-f") 'ignore))))
    (let ((r (leader--resolve-key "C-c" nil "C-" ?f)))
      (should (equal (car r) "C-c C-f"))
      (should (cdr r)))))

(ert-deftest leader-tt-resolve--nothing-bound ()
  (let ((leader--key-lookup-fn (lambda (_k) nil)))
    (let ((r (leader--resolve-key "C-c" "C-" "C-" ?f)))
      (should (equal (car r) "C-c f"))
      (should (cdr r)))))


;;; binding-is-prefix-keymap-p

(ert-deftest leader-tt-prefix--keymap-object ()
  (should (leader--binding-is-prefix-keymap-p (make-sparse-keymap))))

(ert-deftest leader-tt-prefix--keymap-symbol ()
  (defvar leader-tt-map (make-sparse-keymap))
  (should (leader--binding-is-prefix-keymap-p 'leader-tt-map)))

(ert-deftest leader-tt-prefix--command-nil ()
  (should-not (leader--binding-is-prefix-keymap-p 'ignore)))


;;; Handler: basic resolution

(ert-deftest leader-tt-run--basic ()
  "SPC f -> C-c C-f"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                  '(("C-c C-f" . ignore))
                  '(?f))
                 "C-c C-f")))

(ert-deftest leader-tt-run--modifier-fallback ()
  "SPC f (C-c C-f not bound) -> C-c f"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                  '(("C-c f" . ignore))
                  '(?f))
                 "C-c f")))

(ert-deftest leader-tt-run--no-binding-returns-plain ()
  "SPC f (nothing bound) -> C-c f (returned as-is)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                  '()
                  '(?f))
                 "C-c f")))

(ert-deftest leader-tt-run--plain-first ()
  "SPC f (modifier=nil, plain bound)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier nil :fallback "C-"))
                  '(("C-c f" . ignore))
                  '(?f))
                 "C-c f")))

(ert-deftest leader-tt-run--plain-fallback ()
  "SPC f (modifier=nil, plain unbound, fallback to C-)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier nil :fallback "C-"))
                  '(("C-c C-f" . ignore))
                  '(?f))
                 "C-c C-f")))


;;; Handler: dispatch

(ert-deftest leader-tt-run--dispatch ()
  "SPC x f -> C-x C-f"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                  '(("C-x C-f" . ignore) ("C-x" . leader-tt-cx-map))
                  '(?x ?f))
                 "C-x C-f")))

(ert-deftest leader-tt-run--dispatch-fallback-plain ()
  "SPC x f (C-x C-f not bound) -> C-x f"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                  '(("C-x f" . ignore) ("C-x" . leader-tt-cx-map))
                  '(?x ?f))
                 "C-x f")))

(ert-deftest leader-tt-run--dispatch-plain-modifier ()
  "SPC x f (dispatch with modifier=nil) -> C-x f"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?x . (:prefix "C-x" :modifier nil :fallback "C-")))))
                  '(("C-x f" . ignore) ("C-x" . leader-tt-cx-map))
                  '(?x ?f))
                 "C-x f")))


;;; Handler: modifier-prefix dispatch

(ert-deftest leader-tt-run--modifier-prefix ()
  "SPC e x -> M-x"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?e . (:prefix "" :modifier "M-" :fallback nil)))))
                  '(("M-x" . ignore))
                  '(?e ?x))
                 "M-x")))

(ert-deftest leader-tt-run--modifier-prefix-continuation ()
  "SPC x e a -> C-x M-a"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch
                     ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-"))
                      (?e . (:prefix "" :modifier "M-" :fallback nil)))))
                  '(("C-x" . leader-tt-cx-map) ("C-x M-a" . ignore))
                  '(?x ?e ?a))
                 "C-x M-a")))

(ert-deftest leader-tt-run--modifier-prefix-fallback-no-completions ()
  "SPC x e (no M- completions in C-x map) -> C-x C-e (fallback e883dd3)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch
                     ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-"))
                      (?e . (:prefix "" :modifier "M-" :fallback nil)))))
                  ;; C-x map has NO M-* keys — so 'e' should fall back.
                  ;; 'e' with modifier=C- resolves to "C-x C-e"
                  '(("C-x" . leader-tt-cx-map)
                    ("C-x C-e" . ignore))
                  '(?x ?e))
                 "C-x C-e")))


;;; Handler: toggle

(ert-deftest leader-tt-run--toggle-off ()
  "SPC SPC f -> C-c f (toggle C- off)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                  '(("C-c f" . ignore))
                  '(32 102))
                 "C-c f")))

(ert-deftest leader-tt-run--toggle-on ()
  "SPC SPC f -> C-c C-f (toggle nil to C-)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier nil :fallback "C-"))
                  '(("C-c C-f" . ignore))
                  '(32 102))
                 "C-c C-f")))

(ert-deftest leader-tt-run--toggle-dispatch ()
  "SPC d f -> C-c f (:toggle dispatch entry)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?d . :toggle))))
                  '(("C-c f" . ignore))
                  '(?d ?f))
                 "C-c f")))

(ert-deftest leader-tt-run--toggle-in-continuation ()
  "SPC x SPC f -> C-x f (toggle inside continuation)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                  '(("C-x" . leader-tt-cx-map) ("C-x f" . ignore))
                  '(?x 32 ?f))
                 "C-x f")))


;;; Handler: suppress direct dispatch in continuation

(ert-deftest leader-tt-run--suppress-direct-dispatch ()
  "SPC x x -> C-x C-x (dispatch suppressed, modifier applied)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                  '(("C-x" . leader-tt-cx-map) ("C-x C-x" . ignore))
                  '(?x ?x))
                 "C-x C-x")))


;;; Handler: continuation (prefix keymap traversal)

(ert-deftest leader-tt-run--continuation ()
  "SPC a b -> C-c a C-b"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                  '(("C-c a" . leader-tt-sub-map) ("C-c a C-b" . ignore))
                  '(?a ?b))
                 "C-c a C-b")))

(ert-deftest leader-tt-run--continuation-fallback-plain ()
  "SPC a b (C-c a C-b not bound) -> C-c a b"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                  '(("C-c a" . leader-tt-sub-map) ("C-c a b" . ignore))
                  '(?a ?b))
                 "C-c a b")))


;;; dispatch-priority

(ert-deftest leader-tt-priority--nil ()
  "leader-dispatch-priority nil → dispatch wins"
  (let ((leader-dispatch-priority nil))
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                       :dispatch ((?f . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                    '(("C-c C-f" . ignore) ("C-x" . leader-tt-cx-map)
                      ("C-x C-f" . ignore))
                    '(?f ?f))
                   "C-x C-f"))))

(ert-deftest leader-tt-priority--t ()
  "leader-dispatch-priority t → command wins"
  (let ((leader-dispatch-priority t))
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                       :dispatch ((?f . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                    '(("C-c C-f" . ignore) ("C-x" . leader-tt-cx-map)
                      ("C-x C-f" . ignore))
                    '(?f))
                   "C-c C-f"))))

(ert-deftest leader-tt-priority--primary ()
  "leader-dispatch-priority :primary → primary command wins"
  (let ((leader-dispatch-priority :primary))
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                       :dispatch ((?f . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                    '(("C-c C-f" . ignore) ("C-x" . leader-tt-cx-map)
                      ("C-x C-f" . ignore))
                    '(?f))
                   "C-c C-f"))))

(ert-deftest leader-tt-priority--primary-fallback-dispatch-wins ()
  ":primary: fallback command does NOT win over dispatch"
  (let ((leader-dispatch-priority :primary))
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier nil :fallback "C-"
                       :dispatch ((?f . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                    '(("C-c C-f" . ignore) ("C-x" . leader-tt-cx-map)
                      ("C-x C-f" . ignore))
                    '(?f ?f))
                   "C-x C-f"))))

(ert-deftest leader-tt-priority--toggle-command-wins ()
  "leader-toggle-priority=t, SPC SPC -> execute C-c C-SPC command"
  (let ((leader-toggle-priority t))
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                    '(("C-c C-SPC" . ignore))
                    '(32))
                   "C-c C-SPC"))))

(ert-deftest leader-tt-priority--toggle-fallback-command-wins ()
  "leader-toggle-priority=t, modifier=nil, SPC SPC -> fallback command"
  (let ((leader-toggle-priority t))
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier nil :fallback "C-"))
                    '(("C-c C-SPC" . ignore))
                    '(32))
                   "C-c C-SPC"))))

(ert-deftest leader-tt-priority--toggle-nil-no-command ()
  "leader-toggle-priority=nil, SPC SPC -> toggle (no command)"
  (let ((leader-toggle-priority nil))
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                    '(("C-c f" . ignore))
                    '(32 102))
                   "C-c f"))))

(ert-deftest leader-tt-priority--dispatch-nil-toggle-t ()
  "dispatch=nil toggle=t: SPC x dispatch works, SPC SPC command wins"
  (let ((leader-dispatch-priority nil)
        (leader-toggle-priority t))
    ;; dispatch wins (nil)
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                       :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-")))))
                    '(("C-c C-x" . ignore) ("C-x" . leader-tt-cx-map)
                      ("C-x C-f" . ignore))
                    '(?x ?f))
                   "C-x C-f"))
    ;; toggle command wins (t)
    (should (equal (leader-test--do-run
                    '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                    '(("C-c C-SPC" . ignore))
                    '(32))
                   "C-c C-SPC"))))


;;; empty-p helper

(ert-deftest leader-tt-empty-p ()
  (should (leader--empty-p nil))
  (should (leader--empty-p ""))
  (should-not (leader--empty-p "C-x"))
  (should-not (leader--empty-p " ")))

(ert-deftest leader-tt-run--toggle-in-dispatch-continuation ()
  "SPC h SPC a -> C-h C-a (toggle inside dispatched continuation)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?h . (:prefix "C-h" :modifier nil :fallback "C-")))))
                  '(("C-h" . leader-tt-cx-map) ("C-h C-a" . ignore))
                  '(?h 32 ?a))
                 "C-h C-a")))

(ert-deftest leader-tt-run--modifier-prefix-no-echo-prefix ()
  "SPC m x -> M-x (modifier-prefix at top level: no C-c prefix)"
  (should (equal (leader-test--do-run
                  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
                     :dispatch ((?m . (:prefix "" :modifier "M-" :fallback nil)))))
                  '(("M-x" . ignore))
                  '(?m ?x))
                 "M-x")))

(provide 'leader-test)

(defun leader-test-run ()
  "Run all leader tests."
  (ert-run-tests-batch-and-exit))

;;; leader-test.el ends here
