#!/usr/bin/env bash
# git-browse - Open browser for git remote URL or create merge request
#
#   lazygit-action        在浏览器打开 origin 仓库首页
#   lazygit-action mr     打开当前分支新建 MR/PR 的页面
#   lazygit-action ai     用 pi 生成 commit message
#
# forge 识别（mr）：
#   - 域名含 github                   -> GitHub        /compare/<目标>...<来源>?expand=1
#   - 域名含 byted.org                -> 内网           /merge_requests/new?...
#   - 探测到 /api/v1/version 有响应   -> Gitea/Forgejo  /compare/<目标>...<来源>
#   - 其余（含自建 GitLab）           -> GitLab        /-/merge_requests/new?merge_request[...]
# 需要强制指定时（环境变量 FORGE 优先）：
#   git config lazygit-action.forge gitea   # 或 gitlab / github / byted

set -euo pipefail

die() {
  echo -e "$1" >&2
  exit 1
}

_urlencode_impl() {
  local LC_ALL=C
  local keep_slash=$1 s=$2 out='' c i
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
    [a-zA-Z0-9._~-]) out+=$c ;;
    /)
      if [[ "$keep_slash" == 1 ]]; then
        out+=$c
      else
        out+=$(printf '%%%02X' "'$c")
      fi
      ;;
    *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

# 用于 query string，'/' 也编码
urlencode() { _urlencode_impl 0 "$1"; }

# 用于 URL path，保留 '/'（分支名常带 slash）
urlencode_path() { _urlencode_impl 1 "$1"; }

# scheme://host[:port]，用于探测实例类型
url_origin() {
  local url=$1 rest
  rest=${url#*://}
  printf '%s://%s' "${url%%://*}" "${rest%%/*}"
}

# 把 remote.origin.url 规整成网页地址 scheme://host[:port]/group/repo
parse_remote_url() {
  local url netloc path
  url=$(git config --get remote.origin.url 2>/dev/null || true)
  [[ -n "$url" ]] || die "Unable to find origin remote"

  url=${url%.git}

  case "$url" in
  http://* | https://*)
    # 保留原始 scheme 和端口（自建实例常用 8443 之类）
    printf '%s' "$url"
    ;;
  git://*)
    printf 'https://%s' "${url#git://}"
    ;;
  ssh://*)
    # ssh://[user@]host[:port]/group/repo -> https://host/group/repo
    # SSH 端口与网页端口一般不同，这里丢弃端口
    netloc=${url#ssh://}
    netloc=${netloc%%/*}
    path=${url#"ssh://$netloc"}
    netloc=${netloc#*@}
    netloc=${netloc%%:*}
    printf 'https://%s%s' "$netloc" "$path"
    ;;
  *://*)
    die "Unsupported remote url: $url"
    ;;
  *:*)
    # scp 形式：[user@]host:group/repo
    netloc=${url%%:*}
    path=${url#*:}
    netloc=${netloc#*@}
    printf 'https://%s/%s' "$netloc" "${path#/}"
    ;;
  *)
    die "Unable to parse origin url: $url"
    ;;
  esac
}

detect_forge() {
  local url=$1 forge=${FORGE:-}
  if [[ -z "$forge" ]]; then
    forge=$(git config --get lazygit-action.forge 2>/dev/null || true)
  fi
  if [[ -n "$forge" ]]; then
    printf '%s' "$forge"
    return
  fi

  case "$url" in
  *github*)
    printf 'github'
    return
    ;;
  *byted.org*)
    printf 'byted'
    return
    ;;
  esac

  # Gitea/Forgejo 的 API 在站点根路径上，返回 {"version": "..."}
  local origin
  origin=$(url_origin "$url")
  if curl -fsSk --connect-timeout 2 --max-time 3 "$origin/api/v1/version" 2>/dev/null | grep -q '"version"'; then
    printf 'gitea'
  else
    printf 'gitlab'
  fi
}

open_browser() {
  local url="$1"
  echo "Opening \`$url\`"
  xopen "$url"
}

git_local_branch_name() {
  git rev-parse --abbrev-ref HEAD
}

git_remote_bind_branch() {
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | sed 's|^[^/]*/||'
}

git_default_branch() {
  local ref branch
  ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -n "$ref" ]]; then
    printf '%s' "${ref#origin/}"
    return 0
  fi
  for branch in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      printf '%s' "$branch"
      return 0
    fi
  done
  return 1
}

build_mr_url() {
  local forge=$1 base=$2 source_branch=$3 target_branch=$4
  local s t sp tp
  s=$(urlencode "$source_branch")
  t=$(urlencode "$target_branch")
  sp=$(urlencode_path "$source_branch")
  tp=$(urlencode_path "$target_branch")

  case "$forge" in
  gitea)
    # https://host/owner/repo/compare/<merge into>...<pull from>
    if [[ -n "$target_branch" ]]; then
      printf '%s/compare/%s...%s' "$base" "$tp" "$sp"
    else
      printf '%s/compare' "$base"
    fi
    ;;
  github)
    # https://github.com/owner/repo/compare/<base>...<head>?expand=1
    if [[ -n "$target_branch" ]]; then
      printf '%s/compare/%s...%s?expand=1' "$base" "$tp" "$sp"
    else
      printf '%s/compare/%s?expand=1' "$base" "$sp"
    fi
    ;;
  byted)
    printf '%s/merge_requests/new?target_branch=%s&source_branch=%s' "$base" "$t" "$s"
    ;;
  gitlab)
    if [[ -n "$target_branch" ]]; then
      printf '%s/-/merge_requests/new?merge_request%%5Bsource_branch%%5D=%s&merge_request%%5Btarget_branch%%5D=%s' \
        "$base" "$s" "$t"
    else
      printf '%s/-/merge_requests/new?merge_request%%5Bsource_branch%%5D=%s' "$base" "$s"
    fi
    ;;
  *)
    die "Unknown forge '$forge' (set lazygit-action.forge or FORGE)"
    ;;
  esac
}

cmd_mr() {
  local base forge source_branch target_branch
  base=$(parse_remote_url)
  forge=$(detect_forge "$base")

  if ! source_branch=$(git_remote_bind_branch) || [[ -z "$source_branch" ]]; then
    source_branch=$(git_local_branch_name)
    echo "No upstream configured, fallback to local branch: $source_branch" >&2
  fi

  target_branch=$(git_default_branch || true)
  if [[ -z "$target_branch" ]]; then
    echo "No default branch found on origin, generating url without target branch" >&2
  elif [[ "$target_branch" == "$source_branch" ]]; then
    echo "Current branch is the default branch ('$target_branch'), merge request makes no sense" >&2
  fi

  open_browser "$(build_mr_url "$forge" "$base" "$source_branch" "$target_branch")"
}

main() {
  case "${1:-}" in
  mr)
    cmd_mr
    ;;
  ai)
    if [[ -n "${WORK:-}" ]]; then
      echo "Use ark"
      pi --provider ark --model ep-20261015193016-mtb6n --no-session --no-skills /commit
    else
      pi --provider deepseek --model deepseek-flash --no-session --no-skills /commit
    fi
    ;;
  *)
    open_browser "$(parse_remote_url)"
    ;;
  esac
}

main "$@"
