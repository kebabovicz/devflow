# Design it twice

The first shape that comes to mind is rarely the best one, and once it is written into `design.md` nobody argues with it again. This produces three genuinely different shapes in parallel, compares them, and recommends one.

## When it applies

At the detailed-design stage, when what is being decided is **the shape of something expensive to change**:

- the interface of a module — the calls it exposes to the rest of the code, not a screen;
- an API contract between a client and a service, or between two services;
- how responsibilities are split — which part owns what, and what crosses the boundary;
- a user-facing flow, when that flow is the decision rather than a rendering of one already made.

It does not apply to a change that adds a field to an existing call, or to anything whose shape is already fixed by something outside this effort.

**Offered once, with the price named.** Three design agents in parallel are a real spend — tens of thousands of tokens — and the user decides. A refusal is not re-asked later in the same effort. Without the Agent or Workflow tools in the session, say so once and produce a single design.

## 1. Frame the problem space

Before spawning anything, write the frame for the user:

- the constraints any design here has to satisfy;
- the dependencies it would rest on, and which of them cross a seam;
- a rough code sketch — **not a proposal**, a way to make the constraints concrete.

Show it, then start the agents immediately. The user reads and thinks while the agents work; that overlap is the point of doing it this way.

## 2. Three designs, three constraints

Spawn three agents in parallel, each with a different constraint. A fourth joins when a dependency crosses a seam.

1. **Minimize the interface** — one to three entry points, as much work behind each as possible.
2. **Maximize flexibility** — many use cases, room to extend without breaking callers.
3. **Optimize the common caller** — the case that happens ninety percent of the time must be trivial.
4. **Ports and adapters** — the crossing dependency sits behind a port, with adapters on the far side.

These are the baseline, not a liturgy. Where a constraint has no bite here — flexibility nobody will ever use, a common case that does not exist — replace it with one that does. A constraint nobody needs produces a cosmetic variant, and three cosmetic variants are worse than one honest design.

Each agent gets a **technical brief**, separate from the user-facing frame: the files involved, what is coupled to what, what sits behind the seam, the design vocabulary in `${CLAUDE_SKILL_DIR}/../DESIGN-VOCAB.md`, and the project's own vocabulary from CLAUDE.md and the map's *How it works today* — so all three name the same things the same way.

Each returns five things:

1. the interface — types, methods, parameters, invariants, call ordering, error modes;
2. a usage example showing what a caller writes;
3. what the implementation hides behind the seam;
4. how dependencies are handled, and which adapters that implies;
5. trade-offs — where it is strong, where it is thin.

## 3. Present, compare, recommend

Show the designs **one at a time** so each can be absorbed, then compare them in prose along three axes — **depth**, **locality**, and **seam placement**, all three defined in `${CLAUDE_SKILL_DIR}/../DESIGN-VOCAB.md`. Read it before comparing: without those words the comparison collapses into "I like the second one better".

Then **recommend one**, with the reasoning. Not a menu: the user asked for a design, and three options with equal weight hand the work straight back to them. Where elements of two designs combine cleanly, propose the hybrid and say what it borrows from where.

## 4. Record it

The chosen design goes into `design.md` under *Interfaces and seams*, in full.

Each design that lost gets **one paragraph** under *Rejected alternatives*: what the idea was, what it cost, why it lost. The full texts stay in the conversation and die with it — that is deliberate. What a future session needs is the reason the option was rejected, not the option's details; the details would only invite re-litigating a settled decision.
