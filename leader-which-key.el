;;; leader-which-key.el --- which-key integration for leader -*- lexical-binding: t; -*-

;; Author: jixiuf
;; Keywords: convenience
;; Package-Requires: ((emacs "30.1") (which-key nil))

;;; Commentary:
;;
;; Optional module that adds which-key popup support to leader.
;; Load this after both `leader' and `which-key':
;;
;;;;   (require 'leader-which-key)
;;
;; Provides visual key binding hints during leader key sequences,
;; including modifier-prefix contexts (M-, C-M- dispatch targets).

;;; Code:

(require 'which-key)

(declare-function leader--collect-modifier-bindings "leader")
(declare-function leader--binding-sort "leader")
(declare-function leader--prompt "leader")

(defvar leader--event-reader)
(defvar leader--which-key-show-fn)
(defvar leader--which-key-modifier-read-fn)
(defvar leader--which-key-read-event-fn)

(defcustom leader-which-key-modifier-max-bindings 150
  "Maximum number of bindings to show in modifier-prefix which-key popups.
Set to nil for unlimited."
  :type '(choice (const :tag "Unlimited" nil) integer)
  :group 'leader)

(defun leader-wk--modifier-bindings (target)
  "Call `leader--collect-modifier-bindings' with display limit applied."
  (let ((all (leader--collect-modifier-bindings target)))
    (if (and leader-which-key-modifier-max-bindings
             (> (length all) leader-which-key-modifier-max-bindings))
        (cl-subseq all 0 leader-which-key-modifier-max-bindings)
      all)))

(defun leader-wk--collect-prefix-bindings (keys modifier)
  "Collect bindings for prefix KEYS with MODIFIER bias in sorting.
MODIFIER non-nil sorts modified keys first; nil sorts plain keys first."
  (let* ((map (key-binding (kbd keys)))
         (bindings
          (when (keymapp map)
            (let (result)
              (map-keymap
               (lambda (ev def)
                 (unless (or (eq def 'undefined) (eq ev 'which-key)
                             (eq ev 'menu-bar))
                   (cond
                    ((and (eq ev 27) (keymapp def))
                     (map-keymap
                      (lambda (sub-ev sub-def)
                        (unless (eq sub-def 'undefined)
                          (let* ((meta-ev (event-apply-modifier
                                           sub-ev 'meta 27 "M-"))
                                 (key-desc (key-description (vector meta-ev)))
                                 (full-desc (concat keys " " key-desc)))
                            (unless (string-match-p
                                     "\\(?:<mouse\\|<wheel\\|<drag\\|<down-\\)"
                                     full-desc)
                              (push (cons full-desc
                                          (cond ((keymapp sub-def) "prefix")
                                                ((symbolp sub-def)
                                                 (symbol-name sub-def))
                                                (t (format "%s" sub-def))))
                                    result)))))
                      def))
                    (t
                     (let* ((key-desc (key-description (vector ev)))
                            (full-desc (concat keys " " key-desc)))
                       (unless (string-match-p
                                "\\(?:<mouse\\|<wheel\\|<drag\\|<down-\\)"
                                full-desc)
                         (push (cons full-desc
                                     (cond ((keymapp def) "prefix")
                                           ((symbolp def) (symbol-name def))
                                           (t (format "%s" def))))
                               result)))))))
               map)
              result))))
    (when bindings
      (let* ((prefix-len (1+ (length keys)))
             (mod-match-p
              (lambda (b)
                (string-match-p "[ACHMSs]-"
                                (substring (car b) prefix-len))))
             (modified (cl-remove-if-not mod-match-p bindings))
             (plain (cl-remove-if mod-match-p bindings))
             (sorted-mod (sort modified #'leader--binding-sort))
             (sorted-plain (sort plain #'leader--binding-sort))
             (sorted (if modifier
                         (append sorted-mod sorted-plain)
                       (append sorted-plain sorted-mod))))
        sorted))))

(defun leader-wk--next-page (delta)
  "Advance which-key page by DELTA, re-render."
  (when (and which-key--pages-obj
             (> (which-key--pages-num-pages which-key--pages-obj) 1))
    (setq which-key--pages-obj
          (which-key--pages-set-current-page which-key--pages-obj delta))
    (let ((which-key--automatic-display t))
      (which-key--show-page))))

(defun leader-wk--show-popup (&optional force)
  "Show which-key popup if not already visible.  FORCE forces refresh."
  (when (and which-key--pages-obj
             (or force (not (which-key--popup-showing-p))))
    (let ((which-key--automatic-display t))
      (which-key--show-page))))

(defun leader-wk--hide ()
  "Hide our which-key popup."
  (ignore-errors (which-key--hide-popup))
  (setq which-key--pages-obj nil))

(defun leader-wk--page-hint ()
  "Return echo-area paging hint string."
  (when which-key--pages-obj
    (let* ((n (which-key--pages-num-pages which-key--pages-obj))
           (page (car (which-key--pages-page-nums which-key--pages-obj))))
      (when (> n 1)
        (format "  page %d/%d  %s n/p"
                page n (key-description (vector help-char)))))))

(defun leader-wk--read-event (prompt-fn)
  "Read an event with paging support."
  (let ((paging-key (and which-key-paging-key (kbd which-key-paging-key)))
        char)
    (while (not char)
      (setq char (funcall leader--event-reader
                          (concat (funcall prompt-fn)
                                  (or (leader-wk--page-hint) ""))))
      (if (and which-key-use-C-h-commands
               (numberp char) (= char help-char)
               which-key--pages-obj
               (> (which-key--pages-num-pages which-key--pages-obj) 1))
          (let ((ch (funcall leader--event-reader (leader-wk--page-hint))))
            (cond ((eq ch ?n) (leader-wk--next-page 1))
                  ((eq ch ?p) (leader-wk--next-page -1)))
            (setq char nil))
        (when (and paging-key (equal (vector char) paging-key))
          (leader-wk--show-popup t)
          (leader-wk--next-page 1)
          (setq char nil))))
    char))

(defun leader--which-key-show (keys modifier)
  "Show which-key popup for KEYS with MODIFIER bias.
Installed as `leader--which-key-show-fn'."
  (let* ((modifier-only (and (or (null keys) (string-empty-p keys))
                             modifier))
         (bindings (if modifier-only
                       (leader-wk--modifier-bindings modifier)
                     (leader-wk--collect-prefix-bindings keys modifier)))
         (pages (and bindings (which-key--format-and-replace bindings)))
         (prefix (if modifier-only modifier keys)))
    (message "%s" (leader--prompt keys modifier))
    (when pages
      (setq which-key--pages-obj
            (which-key--create-pages pages nil prefix))
      (when (sit-for which-key-idle-delay)
        (leader-wk--show-popup t)))))

(defun leader--which-key-modifier-read (target prefix)
  "Read a key with modifier-prefix which-key for TARGET.
Installed as `leader--which-key-modifier-read-fn'."
  (leader-wk--hide)
  (let* ((continuation-p (and prefix (not (string-empty-p prefix))))
         (page-prefix (if continuation-p (concat prefix " " target) target))
         (raw (leader-wk--modifier-bindings target))
         (bindings
          (if (not continuation-p)
              raw
            ;; Continuation: rebuild full key paths (prefix + mod-key)
            ;; and filter to those reachable under the current prefix.
            (delq nil
                  (mapcar
                   (lambda (b)
                     (let* ((mod-key (car b))
                            (full-key (concat prefix " " mod-key))
                            (binding (key-binding (kbd full-key))))
                       (when binding
                         (cons full-key
                               (cond ((keymapp binding) "prefix")
                                     ((symbolp binding)
                                      (symbol-name binding))
                                     (t (format "%s" binding)))))))
                   raw)))))
    (message "%s" (concat (if continuation-p (concat prefix " ") "")
                          target "-"))
    (when bindings
      (let ((pages (which-key--format-and-replace bindings)))
        (when pages
          (setq which-key--pages-obj
                (which-key--create-pages pages nil page-prefix))
          (sit-for which-key-idle-delay)
          (leader-wk--show-popup t))))
    (unwind-protect
        (leader-wk--read-event
         (lambda ()
           (concat (if continuation-p (concat prefix " ") "")
                   target "-")))
      (leader-wk--hide))))

(defun leader-which-key-setup ()
  "Set up which-key integration hooks into leader."
  (setq leader--which-key-show-fn #'leader--which-key-show)
  (setq leader--which-key-modifier-read-fn #'leader--which-key-modifier-read)
  (setq leader--which-key-read-event-fn #'leader-wk--read-event))

(defun leader-which-key-teardown ()
  "Remove which-key integration hooks."
  (setq leader--which-key-show-fn nil
        leader--which-key-modifier-read-fn nil
        leader--which-key-read-event-fn nil))

(with-eval-after-load 'leader
  (leader-which-key-setup))

(provide 'leader-which-key)

;; Local Variables:
;; coding: utf-8
;; End:
;;; leader-which-key.el ends here
