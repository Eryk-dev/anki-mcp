#!/bin/bash
set -e

ADDON_DIR="/data/addons21/2055492159"
ADDON_GH="https://codeload.github.com/FooSoft/anki-connect/zip/refs/heads/master"

echo "============================================"
echo " Anki MCP Server - Starting..."
echo "============================================"

# ── Primeiro boot: limpa colecao para forcar download do AnkiWeb ──
# Garante que o servidor baixe a colecao do usuario (com model IDs corretos)
# Sem isso, o servidor cria IDs novos que nao batem com o Anki local
if [ ! -f /data/.collection_initialized ]; then
    echo "[entrypoint] Primeiro boot - limpando colecao para download do AnkiWeb..."
    rm -f "/data/User 1/collection.anki2"
    rm -f "/data/User 1/collection.anki2-wal"
    rm -f "/data/User 1/collection.anki2-shm"
    rm -f "/data/User 1/collection.anki21b"
    rm -f "/data/User 1/collection.anki21b-wal"
    rm -f "/data/User 1/collection.anki21b-shm"
    touch /data/.collection_initialized
    echo "[entrypoint] Colecao limpa. Sync inicial vai baixar do AnkiWeb."
fi

# ── Ajusta perfil se veio do macOS (Usuário 1 → User 1) ────────
if [ -d "/data/Usuário 1" ] && [ ! -d "/data/User 1" ]; then
    echo "[entrypoint] Renomeando perfil 'Usuário 1' → 'User 1'..."
    mv "/data/Usuário 1" "/data/User 1"
    if [ -f "/data/prefs21.db" ] && command -v sqlite3 &>/dev/null; then
        sqlite3 /data/prefs21.db "UPDATE profiles SET name='User 1' WHERE name='Usuário 1';"
    fi
fi

# ── Instala AnkiConnect via GitHub ──────────────────────────────
if [ ! -d "$ADDON_DIR" ] || [ ! -f "$ADDON_DIR/__init__.py" ]; then
    echo "[entrypoint] Instalando AnkiConnect via GitHub..."
    rm -rf "$ADDON_DIR"
    mkdir -p "$ADDON_DIR"
    curl -sL "$ADDON_GH" -o /tmp/ankiconnect.zip
    unzip -o /tmp/ankiconnect.zip -d /tmp/ankiconnect-src
    cp -r /tmp/ankiconnect-src/anki-connect-master/plugin/* "$ADDON_DIR/"
    rm -rf /tmp/ankiconnect.zip /tmp/ankiconnect-src
    echo "[entrypoint] AnkiConnect instalado com sucesso."
fi

# ── Manifest e meta ─────────────────────────────────────────────
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

# ── Config do AnkiConnect (bind 0.0.0.0) ────────────────────────
cp /app/ankiconnect-config.json "$ADDON_DIR/config.json"

# ── Instala Auto-Sync Addon (resolve full sync sem GUI) ─────────
AUTOSYNC_DIR="/data/addons21/auto_sync_headless"
mkdir -p "$AUTOSYNC_DIR"
cp /app/auto-sync-addon/__init__.py "$AUTOSYNC_DIR/__init__.py"
cat > "$AUTOSYNC_DIR/manifest.json" << EOF
{
    "package": "auto_sync_headless",
    "name": "Auto Sync Headless",
    "mod": $TIMESTAMP
}
EOF
cat > "$AUTOSYNC_DIR/meta.json" << EOF
{
    "mod": $TIMESTAMP,
    "disabled": false,
    "update_enabled": false
}
EOF
echo "[entrypoint] Auto-Sync addon instalado."

# ── Login automatico no AnkiWeb ─────────────────────────────────
if [ -n "$ANKIWEB_USER" ] && [ -n "$ANKIWEB_PASS" ]; then
    echo "[entrypoint] Autenticando com AnkiWeb..."
    python3 /app/setup-sync.py || echo "[entrypoint] AVISO: login falhou, continua sem sync."
fi

# ── Permissoes ──────────────────────────────────────────────────
chown -R anki:anki /data

# ── Inicia X11 virtual + VNC + Window Manager ───────────────────
echo "[entrypoint] Iniciando X11 virtual..."
Xvfb :99 -screen 0 1920x1080x24 &
sleep 1

openbox &
sleep 1

x11vnc -display :99 -forever -nopw -rfbport 5900 &
sleep 1

export DISPLAY=:99
export QTWEBENGINE_DISABLE_SANDBOX=1

# ── Inicia Anki em background ───────────────────────────────────
echo "[entrypoint] Iniciando Anki headless..."
su -s /bin/bash anki -c "DISPLAY=:99 QTWEBENGINE_DISABLE_SANDBOX=1 anki -b /data" &
ANKI_PID=$!

# ── Aguarda AnkiConnect ficar pronto ────────────────────────────
echo "[entrypoint] Aguardando AnkiConnect (porta 8765)..."
for i in $(seq 1 60); do
    if curl -sf http://localhost:8765 -d '{"action":"version","version":6}' > /dev/null 2>&1; then
        echo "[entrypoint] AnkiConnect pronto!"
        break
    fi
    sleep 2
done

# ── Força sync inicial (auto-download via addon no primeiro boot) ─
echo "[entrypoint] Executando sync inicial..."
curl -sf http://localhost:8765 -d '{"action":"sync","version":6}' && \
    echo "[entrypoint] Sync inicial executado." || \
    echo "[entrypoint] AVISO: sync inicial falhou."
sleep 3

# ── Inicia MCP Server ───────────────────────────────────────────
echo "[entrypoint] Iniciando MCP Server na porta ${MCP_PORT}..."
ankimcp \
    --host 0.0.0.0 \
    --port "${MCP_PORT}" \
    --anki-connect http://localhost:8765 &
MCP_PID=$!

echo "============================================"
echo " Anki MCP Server ONLINE"
echo " MCP:  http://0.0.0.0:${MCP_PORT}"
echo " Anki: http://0.0.0.0:8765"
echo " VNC:  :5900"
echo "============================================"

# ── Mantém container vivo ───────────────────────────────────────
wait $ANKI_PID
