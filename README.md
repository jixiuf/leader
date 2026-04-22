# leader.el

A modal leader-key package for Emacs that intercepts one or more "leader keys" via `key-translation-map' and translates subsequent keystrokes into standard Emacs key sequences, so you can type `SPC f' instead of `C-c C-f', etc.

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
- `DEFAULT-PREFIX`: Either a string or a list specifying the prefix and default modifier.

#### DEFAULT-PREFIX Formats

| Format | modifier-default | Description |
|--------|---------------|------------|
| `"C-c"` | `"C-"` | Auto-add C- to keys |
| `("C-c" nil)` | `nil` | No modifier |
| `("C-c" "C-")` | `"C-"` | Explicit C- |
| `("C-c" "M-")` | `"M-"` | Auto-add M- |

#### Examples

```elisp
;; Single leader with modifier-default="C-" (default)
'(("<SPC>" "C-c"
   (?h . "C-h")
   (?x . "C-x")))

;; Single leader with modifier-default=nil
'(("<SPC>" ("C-c" nil)
   (?h . ("C-h" . nil))
   (?x . ("C-x" . "C-")))

;; Multiple leaders
'(("<SPC>" ("C-c" nil)
   (?h . ("C-h" . nil))
   (?x . ("C-x" . "C-")))
 ("," "M-o"))
```

## Dispatch Entry Types

### Prefix Switch

```elisp
(?x . "C-x")            ; SPC x f -> C-x C-f
(?h . ("C-h" . nil))    ; SPC h k -> C-h k (no auto C-)
(?g . ("C-x" . "M-"))  ; SPC g f -> C-x M-f
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
2. Fall back to `modifier-default+char` if no binding

## Predicates for Pass-through

Use `leader-pass-through-predicates` to define when the leader key should pass through as a normal key (e.g., in isearch or minibuffer):

```elisp
(setq leader-pass-through-predicates '(isearch-mode minibufferp))

;; For helix:
(add-to-list 'leader-pass-through-predicates
             (lambda () (eq helix--current-state 'insert)))

;; For evil:
(add-to-list 'leader-pass-through-predicates
             (lambda () (evil-insert-state-p)))
```

## Full Configuration Example

```elisp
(setq leader-keys
      '(("<SPC>" ("C-c" nil)
         (?h . ("C-h" . nil))     ; SPC h -> C-h prefix, no modifier
         (?x . ("C-x" . "C-"))   ; SPC x -> C-x prefix, modifier="C-"
         (?c . "C-c")            ; SPC c -> C-c prefix (modifier-default)
         (?r . "M-")            ; SPC r x -> M-x
         (?e . "C-M-"))         ; SPC e f -> C-M-f
        ("," "M-o")))

(leader-mode 1)
```

## Behavior Examples

### With `("C-c" nil)` (modifier-default=nil)

| Keystrokes | Translation | Explanation |
|------------|-------------|--------------|
| SPC f | C-c f | modifier=nil, plain f |
| SPC SPC f | C-c C-f | toggle -> modifier="C-" |
| SPC x f | C-x C-f | x->("C-x"."C-") -> modifier="C-" |
| SPC h k | C-h k | h->("C-h".nil) -> modifier=nil |

### With `"C-c"` (modifier-default="C-")

| Keystrokes | Translation | Explanation |
|------------|-------------|--------------|
| SPC f | C-c C-f | modifier="C-", try C-c C-f |
| SPC f (no binding) | C-c f | fallback to plain f |
| SPC SPC f | C-c f | toggle -> modifier=nil |
| SPC x f | C-x C-f | dispatch x->C-x |

## Commands

- `leader-mode` - Toggle the leader mode globally

## Variables

- `leader-keys` - List of leader key configurations
- `leader-pass-through-predicates` - List of predicates for pass-through

## License

GPL v3