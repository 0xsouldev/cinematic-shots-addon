#!/usr/bin/env bash
# Checks every effect in shaders/: ReShade's compiler must accept it, and the code it generates must pass
# glslang (for the HLSL) and spirv-val (for the SPIR-V). Needs glslang-tools and spirv-tools.
# Usage: tools/fxcheck/check.sh <path to fxcheck>
set -euo pipefail
fxcheck="$1"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
for effect in shaders/*.fx; do
    name="$(basename "$effect" .fx)"
    echo "== $effect"
    "$fxcheck" "$effect" hlsl "$out/$name.hlsl"
    "$fxcheck" "$effect" spirv "$out/$name.spv" > /dev/null
    for code in "$out/$name".hlsl.*; do
        entry="${code##*.hlsl.}"
        stage=frag
        [[ "$entry" == *VS ]] && stage=vert
        glslangValidator -V -D -S "$stage" -e "$entry" -o /dev/null "$code" > "$out/log" || { cat "$out/log"; exit 1; }
    done
    for code in "$out/$name".spv.*; do
        spirv-val --target-env vulkan1.1 "$code"
    done
    echo "ok"
done
