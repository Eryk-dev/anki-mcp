"""
Auto-Upload Sync Addon for Headless Anki.

Patches aqt.sync.full_sync() to auto-choose "Upload to AnkiWeb"
instead of showing a dialog that blocks in headless mode.

Based on Anki developer recommendation:
https://forums.ankiweb.net/t/is-there-any-supported-way-to-authenticate-ankiweb-login-without-using-the-gui/67637
"""

import aqt.sync
from aqt import mw


_original_full_sync = None


def _auto_upload_full_sync(out):
    """
    Replaces the default full_sync() which shows a dialog.
    Auto-calls full_upload() to push local collection to AnkiWeb.
    """
    print("[auto-sync] Full sync required. Auto-choosing UPLOAD to AnkiWeb...")
    try:
        aqt.sync.full_upload(mw)
        print("[auto-sync] Full upload triggered successfully.")
    except Exception as e:
        print(f"[auto-sync] Full upload error: {e}")
        # Fallback: try the original in case something changed
        if _original_full_sync:
            _original_full_sync(out)


def setup():
    """Patch full_sync on profile load."""
    global _original_full_sync

    if hasattr(aqt.sync, "full_sync"):
        _original_full_sync = aqt.sync.full_sync
        aqt.sync.full_sync = _auto_upload_full_sync
        print("[auto-sync] Patched full_sync() -> auto-upload enabled.")
    else:
        print("[auto-sync] WARNING: aqt.sync.full_sync not found, patch skipped.")


from aqt import gui_hooks
gui_hooks.profile_did_open.append(lambda: setup())
