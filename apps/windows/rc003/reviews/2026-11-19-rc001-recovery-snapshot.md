# RC001 recovery work: source snapshot

This branch preserves the existing local recovery changes on top of commit
`edaf1306a3617fd05f121c03ca0e4520a3de5bcb` (application version 0.1.10).
It is an archival source snapshot, not a release or a claim that RC001 hardware
acceptance has completed. The changes were retained as found; this save did not
add another device-recovery experiment or merge newer upstream application code.

## Preserved changes

- Persist the Xiaomi profile inferred from the GATT model number.
- Resolve redirected data paths and share file-replacement handling across
  configuration, runtime status, helper manifests and consumer markers.
- Remove consumer aliases only when they resolve to the same executable file.
- Replace an installed helper of the same generation when its hash differs.
- Retry an unavailable HID host and distinguish that state in the settings UI.
- Fall back to present SetupAPI HID interfaces for the selected RC001 identity
  when Raw Input enumeration cannot find its interface.
- Preserve the associated configuration, selection, helper and QML tests.

## Validation performed for this save

On 2026-11-19, using the existing Python virtual environment, UTF-8, Qt offscreen,
`RC003_DISABLE_LIVE_INPUT=1` and `RC003_ALLOW_LIVE_INPUT_TESTS=0`:

1. `test_bridge_runtime_status`, `test_config`, `test_frida_compat`,
   `test_hid_elevation_windows`, `test_hid_helper_consumers`, and
   `test_remote_selection`: 367 tests passed.
2. `test_hid_runtime_upgrade_qml`: 1 test passed.
3. `OffscreenQmlLoadTests.test_rc003_only_three_page_shell_is_rendered`:
   1 test passed.
4. `git diff --check`: passed before committing.

The permission and argument errors printed by the helper tests are intentional
negative test cases; the unittest run completed successfully.
These checks do not establish real BLE connectivity, HID report arrival,
mapping delivery, volume changes, or click/double-click/hold behavior.

## Known limits

- The WinError 17 fallback in `atomic_file.replace_file` uses a direct file copy.
  It is not atomic and cannot guarantee restoration if copying and rollback both
  fail or the process exits mid-copy. Its name must not be read as a durability
  guarantee for that fallback.
- Selecting a SetupAPI interface does not establish that Windows Raw Input is
  delivering events for that interface.
- Existing evidence included both a period with raw keyboard events whose
  mappings were bypassed and a later period with HID discovery and GATT failures.
  This snapshot does not establish the cause of the later disconnection.
- RC001-specific Bluetooth names are defined, but the candidate qualification
  code still accepts RC003 names or hardware matches. That separate code gap is
  not changed by this archival commit.
- No application build, helper installation, pairing change, live key test, or
  Windows restart was performed for this save.

## Scope of the GitHub backup

Only source, tests and this record are committed. Installed application copies,
failed builds, personal configuration, device logs, raw-input probe results and
downloaded archives remain local. Rebuilding this source does not reproduce an
accepted runtime state without a separate build and hardware verification.
