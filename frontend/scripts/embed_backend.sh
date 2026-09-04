#!/bin/bash
set -euo pipefail

resources_dir="${SRCROOT}/RepoWhisper/Resources"
destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

backend_arch="${CURRENT_ARCH:-}"
if [[ -z "${backend_arch}" || "${backend_arch}" == "undefined_arch" ]]; then
    backend_arch="${ARCHS:-}"
    backend_arch="${backend_arch%% *}"
fi
if [[ -z "${backend_arch}" || "${backend_arch}" == "undefined_arch" ]]; then
    backend_arch="${NATIVE_ARCH_ACTUAL:-$(uname -m)}"
fi
case "${backend_arch}" in
    arm64|x86_64) ;;
    *)
        echo "error: Unsupported backend architecture '${backend_arch}'."
        exit 1
        ;;
esac

binary_name="repowhisper-backend-${backend_arch}"
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
