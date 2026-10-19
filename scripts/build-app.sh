#!/bin/zsh
# Builds IssueBar.app into ./build. Pass --install to copy it to ~/Applications and launch.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/IssueBar.app"

swift build -c release --arch arm64
BINARY="$(swift build -c release --arch arm64 --show-bin-path)/IssueBar"

[[ -d "$APP" ]] && trash "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/IssueBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    TARGET="$HOME/Applications/IssueBar.app"
    pkill -x IssueBar 2>/dev/null || true
    mkdir -p "$HOME/Applications"
    [[ -d "$TARGET" ]] && trash "$TARGET"
    cp -R "$APP" "$TARGET"
    open "$TARGET"
    echo "Installed and launched $TARGET"
fi
