# Phil-Connors Plugin Development

## Version Synchronization Rule

**CRITICAL**: When bumping the version, ALL of these files MUST be updated together:

1. `.claude-plugin/plugin.json` - `"version": "X.Y.Z"`
2. `.claude-plugin/marketplace.json` - `"version": "X.Y.Z"` (appears twice: root and plugins array)
3. `commands/phil-connors-help.md` - `**Version: X.Y.Z**`

Always verify all three locations match before committing version changes.
