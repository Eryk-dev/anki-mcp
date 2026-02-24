#!/bin/bash
set -e

ADDON_DIR="/data/addons21/2055492159"
ADDON_GH="https://codeload.github.com/FooSoft/anki-connect/zip/refs/heads/master"

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

# ── Login automatico no AnkiWeb (se credenciais definidas) ──────
if [ -n "$ANKIWEB_USER" ] && [ -n "$ANKIWEB_PASS" ]; then
    echo "[entrypoint] Executando login automatico no AnkiWeb..."
    python3 /app/setup-sync.py || echo "[entrypoint] AVISO: login automatico falhou, continua sem sync."
fi

# ── Permissoes ──────────────────────────────────────────────────
chown -R anki:anki /data

echo "[entrypoint] AnkiConnect configurado. Iniciando Anki..."

# ── Inicia o Anki via script padrao da imagem ───────────────────
exec /app/start.sh
