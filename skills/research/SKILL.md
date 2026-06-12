---
description: Deep web research with built-in methodology — multiple independent sources, contrarian pass, primary sources over SEO content, confidence-graded digest. Use whenever the user asks to research something ("давай проведём ресёрч", "поресерчь", "research X", "что сейчас используют для Y"), compare technologies, find current best practices, check what's current/actual, or gather real-world experience and opinions before a decision. Prefix the argument with "quick" for a cheap single-pass digest without subagents.
---

# Research: $ARGUMENTS

Produce a decision-grade digest, not a list of links. Works anywhere (no manifest needed); when run inside a devflow project, ground the research in its stack and constraints from `.devflow/project.yml` and CLAUDE.md.

**Two depths.** Full (default) — the complete methodology below. `quick` (first word of "$ARGUMENTS") — inline only: no subagents, ~8–10 searches total, the contrarian pass shrinks to one query, triangulation is relaxed. The visible price: every quick finding MUST carry its honest confidence grade, and most will be likely/unverified — quick answers low-stakes questions, it does not back irreversible decisions. Searches are the dominant token cost of research regardless of model or effort — depth is the lever, and choosing it is the user's call.

## Before searching

1. Restate the question and what decision it feeds (choose X vs Y? adopt or wait? how do others solve Z?). No clear decision → ask one clarifying question, then proceed.
2. Note freshness sensitivity: API/pricing/version questions rot in months — anchor queries with the current year/month.
3. **Library/framework/SDK questions → context7 first**: its docs tool returns current official documentation and beats web search for API syntax, config, and migration questions. If the context7 MCP tools are not available in the session, tell the user once and offer the one-time setup — `claude mcp add --transport http context7 https://mcp.context7.com/mcp -s user` — then continue with web search regardless of their choice (missing context7 degrades the research, it doesn't block it).

## Source strategy — in priority order

1. **Primary**: official docs, changelogs, source code, original papers/benchmarks, author posts.
2. **Experience reports**: GitHub issues, postmortems, engineering blogs of teams who actually ran it in production.
3. **Community pulse**: HN/Reddit/forum threads — treat as signals of pain points, not as facts.
4. SEO listicles and vendor marketing rank last; a claim that exists only there stays UNVERIFIED.

## Method — what makes it trustworthy

- **Fan out**: several independently-phrased queries per sub-question, not one. Different phrasings surface different camps.
- **Contrarian pass is mandatory**: for every candidate/claim also search "X problems", "X criticism", "why we moved away from X", "X vs alternatives". A digest with no downsides found means the pass was skipped, not that none exist.
- **Triangulate**: a claim needs 2+ independent sources to count as a finding; single-source claims are reported as such.
- **Date every key fact** (version, post date). Flag anything that predates a major release of the subject.
- **Heavy digs go to subagents — behind a cost gate**: 3+ sub-questions or a deep dive → fan out to general-purpose subagents (one per angle), synthesize in the main session. **Announce before fanning out and ask**: the angles found, how many subagents, and that this is the expensive path (a 3-agent dig runs on the order of 100–200k tokens) — full or quick is the user's spending decision, not yours. Single-angle questions skip the gate.
- **Subagent budget: ~15 tool calls each.** Budget spent → synthesize from what was gathered and name what stayed uncovered; never dig past it. Subagents return compressed, sourced conclusions — search results are context-expensive, the user's session holds conclusions, not raw dumps.

## Output — the digest

1. **Answer first**: 2–5 sentences answering the actual question, with a recommendation when a decision was asked.
2. **Findings** with confidence: established (multiple primary sources) / likely (triangulated community) / disputed (camps disagree — show both) / unverified (single or weak source).
3. **Minority/contrarian view** — always present, explicitly labeled, even when you disagree with it: name the strongest argument against the mainstream answer.
4. **What remains unknown** and what would resolve it.
5. **Sources** as markdown links, grouped by which finding they back.

## Rules

- Never stop at the first satisfying answer — that's confirmation bias with extra steps.
- Report disagreement honestly: "the community is split" is a finding, not a failure.
- Your training knowledge is a hypothesis to verify, not a source — for anything time-sensitive, the web result wins.
