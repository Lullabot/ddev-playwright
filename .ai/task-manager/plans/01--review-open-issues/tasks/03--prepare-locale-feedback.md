---
id: 3
group: "feedback"
dependencies: []
status: "pending"
created: "2026-03-12"
skills:
  - documentation
---
# Prepare locale feedback for issue #35

## Objective
Prepare response text that the maintainer can post as a comment on GitHub issue #35, explaining how to change the date format in Playwright HTML reports. No code changes or PRs — output is feedback text only.

## Skills Required
- `documentation`: Writing clear technical guidance

## Acceptance Criteria
- [ ] Feedback text explains that Playwright's HTML report date uses `Intl.DateTimeFormat()` in Node.js
- [ ] Explains that `use.locale` in `playwright.config.ts` only affects browser context, not report generation
- [ ] Provides the `web_environment` YAML config for `LANG`/`LC_ALL`
- [ ] Mentions that the locale package may need to be installed in the container
- [ ] Feedback text is presented to the user (maintainer) for them to post

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
- This is feedback-only: no code changes, no PRs, no issue modifications
- The feedback should be ready to copy-paste into a GitHub issue comment

## Input Dependencies
None — this is an independent task.

## Output Artifacts
- Feedback text presented to the maintainer in the conversation

## Implementation Notes

<details>
<summary>Detailed implementation guidance</summary>

### Feedback content to prepare

The response should cover:

1. **Root cause**: Playwright's HTML report uses `Intl.DateTimeFormat()` in Node.js to format dates. This reads the system locale, not Playwright's browser `locale` config.

2. **What doesn't work**: Setting `locale` in the `use` section of `playwright.config.ts` only affects the browser context during test execution — it has no effect on report generation.

3. **Solution**: Set `LANG` and `LC_ALL` environment variables in DDEV's web environment:
   ```yaml
   # .ddev/config.yaml
   web_environment:
     - LANG=en_GB.UTF-8
     - LC_ALL=en_GB.UTF-8
   ```

4. **Locale package**: The desired locale may need to be installed in the Debian container. This can be done via a custom Dockerfile in `.ddev/web-build/`:
   ```dockerfile
   RUN apt-get update && apt-get install -y locales && sed -i '/en_GB.UTF-8/s/^# //' /etc/locale.gen && locale-gen
   ```

5. **Verification**: Run `ddev exec locale` to verify the locale is active.

Present this text to the user so they can post it on issue #35.

</details>
