- F: version now 0.9.0 per coordinator (bridge release)
- F done; deprecation strings in E's files lack 'removed in 1.0.0' wording (note for coordinator)

## F2 (v1/slice-f2)
- README/CHANGELOG done; test/readme_snippets_test.dart (19 tests) mirrors README snippets: edit both together. Slice R must update the migration section and delete the "before" snippet test (uses deprecated widgets) and the deprecated-observer install test.
- Tests 183 total pass; analyze: only the 5 example/ infos.
- README claims intended back-gesture behavior ("follows swipe-back and predictive-back") that depends on the slice C2 P0 fix.
- README states the Hero/dialog/zoom-transition caveat under "Routes"; G's example should agree.
