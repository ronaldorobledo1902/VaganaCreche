# Container da Solução — SME Vagas na Creche

Aqui está o diagrama de **contêineres (C2)** do Vagas na Creche: mapa da topologia de software em produção.

Este desenho consolida como o **FrontEnd** e a **API** interagem com o banco aplicacional (`db_vaga`), com o banco da Fila (PostGIS), com o CIEDUDW, com o Redis e com serviços externos (Pelias, OSM, Analytics), sem camada BFF.

![Diagrama de Containers — SME Vagas na Creche](../assets/05-sistema-arquitetura.svg)

---

## Descrição das fronteiras e fluxos

### 1. Camada de apresentação

* **vaganacreche-frontend [Container: React 16 / Nginx]**  
  SPA pública sob basename `/vaga-na-creche`. Serve a interface do cidadão (fila de espera, vagas remanescentes, mapa). Namespace de produção: `sme-vaganacreche`.  
  Comunicação: Axios HTTP/REST para a API; HTTPS para Pelias, OSM e Google Analytics.

### 2. Camada de ingresso

* **Ingress Kubernetes [Container: Ingress K8s]**  
  Roteamento path-based: `/` → FrontEnd; `/api` → API (padrão típico do cluster SME). Tráfego externo passa por VIP + 2 nós Nginx da Infra Física antes do Ingress.

### 3. Camada de API

* **vaganacreche-backend [Container: Django 2.2 + DRF / Gunicorn]**  
  API REST de consulta (fila e vagas) e persistência de telemetria. Gunicorn com **8 workers**, timeout 120s. Nginx reverso no pod (:80 → :8000).  
  Acessa `db_vaga`, CIEDUDW, Fila DB e Redis.

### 4. Camada de dados

* **db_vaga [Container: PostgreSQL 12]**  
  Banco aplicacional. Única entidade gerenciada pela API: `pesq_historico_busca_endereco` (telemetria de buscas).

* **Fila da Creche DB [Container: PostgreSQL + PostGIS]**  
  Snapshot diário da fila, unidades, contatos e geometria. Alimentado pela DAG Airflow `fila_da_creche`. Porta típica levantada: `5433`.

* **CIEDUDW [Software System]**  
  Data Warehouse educacional. Origem das vagas remanescentes e filtros territoriais; origem do ETL da fila.

* **Redis 3.2 [Container]**  
  Cache de `GET /vaga/filtros/` (TTL 1h). Serialização pickle + zlib.

### 5. Orquestração de dados e operação

* **Apache Airflow [Software System]** — DAG `fila_da_creche` (carga diária às 10h).  
* **Jenkins + Registry SME** — CI/CD → `kubectl rollout restart`; notificação Telegram.  
* **Grafana** — métricas HTTP de borda (quando disponível no host público).

### 6. Serviços externos de apoio

* **Pelias** — geocodificação (`/v1/search`)  
* **OpenStreetMap** — tiles Leaflet  
* **Google Analytics** — pageview (UA legado)

---

## O que não existe neste C2 (em relação a padrões SME com BFF)

| Padrão com BFF / identidade | Vagas na Creche as-is |
|-----------------------------|------------------------|
| BFF | **Ausente** — FE → API direto |
| Mensageria / Celery | **Ausente** |
| SME-Identidade / login cidadão | **Ausente** — portal público |
| Backend de matrícula | API de **consulta** (+ telemetria de busca) |
| Connection pool nos DWs | **Ausente** — connect-per-query |
