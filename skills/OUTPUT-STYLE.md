# How devflow talks to the user

Binds **every message a devflow skill puts on the screen** and **every file it writes for a person to read** — tickets, specs, `design.md`, handoffs, digests. Not code, not commit messages, not the skills' own instruction text.

Write in the user's language. The rules below are about shape and wording, not about which language.

## Words

- **Plain words, always.** A term the reader would have to look up either gets replaced by an ordinary word or carries a one-clause explanation at first use. Names that *are* the thing — `REVIEW.md`, `git diff`, a ticket id, a flag — stay as they are, with the explanation next to them. Never assume the vocabulary of this plugin's own internals ("axis", "pass", "triage", "orchestrator", "subagent", "scope creep") means anything to the person reading.
- **Say who does what.** Active voice, concrete subject.
- **15 to 25 words per sentence.** A sentence with three subordinate clauses is two sentences.
- **No word that carries no information** — "currently", "as such", "it is worth noting", "in modern practice". If deleting it changes nothing, it was never there.
- **No metaphors for mechanics.** "The loop wraps around it", "fans out", "closes the gap" — say what actually happens instead.
- Open the text up; do not dumb it down. Every bit of substance and precision stays — only what makes it hard to read on the first pass gets stripped.

## Shape

- **The first words carry the meaning.** A paragraph, a heading, a list item — each starts with what it is about, not with a run-up.
- **Paragraphs of two to four sentences**, one topic each, blank line between them. One topic split across two paragraphs is better than two topics in one.
- **Lists are for enumerations** — steps, options, checklists, files. Reasoning goes in prose: an argument cut into bullets reads as fragments, and the connective tissue that made it an argument is exactly what the bullets drop.
- **Headings only past two sections.** A message with one idea needs none.
- **Bold at most once per paragraph**, on the words that name its topic. Emphasis everywhere is emphasis nowhere.
- **No decorative emoji.** A marker a skill defines and reuses with a fixed meaning (🔴 risk level, ⚠ judgment call) is a label, not decoration — those stay.
- **Cut before adding.** The more irrelevant output, the longer it takes to find what matters.

## Questions

One shape, in the user's language:

```
Question 1. <the question, with as much context as it needs>?
Proposed: <the answer you recommend, and in one sentence why>
```

- **One question, one decision.** Each stands on its own — never "as in the previous question".
- **Three or four per round, no more.** A question whose answer depends on another still-open question belongs to a later round.
- **The recommendation is a real answer**, not a survey of everything possible. A question you cannot recommend an answer to is usually two questions.
- Menus (`AskUserQuestion`) stay the exception: a genuinely closed fork whose whole answer fits in a short label. See `discuss/SKILL.md`.

## Reports

- **The outcome is the first line.** What was done and how it was checked follows in a sentence or two.
- **Say where the result lives** — branch, path, link, ticket.
- **Name the verification honestly**: what was run, what came back. Not run is "not run", not silence.
- **One fact once.** No closing paragraph that restates what was already said.
- Detail most readers will skip goes at the end or into a file, never in the middle.
- **The last line is the next action**, when there is one. In a terminal the eye rests at the bottom, next to the prompt — that is the one place a reader is guaranteed to look.

## Where these rules come from

People scan rather than read: in Nielsen Norman Group's testing 79% scanned a new page, about 20% of the words got read, and the same text rewritten to be scannable scored 47% higher ([NN/g](https://www.nngroup.com/articles/concise-scannable-and-objective-how-to-write-for-the-web/), [plain language for experts](https://www.nngroup.com/articles/plain-language-experts/)). Front-loading, short sentences, and everyday words are [GOV.UK's content principles](https://www.gov.uk/government/publications/govuk-content-principles-conventions-and-research-background/govuk-content-principles-conventions-and-research-background), whose own rule is "open it up, do not dumb it down". Brevity, intentional emphasis, and putting the next action last come from the [command-line guidelines](https://clig.dev/) — "signal-to-noise ratio is crucial", "consider where the user will look first". Lists are held to enumerations because they help on facts and steps and hurt on argument ([the evidence, summarized](https://yoast.com/the-psychology-of-scannable-content-and-bullet-points/)); the cap on structure answers a documented habit of language models, which produce headings, bullets, and bold beyond anything asked for, until the shape of an answer stands in for its content.
