#!/bin/bash

# Auto-setup Xcode project for RepoWhisper
# This script creates the Xcode project automatically

set -e

FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="RepoWhisper"
PROJECT_PATH="$FRONTEND_DIR/$PROJECT_NAME.xcodeproj"

echo "🚀 Setting up Xcode project for RepoWhisper..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode from the App Store."
    exit 1
fi

# Check if project already exists
if [ -d "$PROJECT_PATH" ]; then
    echo "✅ Xcode project already exists at: $PROJECT_PATH"
    echo "📂 Opening project..."
    open "$PROJECT_PATH"
    exit 0
fi

echo "📦 Creating Xcode project..."

# Create project using xcodebuild (if possible) or provide manual steps
# Since xcodebuild can't directly create projects, we'll use a template approach

# Check if xcodegen is available (better option)
if command -v xcodegen &> /dev/null; then
    echo "✅ Found xcodegen - using it to generate project..."
    cd "$FRONTEND_DIR"
    
    # Create project.yml for xcodegen
    cat > project.yml << 'EOF'
name: RepoWhisper
options:
  bundleIdPrefix: com.repowhisper
  deploymentTarget:
    macOS: "13.0"
targets:
  RepoWhisper:
    type: application
    platform: macOS
    sources:
      - path: RepoWhisper
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.repowhisper.app
      INFOPLIST_FILE: RepoWhisper/Info.plist
      SWIFT_VERSION: "5.9"
      MACOSX_DEPLOYMENT_TARGET: "13.0"
    dependencies:
      - package: https://github.com/supabase/supabase-swift
        version: 2.0.0
        product: Supabase
packages:
  supabase-swift:
    url: https://github.com/supabase/supabase-swift
    from: 2.0.0
EOF
    
    xcodegen generate
    echo "✅ Project created!"
    open "$PROJECT_PATH"
    exit 0
fi

# Fallback: Create a basic project structure and guide user
echo "⚠️  xcodegen not found. Creating project structure..."

# Create the project directory structure
mkdir -p "$PROJECT_PATH/project.xcworkspace"
mkdir -p "$PROJECT_PATH/xcshareddata/xcschemes"

# For now, provide a simple solution: use Xcode's built-in project creation
echo ""
echo "📝 Quick Setup (30 seconds):"
echo ""
echo "1. Open Xcode"
echo "2. File > New > Project"
echo "3. Choose: macOS > App"
echo "4. Product Name: RepoWhisper"
echo "5. Interface: SwiftUI"
echo "6. Language: Swift"
echo "7. Save to: $FRONTEND_DIR"
echo "8. Click Create"
echo ""
echo "Then run this script again to auto-configure it!"
echo ""
echo "OR install xcodegen for automatic setup:"
echo "   brew install xcodegen"
echo "   Then run this script again"
echo ""

exit 0

