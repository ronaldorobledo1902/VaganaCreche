# Componente: SME-VagasNaCreche-API (Backend)

O **SME-VagasNaCreche-API** atua como núcleo de **consulta** do Vagas na Creche. É responsável por expor a fila (PostGIS), as vagas remanescentes (CIEDUDW), o cache de filtros (Redis) e a telemetria de buscas (`db_vaga`) — sem BFF/mensageria e **sem** autenticação do cidadão.

---

## 1. Visão geral da arquitetura (C3)

A anatomia interna segue apps Django por domínio (`fila_da_creche`, `vaga_remanescente`, pesquisa) e utilitários de conexão SQL aos warehouses. O fluxo é **síncrono HTTP request/response**.

```{image} ../assets/05-sistema-arquitetura.svg
:width: 100%
:alt: Componentes no contexto da API Vagas na Creche
```

---

## 2. Descrição dos componentes e responsabilidades

### 2.1 Entrada HTTP

* **core/urls.py + DRF:** roteamento das views de fila, vagas e pesquisa.
* **Swagger (`drf-yasg`):** documentação interativa na raiz `/` (pública).
* **Django Admin:** `/admin` (exposto — risco operacional em portal público).
* **Nginx + Gunicorn:** proxy :80 → app :8000; 8 workers; timeout 120s.

### 2.2 Domínio de fila

| Componente | Responsabilidade |
|------------|------------------|
| **fila_da_creche/views** | `GET /fila/espera_escola_raio/{lat}/{lon}/{cd_serie}` |
| **fila_da_creche/queries** | SQL + PostGIS (`ST_DWithin`, JOINs, agregações) |
| **db_fila_creche_connection** | Conexão psycopg2 connect-per-query ao Fila DB |

### 2.3 Domínio de vagas remanescentes

| Componente | Responsabilidade |
|------------|------------------|
| **vaga_remanescente/views** | `GET /vaga/filtros/`, `GET /vaga/{cd_serie}/` |
| **vaga_remanescente/queries** | SQL no CIEDUDW (DREs, distritos, subprefeituras, vagas) |
| **ciedudw_connection** | Conexão psycopg2 connect-per-query ao DW |
| **Redis (`filtros_vaga`)** | Cache de filtros (TTL 1h; pickle + zlib) |

### 2.4 Telemetria

| Componente | Responsabilidade |
|------------|------------------|
| **pesquisa / histórico** | `POST /pesquisa/historico_busca_end/` |
| **ORM `db_vaga`** | Tabela `pesq_historico_busca_endereco` (lat/lon, data/hora) |

### 2.5 Persistência e configuração transversal

* **settings.py:** CORS (`ALLOW_ALL`), `ALLOWED_HOSTS=['*']`, Redis URL, conexões DW/Fila via env.
* **Tratamento de erro frágil:** falha de conexão pode retornar `'ERROR'` e gerar `KeyError` (HTTP 500) em vez de 503.

---

## 3. Diretrizes para o desenvolvedor

1. **Parametrizar SQL:** nunca interpolar `lat`, `lon`, `cd_serie`, `filtro`, `busca` em f-strings — usar placeholders `%s` do psycopg2.
2. **Validar entrada:** ranges de coordenadas e série antes de tocar no banco.
3. **Health checks:** expor `/health/live` e `/health/ready` com verificação de dependências (db_vaga, Fila, DW, Redis).
4. **Connection pooling:** evitar connect-per-query nos warehouses (`psycopg2.pool` ou PgBouncer).
5. **Cache:** expandir Redis para endpoints de fila e vagas (TTL curto), além dos filtros.
6. **CORS / rate limit:** restringir origens do Front e aplicar throttling DRF.
7. **Erros de conexão:** retornar estrutura consistente e HTTP 503 em indisponibilidade parcial.
8. **Secrets:** externalizar `SECRET_KEY` e credenciais para Secrets do Kubernetes (sem fallback hardcoded).

---

## 4. Relação com documentação

| Tema | Referência |
|------|------------|
| Jornada fila | [contexto-fila.md](../contexto/contexto-fila.md) |
| Jornada vagas | [contexto-vagas.md](../contexto/contexto-vagas.md) |
| Carga Airflow | [contexto-dados.md](../contexto/contexto-dados.md) |
| Container API | [container-backend.md](../container/container-backend.md) |
| Matriz de risco | [06-sistema-matriz-risco.svg](../assets/06-sistema-matriz-risco.svg) |
| Recomendações | `visao-arquitetural` / Documentos de recomendações prioritárias |
