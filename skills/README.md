# Agent skills

Personal skills shared by Claude Code, Codex, pi and OpenCode. Each folder
holds a `SKILL.md` in the common agent-skills format.

| Skill | What it does |
| --- | --- |
| `check-in` | A sweep of GitHub PRs, Slack and Google Docs comments: what's waiting on me and what I'm waiting on. It writes one tab per day into a Claude Doc, and items I tick there never come back. |
| `pr-review-tabs` | Opens one Rex tab per PR waiting on my review, runs a read-only reviewer agent in each, and sorts the tabs by review effort. |

## Installation

`post-start-install.sh` links every folder here into each agent's user skills
directory:

- `~/.claude/skills/<name>` (Claude Code; OpenCode also reads this directory)
- `~/.codex/skills/<name>` (Codex)
- `~/.pi/agent/skills/<name>` (pi)

To add a skill, create `skills/<name>/SKILL.md` and rerun
`post-start-install.sh`, or restart the environment.

## Configuration

This repository is public, so work-specific values stay out of it. The skills
read them from `~/.config/agent-skills.env`, a shell-style `KEY=value` file.
Values already set in the environment work too.
[`agent-skills.env.example`](agent-skills.env.example) lists every key.

Skills derive two values on their own: the GitHub login (`gh api user`) and the
display name (`git config user.name`).

### Option A: Ona user secret (recommended)

Store the whole file as one Ona user secret mounted at the path the skills
read. Ona then writes it into every new environment, so it survives losing
the EFS volume or the machine:

```sh
cp skills/agent-skills.env.example /tmp/agent-skills.env   # then fill in the values
ona user secret create --name AGENT_SKILLS_ENV \
  --value-from-file /tmp/agent-skills.env \
  --file-path "$HOME/.config/agent-skills.env"
rm /tmp/agent-skills.env
```

To change a value later, run `ona user secret update` with the same flags.
New environments pick up the change, and running environments keep the old
file until they restart.

### Option B: Local file

```sh
mkdir -p ~/.config
cp skills/agent-skills.env.example ~/.config/agent-skills.env   # then fill in the values
```

This only lasts as long as the machine's home directory.

## Missing values

When a key is empty, a skill names it, points to this README, and keeps going
with the checks that don't need it.
