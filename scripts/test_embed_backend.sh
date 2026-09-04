#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "${fixture_dir}"' EXIT

mkdir -p "${fixture_dir}/src/RepoWhisper/Resources" "${fixture_dir}/out/Resources"
touch "${fixture_dir}/src/RepoWhisper/Resources/repowhisper-backend-arm64"
chmod +x "${fixture_dir}/src/RepoWhisper/Resources/repowhisper-backend-arm64"

SRCROOT="${fixture_dir}/src" \
TARGET_BUILD_DIR="${fixture_dir}/out" \
UNLOCALIZED_RESOURCES_FOLDER_PATH=Resources \
CURRENT_ARCH=undefined_arch \
ARCHS=arm64 \
CONFIGURATION=Release \
    "${repo_root}/frontend/scripts/embed_backend.sh"

test -x "${fixture_dir}/out/Resources/repowhisper-backend-arm64"
echo "Backend embed architecture fallback passed."
