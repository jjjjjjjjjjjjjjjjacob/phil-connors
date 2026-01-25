# Phil-Connors Plugin Development

## Version Synchronization Rule

**CRITICAL**: When bumping the version, ALL of these files MUST be updated together:

1. `.claude-plugin/plugin.json` - `"version": "X.Y.Z"`
2. `.claude-plugin/marketplace.json` - `"version": "X.Y.Z"` (appears twice: root and plugins array)
3. `commands/phil-connors-help.md` - `**Version: X.Y.Z**`

Always verify all three locations match before committing version changes.

**Rule**: The version in these files must always match the version in the most recent `vX.Y.Z` commit message. If a commit is tagged with a version (e.g., `v1.5.3: ...`), all version files must be updated to match.
