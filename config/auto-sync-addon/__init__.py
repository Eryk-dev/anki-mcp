"""
Auto-Upload Sync Addon for Headless Anki 25.x

Watches for the full sync dialog and auto-clicks "Upload to AnkiWeb".
Safe approach: no backend hacking, just clicks the Qt button.
"""

from aqt import mw
from aqt.qt import QApplication, QMessageBox, QTimer


def _log(msg):
    print(f"[auto-sync] {msg}", flush=True)


def _check_sync_dialogs():
    """
    Check all open dialogs for sync-related prompts.
    Auto-click "Upload to AnkiWeb" if found.
    """
    try:
        for widget in QApplication.topLevelWidgets():
            if not widget.isVisible():
                continue

            # Check QMessageBox dialogs (sync conflict dialog)
            if isinstance(widget, QMessageBox):
                text = widget.text() + " " + widget.informativeText()
                _log(f"Dialog found: {text[:100]}...")

                for button in widget.buttons():
                    btn_text = button.text().lower()
                    # Click "Upload" / "Upload to AnkiWeb" / "Enviar"
                    if any(kw in btn_text for kw in ["upload", "enviar", "subir"]):
                        _log(f"Clicking button: '{button.text()}'")
                        button.click()
                        return

                # If no upload button found, try accepting the dialog
                # (e.g. "OK" for sync completed messages)
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
                    # Find and click upload button
                    for child in widget.findChildren(QPushButton):
                        btn_text = child.text().lower()
                        if any(kw in btn_text for kw in ["upload", "enviar"]):
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
    _log("Dialog watcher started (checking every 500ms).")


_log("Addon loaded.")
# Start watcher after event loop is running
QTimer.singleShot(2000, _start_watcher)
