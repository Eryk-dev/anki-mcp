"""
Auto-Upload Sync Addon for Headless Anki 25.x

Two strategies:
1. Adds a custom AnkiConnect action 'forceFullUpload' that uses the
   backend API directly (no GUI dialogs).
2. Patches the sync flow to auto-resolve full sync conflicts.

Based on Anki developer recommendation:
https://forums.ankiweb.net/t/is-there-any-supported-way-to-authenticate-ankiweb-login-without-using-the-gui/67637
"""

from aqt import mw, gui_hooks
import json
import sys


def _log(msg):
    print(f"[auto-sync] {msg}", flush=True)


def _do_full_upload():
    """
    Force full upload to AnkiWeb using Anki backend directly.
    Bypasses all GUI dialogs.
    """
    if mw.col is None:
        _log("ERROR: Collection not open")
        return False

    auth = mw.pm.sync_auth()
    if auth is None:
        _log("ERROR: No sync auth (not logged in)")
        return False

    _log("Starting full upload via backend...")

    try:
        # Close collection for full sync
        mw.col.close_for_full_sync()
        _log("Collection closed for sync.")

        # Do the full upload via backend
        mw.col.full_upload_or_download(
            auth=auth,
            server_usn=None,
            upload=True,
        )
        _log("Full upload completed successfully!")
        return True

    except AttributeError:
        _log("full_upload_or_download not available, trying alternative...")
        try:
            # Alternative for different Anki versions
            mw.col._backend.full_upload_or_download(
                auth=auth,
                upload=True,
            )
            _log("Full upload (alt) completed!")
            return True
        except Exception as e2:
            _log(f"Alternative also failed: {e2}")
            return False

    except Exception as e:
        _log(f"Full upload error: {e}")
        return False

    finally:
        # Reopen collection
        try:
            if not mw.col or mw.col.db is None:
                mw.loadCollection()
                _log("Collection reopened.")
        except Exception as e:
            _log(f"Reopen warning: {e}")


def _patch_ankiconnect():
    """
    Add a 'forceFullUpload' action to AnkiConnect.
    This allows calling it via: {"action": "forceFullUpload", "version": 6}
    """
    try:
        # Find the AnkiConnect addon
        addon_dir = "/data/addons21/2055492159"
        sys.path.insert(0, addon_dir)

        # Try to patch the AnkiConnect instance
        import importlib
        ac_module = importlib.import_module("__init__")

        if hasattr(ac_module, "AnkiConnect"):
            # Add method to the class
            def forceFullUpload(self):
                success = _do_full_upload()
                return {"success": success}

            ac_module.AnkiConnect.forceFullUpload = forceFullUpload
            _log("Added 'forceFullUpload' action to AnkiConnect.")
        else:
            _log("AnkiConnect class not found in module.")

    except Exception as e:
        _log(f"Patch AnkiConnect warning: {e}")
    finally:
        if addon_dir in sys.path:
            sys.path.remove(addon_dir)


def _try_patch_sync():
    """Try to patch the sync dialog for auto-upload."""
    try:
        import aqt.sync as sync_module

        # List all sync-related functions
        sync_funcs = [f for f in dir(sync_module) if 'sync' in f.lower() or 'full' in f.lower() or 'upload' in f.lower()]
        _log(f"Found sync functions: {sync_funcs}")

        # Try to patch full_sync if it exists
        if hasattr(sync_module, 'full_sync'):
            original = sync_module.full_sync

            def patched(out):
                _log("full_sync intercepted! Calling full_upload...")
                if hasattr(sync_module, 'full_upload'):
                    sync_module.full_upload(mw)
                else:
                    _do_full_upload()

            sync_module.full_sync = patched
            _log("Patched full_sync -> auto-upload.")

    except Exception as e:
        _log(f"Patch sync warning: {e}")


def on_profile_open():
    """Setup on profile load."""
    _log("Profile opened. Setting up auto-sync...")
    _try_patch_sync()

    # Schedule initial full upload after Anki is fully loaded
    if mw.col is not None:
        _log("Scheduling initial full upload in 5 seconds...")
        mw.progress.timer(
            5000,
            lambda: _do_full_upload(),
            False,
        )


gui_hooks.profile_did_open.append(on_profile_open)
_log("Addon loaded. Waiting for profile open...")
