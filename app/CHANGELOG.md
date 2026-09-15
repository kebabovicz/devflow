# Changelog — the application

Versioned separately from the plugin at the repository root. The plugin's
version is what `claude plugin update` reads; this one is the desktop
application's, and the two move on their own schedules.

## 0.1.0 — unreleased

- **First slice: one tree over several repositories, and a terminal on the session doing the work.** The problem it answers is navigational, not cosmetic — with a dozen sessions open, `claude agents` is a flat list that says nothing about which work each session belongs to or which of them is waiting on a person.
- **"Waiting on you" comes first.** Above the repositories, above the sessions: every ticket blocked on an answer, on a contract approval, or on acceptance. That list is the reason the window exists; everything else is context for it.
- **A pane is `claude attach` in a pseudo-terminal the application owns.** Measured before the pane was written: attaching that way works, typed input reaches the session, and closing the pseudo-terminal leaves the session running. That last fact is what makes closing a pane an ordinary gesture instead of a destructive one.
- **Sessions started outside the window are listed but not attachable** — `claude attach` only opens background sessions, and an interactive one belongs to the terminal that started it. They are shown dimmed rather than hidden: the state is real, and pretending otherwise would make the tree lie.
- **The frontend never builds a command line.** Rust owns both — `devflow status --json` and `claude agents --json` — and resolves `bin/devflow` out of the installed plugin cache at runtime, newest version, with `DEVFLOW_BIN` overriding for development. The plugin moves with every release; an application that hardcodes its path breaks on the next one.
- **Translucency is a window effect, not a CSS one**: a transparent window with the system's own material behind it, and an overlay title bar so the traffic lights sit in the application's own header. Non-macOS gets an opaque window and the identical layout.
