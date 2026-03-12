---
id: 2
group: "documentation"
dependencies: []
status: "pending"
created: "2026-03-12"
skills:
  - documentation
---
# Document the show-report command

## Objective
Add README documentation for viewing Playwright HTML test reports using the `show-report` command. This addresses GitHub issue #29.

## Skills Required
- `documentation`: Technical writing for README updates

## Acceptance Criteria
- [ ] README contains a section documenting the `show-report` command
- [ ] Documents the `--host=0.0.0.0` flag requirement
- [ ] Documents the access URL pattern (`https://<project>.ddev.site:9324`)
- [ ] A PR is created via `gh pr create` referencing issue #29

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
- The report server port mapping is defined in `config.playwright.yml`: container port 9323 → HTTPS 9324
- The `--host=0.0.0.0` flag is required because the report server defaults to localhost, which is not accessible from outside the container
- The command is `ddev playwright show-report --host=0.0.0.0`

## Input Dependencies
None — this is an independent task.

## Output Artifacts
- Modified `README.md` with show-report documentation
- A PR created via `gh pr create` referencing issue #29

## Implementation Notes

<details>
<summary>Detailed implementation guidance</summary>

### README changes

Add a section about viewing test reports. Place it near the existing usage/commands documentation. Content should include:

- The command: `ddev playwright show-report --host=0.0.0.0`
- Why `--host=0.0.0.0` is needed: binds the report server to all interfaces so it's accessible from the host browser
- The URL: `https://<project>.ddev.site:9324`
- This was discussed in issue #8 and the port is already exposed by the addon

### PR creation

Create a feature branch, commit changes, and open a PR with `gh pr create` referencing issue #29. Use conventional commit format: `docs: document the show-report command`.

</details>
