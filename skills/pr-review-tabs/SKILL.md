---
name: pr-review-tabs
description: Open one Rex tab per GitHub PR waiting on my review, run a read-only Claude Code reviewer in each that tells me where to focus, then rate review effort and sort the tabs from least to most effort. Use when I ask to triage, pre-review, or open my PR review queue.
---

# PR review tabs

Fan my review queue out into Rex tabs, one reviewer agent per PR, so I can
read each agent's guidance on where to focus and keep talking to it.

Optional arguments in the request: `--team <org/team>` and
`--include-team-requests`.

## Configuration

Work-specific values are not in this file. Load them first:

```sh
f=~/.config/agent-skills.env; [ -f "$f" ] && set -a && . "$f" && set +a
for v in WORK_GITHUB_REPO WORK_REPO_DIR REVIEW_TEAM; do echo "$v=$(printenv "$v")"; done
```

Substitute the printed values below, because shell state doesn't carry between
calls. If one is empty, ask me for it, and point to
`~/dotfiles/skills/README.md`.

Defaults (override from the arguments or the request):

- **Repo:** `$WORK_GITHUB_REPO`, with cwd `$WORK_REPO_DIR`.
- **Queue:** open, non-draft PRs where I am *personally* requested
  (`user-review-requested:@me`). Team-only requests are excluded. Report
  how many were skipped and offer to open them too.
- **Ownership scope:** `$REVIEW_TEAM`. Each reviewer scopes its
  focus to files that team owns or maintains.
- **Reviewer agent:** `claude`. Use another CLI only if I name one for this
  run.

Use the `rex` skill for Rex mechanics. Use `$REX_SESSION` for the session.

## 1. Build the queue

```sh
gh search prs "user-review-requested:@me" --state=open --draft=false \
  --json number,title,url --limit 100
```

The search index can lag behind removed requests. Confirm each PR still
lists me before opening a tab, and drop any that don't:

```sh
me=$(gh api user --jq .login)
gh pr view "$n" --json reviewRequests \
  | jq --arg me "$me" '[.reviewRequests[] | .login] | index($me) != null'
```

If I ask why a PR is in the queue, its timeline shows who requested whom and when:
`gh api repos/$WORK_GITHUB_REPO/issues/$n/timeline --paginate --jq '.[] | select(.event|test("review_request")) | "\(.created_at) \(.event) by=\(.actor.login) user=\(.requested_reviewer.login // "-") team=\(.requested_team.slug // "-")"'`

## 2. Open one tab per PR

Name each tab `PR <number>`. Keep focus where it is. Save the returned
`window_id` and `block_ids[0]` for each PR.

```sh
team="$REVIEW_TEAM"
p="Review GitHub PR #$n in $WORK_GITHUB_REPO (https://github.com/$WORK_GITHUB_REPO/pull/$n). Read-only: use 'gh pr view $n', 'gh pr view $n --json comments' and 'gh pr diff $n', and read surrounding code in this repo as needed. Do NOT check out the branch, edit files, or post anything to GitHub. I'm the human reviewer and I review for $team. Find the files $team owns or maintains in the bot PR comment that starts with '<!-- maintainers-comment -->' (fall back to CODEOWNERS). Scope your assessment to those files. If none belong to $team, say so. Print the PR URL as plain text on its own line. Summarize what the PR does in a few lines. Then tell me where to focus my review: the specific files and hunks with the most risk or needing human judgment, what to look for in each, what I can safely skim, and any likely bugs. End with EFFORT_SCORE=<n> on its own line, rating my review effort from 1 to 10 (10 = max), or 0 if no files are in scope, and a one-sentence justification on the next line."
rex window new -s "$REX_SESSION" "PR $n" -c "$WORK_REPO_DIR" \
  --focus=false --keep-open --json -- claude "$p"
```

After about 10 seconds, capture a few tabs to confirm that each agent started and isn't
waiting at a trust or permission prompt. If one is, tell me. Trust and
permission choices are mine.

## 3. Sort tabs by effort

Don't block on a long wait loop. Do a single pass of captures. If some
agents haven't printed `EFFORT_SCORE=`, report which ones and check again
only when I ask.

```sh
rex capture -s "$REX_SESSION" -b "$block" --trim | grep -oE '^● EFFORT_SCORE=[0-9]+' | tail -n1
```

Move the tabs to the end in ascending score order, breaking ties by PR
number. My original tab stays first:

```sh
rex window move -s "$REX_SESSION" "$window_id" --index 99
```

Report a table with tab, score and the agent's one-line justification.

## Follow-up instructions to all reviewers

To send an instruction to every reviewer, such as a new scope or a request
for drafted comments, list the tabs with
`rex session inspect "$REX_SESSION" --json | jq -r '.windows[] | select(.label|startswith("PR ")) | .focused_block_id'`.
Then `rex send` the text and `rex send-key ... enter`.

Check each prompt before typing. Claude shows its suggested next prompt as
dim ghost text, `ESC[2m` in `rex capture --format=vt`. Typing over that
text is fine. Text that isn't dim is a draft I typed, so ask before
sending to that tab. Never send into a tab showing a permission or
selection dialog.

## Ground rules

- Reviewers never post to GitHub, approve, or check out branches unless I
  ask in that tab.
- To run a command in a pane that I might reuse later, such as
  a repo setup task, open a shell pane and `rex send` the command. Don't make the
  command the pane's program.
- Show URLs as plain text.
