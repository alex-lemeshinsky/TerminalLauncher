#!/bin/zsh
# Build a Release copy of TerminalLauncher, install it to ~/Applications,
# link `tl` into ~/.local/bin, and route tlaunch:// URLs to the installed copy.
set -euo pipefail
setopt null_glob   # an unmatched glob expands to nothing instead of erroring

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
DEST="$HOME/Applications"
APP="$DEST/TerminalLauncher.app"

# 1. Repo root
cd "${0:A:h}/.."

# 2. Generate the Xcode project
xcodegen generate

# 3. Release build. A fresh build number on every install makes chronod re-read the widget's
#    descriptor (e.g. its supported sizes); with an unchanged number it keeps the cached one.
xcodebuild -project TerminalLauncher.xcodeproj -scheme TerminalLauncher \
  -configuration Release -derivedDataPath build -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$(date +%Y%m%d%H%M%S)" build

BUILT="build/Build/Products/Release/TerminalLauncher.app"
if [[ ! -d "$BUILT" ]]; then
  echo "error: build did not produce $BUILT" >&2
  exit 1
fi

# 4. Stop the running copy so the new build handles tlaunch://
pkill -x TerminalLauncher || true

# 5. Replace the installed copy
mkdir -p "$DEST"
rm -rf "$APP"
ditto "$BUILT" "$APP"

# 6. Unregister and delete every build copy so LaunchServices ignores them
for copy in build/Build/Products/*/TerminalLauncher.app; do
  "$LSREGISTER" -u "$copy" || true
  rm -rf "$copy"
done

# 7. Register the installed copy
"$LSREGISTER" -f "$APP"

# 8. Link the CLI
mkdir -p "$HOME/.local/bin"
ln -sf "$APP/Contents/MacOS/tl" "$HOME/.local/bin/tl"

# 9. Launch the agent
open "$APP"

# 10. Done
echo "Installed. Add the widget: right-click the desktop → Edit Widgets → TerminalLauncher."
