#!/bin/bash
#
# RepoWhisper - One-Click Build & Run Script
# Usage: ./run.sh [--clean] [--backend]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
BACKEND_DIR="$SCRIPT_DIR/backend"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║               RepoWhisper Build & Run                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Parse arguments
CLEAN_BUILD=false
RUN_BACKEND=false

for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --backend)
            RUN_BACKEND=true
            shift
            ;;
        --help)
            echo "Usage: ./run.sh [options]"
            echo ""
            echo "Options:"
            echo "  --clean     Clean build (removes DerivedData)"
            echo "  --backend   Also start the Python backend server"
            echo "  --help      Show this help message"
            echo ""
            exit 0
            ;;
    esac
done

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    rm -rf ~/Library/Developer/Xcode/DerivedData/RepoWhisper-*
    echo -e "${GREEN}Clean complete.${NC}"
fi

# Build frontend
echo -e "${BLUE}Building RepoWhisper frontend...${NC}"
cd "$FRONTEND_DIR"

if xcodebuild -scheme RepoWhisper -configuration Debug build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"; then
    echo ""
else
    echo -e "${YELLOW}Build in progress...${NC}"
fi

# Check build result
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}Build succeeded!${NC}"
else
    echo -e "${RED}Build failed. Check errors above.${NC}"
    exit 1
fi

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "RepoWhisper.app" -path "*/Debug/*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}Could not find built app.${NC}"
    exit 1
fi

echo -e "${GREEN}Found app: $APP_PATH${NC}"

# Start backend if requested
if [ "$RUN_BACKEND" = true ]; then
    echo -e "${BLUE}Starting Python backend...${NC}"
    cd "$BACKEND_DIR"

    # Check if venv exists
    if [ ! -d "venv" ]; then
        echo -e "${YELLOW}Creating virtual environment...${NC}"
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    else
        source venv/bin/activate
    fi

    # Start backend in background
    python main.py &
    BACKEND_PID=$!
    echo -e "${GREEN}Backend started (PID: $BACKEND_PID)${NC}"

    # Give backend time to start
    sleep 2
fi

# Launch the app
echo -e "${BLUE}Launching RepoWhisper...${NC}"
open "$APP_PATH"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                RepoWhisper is running!                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Look for the ${YELLOW}waveform icon${NC} in your menu bar."
echo ""
echo -e "${BLUE}Hotkeys:${NC}"
echo "  ⌘⇧R        - Toggle recording"
echo "  ⌘⇧Space    - Center popup"
echo "  ⌘B         - Toggle visibility"
echo "  ⌘⇧H        - Toggle stealth mode"
echo "  ⌘+Arrows   - Move window"
echo ""

if [ "$RUN_BACKEND" = true ]; then
    echo -e "${YELLOW}Backend running in background. Press Ctrl+C to stop.${NC}"
    wait $BACKEND_PID
fi
