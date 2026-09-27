#!/bin/sh
# 차트 던전 실행 (macOS, Linux).
# 처음 한 번 Godot 4.4.1 을 .godot_bin 에 받고 게임 파일을 준비한 뒤 게임을 띄운다.
set -e
cd "$(dirname "$0")"
VER=4.4.1-stable
DIR=.godot_bin
case "$(uname -s)" in
  Darwin) ZIP="Godot_v${VER}_macos.universal.zip"; BIN="$DIR/Godot.app/Contents/MacOS/Godot" ;;
  Linux) ZIP="Godot_v${VER}_linux.x86_64.zip"; BIN="$DIR/Godot_v${VER}_linux.x86_64" ;;
  *) echo "macOS와 Linux만 된다. Windows는 run_windows.bat"; exit 1 ;;
esac
if [ ! -x "$BIN" ]; then
  echo "Godot $VER 받는 중..."
  mkdir -p "$DIR"
  curl -L --fail -o "$DIR/godot.zip" "https://github.com/godotengine/godot/releases/download/$VER/$ZIP"
  unzip -q -o "$DIR/godot.zip" -d "$DIR"
  rm "$DIR/godot.zip"
  chmod +x "$BIN"
fi
touch "$DIR/.gdignore"
if [ ! -d .godot/imported ]; then
  echo "게임 파일 준비 중 (처음 한 번)..."
  "$BIN" --headless --path . --import >/dev/null 2>&1 || true
  "$BIN" --headless --path . --import >/dev/null 2>&1 || true
fi
exec "$BIN" --path .
