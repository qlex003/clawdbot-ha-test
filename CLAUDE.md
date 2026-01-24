# Clawdbot HA Add-on - Development Guidelines

## Repository Info
- **Original Fork:** https://github.com/ngutman/clawdbot-ha-addon
- **This Repo:** https://github.com/Al3xand3r1987/clawdbot-ha
- **Maintainer:** Alexander (Al3xand3r1987)
- **Status:** Production-ready fork with enhanced features

## Project Structure
- Add-on source: `clawdbot_gateway/`
- Configuration: `clawdbot_gateway/config.json`
- Startup script: `clawdbot_gateway/run.sh`
- Documentation: Root-level guides (INSTALLATION.md, CONFIGURATION.md, etc.)
- Changelog: `clawdbot_gateway/CHANGELOG.md`

## Key Features (v1.0.0+)
- Automatic updates with rollback
- Full HA snapshot integration
- Native HA integration (Ingress, Panel)
- Structured persistent storage
- Multi-architecture support

## Development Workflow
1. Create feature branch from `master`
2. Implement changes following conventional commits
3. Test on all architectures (amd64, arm64, armv7)
4. Update CHANGELOG.md
5. Create PR for review
6. Merge after approval

## Commit Message Format
- `feat(component): add feature`
- `fix(component): fix bug`
- `docs: update documentation`
- `refactor(component): improve code`

## Testing Requirements
- Multi-arch builds must succeed
- Update system must be tested
- Snapshot restore must be verified
- Documentation must be updated

## Data Safety
- Never commit secrets or credentials
- Use placeholder values in examples
- Test migration paths thoroughly
