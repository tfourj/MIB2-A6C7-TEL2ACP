#!/usr/bin/env bash
# Builds TEL2ACP/TEL2ACP.jar from src/ against the compile-only stubs in stubs/.
# Needs a JDK 8 (newer JDKs cannot target the old class format the MMI's J9 VM expects).
# Set JAVA_HOME to a JDK 8 if javac on PATH is newer.
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
echo "built TEL2ACP/TEL2ACP.jar"
