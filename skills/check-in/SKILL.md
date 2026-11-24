---
name: check-in
description: Holistic "what's outstanding" check across GitHub PRs, Slack, and Google Docs comments — what's waiting on me and what I'm waiting on from others. Use when I ask for a check-in, status sweep, "what's outstanding", "what am I waiting on", or invoke check-in. Read-only; never replies or posts.
---

# Check-in

A read-only sweep I run a few times a day. Report two lists per source:
**Waiting on me** and **Waiting on others**. Never post, reply, react, resolve,
or merge anything — just report.

This skill is shared by Claude Code, Codex, pi, and OpenCode (canonical copy:
`~/dotfiles/skills/check-in`). Tool names differ per agent, so each section
names the *capability* needed and the backends to try in order. Use whichever
the current agent has; if a tool is deferred or lazily loaded, load it first.

Optional arguments in the request: `--since <YYYY-MM-DD>` (default: 7 days
ago) and `--section github|slack|docs`.

## Configuration

Work-specific values are not in this file. Load them first, in one shell call:

```bash
f=~/.config/agent-skills.env; [ -f "$f" ] && set -a && . "$f" && set +a
echo "GITHUB_LOGIN=$(gh api user --jq .login)"
echo "MY_NAME=$(git config user.name)"
for v in SLACK_USER_ID WORK_GITHUB_REPO IGNORED_REVIEW_TEAMS GLEAN_MCP_URL; do echo "$v=$(printenv "$v")"; done
```

Substitute the printed values wherever this file writes `$NAME` below, because
shell state doesn't carry between calls. If a value is empty, say which one
and point to `~/dotfiles/skills/README.md`. Then continue with the checks that
don't need it.

- `$GITHUB_LOGIN`: my GitHub login.
- `$MY_NAME`: my name for people and author filters.
- `$SLACK_USER_ID`: my Slack member ID.
- `$WORK_GITHUB_REPO`: my main work repo, as `owner/name`. Its owner is
  `$WORK_ORG`.
- `$IGNORED_REVIEW_TEAMS`: a comma-separated list of team slugs to ignore as
  requested reviewers.
- `$GLEAN_MCP_URL`: the Glean MCP endpoint.
- Google: my work Google account. The Gmail and Drive connectors already use
  it.

Run the three sources in parallel where the agent allows it.

## Backends by capability

| Capability | 1st choice | Fallback |
| --- | --- | --- |
| GitHub | `gh` CLI (all agents) | — |
| Slack search + threads | Slack MCP (`slack_search_public_and_private`, `slack_read_thread`) | Glean MCP `search` with `app: slack` |
| Docs follow-ups | Google Drive MCP `search_files` | Glean `search` with `app: gdrive` |
| Docs comment emails | Gmail MCP `search_threads` / `get_thread` | Glean `gmail_search` |

If no backend for a source is available, don't skip it silently. Add a line
under **Sources not checked** with the setup hint from the end of this file.

## 1. GitHub

Run the saved query (every open PR I authored, with review state and threads):

```bash
SKILL_DIR=$HOME/dotfiles/skills/check-in
me=$(gh api user --jq .login)
gh api graphql -F query=@$SKILL_DIR/my-open-prs.graphql | jq --arg me "$me" '[.data.search.nodes[] | {repo: .repository.nameWithOwner, number, title, url, isDraft, reviewDecision, updatedAt,
 requested: [.reviewRequests.nodes[].requestedReviewer | (.login // .slug)],
 approvals: [.latestReviews.nodes[] | select(.state=="APPROVED") | .author.login],
 changesRequested: [.latestReviews.nodes[] | select(.state=="CHANGES_REQUESTED") | .author.login],
 humanComments: [.comments.nodes[] | select(.author.login != $me and (.author.login | test("bot|app|actions|greptile|datadog|semgrep|machine-account"; "i") | not)) | {a: .author.login, at: .createdAt, b: (.body[0:200])}],
 openThreads: [.reviewThreads.nodes[] | select(.isResolved|not) | .comments.nodes[0] | select(.author.login != $me) | {a: .author.login, at: .createdAt, b: (.body[0:200]), url}]}]'
```

Classify:

- **Waiting on me — human feedback:** unresolved threads or PR comments from a
  *human* whose latest comment is newer than my last reply. These are the
  most important GitHub items; list each with its discussion URL.
- **Waiting on me — bot findings:** unresolved Greptile/Semgrep threads. Do not
  list each one; give a count per PR and the P1 titles only.
- **Waiting on me — CHANGES_REQUESTED** PRs.
- **Waiting on me — approved but unmerged** non-draft PRs (ready to merge or
  blocked on stack order). Note when they form a stack.
- **Waiting on others — awaiting review:** non-draft PRs with
  `reviewDecision == REVIEW_REQUIRED`. Name the requested people and teams, but
  ignore the teams in `$IGNORED_REVIEW_TEAMS`. Include how long the PR has waited.
- Drafts: one line listing them; no detail unless they have human comments.
- Personal repos (outside `$WORK_ORG`): mention only if there is activity in
  the lookback window.

Also list **reviews I owe**, in one short section. List the PRs that request me
by name in full:
`gh api 'search/issues?q=is:pr+is:open+user-review-requested:$GITHUB_LOGIN+-is:draft&per_page=30' --jq '.items[] | "\(.number)\t\(.updated_at[0:10])\t\(.user.login)\t\(.title)\t\(.html_url)"'`.
Report team-only requests (`gh search prs --review-requested=@me --state open`
minus the above) as a count only, since bad rebases often add whole teams.

## 2. Slack

**With the Slack MCP:** run these searches, each with `after:<since>` and
sorted by timestamp:

1. Mentions of me: `<@$SLACK_USER_ID>`. Exclude bot digests (GitHub reminders,
   standup bot, Google Calendar).
2. DMs and group DMs: an empty query with `channel_types: "im,mpim"`.
3. Threads I posted in: `from:<@$SLACK_USER_ID> is:thread`, without context.
4. My top-level posts that asked something:
   `from:<@$SLACK_USER_ID> -is:thread`, then keep posts containing a question or an
   explicit request.

For every candidate conversation, read the thread (pass `oldest` near the
candidate message to keep it short) and decide who spoke last.

**With Glean only:** `search` with `app: slack`, `updated: past_week`, and
`sort_by_recency: true`, using these queries:

- `query: "*"` with `from: "$MY_NAME"`, for threads I'm in.
- `query: "$MY_NAME"`, for mentions.

Glean can't reliably show who spoke last. Mark items "verify in Slack" unless
the result shows the latest reply.

Classify:

- **Waiting on me:** someone else's message is the latest, and it asks me a
  question, requests something, or @-mentions me. Ignore pure acknowledgements
  ("ty", "sounds good", "done", emoji-only).
- **Waiting on others:** my message is the latest and it asks a question or
  makes a request, or someone said they would get back to me ("I'll ask the
  team", "will let you know") and hasn't yet.
- **My own commitments:** things I said I'd do ("next week I'll…", "I'll
  follow up…") that I haven't visibly done. Keep these short.

Give each item a permalink, who, when, and a one-line gist.

## 3. Google Docs comments

Use these three sources together; none is complete on its own.

1. **Drive follow-ups (the most reliable source for "waiting on me"):** Drive
   `search_files` with query `followUp = 'any'`, `includeRichMetadata: true`,
   `excludeContentSnippets: true`. Each file's `followUps` lists `ASSIGNMENT`
   (a comment assigned to me) or `SUGGESTION` (a pending suggestion in a doc I
   own). Every one is waiting on me. Glean has no equivalent; without Drive,
   say this check was skipped.
2. **Comment notification emails:** search Gmail with
   `from:comments-noreply@docs.google.com newer_than:<N>d`, then read each
   thread as plain text. With Glean, use `gmail_search` with the same sender.
   Some bodies are very large. If a result is spilled to a file, extract it
   with `jq -r '.messages[] | .date, .plaintextBody'` and strip the reply-to
   address lines.
   - If the last post in the thread is someone else's question or request to
     me, it is **waiting on me**.
   - "X replied" and the reply answers my question, so it is resolved:
     skip it, or mention it in one line as "answered".
   - Gmail only sends these emails when *someone else* comments, so I may
     already have replied in the doc. Mark such items "possibly handled"
     unless the follow-up or a recent doc check confirms they are still open.
3. **Waiting on others (best-effort):** comments where I asked a question or
   @-mentioned someone and no reply notification has arrived. Use Glean
   `search` (`app: gdrive`, `from: "$MY_NAME"`, `updated: past_week`),
   or Drive `search_files` with `modifiedTime > '<since>' and 'me' in writers`
   and check `lastCommentedTime`. Report only what you can actually see.

## Output

Keep it scannable. Use this structure, and put each URL in plain text at the
end of its line (no Markdown links):

```
## Waiting on me
### GitHub
### Slack
### Google Docs
### Reviews I owe

## Waiting on others
### GitHub (awaiting review)
### Slack
### Google Docs

## My open commitments  (only if any)

## Sources not checked  (only if any)
```

Put the most urgent items first in each section: human questions, then
anything with a date attached, then items older than 3 days. Leave out empty
subsections, or write "nothing outstanding". End with a one-line summary
count, such as "6 items need me, 4 waiting on others."

## Setup hints for missing backends

Glean MCP URL: `$GLEAN_MCP_URL`. Glean covers Slack,
Drive, and Gmail when no dedicated connector exists.

- **Claude Code:** the claude.ai Slack, Gmail, Google Drive, and Glean
  connectors; reconnect them under `/mcp` if they fail.
- **OpenCode:** `opencode mcp add glean_default --global --url <glean url>`,
  then connect it through `/mcps`.
- **Codex:** `codex mcp add glean_default --url <glean url>`, then
  `codex mcp login glean_default`.
- **pi:** add the server to `~/.pi/agent/mcp.json`. That file is per-machine,
  so keep the source copy in dotfiles.
