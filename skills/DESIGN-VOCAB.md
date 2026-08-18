# Words for designing modules

One vocabulary, used the same way by everything in devflow that designs code: the detailed-design stage of `/devflow:map`, `map/DESIGN-IT-TWICE.md`, and the design sections of `design.md`. Use these words exactly. Substituting "component", "service", "API", or "boundary" is not a stylistic choice — it is how two people end up agreeing in words and disagreeing in fact.

The goal all of this serves: **a lot of behavior behind a small interface, placed at a seam that can be tested through.**

## Glossary

**Module** — anything with an interface and an implementation. Deliberately scale-free: a function, a class, a package, a slice cutting through several layers. Do not say *unit*, *component*, or *service* — each drags in a size the word module deliberately refuses to fix.

**Interface** — everything a caller must know to use the module correctly. Not just the signature: invariants, the order calls must come in, error modes, required configuration, and performance characteristics that callers depend on. *Signature* and *API* are narrower — they name only the type-level surface, which is the part that is already visible.

**Implementation** — what is inside the module. Distinct from *adapter*, which names a role: a thing can be a small adapter with a large implementation (a Postgres-backed repository) or a large adapter with a small one (an in-memory fake). Say *adapter* when the seam is the subject, *implementation* otherwise.

**Depth** — leverage at the interface: how much behavior a caller or a test can reach per unit of interface it has to learn. A module is **deep** when a lot of behavior sits behind a small interface, **shallow** when the interface is nearly as complicated as what it hides.

**Seam** (Michael Feathers) — a place where behavior can be changed without editing in that place; the location where a module's interface lives. Where to put the seam is a design decision of its own, separate from what goes behind it. Do not say *boundary* — it is already taken by DDD's bounded context.

**Adapter** — a concrete thing satisfying an interface at a seam. It names the slot filled, not what is inside.

**Leverage** — what callers get from depth: more capability per unit of interface learned. One implementation pays back across every call site and every test.

**Locality** — what maintainers get from depth: change, bugs, knowledge, and verification concentrate in one place instead of spreading across callers. Fixed once, fixed everywhere.

## Deep and shallow

```
  deep                         shallow
┌──────────────┐             ┌────────────────────────────┐
│  interface   │  small      │        interface           │  large
├──────────────┤             ├────────────────────────────┤
│              │             │  implementation            │  thin
│ implementation             └────────────────────────────┘
│              │
└──────────────┘
```

A shallow module makes the caller learn nearly as much as writing the logic themselves would have — it renames work rather than removing it. Three questions turn a shallow interface deep: can methods be merged or dropped, can parameters be simplified, can more of the complication live inside?

## Principles

- **Depth is a property of the interface, not of the implementation.** A deep module may be built inside from small swappable parts; they are simply not part of what callers see. A module can have internal seams, private to its implementation and used by its own tests, as well as the external seam at its interface.
- **The deletion test.** Imagine the module deleted. If complexity disappears with it, it was a pass-through. If the same complexity reappears in every caller, it was earning its place.
- **The interface is the test surface.** Callers and tests cross the same seam. Wanting to test *past* the interface is the signal that the module has the wrong shape — not the signal to reach around it.
- **One adapter is a hypothetical seam; two adapters make it real.** Do not introduce a seam until something actually varies across it. A seam with one thing behind it is an abstraction waiting for a second consumer that may never arrive.

## Shapes that stay testable

Stack-independent, because the failure is the same everywhere:

- **Take dependencies, do not construct them.** A module that builds its own database client, clock, or HTTP client has welded itself to them; the test has no seam left to stand at.
- **Return results rather than mutate what you were handed.** A function that answers a question can be checked by asking it. One that quietly changes a structure can only be checked by inspecting the world afterwards.
- **Keep the surface small.** Fewer entry points and simpler parameters mean fewer tests and less setup per test — the same property that makes the module deep makes its tests short.

## Framings deliberately rejected

- **Depth as a ratio of implementation lines to interface lines.** It rewards a padded implementation. Depth here is leverage: behavior reachable per unit of interface learned.
- **Interface as the language's `interface` keyword, or a class's public methods.** Too narrow. Ordering rules, error modes, and required configuration are part of the interface even when no type expresses them.
- **Boundary** as a synonym for seam. It already means a bounded context to anyone who has read DDD, and the two decisions are not the same decision.
