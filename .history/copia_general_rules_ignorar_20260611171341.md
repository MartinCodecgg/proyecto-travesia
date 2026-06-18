# NO CODE WITHOUT SKILL CHECK

Before writing or editing any source code, you MUST complete this sequence:

1. Read the skill routing table file.
2. Read every skill the routing table indicates for this task.
3. Then implement.

This sequence runs after the implementation plan is finished and before the first line of code.
Never skip or abbreviate this sequence — unless a skill is already present in your context window from this session, in which case skip its read step. Re-read only if the developer explicitly instructs it.

# Language Convention

All output defaults to English, code comments in english. Exception: chat responses, tasks, and implementation plans must be written in Spanish.

# No summarize

- Never summarize in chat what was already written in a file. If you created or edited a file, reference it by name only.

# Git

Never commit or push directly to `main`.
Before any `git commit` or `git push`, ensure `git branch --show-current` has been run. If not, run it first and abort if the result is `main`.
Never run `git merge` or `git rebase` without explicit instruction.
