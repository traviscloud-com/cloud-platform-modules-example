#!/usr/bin/env bash
#
# Lint + security + docs checks. Runs what ci.yml runs (minus terraform
# fmt/validate/test, see README).
#   scripts/lint.sh          all checks
#   scripts/lint.sh tflint   | trivy | docs | docs-check
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "${REPO_ROOT}"
export PATH="${HOME}/.local/bin:${PATH}"

run_tflint() {
  tflint --init --config "${REPO_ROOT}/.tflint.hcl" >/dev/null
  for m in modules/*/; do
    echo "== tflint ${m}"
    tflint --config "${REPO_ROOT}/.tflint.hcl" --chdir "${m}"
  done
}

run_trivy() {
  echo "== trivy config (modules)"
  trivy config --exit-code 1 --severity HIGH,CRITICAL --ignorefile .trivyignore --quiet \
    --skip-dirs '**/.terraform' modules
}

run_docs() { # regenerate modules/*/README.md
  for m in modules/*/; do terraform-docs -c .terraform-docs.yml "${m}" >/dev/null; echo "== terraform-docs ${m}README.md"; done
}

run_docs_check() { # render into a temp copy, fail if any README differs (no git needed)
  local tmp stale=0; tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' RETURN
  for m in modules/*/; do
    [ -f "${m}README.md" ] || { echo "MISSING ${m}README.md" >&2; stale=1; continue; }
    cp -r "${m}" "${tmp}/$(basename "${m}")"
    terraform-docs -c .terraform-docs.yml "${tmp}/$(basename "${m}")" >/dev/null
    if ! diff -q "${m}README.md" "${tmp}/$(basename "${m}")/README.md" >/dev/null; then
      echo "STALE ${m}README.md - run scripts/lint.sh docs and commit:" >&2
      diff -u "${m}README.md" "${tmp}/$(basename "${m}")/README.md" | head -20 >&2 || true
      stale=1
    fi
  done
  [ "${stale}" -eq 0 ] || exit 1
  echo "== module READMEs up to date"
}

case "${1:-all}" in
  tflint) run_tflint ;;
  trivy) run_trivy ;;
  docs) run_docs ;;
  docs-check) run_docs_check ;;
  all) run_tflint; run_trivy; run_docs_check ;;
  *) echo "usage: $0 [tflint|trivy|docs|docs-check|all]" >&2; exit 2 ;;
esac
