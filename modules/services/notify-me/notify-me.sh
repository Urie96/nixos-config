#!/usr/bin/env bash

MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  -t | --title)
    shift
    TITLE="$1"
    ;;
  -*)
    echo "Unknown option $1"
    exit 1
    ;;
  *)
    MESSAGE="$1"
    ;;
  esac
  shift
done

if [ ! -t 0 ]; then
  STDIN="$(cat)"
  if [ -n "$STDIN" ]; then
    MESSAGE="$STDIN"
  fi
fi

JSON_STRING=$(jq -n \
  --arg body "$MESSAGE" \
  --arg title "$TITLE" \
  '{title: $title, body: $body, tag: "me"}')

curl "http://localhost:3102" -H "content-type: application/json" -d "$JSON_STRING"
