#!/usr/bin/env bash
# Render the upstream Buildah task bundle and apply the Foreman overlay.
set -euo pipefail

readonly repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly task_dir="${repo_root}/tekton-catalog/tasks/buildah-oci-ta"
readonly generated_task="${task_dir}/buildah-oci-ta.generated.yaml"
readonly upstream_bundle="${BUILDAH_OCI_TA_BUNDLE:-quay.io/konflux-ci/tekton-catalog/task-buildah-oci-ta@sha256:5fcf620537b0dece56a9c9a8090ce7592a874da92cc2a5d398abdc2382eb8a3c}"

cleanup() {
  rm -f -- "${generated_task}"
}
trap cleanup EXIT

tkn bundle list -o yaml "${upstream_bundle}" > "${generated_task}"
kustomize build "${task_dir}"
