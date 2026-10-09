## Agent skills

### Issue tracker

Issues live in GitHub Issues (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context. See `docs/agents/domain.md`.

## UI rule: no entrance animations

Never animate the entrance of a button, text, or any view. Content must appear in its final state at once. Do not use `.transition`, `.onAppear` with `withAnimation`, `PhaseAnimator`, `KeyframeAnimator`, `.symbolEffect` on appear, or staggered fades for first appearance. Allowed: animation that answers a user action (tap, drag, toggle), and system navigation transitions.
