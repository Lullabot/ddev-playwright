---
id: 1
group: "bug-fix"
dependencies: []
status: "pending"
created: "2026-03-12"
skills:
  - bash
---
# Improve install-playwright error handling and documentation

## Objective
Improve the `install-playwright` host command to validate prerequisites and provide clear error messages, and update the README to document the full setup workflow. This addresses GitHub issue #26.

## Skills Required
- `bash`: Shell scripting for the install-playwright host command

## Acceptance Criteria
- [ ] `install-playwright` checks that `test/playwright/package.json` contains `@playwright/test` or `playwright` as a dependency
- [ ] If the dependency is not found, the script exits with a clear error message
- [ ] The script prints a reminder about running `npm install` / `yarn` inside the container before rebuilding
- [ ] README documents the full setup workflow: initialize → npm install → install-playwright
- [ ] README documents when to re-run `install-playwright` (after Playwright version updates)
- [ ] Existing BATS tests still pass (no regression)

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
- The script runs on the **host** (not inside the container), so validation must use file-based checks
- Use `grep` to check `package.json` contents — no JSON parsing in bash
- The script is at `commands/host/install-playwright`
- Check for both `@playwright/test` and `playwright` package names

## Input Dependencies
None — this is an independent task.

## Output Artifacts
- Modified `commands/host/install-playwright` with prerequisite validation
- Modified `README.md` with updated setup workflow documentation
- A PR created via `gh pr create` referencing issue #26

## Implementation Notes

<details>
<summary>Detailed implementation guidance</summary>

### install-playwright script changes

The current script at `commands/host/install-playwright` checks for `test/playwright/package.json` existence (line 5) and exits if not found. After this existing check, add a new validation:

1. Check that `@playwright/test` or `playwright` appears in `test/playwright/package.json`:
   ```bash
   if ! grep -qE '"(@playwright/test|playwright)"' test/playwright/package.json; then
     echo "Error: @playwright/test is not listed as a dependency in test/playwright/package.json."
     echo "Initialize Playwright first. See the README for setup instructions."
     exit 1
   fi
   ```

2. Before the `ddev restart` line, print a reminder:
   ```
   echo "Note: If this is a fresh clone, make sure you've run 'ddev exec -d /var/www/html/test/playwright npm install'"
   echo "(or yarn) to install dependencies before rebuilding."
   ```

### README changes

Find the "Getting Started" or setup section and clarify the workflow:
1. After addon installation (`ddev add-on get`), initialize Playwright
2. Run `npm install` or `yarn` inside the container to install dependencies
3. Run `ddev install-playwright` to bake browser binaries into the Docker image
4. Note: re-run `ddev install-playwright` after updating Playwright versions

### PR creation

Create a feature branch, commit changes, and open a PR with `gh pr create` referencing issue #26. Use conventional commit format: `fix: improve install-playwright error handling and documentation`.

</details>
