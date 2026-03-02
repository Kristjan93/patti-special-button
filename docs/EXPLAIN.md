# Concepts Explained

## GitHub Releases

A GitHub Release is not in your repo. It's a GitHub website feature that lives on top of a tag.

Your repo has:
- Code (Swift files, scripts, etc.)
- Commits (history of changes)
- Tags (bookmarks on commits, like `v1.0`)

All of that is git. It lives in your `.git` folder and on GitHub.

A **GitHub Release** is extra stuff GitHub attaches to a tag:
- A title and description (like a blog post)
- Uploaded files (your DMG)

The DMG is not in the repo. It's hosted on GitHub's servers as an attachment. When the script runs `gh release create v1.1 PattiSpecialButton-v1.1.dmg`, it:
1. Finds the tag `v1.1` on GitHub
2. Creates a Release page for it
3. Uploads the DMG file to GitHub's file storage
4. Gives it a download URL like `github.com/.../releases/download/v1.1/PattiSpecialButton-v1.1.dmg`

That URL is what goes into `appcast.xml` so Sparkle knows where to download the update from.

If you delete a release, the DMG disappears from GitHub's servers. The tag and your code are unaffected.

## Git Tags

A tag is a bookmark on a specific commit. When the script does `git tag v1.1`, it marks that exact commit with the name `v1.1` so you can always find it later.

Without tags, your commit history is just a stream of messages -- "Add new sound", "Fix bug", "Release v1.1" -- and there's no way to tell which commit is an actual release. Tags solve that. GitHub also uses tags to organize the Releases page -- each release is attached to a tag.

## Version vs Build

Two fields in Xcode (target > General > Identity):

**Version** is what users see in the update dialog ("Version 1.1 is available"). Pick whatever feels right -- `1.1`, `1.2`, `2.0`.

**Build** is a counter that goes up by 1 every time you release. Users never see it. Sparkle uses it to decide "is this newer?" If Build says `2` and the user has `1`, Sparkle knows to offer the update.

Both only go up. Never reset them -- Sparkle would think the new release is older and skip it.
