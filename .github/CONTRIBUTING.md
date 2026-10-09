# Contributing to ClassicUI Forever

Thanks for helping out. These notes keep pull requests quick to review and easy to land.

## Before you start

- A bug fix is welcome as a pull request right away. Link its issue if there is one.
- For a new feature or a larger rework, open an issue first and describe what you have in mind, so the approach is agreed before you build it.
- The addon restores the 1.x look. Styling options of its own, such as font, outline or background pickers, are usually declined.

## Pull requests

- One change per pull request. A rework of existing code goes in its own pull request, ahead of the feature that needs it.
- Follow `tools/CONVENTIONS.md`, and run `bash tools/ci-local.sh` before opening the pull request: it should end with "all steps passed".
- Test in game on WoW Forever, in and out of combat, and say which class and level you used.
- Leave `CHANGELOG.md`, the What's New texts and the version number alone, and don't add changelog or notes files of your own. They are written at release, from your description.
- Keep the description short: what changed, why, and how you tested it. A few lines and a screenshot usually cover it.

## AI tools

You may use them, but you are responsible for everything you submit. Read and trim generated code and text before you open the pull request, and mention in the description that you used them.

## Code and license

Only submit code you wrote yourself; don't copy code from other addons. The addon is source-available, not open source: by submitting a contribution you grant the license described in `LICENSE`.
