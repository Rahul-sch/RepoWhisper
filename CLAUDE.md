# CLAUDE.md: RepoWhisper Workflow

## Token Efficiency
- Use repomix.xml as repo map — never reload full files
- Output diffs only, no full code reprints

## M2 Optimization
- Prefer device="mps" for SentenceTransformers/PyTorch
- Use float16 compute type for Whisper on ARM

## Stealth Mode
- sharingType = .none ONLY when stealth mode toggled (⌘⇧H)
- Normal mode: sharingType = .readOnly (shareable)

## Hotkeys
- ⌘⇧R: Toggle recording
- ⌘⇧Space: Show/center overlay
- ⌘B: Toggle visibility
- ⌘⇧H: Toggle stealth mode
- ⌘+Arrows: Move window

## Commits
- Commit after every phase or significant change
- Format: "Phase X: [description]"

---

## Verification & Drift Control

### 14. MAX CHANGE WINDOW
- May not modify more than ~10-15 files per phase
- Complete only ONE phase before stopping

### 15. MANDATORY CHECKPOINT
After each phase, must:
- List all files changed
- Confirm which rules/features are implemented
- Wait for explicit approval before continuing

### 16. NO SILENT DRIFT
- If touching files outside current phase scope, STOP and report
- No unauthorized file modifications
