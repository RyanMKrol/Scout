# Scout — standing rules for every audit (injected into every auditor prompt)

Beyond the task's `## Done when`, FAIL the audit if the diff violates any of these repo invariants:

- **Generated files hand-edited:** any change to `Scout.xcodeproj/**` or `Sources/Info.plist` without a
  corresponding `project.yml` change is a hand-edit of XcodeGen output — fail.
- **Live radio in tests:** a unit/UI test that exercises a real `NetworkConnection` over `.cellular` or a
  live `CoreTelephony` read (instead of an injected fake/protocol) — fail. The Simulator has no radio;
  such a test is either dishonest or flaky. Measurement logic must be tested against a scripted fake
  sample stream, never a live transfer.
- **Determinism leaks:** new rolling-window / timing code reading bare `.now` / `Date()` instead of an
  injected clock — fail (it can't be unit-tested deterministically at the ~4Hz update rate).
- **Legacy APIs:** `ObservableObject` / `NavigationView` / `NWConnection` introduced where the iOS 26
  modern equivalent applies — fail.
- **Force-unwraps:** a new `!` force-unwrap or `try!` in non-test `Sources` — fail.
- **UI-test house-rule violations:** new XCUITest querying by display copy instead of
  `accessibilityIdentifier`, or asserting live UI state directly instead of using bounded waits — fail.
- **Copy style:** an em dash introduced in a user-facing string — fail.
- **Docs lockstep:** the change alters user-visible behaviour but `README.md` wasn't updated in the same
  change — fail.
