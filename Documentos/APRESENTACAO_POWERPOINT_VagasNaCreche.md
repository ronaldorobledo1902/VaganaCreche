# Apresentação PowerPoint — SME Vagas na Creche

**Levantamento Arquitetural Completo**  
**Data:** Julho/2026  
**Duração sugerida:** 45–60 minutos  
**Público:** Stakeholders técnicos, gestão e operação (SME / Spassu)

> **Como usar:** cada seção `## Slide N` = 1 slide no PowerPoint.  
> **Diagramas:** exportar as 7 páginas do arquivo `diagramas/drawio/ARQUITETURA - VAGA NA CRECHE.drawio` (PNG ou SVG) e inserir nos slides indicados.

---

## Slide 1 — Capa

**SME Vagas na Creche**  
Levantamento Arquitetural, Infraestrutura e Sustentabilidade

- Secretaria Municipal de Educação de São Paulo
- Spassu Tecnologia · Julho/2026
- Sistema + Pipeline Airflow + Infraestrutura On-Premises

---



## Slide 2 — Agenda

1. Contexto e objetivo do sistema
2. Arquitetura da aplicação
3. Pipeline de dados (Airflow)
4. Infraestrutura e DevOps
5. Avaliação consolidada e riscos
6. Sustentabilidade (5 anos)
7. Pontos fortes, fracos e recomendações
8. Estimativa de custos
9. Próximos passos

---



## Slide 3 — Resumo Executivo


| Aspecto              | Situação                                                              |
| -------------------- | --------------------------------------------------------------------- |
| **Propósito**        | Portal público de consulta de fila e vagas remanescentes em creches   |
| **Arquitetura**      | React + Django API + 3 bancos PostgreSQL + Redis + Airflow            |
| **Infraestrutura**   | On-premises, Kubernetes (Rancher), 100% open source                   |
| **Tráfego**          | ~100–150 acessos/dia; pico sazonal no fim do ano                      |
| **DevOps**           | CI/CD maduro (Jenkins + Docker + K8s) — **nota boa**                  |
| **Segurança**        | Riscos críticos ativos (SQL injection, stack EOL) — **ação imediata** |
| **Sustentabilidade** | Viável com modernização programada; insustentável "as-is"             |


**Mensagem-chave:** sistema funcional e de baixo custo de licença, porém com **dívida técnica e riscos de segurança** que exigem plano de ação.

---



## Slide 4 — O que é o Sistema?

Portal público que permite ao cidadão:

- Consultar **fila de espera** por creches próximas a um endereço
- Consultar **vagas remanescentes** (filtro por DRE, distrito, subprefeitura)
- Visualizar escolas em **mapa interativo** (Leaflet / OpenStreetMap)
- Registrar telemetria de buscas (histórico por coordenada)

**Repositórios:** `SME-VagasNaCreche-API` + `SME-VagasNaCreche-FrontEnd`  
**URL:** `vaga-na-creche.sme.prefeitura.sp.gov.br`

---



## Slide 5 — Componentes e Stack


| Camada                         | Tecnologia                            | Status                  |
| ------------------------------ | ------------------------------------- | ----------------------- |
| FrontEnd                       | React 16, Nginx, Node 12              | EOL                     |
| API                            | Django 2.2, DRF, Gunicorn (8 workers) | EOL                     |
| Banco aplicacional (`db_vaga`) | PostgreSQL 12 (~1 GB)                 | Suporte limitado        |
| Data Warehouse                 | CIEDUDW (PostgreSQL)                  | Leitura                 |
| Fila da Creche                 | PostgreSQL + PostGIS (:5433)          | Alimentado pelo Airflow |
| Cache                          | Redis 3.2 (1 endpoint)                | EOL                     |
| Orquestração                   | Kubernetes + Rancher                  | OSS                     |
| CI/CD                          | Jenkins + Docker                      | OSS                     |


**Comunicação:** exclusivamente HTTP síncrono — sem mensageria, WebSocket ou filas.

---



## Slide 6 — Diagrama de Arquitetura

> **Visual:** Página 4 do drawio — `SISTEMA -Diagrama de Arquitetura`  
> Arquivo: `diagramas/drawio/ARQUITETURA - VAGA NA CRECHE.drawio`

**Fluxo principal:**

```
Cidadão → SPA React → Nginx (K8s FE) → Nginx + Gunicorn (K8s API)
                                              ↓
                    db_vaga | CIEDUDW | Fila DB | Redis
```

**Serviços externos (FE):** Pelias (geocodificação), OpenStreetMap, Google Analytics

**Operação:** Jenkins → Registry SME → Deploy K8s → Telegram

**Destaques do diagrama:**

- 2 deployments K8s (FrontEnd + API)
- API conecta a **3 bancos** + Redis (cache parcial)
- CIEDUDW e Fila da Creche são **SPOFs** para funcionalidades principais

---



## Slide 7 — Contexto: Sistema + Airflow

> **Visual:** Página 1 do drawio — `AIRFLOW-Contexto VagasNaCreche + Airflow`

**Visão integrada:**

- **Camada Aplicação (K8s):** FE → API → lê Fila DB, CIEDUDW e `db_vaga`
- **Camada ETL (Airflow):** DAG `fila_da_creche` alimenta o banco Fila da Creche diariamente
- **Origem dos dados:** CIEDU DW (`potomac.educacao.intranet`) → Airflow → Fila DB

**Legenda do diagrama:**

- Pipeline ETL alimenta Fila da Creche
- API lê Fila (fila), CIEDUDW (vagas) e `db_vaga` (histórico)
- Dados atualizados **diariamente às 10h** (America/Sao_Paulo)

---



## Slide 8 — DAG fila_da_creche (11 tasks)

> **Visual:** Página 2 do drawio — `ARFLOW- Dag Fila da Creche`


| Atributo          | Valor                  |
| ----------------- | ---------------------- |
| Schedule          | `0 10 * * *` (10h BRT) |
| Duração média     | ~1 min 03 s            |
| Sucesso histórico | ~31.274 execuções      |
| Falhas            | ~156                   |
| Últimas 25 runs   | 100% sucesso           |


**4 fases:**


| Fase         | Tasks                            | Descrição             |
| ------------ | -------------------------------- | --------------------- |
| 1 — Extração | 5 tasks (paralelo)               | Extrai do CIEDU DW    |
| 2 — Limpeza  | `truncate_fila_da_creche_tables` | Apaga tabelas destino |
| 3 — Carga    | 4 tasks copy (sequencial)        | Recarrega dados       |
| 4 — Geo      | `add_geom_to_schools`            | Geometria PostGIS     |


**Destino:** `10.50.1.45:5432` → consumido pela API via `FILADB_`* (:5433)

---



## Slide 9 — Fluxo ETL Diário

> **Visual:** Página 3 do drawio — `ARFLOW-Fluxo ETL Diário`

**Pipeline truncate-and-load:**

```
Trigger 10h → EXTRACT (CIEDU DW) → TRUNCATE → LOAD (4 copies) → ENRIQUECER (PostGIS) → Fila DB → API → FE
```

**Timing:**

- Início DAG: 10:00 BRT
- Duração: ~1 min
- API `updated_at`: dia anterior 09:00

**Riscos operacionais (do diagrama):**

- Janela truncate: dados vazios durante carga
- Catchup=True: backfill de execuções perdidas
- 854 upstream_failed históricos
- Gargalo: tasks `unidades_educacionais_*` (15–50 s)

---



## Slide 10 — Fluxos de Negócio

**Consulta de Fila de Espera:**

1. Cidadão informa endereço → Pelias retorna coordenadas
2. FE chama `GET /fila/espera_escola_raio/{lat}/{lon}/{serie}`
3. API consulta Fila DB (PostGIS — raio geográfico)
4. Retorna escolas + posição na fila + mapa

**Consulta de Vagas Remanescentes:**

1. FE chama `GET /vaga/filtros/` (cache Redis, TTL 1h)
2. Cidadão seleciona DRE/distrito/subprefeitura
3. FE chama `GET /vaga/{serie}/?filtro=&busca=`
4. API consulta CIEDUDW → retorna escolas com vagas

---



## Slide 11 — Infraestrutura On-Premises


| Item             | Detalhe                                                     |
| ---------------- | ----------------------------------------------------------- |
| **Modelo**       | On-premises (Zen Orchestra + Hyper-V)                       |
| **Orquestração** | Kubernetes via Rancher                                      |
| **Clusters**     | Produção (3 CP + 13 workers = 16 nós), Release (QA/homolog) |
| **Segregação**   | Prod no cluster prod; QA/homolog no cluster release         |
| **Proxy**        | IP VIP + 2 Nginx (Infra Física) → Ingress K8s               |
| **Storage**      | NFS (PV/PVC até 100 GB)                                     |
| **Plataforma**   | 100% OSS — zero custo de licença                            |


**Tráfego de entrada:** `vaga-na-creche.sme.prefeitura.sp.gov.br` — `/` → FE; `/api`, `/admin` → API:8000

---



## Slide 12 — Kubernetes: Vaga na Creche


| Recurso         | Produção                                  |
| --------------- | ----------------------------------------- |
| Namespace       | `sme-vaganacreche`                        |
| Deployments     | FrontEnd + API                            |
| Pods            | **1 pod por serviço** (sem réplica extra) |
| HPA / Autoscale | **Desabilitado** (restrição de recursos)  |
| Deploy          | Rolling Update (~5 min)                   |
| Rollback        | Revert Git + reexecução Jenkins           |
| Secrets         | K8s Secrets + ConfigMaps                  |


**Limitação crítica:** 1 pod/serviço = sem resiliência; pico sazonal exige intervenção manual ou novos servidores.

---



## Slide 13 — Pipeline CI/CD

> **Visual:** Página 6 do drawio — `SISTEMA - Pipeline CI/CD`

```
GitHub (webhook) → Jenkins → JSHint/SonarQube → Docker Build → Registry SME → kubectl rollout → Telegram
```


| Branch          | Ambiente                              |
| --------------- | ------------------------------------- |
| `develop`       | `vaganacreche-dev`                    |
| `homolog`       | `vaganacreche-hom`                    |
| `homolog-r2`    | `vaganacreche-hom2`                   |
| `master`/`main` | `sme-vaganacreche` (aprovação manual) |


**Pontos fortes:** automatizado, multi-ambiente, notificação Telegram  
**Gaps:** apps legadas sem testes/Quality Gate; sem Blue/Green ou Canary

---



## Slide 14 — Banco de Dados


| Banco                       | Função                 | Capacidade                          |
| --------------------------- | ---------------------- | ----------------------------------- |
| `db_vaga` (PG aplicacional) | Histórico de buscas    | 16 vCPUs, 18 GiB, ~1 GB (+1 MB/mês) |
| CIEDUDW                     | Vagas remanescentes    | Compartilhado, leitura              |
| Fila da Creche              | Fila + PostGIS         | Alimentado pelo Airflow             |
| Redis 3.2                   | Cache `/vaga/filtros/` | Sem HA informada                    |


**HA (prod):** réplica read-only no `db_vaga`  
**Backup:** dump diário — **sem PITR** (RPO ~24h)  
**Ambientes:** banco **não separado** por ambiente para Vaga na Creche

Obs.: Pelo tamanho atual da base 1GB parece pequeno para 16 vCPUs, mas não dá para afirmar superdimensionamento sem olhar consumo real de CPU, memória, conexões e consultas.

---



## Slide 15 — Matriz de Risco de Segurança

> **Visual:** Página 5 do drawio — `SISTEMA -Matriz Risco de Seguranca`


| Quadrante                | Riscos                                |
| ------------------------ | ------------------------------------- |
| **Mitigar urgentemente** | SQL Injection, Stack EOL, CORS aberto |
| **Monitorar**            | Swagger público                       |
| **Planejar correção**    | API sem auth, sem rate limit          |
| **Aceitar**              | (nenhum)                              |


**Controles existentes:** CSRF, X-Frame-Options, Security Middleware  
**Ausentes:** Auth JWT, CORS restritivo, rate limit, parametrização SQL, validação lat/lon

---



## Slide 16 — Principais Riscos Técnicos


| #   | Risco                                        | Impacto                                  |
| --- | -------------------------------------------- | ---------------------------------------- |
| 1   | SQL injection (queries não parametrizadas)   | Comprometimento de dados                 |
| 2   | Stack EOL (Python 3.7, Django 2.2, React 16) | CVEs sem patch                           |
| 3   | 1 pod/serviço, sem HPA                       | Sem resiliência em picos                 |
| 4   | Connect-per-query nos DWs                    | Latência e esgotamento de conexões       |
| 5   | Cache insuficiente                           | Carga excessiva nos bancos legados       |
| 6   | Observabilidade fraca                        | Erros 500 intermitentes (6–8/dia)        |
| 7   | Conhecimento escasso                         | Sistema "arqueológico", pouca manutenção |
| 8   | Full refresh Airflow                         | Janela de dados vazios durante carga     |


**SPOFs:** CIEDUDW, Fila DB, API (1 réplica), possivelmente NFS

---



## Slide 17 — Avaliação Consolidada

> **Visual:** Página 7 do drawio — `SISTEMA - AVALIAÇÃO CONSOLIDADA`


| Dimensão         | Nota        | Cor sugerida |
| ---------------- | ----------- | ------------ |
| Funcionalidade   | Adequada    | Verde        |
| Segurança        | **Crítica** | Vermelho     |
| Resiliência      | Baixa       | Vermelho     |
| Performance      | Média       | Amarelo      |
| Observabilidade  | Baixa       | Vermelho     |
| Manutenibilidade | Média-Baixa | Laranja      |
| DevOps / Deploy  | **Boa**     | Verde        |
| Escalabilidade   | Média       | Amarelo      |


**Conexões (resumo do diagrama):**

- FE → API: HTTP/REST (Axios)
- API → `db_vaga`: Django ORM
- API → CIEDUDW / Fila: psycopg2 connect-per-query
- API → Redis: django-redis (1 endpoint cacheado)

---



## Slide 18 — Observabilidade e Operação


| Ferramenta  | Uso atual                         |
| ----------- | --------------------------------- |
| Rancher/K8s | Logs de pods                      |
| Grafana     | Dashboards HTTP (200/400/500)     |
| Telegram    | Alertas de build/deploy           |
| SonarQube   | Análise estática (branch homolog) |


**Ausente:** Prometheus, APM, tracing, health checks, alertas runtime, Sentry

**Tráfego observado:** ~98–154 acessos/dia; 6–8 erros HTTP 500 intermitentes

---



## Slide 19 — Sustentabilidade: Próximos 5 Anos


| Dimensão   | Hoje                  | Sem ação            | Com plano           |
| ---------- | --------------------- | ------------------- | ------------------- |
| Stack      | EOL                   | Insustentável ~2027 | Upgrade programado  |
| Segurança  | Crítica               | Risco crescente     | Correções imediatas |
| Capacidade | 1 pod/serviço         | Falha em picos      | Réplicas + HPA      |
| Dados      | ~1 GB (+60 MB/5 anos) | Sem impacto         | Sem impacto         |
| Infra OSS  | Adequada              | Manutenção humana   | Ferramentas maduras |


**Roadmap mínimo:**

- **Ano 1:** Segurança, health checks, pooling, 2 réplicas
- **Ano 2:** Upgrade stack, cache, testes, observabilidade
- **Ano 3:** HPA, PITR, alertas runtime
- **Anos 4–5:** Carga incremental Airflow, DR, runbooks, GA4

---



## Slide 20 — Pontos Fortes

1. **CI/CD funcional** — Jenkins + Docker + K8s + multi-ambiente
2. **Custo zero de licença** — plataforma 100% open source
3. **Arquitetura simples** — 2 serviços, fácil de operar
4. **Pipeline Airflow estável** — ~99,5% sucesso histórico
5. **Proxy redundante** — VIP + 2 Nginx
6. **Tráfego moderado** — ~150 acessos/dia
7. **Crescimento de dados mínimo** — ~1 MB/mês
8. **Cluster robusto** — 3 control planes + 13 workers

---



## Slide 21 — Pontos Fracos

1. Stack tecnológica **EOL** (sem patches de segurança)
2. **1 pod/serviço**, sem autoscale
3. **SQL injection** + CORS aberto
4. Connect-per-query → performance degradada sob carga
5. Cache Redis em **apenas 1 endpoint**
6. Observabilidade **insuficiente**
7. Pipeline legada **sem testes/Quality Gate**
8. Backup **sem PITR** (RPO ~24h)
9. Sistema **pouco mantido** — conhecimento escasso
10. Full refresh Airflow — risco operacional

---



## Slide 22 — Recomendações Prioritárias



### Curto prazo (0–3 meses) — CRÍTICO

1. Parametrizar SQL (eliminar injection)
2. Health checks (`/health/live`, `/health/ready`)
3. Restringir CORS
4. Tratamento de erro consistente (HTTP 503)
5. Validar entrada (lat/lon, filtros)
6. Corrigir race condition no FE
7. Configurar **2 réplicas** em produção



### Médio prazo (3–6 meses) — ALTO

Connection pooling · Cache Redis expandido · Logging JSON · Prometheus · Rate limiting · Sentry

### Longo prazo (6–12 meses) — PLANEJADO

Upgrade stack · React Query · GA4 · Testes automatizados · Carga incremental Airflow

---



## Slide 23 — Estimativa de Custos (Equipe)

**Premissas:** infraestrutura R$ 0 licença · ferramentas OSS · dedicação parcial


| Papel            | Qtd |
| ---------------- | --- |
| Arquiteto Sênior | 1   |
| Tech Lead        | 1   |
| DevOps           | 3   |
| DBA              | 1   |
| Desenvolvedor    | 1   |
| Product Owner    | 1   |



| Cenário                     | FTE médio | Custo anual     |
| --------------------------- | --------- | --------------- |
| A — Operação mínima         | 20%       | ~R$ 370.000     |
| **B — Operação + evolução** | 40%       | **~R$ 999.000** |
| C — Modernização intensiva  | 70%       | ~R$ 1.750.000   |


**5 anos (Cenário B recomendado):** ~R$ 4,2 – 4,5 milhões  
**Economia OSS vs SaaS:** R$ 165–450.000/ano evitados em licenças

---



## Slide 24 — Quick Wins (Alto ROI, Zero Licença)


| Ação                  | Impacto                    | Esforço |
| --------------------- | -------------------------- | ------- |
| Parametrizar SQL      | Elimina risco crítico      | Baixo   |
| Health checks         | Operação confiável no K8s  | Baixo   |
| 2 réplicas prod       | Resiliência imediata       | Baixo   |
| Connection pooling    | Maior ganho de performance | Médio   |
| Cache Redis expandido | Reduz carga nos DWs        | Médio   |
| Prometheus + Grafana  | Visibilidade runtime       | Médio   |


---



## Slide 25 — Próximos Passos

1. **Aprovar plano de ação** — priorizar itens de curto prazo (segurança)
2. **Alocar equipe** — definir FTE por papel (Cenário B recomendado)
3. **Solicitar novos servidores** — ampliar capacidade on-prem para réplicas/HPA
4. **Exportar diagramas** — usar as 7 páginas do drawio nesta apresentação
5. **Documentar runbooks** — reduzir dependência de conhecimento tácito
6. **Agendar revisão** — acompanhamento trimestral do roadmap

---



## Slide 26 — Encerramento / Perguntas

**Síntese em 3 frases:**

1. O **Vaga na Creche** atende sua função pública com arquitetura simples e custo zero de licença.
2. Existem **riscos críticos de segurança e stack EOL** que exigem ação nos próximos 3 meses.
3. Com investimento moderado em equipe e melhorias OSS, o sistema é **sustentável por 5+ anos**.

**Documentação completa disponível em:** `Documentos/`

---



# Anexo A — Mapa dos 7 Slides do [Draw.io](http://Draw.io)

Arquivo: `diagramas/drawio/ARQUITETURA - VAGA NA CRECHE.drawio`


| Página # | Nome no Draw.io                          | Slide desta apresentação | Conteúdo                                                        |
| -------- | ---------------------------------------- | ------------------------ | --------------------------------------------------------------- |
| 1        | AIRFLOW-Contexto VagasNaCreche + Airflow | **Slide 7**              | Visão integrada: FE, API, Airflow, CIEDU DW, Fila DB, `db_vaga` |
| 2        | ARFLOW- Dag Fila da Creche               | **Slide 8**              | 11 tasks em 4 fases + estatísticas + metadados DAG              |
| 3        | ARFLOW-Fluxo ETL Diário                  | **Slide 9**              | Extract → Truncate → Load → Enriquecer → API → FE + riscos      |
| 4        | SISTEMA -Diagrama de Arquitetura         | **Slide 6**              | Arquitetura completa: K8s, dados, externos, operação            |
| 5        | SISTEMA -Matriz Risco de Seguranca       | **Slide 15**             | Quadrantes de risco + controles existentes/ausentes             |
| 6        | SISTEMA - Pipeline CI/CD                 | **Slide 13**             | Jenkins, Registry, ambientes K8s, branches                      |
| 7        | SISTEMA - AVALIAÇÃO CONSOLIDADA          | **Slide 17**             | 8 dimensões + prioridades + resumo de conexões                  |


**Como exportar para o PowerPoint:**

1. Abrir o arquivo em [app.diagrams.net](https://app.diagrams.net)
2. Selecionar cada aba/página na parte inferior
3. File → Export as → **PNG** (300 DPI) ou **SVG**
4. Inserir imagem no slide correspondente

---



# Anexo B — Ordem Sugerida dos Slides (26 slides)


| #   | Título                     | Diagrama drawio |
| --- | -------------------------- | --------------- |
| 1   | Capa                       | —               |
| 2   | Agenda                     | —               |
| 3   | Resumo Executivo           | —               |
| 4   | O que é o Sistema          | —               |
| 5   | Componentes e Stack        | —               |
| 6   | Diagrama de Arquitetura    | Página 4        |
| 7   | Contexto Sistema + Airflow | Página 1        |
| 8   | DAG fila_da_creche         | Página 2        |
| 9   | Fluxo ETL Diário           | Página 3        |
| 10  | Fluxos de Negócio          | —               |
| 11  | Infraestrutura On-Premises | —               |
| 12  | Kubernetes                 | —               |
| 13  | Pipeline CI/CD             | Página 6        |
| 14  | Banco de Dados             | —               |
| 15  | Matriz de Risco            | Página 5        |
| 16  | Principais Riscos          | —               |
| 17  | Avaliação Consolidada      | Página 7        |
| 18  | Observabilidade            | —               |
| 19  | Sustentabilidade 5 Anos    | —               |
| 20  | Pontos Fortes              | —               |
| 21  | Pontos Fracos              | —               |
| 22  | Recomendações              | —               |
| 23  | Estimativa de Custos       | —               |
| 24  | Quick Wins                 | —               |
| 25  | Próximos Passos            | —               |
| 26  | Encerramento               | —               |


**Versão enxuta (20 slides):** omitir slides 10, 12, 14, 18, 24 e combinar 20+21 em 1 slide "SWOT".

---



# Anexo C — Notas do Apresentador (por slide de diagrama)

**Slide 6 — Arquitetura:** enfatizar que CIEDUDW e Fila DB são dependências externas sem fallback; se caírem, portal fica indisponível.

**Slide 7 — Contexto Airflow:** a API **não escreve** na Fila DB — apenas lê. Quem alimenta é o Airflow às 10h. Dados de vagas remanescentes vêm direto do CIEDUDW.

**Slide 8 — DAG:** pipeline maduro (~8 anos operando). Gargalo nas tasks de unidades educacionais. Full refresh é simples mas arriscado.

**Slide 9 — ETL:** durante ~1 min após truncate, consultas de fila podem retornar vazio. Catchup=True pode gerar reprocessamentos em massa.

**Slide 13 — CI/CD:** deploy leva ~5 min. Rollback = revert no GitHub. Produção exige aprovação manual.

**Slide 15 — Segurança:** portal é público por design, mas SQL injection e CORS aberto são inaceitáveis mesmo em API pública.

**Slide 17 — Avaliação:** DevOps é o ponto mais forte; Segurança e Resiliência são os mais fracos. Investimento deve focar nesses dois eixos.

---

*Documento gerado em Julho/2026 · Spassu Tecnologia · Levantamento Arquitetural SME Vagas na Creche*