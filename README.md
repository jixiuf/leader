# leader.el

A modal leader-key package for Emacs.  It intercepts one or more "leader keys"
via `key-translation-map` and translates subsequent keystrokes into standard
Emacs key sequences, so you can type `SPC f` instead of `C-c C-f`, etc.

## Quick Start

```elisp
(require 'leader)
(require 'leader-which-key)
(leader-mode 1)
```

## Configuration

`leader-keys` is a list of plists.  Each entry describes one leader key:

| Keyword | Required | Default | Description |
|---------|----------|---------|-------------|
| `:key` | yes | — | Leader key string (`"<SPC>"`, `","`) |
| `:prefix` | yes | — | Target prefix string (`"C-c"`, `"M-s"`, `""` for modifier-only) |
| `:modifier` | no | inferred | Default modifier (`"C-"`, `"M-"`, nil). Empty string = nil |
| `:fallback` | no | inferred | Fallback modifier. nil = plain only |
| `:toggle` | no | inferred | Toggle target modifier (see toggle section) |
| `:dispatch` | no | nil | Alist `(CHAR . PLIST)` or `(CHAR . :toggle)` |

### Default Inference

- **`:fallback`** defaults to `:modifier` (regular prefix) or nil (modifier-only prefix)
- **`:toggle`** defaults to fallback if fallback differs from modifier, else nil (flip on/off) or `"C-"` (modifier=nil)

### Examples

```elisp
(setq leader-keys
  '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
     :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-"))
                (?h . (:prefix "C-h" :modifier nil  :fallback "C-"))
                (?s . (:prefix "M-s" :modifier nil  :fallback "M-"))
                (?m . (:prefix ""   :modifier "M-" :fallback nil))
                (?d . :toggle)))
    (:key "," :prefix "" :modifier "C-M-" :fallback nil)))
```

## Dispatch Entries

Dispatch entries carry the same keys as a top-level leader entry (except `:key`).

| Type | Config | Behavior |
|------|--------|----------|
| Prefix switch | `(?x . (:prefix "C-x" :modifier "C-" :fallback "C-"))` | SPC x → enter C-x prefix |
| Plain modifier | `(?h . (:prefix "C-h" :modifier nil :fallback "C-"))` | SPC h k → C-h k (plain first) |
| Modifier-prefix | `(?m . (:prefix "" :modifier "M-" :fallback nil))` | SPC m x → M-x |
| Toggle | `(?d . :toggle)` | SPC d → toggle modifier |

Modifier-prefix dispatches (`:prefix ""` with a modifier) read a second key
and translate it with the modifier prepended.  In continuation contexts,
if no completions exist under the current prefix keymap, they fall back
to plain key resolution.

## Key Resolution Logic

For each subsequent keystroke after the leader key:

- **Modifier non-nil**: try `MODIFIER+char` → fall back to plain `char`
- **Modifier nil**: try plain `char` → fall back to `FALLBACK+char`

When nothing is bound, the plain key is returned as-is.

## Modifier Toggle

Pressing the leader key itself (SPC SPC) or a `:toggle` dispatch entry toggles
the current modifier between its value and the `:toggle` target.

Each context (dispatch entry or top-level) has an independent toggle target.
The default is inferred: if fallback differs from modifier, toggle to fallback;
if they are the same, toggle on/off (non-nil ↔ nil, nil ↔ `"C-"`).

## Continuation

When a key sequence resolves to a prefix keymap (e.g., C-c a → keymap),
the handler enters **continuation** and keeps reading keys until a command
is found or the sequence is exhausted.

In continuation:
- **Toggle** and **modifier-prefix** dispatches still apply
- **Direct prefix-switch** dispatches are suppressed (they don't make sense
  when already inside a prefix)
- Per-context `:dispatch` on dispatch entries defines local dispatches
  (modifier-prefix and toggle only) that apply in continuation

```elisp
;; Define M- and C- modifier-prefix dispatches for C-x continuation
(?x . (:prefix "C-x" :modifier "C-" :fallback "C-"
       :dispatch ((?m . (:prefix nil :modifier "M-" :fallback nil))
                  (?c . (:prefix nil :modifier "C-" :fallback "C-")))))
;; SPC x m a → C-x M-a  (local M- dispatch)
;; SPC x c f → C-x C-f  (local C- dispatch)
```

## Priority System

| Variable | Default | Controls |
|----------|---------|----------|
| `leader-dispatch-priority` | nil | Dispatch vs. bound-command |
| `leader-toggle-priority` | nil | Toggle vs. bound-command |

Values for both:

| Value | Behavior |
|-------|----------|
| `nil` | Feature (dispatch/toggle) always wins |
| `t` | Bound command always wins (primary + fallback) |
| `:primary` | Primary command wins; fallback loses to feature |

```elisp
;; Dispatch always wins, toggle checked against bound commands
(setq leader-dispatch-priority nil)
(setq leader-toggle-priority t)
;; → SPC x → dispatch to C-x (dispatch wins)
;; → SPC SPC → C-c C-SPC if bound, else toggle
```

## Pass-Through Predicates

`leader-pass-through-predicates` controls when the leader key acts as its
literal character (e.g., SPC inserts a space).  Each element is:

- A **function**: called with no args, pass-through if non-nil
- A **symbol**: checked in order: variable value → matches `major-mode`
  → non-command function.  Mode symbols like `vc-dir-mode` work
  even if their variable is void.

```elisp
;; Default — pass through in minibuffer and isearch
(setq leader-pass-through-predicates '(minibufferp isearch-mode))

;; Evil integration (use lambda — symbols are never funcall'd)
(add-to-list 'leader-pass-through-predicates
             (lambda () (and (bound-and-true-p evil-mode)
                             (evil-insert-state-p))))
```

## Which-Key Integration

```elisp
(require 'leader-which-key)
```

Automatically enables which-key popup display during leader key sequences,
including modifier-prefix contexts.  The popup respects `which-key-idle-delay`
and supports C-h n/p paging.

| Custom variable | Default | Description |
|-----------------|---------|-------------|
| `leader-which-key-modifier-max-bindings` | 150 | Max bindings in modifier-prefix popup (nil = unlimited) |

Modifier-prefix which-key (M-, C-M-) collects bindings from all active
keymaps filtered by the modifier, with the modifier string as the popup header.
In continuation the accumulated prefix is included in the header.

## Commands

- `leader-mode` — global minor mode, toggle leader key support

## Variables

- `leader-keys` — leader key configurations
- `leader-pass-through-predicates` — predicates for pass-through
- `leader-dispatch-priority` — dispatch vs. command priority
- `leader-toggle-priority` — toggle vs. command priority
