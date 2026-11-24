#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Writes the Slack incoming-webhook payload announcing that a release awaits
# deployment approval to $PAYLOAD_FILE. Values are passed to jq as arguments,
# so quotes or other JSON syntax in them cannot break or inject into it.
#
# Environment: PAYLOAD_FILE, SERVER_URL, REPOSITORY, RUN_ID, SLACK_SUBTEAM,
# SLACK_USERNAME, SLACK_ICON_URL, SLACK_CHANNEL (all four optional).

set -euo pipefail

name_version="$(jq --raw-output 'if .name then .name + "@" + .version else .version end' package.json)"

text="\`$name_version\` is awaiting deployment :rocket:
<$SERVER_URL/$REPOSITORY/actions/runs/$RUN_ID|→ Review deployment>"
if [[ -n "${SLACK_SUBTEAM:-}" ]]; then
  text="<!subteam^$SLACK_SUBTEAM> $text"
fi

jq -n \
  --arg text "$text" \
  --arg username "${SLACK_USERNAME:-}" \
  --arg icon_url "${SLACK_ICON_URL:-}" \
  --arg channel "${SLACK_CHANNEL:-}" \
  '{text: $text}
  + (if $username != "" then {username: $username} else {} end)
  + (if $icon_url != "" then {icon_url: $icon_url} else {} end)
  + (if $channel != "" then {channel: ("#" + $channel)} else {} end)' \
  >"$PAYLOAD_FILE"
