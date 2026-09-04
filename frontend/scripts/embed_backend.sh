#!/bin/bash
set -euo pipefail

resources_dir="${SRCROOT}/RepoWhisper/Resources"
destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
binary_name="repowhisper-backend-${CURRENT_ARCH}"
binary_path="${resources_dir}/${binary_name}"

if [[ ! -x "${binary_path}" ]]; then
    if [[ "${CONFIGURATION}" == "Release" ]]; then
        echo "error: Missing staged backend ${binary_path}. Run build_binaries.sh first."
        exit 1
    fi
    echo "warning: Backend binary is not staged; debug builds will use backend/main.py."
    exit 0
fi

mkdir -p "${destination}"
install -m 755 "${binary_path}" "${destination}/${binary_name}"

if [[ -d "${resources_dir}/models" ]]; then
    rm -rf "${destination}/models"
    cp -R "${resources_dir}/models" "${destination}/models"
fi
