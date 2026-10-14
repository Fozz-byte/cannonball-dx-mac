# Publishing the Mac source fork

- Proposed repository: **Fozz-byte/cannonball-dx-mac**
- Display name: **CannonBall DX for Mac**
- Description: **Apple silicon macOS fork of CannonBall DX with native Metal rendering. Mac port by Astra and Fozz-byte.**

This guide prepares a source-only GitHub fork of
`Endprodukt/cannonball-dx`. It does not publish the repository or a binary release.
The local history retains upstream commit
`09edd625138d5b95bc41b184ee8bda0e0d7c4b8b` and its ancestors, followed by the Mac
port commit on `codex/macos-metal`.

## Before publishing

- Review the staged/committed file list and author identity. Git commits expose
  the configured author name and email when pushed; use your preferred GitHub
  attribution before publication.
- Keep ROMs, local configuration/high scores, build tools, fetched dependencies,
  app bundles and raw test results out of the source tree. The ignore rules cover
  the project's standard locations; do not force-add private local files.
- Preserve the upstream and third-party notices. See `license.txt`,
  `CannonBall-SE-license.txt`, `THIRD-PARTY-NOTICES.md` and the README license
  overview in this repository. Do not add an incompatible blanket license.
- Use the documented macOS 27 / Xcode 27 arm64 build and validation commands.
  ROM-dependent tests use privately supplied data and isolated temporary saves.
- Keep the documented acceptance gaps visible. The completed automated soak
  does not establish every game mode, controller or display configuration.

## Create and push the fork when approved

The proposed repository is public because it is a GitHub fork of the public
upstream. Confirm the owner, name and public visibility before running these
publication commands. If a fork already exists in this GitHub fork network,
inspect and reuse that repository rather than overwriting it.

Run from the local project after committing, with a clean working tree:

```sh
gh auth status
gh repo fork Endprodukt/cannonball-dx --fork-name cannonball-dx-mac --clone=false --remote=false
git remote add origin https://github.com/Fozz-byte/cannonball-dx-mac.git
git push -u origin HEAD:main
gh repo edit Fozz-byte/cannonball-dx-mac --default-branch main \
  --description 'Apple silicon macOS fork of CannonBall DX with native Metal rendering. Mac port by Astra and Fozz-byte.'
```

The `upstream` remote points to `Endprodukt/cannonball-dx`; only `origin` should
receive the Mac fork's changes. If `origin` is already configured, inspect it
instead of adding or replacing it blindly. Do not force-push. The push creates
the fork's `main` branch from the current Mac port commit; the inherited `master`
branch remains available for comparison.

Verify the result:

```sh
gh repo view Fozz-byte/cannonball-dx-mac --json url,isFork,parent,defaultBranchRef
git ls-remote origin refs/heads/main
git rev-parse HEAD
```

Check that GitHub identifies the repository as a fork, that `main` points at the
local commit, and that the README, Mac documentation and credits render correctly.
The inherited Windows/Linux workflows target `master`; they are not Mac build
validation. No hosted macOS 27 CI run is claimed by this source publication.

## Binary releases are separate

The app is currently ad-hoc signed for personal use. Publishing a downloadable
app requires separate work on signing/notarization, outstanding hardware tests,
and the repository's mixed non-commercial and third-party license terms,
including complete corresponding source and static LGPL redistribution needs.
Do not attach the local `dist/` app, ROMs or raw test logs to the initial source
publication. A public binary release is not part of these commands.
