#!/usr/bin/env bash
# git-browse - Open browser for git remote URL or create merge request

set -euo pipefail

die() {
  echo -e "$1" >&2
  exit 1
}

parse_remote_url() {
  local origin_url
  origin_url=$(git remote -v | grep '^origin' | head -1 | awk '{print $2}')

  if [[ -z "$origin_url" ]]; then
    die "Unable to find origin remote"
  fi

  # Remove .git suffix if present
  origin_url="${origin_url%.git}"

  if [[ "$origin_url" =~ ^https?:// ]]; then
    # Already HTTPS format
    echo "$origin_url" | sed -E 's|^https?://(.+)$|\1|'
  elif [[ "$origin_url" =~ ^git@ ]]; then
    # SSH format: git@domain:user/repo
    echo "$origin_url" | sed -E 's|^git@([^:]+):([^/]+)/(.+)$|\1/\2/\3|'
  else
    die "Unable to parse origin url: $origin_url"
  fi
}

open_browser() {
  local url="$1"
  echo "Opening \`$url\`"
  xopen "http://$url"
}

git_local_branch_name() {
  git rev-parse --abbrev-ref HEAD
}

git_remote_bind_branch() {
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | sed 's/^[^\/]*\///'
}

git_origin_master_branch() {
  git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's/^[^\/]*\///'
}

cmd_mr() {
  local remote_url
  remote_url=$(parse_remote_url)

  if [[ "$remote_url" == code.byted.org* ]]; then
    local source_branch target_branch
    if source_branch=$(git_remote_bind_branch); then
      :
    else
      source_branch=$(git_local_branch_name)
      echo "No upstream configured, fallback to local branch: $source_branch" >&2
    fi
    target_branch=$(git_origin_master_branch)
    open_browser "$remote_url/merge_requests/new?target_branch=$target_branch&source_branch=$source_branch"
  else
    die "Unable to generate merge request url for \`$remote_url\`"
  fi
}

main() {
  case "${1:-}" in
  mr)
    cmd_mr
    ;;
  ai)
    if [[ -n "${WORK:-}" ]]; then
      echo "Use modelhub"
      pi --provider modelhub --model ali-deepseek-v4-flash --no-session --no-skills --print /commit
    else
      pi --provider deepseek --model deepseek-v4-flash --no-session --no-skills --print /commit
    fi
    ;;
  *)
    open_browser "$(parse_remote_url)"
    ;;
  esac
}

main "$@"
