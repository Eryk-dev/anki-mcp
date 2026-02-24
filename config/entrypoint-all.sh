#!/bin/bash
set -e

ADDON_DIR="/data/addons21/2055492159"
ADDON_GH="https://codeload.github.com/FooSoft/anki-connect/zip/refs/heads/master"

echo "============================================"
echo " Anki MCP Server - Starting..."
echo "============================================"

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

# ── Login automatico no AnkiWeb ─────────────────────────────────
if [ -n "$ANKIWEB_USER" ] && [ -n "$ANKIWEB_PASS" ]; then
    echo "[entrypoint] Autenticando com AnkiWeb..."
    python3 /app/setup-sync.py || echo "[entrypoint] AVISO: login falhou, continua sem sync."
fi

# ── Permissoes ──────────────────────────────────────────────────
chown -R anki:anki /data

# ── Inicia Anki em background ───────────────────────────────────
echo "[entrypoint] Iniciando Anki headless..."
/app/start.sh &
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

# ── Mantém container vivo (espera qualquer processo morrer) ─────
wait -n $ANKI_PID $MCP_PID
exit $?
