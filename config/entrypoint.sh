#!/bin/bash
set -e

ADDON_DIR="/data/addons21/2055492159"
ADDON_PKG="https://ankiweb.net/shared/downloadAddon?id=2055492159&version=250203"

# ── Ajusta perfil se veio do macOS (Usuário 1 → User 1) ────────
if [ -d "/data/Usuário 1" ] && [ ! -d "/data/User 1" ]; then
    echo "[entrypoint] Renomeando perfil 'Usuário 1' → 'User 1'..."
    mv "/data/Usuário 1" "/data/User 1"

    # Atualiza o prefs21.db para usar o novo nome
    if [ -f "/data/prefs21.db" ] && command -v sqlite3 &>/dev/null; then
        sqlite3 /data/prefs21.db "UPDATE profiles SET name='User 1' WHERE name='Usuário 1';"
        echo "[entrypoint] prefs21.db atualizado."
    fi
fi

# ── Instala AnkiConnect se nao existir ──────────────────────────
if [ ! -d "$ADDON_DIR" ]; then
    echo "[entrypoint] Instalando AnkiConnect..."
    mkdir -p "$ADDON_DIR"
    curl -sL "$ADDON_PKG" -o /tmp/ankiconnect.zip
    unzip -o /tmp/ankiconnect.zip -d "$ADDON_DIR"
    rm /tmp/ankiconnect.zip
fi

# ── Manifest e meta (suprime avisos de update) ──────────────────
TIMESTAMP=$(date +%s)

cat > "$ADDON_DIR/manifest.json" << EOF
{
    "package": "2055492159",
    "name": "AnkiConnect",
    "mod": $TIMESTAMP
}
EOF

cat > "$ADDON_DIR/meta.json" << EOF
{
    "mod": $TIMESTAMP,
    "disabled": false,
    "update_enabled": false
}
EOF

# ── Aplica config do AnkiConnect (bind 0.0.0.0) ────────────────
cp /app/ankiconnect-config.json "$ADDON_DIR/config.json"

# ── Permissoes ──────────────────────────────────────────────────
chown -R anki:anki /data

echo "[entrypoint] AnkiConnect configurado. Iniciando Anki..."

# ── Inicia o Anki via script padrao da imagem ───────────────────
exec /app/start.sh
