
## Status at stop
Done: example/lib (main, settings, pages/*, restart_widget) written; example analyze clean. Tests written (smoke_test.dart, adapted home_page_test.dart).
Parting verified by a debug run: items above negative dy, below positive, tapped 0. Finders must target the Card inside the keyed CnRouteAnimation (the keyed render object sits outside the translation).
Not done: last full `flutter test` in example/ not re-run after the finder fix (smoke tests use the Card finder only in the list helper; dialog test uses `_pos` on the keyed widget and may need a descendant Card/Text finder); root `flutter analyze` and root `flutter test` not run.
Next: run flutter test in example/, fix the dialog test finders, run both analyzes and the root tests, then amend the commit.
