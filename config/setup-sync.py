#!/usr/bin/env python3
"""
Autentica com AnkiWeb e salva o token no prefs21.db.
Roda ANTES do Anki iniciar, no entrypoint do container.

Endpoint: POST https://sync.ankiweb.net/sync/hostKey
Params:   u=email&p=password
Response: {"key": "abc123..."}
"""

import json
import os
import pickle
import sqlite3
import sys
import urllib.request
import urllib.parse

ANKIWEB_SYNC_URL = "https://sync.ankiweb.net/sync/hostKey"
PREFS_DB = "/data/prefs21.db"
PROFILE_NAME = "User 1"


def get_host_key(user: str, password: str) -> str:
    """Autentica com AnkiWeb e retorna o hkey."""
    data = urllib.parse.urlencode({"u": user, "p": password}).encode()
    req = urllib.request.Request(ANKIWEB_SYNC_URL, data=data)

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = json.loads(resp.read())
            key = body.get("key")
            if not key:
                print(f"[setup-sync] Resposta inesperada: {body}", file=sys.stderr)
                sys.exit(1)
            return key
    except Exception as e:
        print(f"[setup-sync] Erro ao autenticar com AnkiWeb: {e}", file=sys.stderr)
        sys.exit(1)


def ensure_prefs_db():
    """Cria prefs21.db se nao existir."""
    if os.path.exists(PREFS_DB):
        return

    print("[setup-sync] Criando prefs21.db...")
    conn = sqlite3.connect(PREFS_DB)
    conn.execute("CREATE TABLE profiles (name TEXT PRIMARY KEY, data BLOB NOT NULL)")

    # Perfil global minimo
    global_data = pickle.dumps({})
    conn.execute("INSERT INTO profiles (name, data) VALUES (?, ?)", ("_global", global_data))

    conn.commit()
    conn.close()


def update_profile_sync(hkey: str, user: str):
    """Injeta hkey e user no perfil do prefs21.db."""
    ensure_prefs_db()

    conn = sqlite3.connect(PREFS_DB)

    # Verifica se o perfil existe
    row = conn.execute(
        "SELECT data FROM profiles WHERE name = ?", (PROFILE_NAME,)
    ).fetchone()

    if row:
        try:
            profile_data = pickle.loads(row[0])
        except Exception:
            profile_data = {}
    else:
        profile_data = {}

    # Injeta credenciais de sync
    profile_data["syncKey"] = hkey
    profile_data["syncUser"] = user
    profile_data["syncMedia"] = True

    blob = pickle.dumps(profile_data)

    if row:
        conn.execute(
            "UPDATE profiles SET data = ? WHERE name = ?", (blob, PROFILE_NAME)
        )
    else:
        conn.execute(
            "INSERT INTO profiles (name, data) VALUES (?, ?)", (PROFILE_NAME, blob)
        )

    conn.commit()
    conn.close()
    print(f"[setup-sync] Perfil '{PROFILE_NAME}' atualizado com sync token.")


def main():
    user = os.environ.get("ANKIWEB_USER", "").strip()
    password = os.environ.get("ANKIWEB_PASS", "").strip()

    if not user or not password:
        print("[setup-sync] ANKIWEB_USER/ANKIWEB_PASS nao definidos, pulando login automatico.")
        return

    print(f"[setup-sync] Autenticando '{user}' com AnkiWeb...")
    hkey = get_host_key(user, password)
    print(f"[setup-sync] Token obtido com sucesso.")

    update_profile_sync(hkey, user)
    print("[setup-sync] Login automatico configurado.")


if __name__ == "__main__":
    main()
