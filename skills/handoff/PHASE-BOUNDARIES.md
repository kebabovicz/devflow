# Choosing at a phase boundary

A **phase** is a chunk of work inside a session — the interview, the recon, the implementation, the checking. The definition is loose on purpose: a phase ends at the moment you think *"right, that's dealt with"*.

That gap between two phases is the only place this decision belongs. **Mid-phase there is nothing to decide** — either keep going, or send what is left to subagents. Compacting in the middle of a phase is how an agent loses the thread of what it was doing.

## Five options, in order. The first yes wins.

**1. Continue in this session.** Yes when the next phase needs this one as a **primary source** — the reasoning verbatim, not a summary of it — or when enough of the window is left for the next phase to fit. Interview into implementation is the standard yes: the implementation wants the actual arguments, including the ones that lost. Continuing costs nothing and loses nothing, so it is ruled out first, not last.

**2. `/clear` — is everything here disposable?** The exploration, the dead ends, the decisions: if nothing after this needs them, clear. It is the cheapest move available, it returns the whole window, and the old session stays resumable.

Getting this one wrong is the one-way failure. Clear a context that mattered and what is lost is the **why** — and reading the diff back does not return it. In a devflow project the question is narrower than it looks: decisions that reached `<maps.dir>` — the map, its tickets, `design.md` — are on disk, not in the window, so clearing costs only what was never written down. Work with no map behind it pays full price.

**3. Write a work handoff.** Narrow by design. You need it when the work is travelling: a different harness, a different directory or repository, a colleague picking it up, or a side task you found mid-phase and want to park without derailing what you are doing. What a handoff buys is **portability** — a file that arrives somewhere else. Nothing travelling, no handoff.

Format and content: `${CLAUDE_SKILL_DIR}/SKILL.md`, the unfinished-work mode.

**4. Send it to a subagent.** Yes when the remaining task is scoped tightly enough to run with nobody steering it. Review of a finished diff is the standard case: the agent reads, checks, and reports, and this session stays untouched while it does.

**5. Otherwise `/compact`.** Relevant context, same harness, same directory, and you need to stay in the loop — this is where the tree lands, and it lands here often. Pass it an instruction, so the summary keeps what the next phase actually needs.

`/compact` is the **default, not the first reach**. It sits at the bottom because the four questions above it are cheaper or more precise. Starting here produces the familiar failure: a fresh session confidently wrong about a decision the summary flattened.

## When devflow has already decided

Three places mandate a handoff regardless of this tree, because the work is stopping unfinished and someone else will find it: a ticket abandoned before it is done (`/devflow:task`), an iteration that cannot finish its ticket (`/devflow:build`), and a whole effort being parked (`/devflow:map`). The tree is for the boundaries where you still have a choice.

## Every move except continuing costs the same thing

Continuing keeps a **primary source**: everything that happened, noise included, and little room left to move. Every other option replaces it with a **secondary source** — a summary, cleaner and smaller, with room to work in, and lossy in ways nobody notices until the missing piece is needed.

That trade is why question 1 comes first. The lossiness is worth paying only when staying costs more than it saves.

## How much window is "enough"

Roughly the first 150k tokens of a context window is where reasoning stays sharp; past that, quality degrades before the window is technically full. Treat the number as an orientation, not a threshold — it moves with the model and with how dense the context is. The honest test is behavioral: an agent that has started re-reading files it already read, or restating decisions already made, is telling you the boundary was passed a while ago.

## These are judgment calls

None of the five questions is objective, and the same boundary can go two ways on two different days. The value is in asking them **in order**, at the boundary rather than in the middle of the work.
