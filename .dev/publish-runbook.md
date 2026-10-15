# cn_animations: publish runbook (0.9.0 then 1.0.0)

Prepared 2026-10-15 (session 6). Nothing here has been run against pub.dev. Every step that changes something outside this machine is marked **OWNER**.

## 0. State verified on 2026-10-15

| Check | Result |
| --- | --- |
| PR #2 (`feat/v1-choreography` → `master`, head cb22ad8) | Open, `MERGEABLE`, merge state `CLEAN`; CI green on Flutter 3.29.0 and stable |
| Tags | `v0.9.0` → 9f3d415, `v1.0.0` → af49f7a; local and `origin` agree; both are in the PR head; only `.dev/` sits above `v1.0.0` |
| 0.9.0 → 1.0.0 diff | Deprecation removals, their tests, the README migration wording and the tag-pinned image URLs. `pubspec.yaml` differs only in `version` |
| Clean checkout of `v0.9.0` (Flutter 3.32.7) | `flutter analyze` clean; 301 root + 7 example tests pass; `flutter pub publish --dry-run` 0 warnings, 1 hint (the version jump from 0.0.3, expected) |
| Clean checkout of `v1.0.0` (Flutter 3.32.7) | `flutter analyze` clean; 280 root + 7 example tests pass; dry-run 0 warnings, 0 hints |
| Archive | 2 MB compressed; contains CHANGELOG, LICENSE, README, analysis_options, example, lib, pubspec, screenshots, test. `.dev/`, `.github/`, `.metadata` and `.gitignore` are excluded (pub skips hidden paths; no `.pubignore` is needed) |
| README links at both tags | All return 200, including the three `raw.githubusercontent.com/…/v0.9.0|v1.0.0/screenshots/*.gif` images and the badges |
| pub.dev | Latest 0.0.3 (2023-01-30); versions 0.0.1–0.0.3; no publisher (`publisherId: null`, "unverified uploader") |
| Local credentials | `~/Library/Application Support/dart/pub-credentials.json`, dated 2023-01-31, Google OAuth with a refresh token. Whether it still refreshes is untested (there is no non-publishing call that checks it) |
| GitHub repo | No description, homepage or topics; no GitHub Releases; `.dev/` is already public on `master` (since PR #1) |

## 1. Before publishing (OWNER, about five minutes)

1. **Re-login to pub.dev with the account that uploaded 0.0.3.** The stored credential is from January 2023 and the uploader must match, so do not rely on it:

   ```sh
   dart pub logout
   dart pub login      # opens the browser; pick the Google account used in 2023
   ```

   If that account is not the 0.0.3 uploader, `pub publish` fails with a 403 "not an uploader" and nothing is published. The fix is on pub.dev: sign in as the 2023 uploader, open the package's Admin tab and add the new account as an uploader (or create a verified publisher later; the owner decided not to for now).
2. **Decide the merge of PR #2** (§6, D1). The default is to merge it right before publishing 0.9.0, because the merge deletes the root GIF that the live 0.0.3 page still links from `master`.
3. Make sure nothing else is pending: `git -C ~/Development/CnPackages/cn_animations-wt/integration status --porcelain` is empty, and `gh pr checks 2` is all green.

## 2. Publish 0.9.0

```sh
# OWNER: merge PR #2 with a merge commit, as PR #1 was merged. CI reruns on master.
gh pr merge 2 --merge --repo SinaSeirafi/CnAnimations

cd ~/Development/CnPackages/cn_animations-wt/integration
git fetch origin
git merge-base --is-ancestor v1.0.0 origin/master && echo "v1.0.0 is in master"

# A clean checkout of the tag, outside every working tree.
P=/tmp/cn_publish && rm -rf "$P" && mkdir -p "$P"
git worktree add --detach "$P/0.9.0" v0.9.0
cd "$P/0.9.0"
git status --porcelain        # must print nothing
git rev-parse --short HEAD    # 9f3d415
flutter pub get
flutter pub publish --dry-run # expect: 0 warnings, 1 hint (version jump)

# OWNER: the real thing. pub prints the file list and asks "Do you want to publish ... (y/N)?"
flutter pub publish
```

Confirm, then wait for pub.dev (usually under a minute):

```sh
curl -s https://pub.dev/api/packages/cn_animations | python3 -c 'import sys,json;print(json.load(sys.stdin)["latest"]["version"])'
```

## 3. Publish 1.0.0

Same shape, right after 0.9.0 is visible:

```sh
cd ~/Development/CnPackages/cn_animations-wt/integration
git worktree add --detach /tmp/cn_publish/1.0.0 v1.0.0
cd /tmp/cn_publish/1.0.0
git status --porcelain        # must print nothing
git rev-parse --short HEAD    # af49f7a
flutter pub get
flutter pub publish --dry-run # expect: 0 warnings, 0 hints
flutter pub publish           # OWNER
```

Then the same `curl` check should print `1.0.0`. Remove the temporary worktrees afterwards:

```sh
cd ~/Development/CnPackages/cn_animations-wt/integration
git worktree remove /tmp/cn_publish/0.9.0 && git worktree remove /tmp/cn_publish/1.0.0
```

## 4. After publishing

1. **Check the pub.dev page** (https://pub.dev/packages/cn_animations): the four screenshots render, the Changelog and Example tabs show, and the score appears after pub.dev's analysis (10–60 minutes). Local pana is 150/160, with the missing 10 only because this machine lacks the webp tools pub.dev has; expect 160 there, or read the report if not.
2. **GitHub Releases** (OWNER), one per tag, with the CHANGELOG section as the notes:

   ```sh
   cd ~/Development/CnPackages/cn_animations-wt/integration
   for v in 0.9.0 1.0.0; do
     git show "v$v:CHANGELOG.md" | awk -v v="$v" '$0=="## "v{p=1;next} /^## /{p=0} p' > "/tmp/notes-$v.md"
     gh release create "v$v" --verify-tag --title "cn_animations $v" --notes-file "/tmp/notes-$v.md"
   done
   ```

   Tested: the extraction yields 31 lines for 0.9.0 and 10 for 1.0.0. Add `--prerelease` to neither; both are real releases.
3. **Repository metadata** (OWNER; the repo has none today):

   ```sh
   gh repo edit SinaSeirafi/CnAnimations \
     --description "Flutter: animate page elements with the route transition (enter on push, part around the tapped item, follow swipe-back and predictive back). Also fade, slide, scale." \
     --homepage https://pub.dev/packages/cn_animations \
     --add-topic flutter,dart,flutter-package,animation,page-transition,navigation,predictive-back
   ```

4. **Owner's `master` checkout:** the 2023 WIP (4 files) is superseded. `git -C ~/Development/CnPackages/cn_animations checkout -- . && git -C ~/Development/CnPackages/cn_animations pull`.
5. **Cleanup** (local, any time after publishing): `git worktree remove ../prepublish`, `git worktree remove ../screenshots`, `git branch -D v1/prepublish v1/prepublish-2 v1/screenshots`, `git push origin --delete release/0.9.0` (OWNER), and `git branch -d feat/v1-choreography` once PR #2 is merged.
6. **Discoverability:** §4 of `publishing-suggestions.md`. Then the concept document and the sister packages (STATUS.md, "Scheduled after the package").

## 5. If something goes wrong

- **403 on publish:** the signed-in account is not an uploader. Nothing was published. See §1.1.
- **A published version has a mistake:** pub.dev versions cannot be deleted. Within 7 days a version can be **retracted** from the package's Admin page on pub.dev (it stays installable for pinned users but is hidden from resolution); otherwise publish a patch (0.9.1 / 1.0.1). Never move a published tag.
- **0.9.0 published, 1.0.0 fails its dry run:** stop and look; 0.9.0 alone is a consistent release (every API, deprecations marked), so there is no rush.
- **pub.dev shows a low score:** read its analysis tab. The likely causes are formatting (pana formats at the pubspec language version; the tree is formatted with Dart 3.13.5 for that reason) or screenshots. Both were clean in the dry run.

## 6. Decisions for the owner, and suggestions

**Requirements (not optional):**
- R1. Re-login to pub.dev as the 0.0.3 uploader before publishing (§1.1).
- R2. Explicit go-ahead for each outward step: merging PR #2, `pub publish` ×2, GitHub releases, repo metadata, deleting the remote branch.

**Decisions:**
- D1. **When to merge PR #2.** Default: right before publishing 0.9.0, same sitting. Merging earlier breaks the GIF on the live 0.0.3 page until the publish; merging later leaves the published READMEs pointing at tags that `master` does not yet contain (harmless, the tags exist, but untidy).
- D2. **`.dev/` is public on `master`.** It holds the design, reviews, run notes and this runbook: nothing secret (scanned 2026-10-15 for credentials, emails and local paths; only a mention of another project's settings file name). Keep it, or move it out of the repo before the package draws readers. Moving it means a commit on `master` after the merge, nothing to do with the release commits.
- D3. **CHANGELOG attribution** ("done with Claude (Anthropic)") is in both release commits. Keeping it is the default; removing it would mean rebuilding both releases and moving both tags, so decide before publishing or leave it.
- D4. **Release pacing.** The owner decided 0.9.0 then 1.0.0 on the same day. Note that no existing user is moved automatically: a `^0.0.3` constraint resolves only to `<0.0.4`, so 0.9.0 is reached by opting in with `^0.9.0`, and 1.0.0 with `^1.0.0`.

**Suggestions (do after publishing, in this order):**
- S1. GitHub Releases and repo description/topics (§4.2–4.3). The repo page is the second thing pub.dev visitors open, and today it has no description and no topics.
- S2. The owner's physical-device feel check on 120 Hz, still outstanding since session 2 (STATUS.md, "Device check"). Not blocking: emulator checks and the integration tests cover the behavior, but a feel pass on a real finger is the only thing no agent could do.
- S3. Optional: `brew install webp` and rerun `dart pub global run pana .` on the 1.0.0 checkout to see 160/160 locally before pub.dev computes it. Not needed for correctness.
- S4. Cleanup of the worktrees and branches (§4.5), and the owner's `master` checkout (§4.4).
- S5. Deferred-past-1.0.0 items stay as listed in STATUS.md: `CnPage` and `MaterialPageRoute` parity on `CnPageRoute`, `@internal` on internal types, a dartdoc note on `CnFade`'s 10 ms default delay, testing `PredictiveBackFullscreenPageTransitionsBuilder`, and the nested-navigator double handling on Flutter 3.47. The pana report also lists 51 undocumented public API elements (69.5 % documented, which already earns the full dartdoc points); the named ones are `CnPartingSpec()`, `CnRouteChoreography()`, `.parting` and `.scrollReveal`. A 1.0.1 docs pass could cover them.
