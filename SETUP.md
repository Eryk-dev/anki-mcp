# Anki MCP Server - Deploy na VPS (EasyPanel)

## Arquitetura

```
Internet
  |
  v
EasyPanel (VPS)
  |
  +-- anki-mcp-server (porta 3141) <-- Claude/ChatGPT conectam aqui
  |     |
  |     v
  +-- anki-headless (porta 8765) <-- AnkiConnect API
  |     |
  |     v
  +-- AnkiWeb Sync <-- sincroniza com seu celular/PC
```

## Passo 1 - Empacotar dados locais (no seu Mac)

Rode no terminal do Mac:

```bash
cd /Volumes/SSD\ Eryk/FLUXO\ KOMMO/anki-mcp-vps
./pack-anki-data.sh
```

Isso gera o arquivo `anki-data-seed.tar.gz` com:
- `prefs21.db` (sessao AnkiWeb ja logada)
- `Usuario 1/` (collection + media)

## Passo 2 - Enviar para a VPS

```bash
scp anki-data-seed.tar.gz usuario@sua-vps:/tmp/
```

## Passo 3 - Deploy no EasyPanel

No EasyPanel:
1. Criar novo projeto: `anki-mcp`
2. Adicionar servico > Docker Compose
3. Colar o conteudo do `docker-compose.yml`
4. Fazer upload dos arquivos `config/` para o volume do servico
5. Deploy

## Passo 4 - Injetar dados do Anki no container

Apos o container subir, no terminal da VPS:

```bash
# Copiar seed para dentro do container
docker cp /tmp/anki-data-seed.tar.gz anki-headless:/tmp/

# Extrair no volume de dados
docker exec anki-headless bash -c 'tar -xzf /tmp/anki-data-seed.tar.gz -C /data/ && rm /tmp/anki-data-seed.tar.gz'

# Reiniciar para carregar com os dados
docker compose restart
```

O entrypoint automaticamente:
- Renomeia "Usuario 1" para "User 1" (formato Linux)
- Atualiza o prefs21.db
- Instala AnkiConnect
- Inicia o Anki ja logado no AnkiWeb

## Passo 5 - Configurar dominio

No EasyPanel, adicionar dominio ao servico `mcp-server`:
- Dominio: `anki-mcp.seudominio.com`
- Porta interna: `3141`
- HTTPS: ativado (EasyPanel faz automaticamente)

## Passo 6 - Configurar MCP no Claude

```json
{
  "mcpServers": {
    "anki": {
      "type": "streamable-http",
      "url": "https://anki-mcp.seudominio.com/mcp"
    }
  }
}
```

## Seguranca

- Porta 5900 (VNC): manter fechada, so abrir se precisar debug visual
- Adicionar basic auth via EasyPanel no dominio do MCP
- O `ankiconnect-config.json` aceita `apiKey` para protecao extra

## Comandos uteis

```bash
# Ver logs do Anki
docker logs anki-headless -f

# Ver logs do MCP server
docker logs anki-mcp-server -f

# Forcar sync manual
curl -X POST http://localhost:8765 -d '{"action":"sync","version":6}'

# Testar se AnkiConnect responde
curl http://localhost:8765 -d '{"action":"version","version":6}'
```

## Manutencao

- O volume `anki-data` persiste a collection e configuracoes
- Backups: faca backup do volume `anki-data` periodicamente
- Updates: alterar a tag da imagem no docker-compose e redeployar
- Se a sessao do AnkiWeb expirar: rodar `pack-anki-data.sh` de novo no Mac e reinjetar
