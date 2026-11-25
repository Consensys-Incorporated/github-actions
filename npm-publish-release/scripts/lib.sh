#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Functions shared by the npm-publish-release scripts and their tests. None of
# them runs Yarn, npm or Node.js: the job holds a token with contents: write.

# A SemVer 2.0.0 version, as an ERE.
readonly SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$'

# is_semver <version>
is_semver() {
  [[ "$1" =~ $SEMVER_RE ]]
}

# escape_data <value>
#
# Prints <value> with %, CR and LF percent-encoded, as the runner decodes
# workflow command values. Repository text printed with it stays on one line,
# so it cannot start a workflow command of its own.
escape_data() {
  local value="$1"
  value="${value//%/%25}"
  value="${value//$'\r'/%0D}"
  value="${value//$'\n'/%0A}"
  printf '%s' "$value"
}

# escape_log <value>
#
# Prints <value> as escape_data does, with #, [ and ] percent-encoded too, for
# repository text in a plain log line. The runner reads the older
# "##[<command>]" form anywhere in a line, not only "::<command>::" at its
# start, so escape_data alone does not keep such a line from running one.
escape_log() {
  local value
  value="$(escape_data "$1")"
  value="${value//'#'/%23}"
  value="${value//'['/%5B}"
  value="${value//']'/%5D}"
  printf '%s' "$value"
}

# remote_tag_commit <tag> <error file>
#
# Prints the commit that <tag> points at in $GITHUB_REPOSITORY, following
# annotated tags, or nothing if the tag does not exist (HTTP 404). Fails on
# any other lookup error, with gh's error in <error file>.
remote_tag_commit() {
  local tag="$1" error_file="$2" object fields type sha depth
  if ! object="$(gh api "repos/$GITHUB_REPOSITORY/git/ref/tags/$tag" 2>"$error_file")"; then
    if grep -qF "HTTP 404" "$error_file"; then
      return 0
    fi
    echo "::error::Could not look up tag $tag: $(escape_data "$(cat "$error_file")")" >&2
    return 1
  fi
  for depth in 1 2 3 4 5; do
    fields="$(jq -r '"\(.object.type) \(.object.sha)"' <<<"$object")" || return 1
    type="${fields%% *}"
    sha="${fields#* }"
    if [[ ! "$sha" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]]; then
      echo "::error::Tag $tag points at '$(escape_data "$sha")', which is not an object SHA." >&2
      return 1
    fi
    case "$type" in
      commit)
        printf '%s\n' "$sha"
        return 0
        ;;
      tag)
        if ! object="$(gh api "repos/$GITHUB_REPOSITORY/git/tags/$sha" 2>"$error_file")"; then
          echo "::error::Could not look up annotated tag object $sha of $tag: $(escape_data "$(cat "$error_file")")" >&2
          return 1
        fi
        ;;
      *)
        echo "::error::Tag $tag points at a $(escape_data "$type"), not a commit." >&2
        return 1
        ;;
    esac
  done
  echo "::error::Tag $tag has more than $depth levels of annotated tags." >&2
  return 1
}

# require_committed <path>...
#
# Fails unless each <path>, relative to the repository root (the current
# directory), is a regular file at HEAD with no uncommitted changes in the
# index or the working tree. The scripts read files from the working tree, and
# what they read must be what HEAD releases.
require_committed() {
  local path entry
  for path in "$@"; do
    entry="$(git --literal-pathspecs ls-tree HEAD -- "$path")"
    if [[ "$entry" != "100644 "* && "$entry" != "100755 "* ]]; then
      echo "::error::$(escape_data "$path") is not a file committed at HEAD. The release is HEAD, so the files it is made from must be committed." >&2
      return 1
    fi
    if ! git --literal-pathspecs diff --quiet HEAD -- "$path"; then
      echo "::error::$(escape_data "$path") has uncommitted changes. The release is HEAD, so the files it is made from must be committed." >&2
      return 1
    fi
  done
}

# workspace_children <root> <dir>
#
# Prints the directories (relative to <root>) matched by the "workspaces"
# patterns of <root>/<dir>/package.json that contain a package.json, sorted.
# Supports the array and {"packages": [...]} forms, with patterns "<dir>/*"
# and literal paths. Fails on any other pattern rather than misreading it.
workspace_children() {
  local root="$1" dir="$2" prefix pattern base child patterns
  local -a children=()
  if [[ "$dir" == "." ]]; then
    prefix=""
  else
    prefix="$dir/"
  fi

  patterns="$(jq -r '
    (.workspaces // [])
    | if type == "array" then . elif type == "object" then (.packages // []) else error("unsupported workspaces value") end
    | .[]
    | if type == "string" then . else error("workspace patterns must be strings") end
  ' "$root/$dir/package.json")" || {
    echo "::error::Could not read the workspaces of $(escape_data "$dir")/package.json." >&2
    return 1
  }

  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    pattern="${pattern#./}"
    if [[ "$pattern" =~ (^|/)\.\.(/|$) ]]; then
      echo "::error::Unsupported workspace pattern '$(escape_data "$pattern")' in $(escape_data "$dir")/package.json: '..' is not supported." >&2
      return 1
    elif [[ "$pattern" =~ ^[^*?{}!\[]+/\*$ ]]; then
      base="${pattern%/\*}"
      for child in "$root/$prefix$base"/*/; do
        [[ -d "$child" ]] || continue
        child="${child%/}"
        child="${child#"$root"/}"
        case "${child##*/}" in
          node_modules | .git | .yarn) continue ;;
        esac
        if [[ -f "$root/$child/package.json" ]]; then
          children+=("$child")
        fi
      done
    elif [[ "$pattern" =~ ^[^*?{}!\[]+$ ]]; then
      pattern="${pattern%/}"
      if [[ "$pattern" != "." && -f "$root/$prefix$pattern/package.json" ]]; then
        children+=("$prefix$pattern")
      fi
    else
      echo "::error::Unsupported workspace pattern '$(escape_data "$pattern")' in $(escape_data "$dir")/package.json. Only '<dir>/*' and literal paths are supported." >&2
      return 1
    fi
  done <<<"$patterns"

  # Workspace paths are printed, and written one per line and tab-separated
  # to packages.tsv, so they must not contain control characters.
  for child in "${children[@]}"; do
    if [[ "$child" =~ [[:cntrl:]] ]]; then
      echo "::error::Workspace path '$(escape_data "$child")' contains a control character." >&2
      return 1
    fi
  done

  if ((${#children[@]} > 0)); then
    printf '%s\n' "${children[@]}" | LC_ALL=C sort -u
  fi
}

# list_workspaces <root>
#
# Prints the workspaces of the project at <root>, one relative path per line,
# in the order `yarn workspaces list` uses: "." first, then each workspace
# followed by its own nested workspaces, children sorted at each level.
list_workspaces() {
  local root="$1"
  declare -gA _visited_workspaces=([.]=1)
  _list_workspaces_from "$root" "."
}

_list_workspaces_from() {
  local root="$1" dir="$2" children child
  local -a new_children=()
  echo "$dir"
  children="$(workspace_children "$root" "$dir")" || return 1
  while IFS= read -r child; do
    [[ -n "$child" ]] || continue
    if [[ -z "${_visited_workspaces[$child]:-}" ]]; then
      _visited_workspaces[$child]=1
      new_children+=("$child")
    fi
  done <<<"$children"
  for child in "${new_children[@]}"; do
    _list_workspaces_from "$root" "$child" || return 1
  done
}

# changelog_section <changelog file> <version>
#
# Prints the body of the "## [<version>]" section: the lines after its
# heading, up to the next "## " heading or the first link reference
# definition, with leading and trailing blank lines removed. CRLF line endings
# are read as LF. Fails if the section does not exist.
changelog_section() {
  local file="$1" version="$2"
  awk -v heading="## [$version]" '
    BEGIN { found = 0; inside = 0 }
    { sub(/\r$/, "") }
    inside && (/^## / || /^\[[^]]+\]: /) { inside = 0; exit }
    inside { lines[++n] = $0; next }
    $0 == heading || index($0, heading " ") == 1 { found = 1; inside = 1 }
    END {
      if (!found) { exit 2 }
      first = 1
      while (first <= n && lines[first] ~ /^[[:space:]]*$/) first++
      last = n
      while (last >= first && lines[last] ~ /^[[:space:]]*$/) last--
      for (i = first; i <= last; i++) print lines[i]
    }
  ' "$file"
}
