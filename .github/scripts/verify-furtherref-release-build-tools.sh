#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_FILE="${1:-.github/workflows/furtherref-release.yml}"

require_text() {
  local text="$1"
  if ! grep -Fq "${text}" "${WORKFLOW_FILE}"; then
    echo "missing expected workflow text: ${text}" >&2
    exit 1
  fi
}

reject_text() {
  local text="$1"
  if grep -Fq "${text}" "${WORKFLOW_FILE}"; then
    echo "unexpected workflow text remains: ${text}" >&2
    exit 1
  fi
}

require_text 'description: "Ref in furtherref/onlyoffice-build-tools"'
require_text "BUILD_TOOLS_REPO: furtherref/onlyoffice-build-tools"
require_text 'BUILD_TOOLS_REF="${INPUT_BUILD_TOOLS_REF:-${SOURCE_REF}}"'
reject_text "BUILD_TOOLS_REPO: ONLYOFFICE/build_tools"
reject_text 'OFFICIAL_BUILD_TOOLS_REF="release/v${PRODUCT_VERSION}"'

awk '
  $1 == "build_tools_ref:" { in_build_tools_ref = 1; next }
  in_build_tools_ref && $1 == "default:" {
    if ($2 != "\"9.4.0\"") {
      print "build_tools_ref default must be \"9.4.0\", got " $2 > "/dev/stderr"
      exit 1
    }
    found_default = 1
    in_build_tools_ref = 0
  }
  END {
    if (!found_default) {
      print "build_tools_ref default was not found" > "/dev/stderr"
      exit 1
    }
  }
' "${WORKFLOW_FILE}"
