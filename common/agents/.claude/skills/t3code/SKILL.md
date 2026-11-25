---
name: t3code
description: Drive T3 Code from the command line with the `t3` CLI — start agent threads in a project with a chosen provider/model, send follow-ups, and read their replies. Use when asked to hand a task to another agent or thread, run work in parallel in T3 Code, or check on a T3 Code thread.
---

# T3 Code from the CLI

T3 Code is the desktop app that runs Claude Code, Codex and other agents as
"threads" inside "projects". Its CLI is `~/.t3/bin/t3` (not on PATH; examples below say `t3` for short)
and talks to the running app's server. `t3 <command> --help` documents every flag.

```sh
t3 thread list --project <path-or-id> --json      # a project's threads, newest first
t3 thread start <project> <message> [flags]       # prints the new thread id
t3 thread send <thread-id> <message>              # queued as the next turn if busy
t3 thread show <thread-id>                        # state + latest messages
```

- `<project>` is a project id or any path inside a project's folder. A folder
  T3 Code doesn't know yet must be added first: `t3 project add <path>`. For
  tasks with no repository, use the scratch project at `~/.t3/scratch`.
- Pass `-` as the message to read it from stdin (best for long briefs).
- Model selection needs both `--provider` and `--model`; effort is an option:

  | Want | Flags |
  |---|---|
  | Claude Haiku 5.5, medium | `--provider claudeAgent --model claude-haiku-5-5 --option effort=medium` |
  | Claude Sonnet 5.5, high | `--provider claudeAgent --model claude-sonnet-5-5 --option effort=high` |
  | Claude Opus 5.5, xhigh | `--provider claudeAgent --model claude-opus-5-5 --option effort=xhigh` |
  | Codex | `--provider codex --model <slug> --option reasoningEffort=high` |

- `--title` names the thread; `--worktree <branch>` runs it in a fresh git
  worktree instead of the project folder; `--wait` blocks until the agent
  finishes and prints its reply (exit 1 = failed, 2 = waiting for an answer);
  `--output-schema file.json --wait --json` makes it return structured data.

## Writing the brief

The new thread starts with no memory of your conversation. Give it the goal,
the constraints, what "done" looks like, what it must not do, and where to
report back. Tell the user the thread id/title you started; don't claim results
until `t3 thread show` has them.
