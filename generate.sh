#!/usr/bin/env bash

set -euo pipefail

# Pin the generator so regenerations are reproducible; bump deliberately.
GENERATOR_IMAGE="openapitools/openapi-generator-cli:v7.26.0"

# The spec is committed so regenerations are reproducible. Run with
# --update-spec to download the current spec from ClinicalTrials.gov first.
SPEC_URL="https://clinicaltrials.gov/api/oas/v2"
SPEC_FILE="openapi-spec.yaml"

if [ "${1:-}" = "--update-spec" ]; then
    echo "Downloading $SPEC_URL"
    curl -fsSL "$SPEC_URL" -o "$SPEC_FILE"
fi

# Package version tracks the API version in the spec. PyPI never accepts the
# same version twice, so a regeneration that doesn't change the API version
# (a generator bump, say) needs a post-release suffix:
#   VERSION_SUFFIX=.post1 ./generate.sh
API_VERSION=$(grep -E '^\s+version:' "$SPEC_FILE" | head -1 | sed 's/.*version: "\(.*\)"/\1/')

if [ -z "$API_VERSION" ]; then
    echo "❌ Could not extract version from $SPEC_FILE" >&2
    exit 1
fi

PACKAGE_VERSION="${API_VERSION}${VERSION_SUFFIX:-}"

echo "Generating altissimo-clinicaltrials $PACKAGE_VERSION with $GENERATOR_IMAGE"

# Patch a temporary copy of the spec, so the committed spec stays exactly what
# ClinicalTrials.gov publishes. The generator takes the package's license from
# info.license, which the spec doesn't set, so add this package's license.
PATCHED_DIR=$(mktemp -d)
trap 'rm -rf "$PATCHED_DIR"' EXIT
if grep -qE '^  license:' "$SPEC_FILE"; then
    echo "❌ $SPEC_FILE now sets info.license; update the patch in generate.sh" >&2
    exit 1
fi
awk '{ print } /^info:$/ { print "  license:"; print "    name: \"Apache-2.0\"" }' "$SPEC_FILE" > "$PATCHED_DIR/openapi-spec.yaml"

# The generator never deletes files, so remove the ones it wrote last time;
# otherwise models and endpoints dropped from the spec would linger. Keep
# .openapi-generator-ignore and the paths it lists (matched exactly, not as
# globs), which hold local changes. If generation then fails, restore the
# removed files from git.
if [ -f .openapi-generator/FILES ]; then
    STALE=$(grep -vxF -e .openapi-generator-ignore -f <(grep -vE '^[[:space:]]*(#|$)' .openapi-generator-ignore) .openapi-generator/FILES || true)
    trap 'echo "❌ Generation failed; restoring the previous files" >&2; git checkout -- $STALE' ERR
    echo "$STALE" | xargs -r rm -f
fi

# Keep the generator's default disallowAdditionalPropertiesIfNotPresent=true:
# with it off, every model gains an additional_properties field, and everygene
# builds its Firestore Study (extra="forbid") from study.model_dump().
#
# projectName is the PyPI name; packageName is the import name.
docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$(pwd):/local" \
    -v "$PATCHED_DIR:/spec:ro" \
    "$GENERATOR_IMAGE" \
    generate -i /spec/openapi-spec.yaml -g python -o /local \
    --package-name clinicaltrials \
    --git-user-id altissimo-hq \
    --git-repo-id clinicaltrials-python \
    --additional-properties="projectName=altissimo-clinicaltrials,packageVersion=${PACKAGE_VERSION},packageUrl=https://github.com/altissimo-hq/clinicaltrials-python,buildSystem=hatchling"

trap - ERR

# The generator names the pyproject.toml project after the import name and
# credits itself as the author; set the PyPI name and our authorship. With the
# name no longer matching the package directory, hatchling needs to be told
# which package to build.
python3 - <<'PY'
import pathlib
import sys

path = pathlib.Path("pyproject.toml")
text = path.read_text()
replacements = {
    'name = "clinicaltrials"\n': 'name = "altissimo-clinicaltrials"\n',
    '  {name = "OpenAPI Generator Community",email = "team@openapitools.org"},\n': '  {name = "Altissimo HQ"},\n',
}
for old, new in replacements.items():
    if text.count(old) != 1:
        sys.exit(f"❌ pyproject.toml no longer has {old.strip()!r}; update generate.sh")
    text = text.replace(old, new)
text += '\n[tool.hatch.build.targets.wheel]\npackages = ["clinicaltrials"]\n'
path.write_text(text)
PY
