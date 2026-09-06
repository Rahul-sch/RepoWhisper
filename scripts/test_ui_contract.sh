#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_file="${repo_root}/frontend/RepoWhisper.xcodeproj/project.pbxproj"

for source in RWTheme.swift RWAmbientBackground.swift RWNavigation.swift RWPageHeader.swift; do
    if ! grep -q "${source}" "${project_file}"; then
        echo "UI contract failed: ${source} is missing from the generated Xcode project."
        exit 1
    fi
done

for identifier in search.composer onboarding.chooseRepository repositories.add indexing.start overlay.composer menubar.recording; do
    if ! grep -R -q "accessibilityIdentifier(\"${identifier}\")" "${repo_root}/frontend/RepoWhisper"; then
        echo "UI contract failed: ${identifier} is missing."
        exit 1
    fi
done

echo "UI accessibility and project integration contract passed."
