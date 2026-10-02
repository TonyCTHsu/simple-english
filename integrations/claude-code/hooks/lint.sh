#!/usr/bin/env bash
set -u

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
findings_json="$("$se_bin" lint --format json "$file_path" 2>/dev/null)"
[ -n "$findings_json" ] || exit 0

printf '%s' "$findings_json" | ruby -rjson -e '
  begin
    findings = JSON.parse(STDIN.read)
  rescue JSON::ParserError
    exit
  end
  exit if !findings.is_a?(Array) || findings.empty?
  lines = findings.filter_map do |f|
    next unless f.is_a?(Hash)
    location = "#{f["path"]}:#{f["line"]}"
    if f["column"]
      location += ":#{f["column"]}"
      if f["end_line"] && f["end_column"]
        finish = f["end_line"] == f["line"] ? f["end_column"] : "#{f["end_line"]}:#{f["end_column"]}"
        location += "-#{finish}"
      end
    end
    "#{location}: [#{f["rule"]}] #{f["message"]}"
  end
  exit if lines.empty?
  word = lines.length == 1 ? "finding" : "findings"
  text = "se found #{lines.length} lint #{word}. Fix them, then lint again.\n#{lines.join("\n")}"
  puts(JSON.generate({
    "hookSpecificOutput" => {
      "hookEventName" => "PostToolUse",
      "additionalContext" => text
    }
  }))
'

exit 0
