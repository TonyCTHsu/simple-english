#!/usr/bin/env bash
set -u

emit() {
  SE_MSG="$1" ruby -rjson -e '
    puts(JSON.generate({
      "hookSpecificOutput" => {
        "hookEventName" => "PostToolUse",
        "additionalContext" => ENV.fetch("SE_MSG")
      }
    }))
  '
}

emit_findings() {
  SE_TEXT="$1" ruby -rjson -e '
    lines = ENV.fetch("SE_TEXT").split("\n")
    word = lines.length == 1 ? "finding" : "findings"
    message = "se found #{lines.length} lint #{word}. Fix them, then lint again.\n#{ENV.fetch("SE_TEXT")}"
    puts(JSON.generate({
      "hookSpecificOutput" => {
        "hookEventName" => "PostToolUse",
        "additionalContext" => message
      }
    }))
  '
}

payload="$(cat)"

file_path="$(printf '%s' "$payload" | ruby -rjson -e '
  begin
    data = JSON.parse(STDIN.read)
  rescue JSON::ParserError
    exit
  end
  path = data.is_a?(Hash) ? data.dig("tool_input", "file_path") : nil
  print(path) if path.is_a?(String) && !path.empty?
')"

[ -n "${file_path:-}" ] || exit 0

case "$file_path" in
  *.md) ;;
  *) exit 0 ;;
esac

se_bin="${SE_BIN:-se}"
command -v "$se_bin" >/dev/null 2>&1 || exit 0

text="$("$se_bin" lint --format text "$file_path" 2>/dev/null)"
rc=$?

# A clean file stays silent. A failed lint must not read as clean: say
# so, or the agent takes silence for approval.
if [ "$rc" -ge 2 ]; then
  emit "se exited ${rc} and the prose was not linted. Run \"${se_bin} lint ${file_path}\" to see the error."
  exit 0
fi

if [ "$rc" -eq 1 ] && [ -n "$text" ]; then
  emit_findings "$text"
fi

exit 0
