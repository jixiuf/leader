# leader.el

A modal leader-key package for Emacs that intercepts one or more "leader keys" via
`key-translation-map` and translates subsequent keystrokes into standard Emacs key sequences, so you
can type `SPC x f` instead of `C-x C-f`, etc.

## Installation

```elisp
(add-to-list 'load-path "/path/to/leader")
(require 'leader)
(leader-mode 1)
```

## Quick Start

```elisp
(require 'leader)
(leader-mode 1)           ; enable
(leader-mode -1)          ; disable
```

## Configuration

### `leader-keys'

A list of leader key configurations. Each element has the form:

```elisp
(LEADER-KEY DEFAULT-PREFIX [DISPATCH-ENTRY ...])
```

- `LEADER-KEY`: A key description string (e.g. `"<SPC>"`, `","`).
- `DEFAULT-PREFIX`: Either a string or a list specifying the prefix, modifier-default, and optionally fallback-modifier.

#### DEFAULT-PREFIX Formats

| Format | modifier-default | fallback-modifier | Description |
|--------|---------------|-------------------|-------------|
| `"C-c"` | `"C-"` | `"C-"` | Auto-add C- to keys |
| `("C-c" nil)` | `nil` | `nil` | No modifier, no fallback |
| `("C-c" nil "C-")` | `nil` | `"C-"` | Plain keys, fallback to C- |
| `("C-c" "C-")` | `"C-"` | `"C-"` | Explicit C- |
| `("C-c" "M-")` | `"M-"` | `"M-"` | Auto-add M- |

The third element (`fallback-modifier`) is optional. When omitted it
defaults to `modifier-default`.

#### Examples

```elisp
;; Single leader with modifier-default="C-" (default)
'(("<SPC>" "C-c"
   (?h . "C-h")
   (?x . "C-x")))

;; Single leader with modifier-default=nil, fallback-modifier="C-"
'(("<SPC>" ("C-c" nil "C-")
   (?h . ("C-h" nil))
   (?x . ("C-x" "C-")))

;; Multiple leaders
'(("<SPC>" ("C-c" nil "C-")
   (?h . ("C-h" nil))
   (?x . ("C-x" "C-")))
 ("," "M-o"))
```

## Dispatch Entry Types

Dispatch entries apply at **every level**, including inside prefix keymaps
(after entering a prefix like `C-x`). Use `leader-dispatch-priority`
to control priority between bound commands and dispatch entries.

### Prefix Switch

```elisp
(?x . "C-x")            ; SPC x f -> C-x C-f (reset to defaults)
(?h . ("C-h" nil))      ; SPC h k -> C-h k (modifier=nil)
(?g . ("C-x" "M-"))    ; SPC g f -> C-x M-f (modifier="M-")
```

With fallback override (third element):
```elisp
(?x . ("C-x" "C-" nil)) ; SPC x f -> C-x C-f (C- only, no plain fallback)
(?h . ("C-h" nil "C-")) ; SPC h k -> C-h k (plain first, fallback to C-)
```

### Modifier Prefix (values ending with "-")

```elisp
(?r . "M-")    ; SPC r x -> M-x
(?e . "C-M-")  ; SPC e f -> C-M-f
```

### Modifier Toggle (`"C-"`)

Pressing the leader key itself (when not in dispatch alist) or a key dispatched to `"C-"` toggles the modifier state between `modifier-default` and `nil` (or `"C-"` if `modifier-default` is also nil).

| DEFAULT-PREFIX | modifier-default | toggle-target |
|---------------|----------------|--------------|
| `"C-c"` | `"C-"` | `nil` |
| `("C-c" "C-")` | `"C-"` | `nil` |
| `("C-c" nil)` | `nil` | `"C-"` |
| `("C-c" "M-")` | `"M-"` | `nil` |

### Key Resolution Logic

When modifier is non-nil:
1. Try `modifier+char` first
2. Fall back to plain char if no binding

When modifier is nil:
1. Try plain char first
2. Fall back to `fallback-modifier+char` if set and binding exists

## Predicates for Pass-through

`leader-pass-through-predicates` controls when the leader key passes through as a normal key (e.g., SPC inserts a space). By default, pass through happens in the minibuffer and during isearch.

Each element is either:
- A function (or lambda): called with no arguments, pass through if non-nil.
- A symbol: if bound as a variable, use its value; if bound as a function, call it.

```elisp
;; Default value:
(setq leader-pass-through-predicates
      '(minibufferp isearch-mode))

;; For helix:
(add-to-list 'leader-pass-through-predicates
             (lambda () (eq helix--current-state 'insert)))

;; For evil:
(add-to-list 'leader-pass-through-predicates
             (lambda () (evil-insert-state-p)))

;; Pass through when a minor mode is active:
(add-to-list 'leader-pass-through-predicates 'my-special-input-mode)
```

## Dispatch in Continuation

Dispatch entries apply at **every level**, including inside prefix keymaps.
After entering a prefix (e.g., `C-x`), subsequent keys still consult the
dispatch alist.

```elisp
;; With modifier-default=nil, dispatch has (?b . ("C-b" "C-")):
;;   SPC a → C-c a (prefix), b → dispatch to C-b (direct, in continuation)
;;   Then f → C-c a C-b C-f
```

### `leader-dispatch-priority`

Priority ordering for resolving dispatch vs. command conflicts.
When a key matches a dispatch entry AND resolves to a bound command,
the higher-priority action wins.

Categories (ordered by priority, higher first):
- `:dispatch` — direct key sequences (e.g. `C-x`, `C-b`)
- `:modifier-prefix` — modifier prefixes (e.g. `M-`, `C-M-`)
- `:toggle` — modifier toggles (`C-` dispatch, leader double-press)
- `:command` — primary bound commands (modifier or plain match)
- `:command-fallback` — fallback bound commands (modifier-fallback match)

```elisp
(setq leader-dispatch-priority nil)
;; Default: dispatch always wins.  Equivalent to:
;; '(:dispatch :modifier-prefix :toggle)

(setq leader-dispatch-priority t)
;; Commands (primary and fallback) always win.  Equivalent to:
;; '(:command :command-fallback)

(setq leader-dispatch-priority '(:modifier-prefix :dispatch :command :command-fallback :toggle))
;; Modifier prefixes and direct dispatches take priority over primary
;; commands, primary commands over fallback commands, fallback commands
;; over toggles.

;; Example: dispatch has (?e . "M-"), and "C-c e" is a bound command
;; With '(:modifier-prefix :dispatch :command :command-fallback :toggle):
;;   SPC e → M- (dispatch wins)
;; With '(:command :command-fallback :modifier-prefix):
;;   SPC e → C-c e (command wins)
;; With nil:
;;   SPC e → M- (dispatch wins)
```

## Full Configuration Example

```elisp
(setq leader-keys
      '(("<SPC>" ("C-c" nil "C-")  ; prefix, modifier-default, fallback-modifier
         (?h . ("C-h" nil "C-"))  ; SPC h -> C-h prefix, plain first, fallback C-
         (?x . ("C-x" "C-" nil)) ; SPC x -> C-x prefix, C- only, no plain fallback
         (?c . "C-c")            ; SPC c -> C-c prefix (modifier-default)
         (?r . "M-")            ; SPC r x -> M-x
         (?e . "C-M-"))         ; SPC e f -> C-M-f
        ("," "M-o")))
```

## Behavior Examples

### With `("C-c" nil "C-")` (modifier-default=nil, fallback-modifier="C-")

| Keystrokes | Translation | Explanation |
|------------|-------------|--------------|
| SPC f | C-c f | modifier=nil, plain f bound |
| SPC f (no binding) | C-c C-f | fallback to fallback-modifier+char |
| SPC SPC f | C-c C-f | toggle -> modifier="C-" |
| SPC x f | C-x C-f | x->("C-x" "C-") -> modifier="C-" |
| SPC h k | C-h k | h->("C-h" nil) -> modifier=nil |

### With `"C-c"` (modifier-default="C-")

| Keystrokes | Translation | Explanation |
|------------|-------------|--------------|
| SPC f | C-c C-f | modifier="C-", try C-c C-f |
| SPC f (no binding) | C-c f | fallback to plain f |
| SPC SPC f | C-c f | toggle -> modifier=nil |
| SPC x f | C-x C-f | dispatch x->C-x |

### Dispatch in Continuation (modifier-default=nil, dispatch has (?b . ("C-b" "C-")))

| Keystrokes | Translation | Explanation |
|------------|-------------|--------------|
| SPC a b | C-c a C-b | a->prefix "C-c a", b->dispatch "C-b" in continuation |
| SPC a b f | C-c a C-b C-f | dispatch "C-b" then f with C- modifier |

### Prefer-command (dispatch has (?e . "C-M-"), C-c e is bound)

| Keystrokes | Translation | Explanation |
|------------|-------------|--------------|
| SPC e | C-c e | prefer-command=t (default), command wins |
| SPC e (nil) | dispatches | prefer-command=nil, dispatch to C-M- |

## Commands

- `leader-mode` - Toggle the leader mode globally

## Variables

- `leader-keys` - List of leader key configurations
- `leader-pass-through-predicates` - List of predicates for pass-through
- `leader-dispatch-priority` - Priority ordering for dispatch vs. command conflicts (default nil)

## Comparison with Other Leader Key Packages

### Overview

| Feature | leader.el | general.el | bind-map | evil-leader |
|---------|----------|------------|---------|------------|
| Works without Evil | ✓ | ✓ | ✓ | ✗ |
| Dynamic key translation | ✓ | ✗ | ✗ | ✗ |
| Smart fallback (C-/plain) | ✓ | ✗ | ✗ | ✗ |
| Modifier toggle | ✓ | ✗ | ✗ | ✗ |
| Active development | ✓ | ✓ | ✓ | ✗ (deprecated) |

### leader.el vs general.el

general.el is a key-definition convenience library that can also provide leader-key functionality. It works with or without Evil.

**general.el Pros:**
- Mature (2016-), well-documented
- Works with Evil states (normal, insert, visual, etc.)
- Integrates with `use-package`
- Rich key-definition DSL
- Can define keys for multiple states at once
- Works without Evil

**general.el Cons:**
- Uses static keymaps (not dynamic translation)
- No smart fallback between C-/plain keys
- No modifier toggle feature
- Requires more boilerplate for simple leader use

**leader.el Pros:**
- Uses `key-translation-map` for universal interception
- Smart modifier system with automatic fallback
- Per-prefix modifier override
- Dispatch entries apply at every level (in prefix keymaps too)
- Toggle between different modifier states
- Simple configuration format

**leader.el Cons:**
- Less mature (newer package)
- No Evil state integration
- Requires Emacs 28.1+

### leader.el vs bind-map

bind-map makes keymaps available across different leader keys and Evil states. It can work without Evil.

**bind-map Pros:**
- Works without Evil
- Supports per-major-mode keymaps
- Mature, stable

**bind-map Cons:**
- Uses static keymaps (not dynamic translation)
- No smart fallback
- No modifier toggle
- More verbose configuration

### leader.el vs evil-leader

evil-leader is a simple Evil-specific leader key package that has not been updated since 2014. Deprecated.

### Key Differences

1. **Dynamic vs Static**: leader.el uses `key-translation-map` to dynamically translate keys, while general.el and bind-map use static keymaps attached to prefix keys.

2. **Smart Fallback**: leader.el automatically tries `C-x C-f`, falls back to `C-x f` if no binding. Static keymaps require explicit fallback bindings.

3. **Modifier Toggle**: leader.el can toggle between `C-` and plain keys on the fly (e.g., `SPC SPC` toggles), unique among all packages.
