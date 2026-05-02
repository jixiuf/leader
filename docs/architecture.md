# leader.el — Architecture

## Overview

A modal leader-key package for Emacs.  Press a leader key (SPC, `,`, `.`) and
subsequent keystrokes are translated via dispatch rules + modifier/fallback
logic, through `key-translation-map` (lowest input level, universal coverage).

```
User presses SPC f
  → key-translation-map intercepts SPC
  → handler builds key sequence "C-c C-f"
  → Emacs executes C-c C-f command
```

## File Map

| File | Lines | Role |
|------|-------|------|
| `leader.el` | ~650 | Core: config, normalization, handler, install/uninstall |
| `leader-which-key.el` | ~230 | Optional which-key popup module, connected via hooks |
| `test/leader-test.el` | ~485 | 50 ERT tests covering all features |
| `README.md` | ~200 | User-facing docs with full config demo |

## Data Model

### `leader-context` struct

The central data structure.  Every leader key and every dispatch entry is
normalized into one instance.  All fields are fully resolved at normalize time;
no runtime default-filling.

```
(cl-defstruct leader-context
  prefix                  ; "C-x", "C-c", nil (modifier-only)
  modifier                ; "C-", "M-", nil
  fallback                ; "C-", nil (always explicit)
  toggle-target           ; "C-", nil
  dispatch-alist          ; ((char . leader-context) ...)  root-level
  local-dispatch-alist    ; ((char . leader-context) ...)  cont-only, nil=use root
  leader-char             ; integer event code
  pass-through-predicates) ; nil=use global, list=per-key override
```

### User Config → Normalized

```elisp
;; User writes:
(:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"
 :dispatch ((?x . (:prefix "C-x" :modifier "C-" :fallback "C-"))))

;; After leader--normalize-config:
#s(leader-context
   prefix "C-c" modifier "C-" fallback "C-" toggle-target nil
   dispatch-alist ((?x . #s(leader-context prefix "C-x" modifier "C-" ...)))
   local-dispatch-alist nil leader-char 32 pass-through-predicates nil)
```

## Normalization Pipeline

```
leader-keys (user plists)
  │
  ├─ leader--normalize-config()
  │    ├─ Extract :key, :prefix, :modifier, :fallback, :toggle
  │    ├─ leader--normalize-prefix-plist(plist) → (prefix mod fb toggle local-dispatch)
  │    │    ├─ Empty-string → nil normalization
  │    │    ├─ Fallback default: (null prefix) → nil, else → modifier
  │    │    └─ Toggle default: leader--infer-toggle(modifier, fallback)
  │    └─ leader--normalize-dispatch(alist)
  │         └─ Recursively normalizes nested :dispatch entries
  │
  └─ leader--normalized-config (cached list of leader-context)
```

### Inference Rules

| Field | When omitted | Logic |
|-------|-------------|-------|
| `:fallback` | Inferred | modifier-only prefix (nil) → nil; regular prefix → equals `:modifier` |
| `:toggle` | Inferred | fallback ≠ modifier → fallback; modifier non-nil → nil; modifier nil → `"C-"` |

## Handler Flow (State Machine)

```
key-translation-map
  │
  └─ leader--make-handler(ctx) → closure
       └─ leader--run-handler(vkeys, ctx)
            │
            ├─ len > 1: pass through (not a fresh leader press)
            ├─ leader--pass-through-p(ctx.pass-through-predicates): pass through
            │
            └─ len = 1: MAIN LOOP
                 │
                 ┌─────────────────────────────────────────┐
                 │  let: which-key-inhibit = t             │
                 │  let: which-key-this-command-keys-fn    │
                 │                                         │
                 │  WHILE state ≠ :done                    │
                 │    │                                     │
                 │    ├─ leader--read-event-with-which-key │
                 │    │   ├─ leader--which-key-show-fn     │──→ which-key popup
                 │    │   └─ leader--which-key-read-fn     │──→ paging support
                 │    │                                     │
                 │    └─ leader--process-char(ctx, char,   │
                 │          prefix-keys, continuation-p)    │
                 │         │                                 │
                 │         ├─ :done     → exit loop         │
                 │         ├─ :continue → set cont-p, loop  │
                 │         └─ nil       → loop (toggle)     │
                 │                                           │
                 └─ (kbd (car prefix-keys))  → final key    │
                 └─────────────────────────────────────────┘
```

## leader--process-char — Core Dispatch Logic

```
1. Determine dispatch alist:
   continuation-p ? (or ctx.local-dispatch-alist ctx.dispatch-alist)
                  : ctx.dispatch-alist

2. Classify dispatch (if any):
   is-toggle-dispatch:   prefix=empty, modifier=nil, toggle-target set
   is-direct-dispatch:   prefix non-empty
   is-modifier-dispatch: prefix=empty, modifier non-nil

3. Suppress direct dispatch in continuation (continuation-p && is-direct-dispatch)

4. Prefer-command check (non-nil leader-dispatch-priority only):
   Resolve char via leader--resolve-key → if bound command wins → return :done

5. Route to handler:
   ├─ TOGGLE
   │   ├─ Prefer-command (leader-toggle-priority ≠ nil): check bound command
   │   └─ Flip modifier: current-modifier → nil → toggle-target → ...
   │
   ├─ MODIFIER-PREFIX (e.g., ?m → M-)
   │   ├─ continuation-p && no completions → fallback (e883dd3)
   │   └─ Read second key via leader--read-modifier-event → build key
   │
   └─ t (direct dispatch or no dispatch)
       ├─ dispatch-ctx: set new prefix/modifier/fallback/toggle/local-dispatch
       └─ no dispatch: apply leader--resolve-key
       └─ Check binding: keymap → :continue, command → :done
```

## Modifier/Fallback Resolution

`leader--resolve-key(prefix, modifier, fallback, char)` → `(KEY-STRING . FALLBACK-P)`

```
modifier non-nil:
  try MODIFIER+char → if bound, (key nil)
                    → else (plain-char t)

modifier nil:
  try plain char    → if bound, (key nil)
  try FALLBACK+char → if bound, (key t)
                    → else (plain-char t)
```

## Continuation

When a resolved key is a prefix keymap (not a command), the handler loops
with `continuation-p = t`:

- **Direct dispatches** (prefix switches) are suppressed — changing prefix
  mid-continuation makes no sense.
- **Toggle** always works, using the current context's toggle-target.
- **Modifier-prefix dispatches** work if completions exist under the prefix;
  otherwise fall back to plain key resolution (e883dd3).
- `ctx.local-dispatch-alist` is copied from the dispatch entry on context switch.
  In continuation, it takes priority over the root dispatch-alist.

## Priority System

Two independent variables:

| Variable | Default | Controls |
|----------|---------|----------|
| `leader-dispatch-priority` | nil | Whether dispatch entries or bound commands win |
| `leader-toggle-priority` | nil | Whether toggle or bound commands win |

Both use `leader--command-wins-p(priority, fallback-p)`:
- `nil` → feature always wins
- `t` → command always wins (primary + fallback)
- `:primary` → primary command wins; fallback match loses

## Pass-Through Predicates

`leader--pass-through-p(&optional predicates)` checks each element:

```
symbol:
  1. boundp    → symbol-value (e.g., minor-mode variable isearch-mode)
  2. commandp && eq major-mode → t (e.g., vc-dir-mode with void variable)
  3. fboundp && !commandp → funcall (e.g., isearch-mode as function)
  4. otherwise → nil

function: funcall → non-nil means pass-through
```

Per-key override via `:pass-through-predicates` on leader-keys entries.

## Which-Key Integration

`leader-which-key.el` is a separate optional module.  It communicates with the
core through three hook variables:

| Hook | Set by which-key module | Called from core |
|------|------------------------|------------------|
| `leader--which-key-show-fn` | `leader--which-key-show` | `leader--read-event-with-which-key` |
| `leader--which-key-modifier-read-fn` | `leader--which-key-modifier-read` | `leader--read-modifier-event` |
| `leader--which-key-read-event-fn` | `leader-wk--read-event` | `leader--read-event-with-which-key` |

The core never depends on which-key — when hooks are nil, it falls back to
plain `read-event` and `message` prompts.

### Architecture

```
leader.el                          leader-which-key.el
─────────                          ───────────────────
leader--read-event-with-which-key
  ├─ funcall show-fn ─────────────→ leader--which-key-show
  │                                  ├─ leader-wk--collect-prefix-bindings (keymap)
  │                                  │  or leader-wk--modifier-bindings (mod-only)
  │                                  ├─ which-key--format-and-replace
  │                                  ├─ which-key--create-pages
  │                                  └─ sit-for + leader-wk--show-popup
  └─ funcall read-event-fn ───────→ leader-wk--read-event
                                      └─ paging: C-h n/p via leader-wk--next-page

leader--read-modifier-event
  └─ funcall modifier-read-fn ────→ leader--which-key-modifier-read
                                      ├─ leader-wk--hide (clear old popup)
                                      ├─ leader-wk--modifier-bindings (from all maps)
                                      │  └─ leader--collect-modifier-bindings (core)
                                      ├─ continuation filtering (prefix + key-binding)
                                      ├─ which-key--create-pages
                                      └─ sit-for + leader-wk--show-popup
```

## Test Patterns

Tests use mock injection via dynamic variables:
- `leader--event-reader` → mock that pops from a list of events
- `leader--key-lookup-fn` → mock that looks up binding alists
- `leader-test--do-run(config, bindings, events)` → sets up mocks, calls handler

```elisp
(should (equal (leader-test--do-run
                '((:key "<SPC>" :prefix "C-c" :modifier "C-" :fallback "C-"))
                '(("C-c C-f" . ignore))      ; mock bindings
                '(?f))                        ; mock events
               "C-c C-f"))                    ; expected key-description
```

## Install / Uninstall

`leader-mode` is a global minor mode:
- Enable: `leader--normalize-config()` → `leader--install()`
  → define-key in `key-translation-map` for each leader
- Disable: `leader--uninstall()` → remove from `key-translation-map`

Handlers are closures created by `leader--make-handler(ctx)` which copies the
context before each invocation (via `copy-leader-context`) to avoid state leaks.

## Key Design Decisions

1. **key-translation-map** over static keymaps — translates keys at the lowest
   input level, works in any mode, no keymap conflicts.

2. **Normalize upfront** — all config parsing, default filling, and inference
   happens once in `leader--normalize-config`.  Runtime code has zero
   conditional logic for config defaults.

3. **Hook-based which-key** — core never imports which-key.  Three hook
   variables provide clean separation.  No which-key → plain prompts still work.

4. **Per-context state** — each dispatch entry carries its own `leader-context`
   with independent modifier, fallback, toggle-target, and local dispatches.
   Entering a dispatch copies relevant fields into the active ctx.

5. **Dynamic-binding cleanup** — `which-key-inhibit` and
   `which-key-this-command-keys-function` are let-bound in the handler.
   C-g triggers `condition-case` cleanup (hide popup, clear pages).
   Let-bindings auto-restore on any exit path.
