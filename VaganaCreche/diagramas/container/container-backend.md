# Container — vaganacreche-backend

```{image} ../assets/05-sistema-arquitetura.svg
:width: 100%
:alt: Backend/API no diagrama de containers do Vagas na Creche
```

## Processamento de Backend (SME-VagasNaCreche-API)

O container **vaganacreche-backend** é a API REST pública do Vagas na Creche. Stack: **Python 3.7 / Django 2.2 / DRF / Gunicorn** (8 workers, timeout 120s), atrás de Nginx reverso no pod, no namespace `sme-vaganacreche`.

### Responsabilidades

* Expor consulta de **fila de espera** por raio geográfico (`/fila/espera_escola_raio/`)
* Expor **vagas remanescentes** e filtros territoriais (`/vaga/`, `/vaga/filtros/`)
* Persistir **telemetria** de buscas em `db_vaga` (`/pesquisa/historico_busca_end/`)
* Cachear filtros em Redis (TTL 1h)
* Documentação Swagger pública na raiz (`/`)

### Comunicação

| Destino | Padrão | Uso |
|---------|--------|-----|
| **db_vaga** | Django ORM + psycopg2 | Histórico de buscas |
| **Fila da Creche DB** | psycopg2 + SQL bruto / PostGIS | Fila e geometria (`ST_DWithin`) |
| **CIEDUDW** | psycopg2 + SQL bruto | Vagas e filtros territoriais |
| **Redis** | django-redis | Cache de `/vaga/filtros/` |
| FrontEnd / Ingress | HTTP (CORS allow-all) | Consumo público |

**Não utiliza:** Celery, filas, WebSocket, GraphQL, JWT de cidadão.

### Pilares de rede

1. **Inbound:** requisições HTTP do Ingress/Front (e Swagger `/`)
2. **Outbound dados:** PostgreSQL aplicacional + Fila + CIEDUDW
3. **Outbound cache:** Redis
4. **Padrão atual nos DWs:** connect-per-query (sem pool) — gargalo sob carga

### Premissas arquiteturais

* Portal **público** — sem autenticação do cidadão
* Thin query service sobre warehouses externos (fila e vagas)
* Escrita restrita à telemetria em `db_vaga`
* Cache mínimo (apenas filtros)
* Riscos ativos: SQL injection por interpolação, CORS aberto, ausência de health checks
