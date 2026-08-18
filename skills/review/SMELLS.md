# The smell baseline

A fixed set of code smells (Fowler, *Refactoring*, ch. 3) that the Standards check carries in **every** project, including one that documents nothing. Paste it whole into the Standards prompt — the checker has no other access to it.

## How it binds

- **Every entry is a judgment call**, and is reported as one: "possible Feature Envy", never "violation". A smell is a shape worth a second look, not a rule with an authority behind it.
- **A documented project rule does not silence a smell — it turns it into one question.** Where the repo's own standard endorses the shape, or the surrounding code does it everywhere, say so and ask once: is this deliberate, or is it what nobody had time to undo? Suppressing it silently is how a project's worst habit becomes invisible — the user only ever learns about it if someone points at it.
- **"Deliberate" gets written down, not just heard.** On a "yes, that's on purpose", offer to add one line to the repo's `REVIEW.md` — the file the Standards check reads first. Declined, the finding is dropped for this run only; the next session knows nothing about this conversation and will raise it again.
- **Skip anything tooling already enforces.** A linter, formatter, or analyzer that fails the build on it does not need a reviewer repeating it.
- **The diff is the scope.** A smell counts when the changed hunks exhibit it; that the rest of the file does the same is the reason to ask the pattern question, not the reason to stay quiet.

## The baseline

- **Mysterious name** — a function, variable, or type whose name does not say what it does or holds. → Rename it. If no honest name comes, the design behind it is murky.
- **Duplicated code** — the same logic shape in more than one hunk or file of the change. → Extract it once, call it from both.
- **Long function / long parameter list** — a body that has to be read in full to be understood, or a signature nobody can call without checking the definition. → Extract the steps; bundle the parameters that travel together.
- **Feature envy** — a function that reaches into another object's data more than its own. → Move it onto the data it envies.
- **Data clumps** — the same few fields or arguments keep appearing together: a type asking to be born. → Give them one type and pass that.
- **Primitive obsession** — a string or int standing in for a domain concept with its own rules. → Give the concept a small type of its own.
- **Repeated switches** — the same `switch`/`if`-cascade over the same type recurring across the change. → Polymorphism, or one map both sites share.
- **Shotgun surgery** — one logical change forcing scattered edits across many files. → Gather what changes together into one place.
- **Divergent change** — one module edited for several unrelated reasons. → Split it so each part changes for one reason.
- **Speculative generality** — abstraction, parameters, or extension points for needs nothing has yet. → Delete it; inline back until a second real consumer shows up.
- **Message chains** — `a.b().c().d()` navigation the caller should not depend on. → Hide the walk behind one method on the first object.
- **Middle man** — a class or function that mostly delegates onward. → Cut it, call the real target.
- **Refused bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → Drop the inheritance, compose instead.
- **Comments standing in for code** — a comment explaining what an unreadable block does. → Extract and name it; keep the comment only where it explains *why*.
