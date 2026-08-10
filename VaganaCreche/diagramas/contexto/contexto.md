# Contexto Geral do Sistema — SME Vagas na Creche

O **Vagas na Creche** é o portal público da Secretaria Municipal de Educação de São Paulo (SME) que permite a qualquer cidadã(o) consultar a **demanda (fila de espera)** e as **vagas remanescentes** em creches da Rede Municipal, com resultado em tabela e **mapa interativo**.

A arquitetura **as-is** é composta por dois repositórios implantados em Kubernetes, uma API REST que consulta o Data Warehouse (CIEDUDW) e o banco da Fila (PostGIS), um banco aplicacional (`db_vaga`) para telemetria de buscas, Redis para cache de filtros, e um pipeline diário (Airflow) que publica os dados da fila.

**Premissa de negócio:** portal **público**, sem autenticação do cidadão. Não há BFF; o FrontEnd consome diretamente a API.

```{image} ../assets/02-airflow-contexto.svg
:width: 100%
:alt: Diagrama de Contexto — SME Vagas na Creche + Airflow
```

Para detalhamento das interações, o ecossistema é documentado pelas jornadas/contextos funcionais principais:

```{toctree}
:maxdepth: 1
:caption: Contextos

contexto-fila
contexto-vagas
contexto-dados
```

---

## Atores e sistemas

| Elemento | Tipo | Papel |
|----------|------|-------|
| **Cidadão / Família** | Person | Consulta fila de espera e vagas remanescentes |
| **SPA FrontEnd** | Container (React / Nginx) | Interface pública sob `/vaga-na-creche` |
| **API Vagas na Creche** | Container (Django DRF) | API REST de consulta e telemetria |
| **db_vaga** | Container (PostgreSQL) | Histórico de buscas por endereço |
| **Fila da Creche DB** | Container (PostgreSQL + PostGIS) | Snapshot diário da fila e geometria das escolas |
| **CIEDUDW** | Software System externo | Vagas remanescentes, DREs, distritos, subprefeituras |
| **Redis** | Container | Cache de filtros de vagas (TTL 1h) |
| **Apache Airflow** | Software System externo | DAG `fila_da_creche` (carga diária) |
| **Pelias** | Software System externo | Geocodificação de endereços |
| **OpenStreetMap** | Software System externo | Tiles do mapa Leaflet |
| **Google Analytics** | Software System externo | Telemetria de uso (UA legado) |

---

## O que não faz parte deste contexto

- Login/cadastro do cidadão (portal aberto por desenho)
- Matrícula ou alteração da posição na fila (domínio do EOL)
- Estatísticas gerais da RME (domínio do **Escola Aberta**)
- BFF ou mensageria na API de consulta
