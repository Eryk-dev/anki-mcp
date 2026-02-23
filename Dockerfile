FROM ghcr.io/ankimcp/headless-anki:x11-vnc-v1.1.0

# ── Instala Node.js para o MCP Server ───────────────────────────
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl sqlite3 && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g @ankimcp/anki-mcp-server && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Copia configs ───────────────────────────────────────────────
COPY config/ankiconnect-config.json /app/ankiconnect-config.json
COPY config/setup-sync.py /app/setup-sync.py
COPY config/entrypoint-all.sh /app/entrypoint-all.sh
RUN chmod +x /app/entrypoint-all.sh

# ── Credenciais via ENV (runtime, nao build) ────────────────────
ENV ANKIWEB_USER=""
ENV ANKIWEB_PASS=""
ENV READ_ONLY="false"
ENV MCP_PORT="3141"

# ── Portas ──────────────────────────────────────────────────────
EXPOSE 3141 8765 5900

ENTRYPOINT ["bash", "/app/entrypoint-all.sh"]
