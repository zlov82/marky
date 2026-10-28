#!/bin/zsh
# Собирает Marky, заменяет копию в /Applications и перезапускает приложение.
# Автозапуск перепривязывать не нужно: путь /Applications/Marky.app не меняется.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="/Applications/Marky.app"
pkill -x Marky || true
# Дождаться выхода процесса, иначе копирование может застать старый файл.
while pgrep -x Marky >/dev/null; do sleep 0.1; done

rm -rf "$DEST"
cp -R build/Marky.app "$DEST"
open "$DEST"
echo "Установлено и запущено: $DEST"
