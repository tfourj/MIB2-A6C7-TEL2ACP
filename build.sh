#!/usr/bin/env bash
# Builds TEL2ACP/TEL2ACP.jar from src/ against the compile-only stubs in stubs/.
# Needs a JDK 8 (newer JDKs cannot target the old class format the MMI's J9 VM expects).
# Set JAVA_HOME to a JDK 8 if javac on PATH is newer. Set JXE to also check the jar against the firmware.
set -euo pipefail

cd "$(dirname "$0")"

BIN="${JAVA_HOME:+$JAVA_HOME/bin/}"
JAVAC="${BIN}javac"
JAR="${BIN}jar"

if ! "$JAVAC" -version 2>&1 | grep -q '1\.8\.'; then
    echo "error: JDK 8 javac required, got: $("$JAVAC" -version 2>&1)" >&2
    echo "set JAVA_HOME to a JDK 8 install" >&2
    exit 1
fi

rm -rf build
mkdir -p build/stubs build/classes

# Stubs are only used to resolve firmware types and never go into the jar
"$JAVAC" -nowarn -source 1.3 -target 1.2 -d build/stubs $(find stubs -name '*.java')
"$JAVAC" -nowarn -source 1.3 -target 1.2 -cp build/stubs -d build/classes $(find src -name '*.java')

"$JAR" cf TEL2ACP/TEL2ACP.jar -C build/classes .

# The installer compares this against the jar on the SD card and on the unit
sha1sum TEL2ACP/TEL2ACP.jar | cut -d ' ' -f 1 > TEL2ACP/TEL2ACP.jar.sha1
echo "built TEL2ACP/TEL2ACP.jar ($(cat TEL2ACP/TEL2ACP.jar.sha1))"

# Optional: check the jar against the firmware (JXE=/path/to/lsd.jxe ./build.sh)
if [ -n "${JXE:-}" ]; then
    PYTHON="$(command -v python3 || command -v python)"
    "$PYTHON" tools/jxe/checkrefs.py "$JXE" TEL2ACP/TEL2ACP.jar
fi
