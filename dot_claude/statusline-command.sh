#!/usr/bin/env bash
# Claude Code status line — no jq dependency, pure bash JSON parsing
# Receives JSON on stdin from Claude Code

input=$(cat)

# Extract fields using grep/sed (avoids jq dependency)
cwd=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -z "$cwd" ] && cwd=$(echo "$input" | grep -o '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
used=$(echo "$input" | grep -o '"used_percentage":[0-9.]*' | head -1 | sed 's/.*://')
model=$(echo "$input" | grep -o '"display_name":"[^"]*"' | head -1 | cut -d'"' -f4)
cost=$(echo "$input" | grep -o '"total_cost_usd":[0-9.]*' | head -1 | sed 's/.*://')

# Git branch + dirty state (skip optional locks so it never blocks)
git_branch=""
if [ -n "$cwd" ] && command -v git &>/dev/null; then
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -n "$git_branch" ]; then
    git_status=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --porcelain 2>/dev/null)
    dirty=""
    if echo "$git_status" | grep -q '^[MADRC]'; then
      dirty="${dirty}+"
    fi
    if echo "$git_status" | grep -q '^.[MADRC?]'; then
      dirty="${dirty}*"
    fi
    git_branch=" (${git_branch}${dirty})"
  fi
fi

# Context usage indicator
context_part=""
if [ -n "$used" ]; then
  used_int=${used%.*}   # truncate to integer
  context_part=" [ctx: ${used_int}%]"
fi

# Cost indicator
cost_part=""
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
  cost_part=$(printf ' [$%.2f]' "$cost")
fi

# Build the status line with ANSI colors
printf "\033[36m[%s]\033[0m \033[32m%s\033[33m%s\033[0m%s%s" \
  "$model" \
  "$cwd" \
  "$git_branch" \
  "$context_part" \
  "$cost_part"
