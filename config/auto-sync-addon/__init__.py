"""
Auto-Sync Addon for Headless Anki 25.x

On full sync conflict: always DOWNLOADS from AnkiWeb.
This ensures the server gets the user's collection with correct model IDs.
After the initial download, regular syncs do incremental merges automatically.
"""

from aqt import mw
from aqt.qt import QApplication, QMessageBox, QTimer


def _log(msg):
    print(f"[auto-sync] {msg}", flush=True)


def _check_sync_dialogs():
    """
    Check all open dialogs for sync-related prompts.
    Always click "Download from AnkiWeb" on full sync conflicts.
    This ensures the server stays in sync with the user's collection.
    """
    try:
        for widget in QApplication.topLevelWidgets():
            if not widget.isVisible():
                continue

            # Check QMessageBox dialogs (sync conflict dialog)
            if isinstance(widget, QMessageBox):
                text = widget.text() + " " + widget.informativeText()
                _log(f"Dialog found: {text[:100]}...")

                # ALWAYS download from AnkiWeb - user's collection is source of truth
                for button in widget.buttons():
                    btn_text = button.text().lower()
                    if any(kw in btn_text for kw in ["download", "baixar"]):
                        _log(f"Clicking button: '{button.text()}'")
                        button.click()
                        return

                # Fallback: OK for info/completion dialogs
                accept_btn = widget.button(QMessageBox.StandardButton.Ok)
                if accept_btn:
                    _log("Clicking OK button.")
                    accept_btn.click()
                    return

            # Check for any QDialog (some Anki versions use custom dialogs)
            from aqt.qt import QDialog, QPushButton
            if isinstance(widget, QDialog) and widget.windowTitle():
                title = widget.windowTitle().lower()
                if any(kw in title for kw in ["sync", "full", "upload", "download"]):
                    _log(f"Custom dialog found: {widget.windowTitle()}")
                    for child in widget.findChildren(QPushButton):
                        btn_text = child.text().lower()
                        if any(kw in btn_text for kw in ["download", "baixar"]):
                            _log(f"Clicking: '{child.text()}'")
                            child.click()
                            return

    except Exception as e:
        _log(f"Check error: {e}")


# Timer that checks for dialogs every 500ms
_timer = None


def _start_watcher():
    """Start watching for sync dialogs."""
    global _timer
    _timer = QTimer()
    _timer.timeout.connect(_check_sync_dialogs)
    _timer.start(500)
    _log("Dialog watcher started - will DOWNLOAD on full sync conflicts.")


_log("Addon loaded.")
# Start watcher after event loop is running
QTimer.singleShot(2000, _start_watcher)
