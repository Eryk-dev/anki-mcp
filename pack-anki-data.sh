#!/bin/bash
# ── Empacota dados locais do Anki para enviar à VPS ─────────────
set -e

ANKI_DIR="$HOME/Library/Application Support/Anki2"
OUTPUT="./anki-data-seed.tar.gz"

if [ ! -d "$ANKI_DIR" ]; then
    echo "Erro: diretório Anki não encontrado em $ANKI_DIR"
    exit 1
fi

echo "Empacotando dados do Anki..."
echo "  - prefs21.db (sessão AnkiWeb)"
echo "  - Usuário 1/ (collection + media)"

tar -czf "$OUTPUT" \
    -C "$ANKI_DIR" \
    prefs21.db \
    "Usuário 1"

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo ""
echo "Pronto! Arquivo criado: $OUTPUT ($SIZE)"
echo ""
echo "Próximo passo: enviar para a VPS com:"
echo "  scp $OUTPUT usuario@sua-vps:/tmp/"
echo ""
echo "Depois no server, rodar:"
echo "  docker compose up -d anki"
echo "  docker cp /tmp/anki-data-seed.tar.gz anki-headless:/tmp/"
echo "  docker exec anki-headless bash -c 'tar -xzf /tmp/anki-data-seed.tar.gz -C /data/ && rm /tmp/anki-data-seed.tar.gz'"
echo "  docker compose restart anki"
