# Releasing

## Versioning

Pass-Y uses one scheme: `MAJOR.MINOR.PATCH` (for example `1.27.0`). The upstream Bitwarden scheme
(`2026.4.0`) is no longer used.

- `MARKETING_VERSION` is set once in `project-pm.yml` (and mirrored in `project-bwk.yml` for the BitwardenKit
  project). Every target (app, Action/AutoFill/Share/Notification extensions, watch app, watch widget) reads it
  through `$(MARKETING_VERSION)`, so all embedded bundles carry the same version, as the App Store requires.
  Embedded frameworks keep their own `1.0` and are not checked.
- `CURRENT_PROJECT_VERSION` is the build number. It is bumped by the release procedure for each upload and
  is independent of the marketing version.
- Git tags are `vMAJOR.MINOR.PATCH` (for example `v1.27.0`) from 1.27.0 on. Older tags (`v1.26-ui-r9`, ...) stay as
  they are. Tags from the upstream merge (`v2026.*-bwpm`, `-bwa`) are upstream's, not Pass-Y releases.
- Every tag has a `CHANGELOG.md` entry. Collect entries under `## Unreleased` and rename that heading to
  `## vX.Y.Z (date) - title` when tagging.

## Steps for a release

1. Move the `Unreleased` entries in `CHANGELOG.md` under a new `vX.Y.Z` heading.
2. Set `MARKETING_VERSION` in `project-pm.yml` and `project-bwk.yml` to `X.Y.Z`; raise `CURRENT_PROJECT_VERSION`.
3. Regenerate the projects: `xcodegen --spec project-bwk.yml && xcodegen --spec project-pm.yml`.
4. Commit, then tag `vX.Y.Z`.
