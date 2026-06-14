# Homebrew Cask Distribution

The macOS release ships as a `.dmg` that is **not code-signed** (no paid
Apple Developer Program), so opening it directly triggers a Gatekeeper
"cannot be opened because the developer cannot be verified" warning.

To avoid that warning without paying Apple $99/year, distribute via
**Homebrew Cask**. Homebrew installs casks by stripping the quarantine
attribute, so users get a clean first-launch experience.

## One-time setup (you, the maintainer)

1. Create a Homebrew tap repository on GitHub. Convention:
   `craftor/homebrew-task-manager`.
2. Add `packaging/homebrew/Casks/task-manager.rb` from this repo at
   `Casks/task-manager.rb` in the tap repo.
3. Push the tap repo.

That's it. The cask points at this repo's GitHub Releases for the DMG.

## Updating the cask after a release

The DMG SHA256 must be hardcoded in the cask. After pushing a new tag:

```bash
# Reads the digest straight from the GitHub Releases API — no 27 MB DMG
# download. Patches packaging/homebrew/Casks/task-manager.rb in place.
./scripts/update_cask_sha.sh 0.12.4

# Copy the patched file to your tap repo.
cp packaging/homebrew/Casks/task-manager.rb \
   ../homebrew-task-manager/Casks/task-manager.rb

# Commit + push the tap repo.
cd ../homebrew-task-manager
git add Casks/task-manager.rb
git commit -m "task-manager 0.12.4"
git push
```

If you omit the version argument, the script reads the latest tag from
`origin/master`.

## Installing for users

After the tap is in place, anyone can install with:

```bash
brew tap craftor/task-manager
brew install --cask task-manager
```

Upgrades flow through normal `brew update && brew upgrade --cask task-manager`.