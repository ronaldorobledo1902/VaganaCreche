# Análise de Infraestrutura, Sustentabilidade e Custos — SME Vagas na Creche

**Sistema:** SME Vagas na Creche (+ pipeline Airflow `fila_da_creche`)  
**Data:** Julho/2026  
**Escopo:** Infraestrutura DevOps, capacidade, sustentabilidade 5 anos, SWOT e estimativa de custos  
**Contexto:** Ambiente **on-premises**, ferramentas **open source / sem licenças pagas**

**Fontes:** Questionário arquitetural (PDF), `DOCUMENTACAO_ARQUITETURAL_SISTEMA_VagasNaCreche.md`, `Documento_Arquitetural_Fila_da_Creche_Arflow.md`, `RECOMENDACOES_PRIORITARIAS_SISTEMA_VagasNaCreche.md`

---

## 1. Infraestrutura DevOps e Capacidade de Máquinas



### 1.1 Visão geral da plataforma


| Aspecto          | Situação atual                                                              |
| ---------------- | --------------------------------------------------------------------------- |
| **Modelo**       | On-premises (Zen Orchestra/Linux + Hyper-V/Windows)                         |
| **Orquestração** | Kubernetes gerenciado via **Rancher**                                       |
| **Clusters**     | Produção (3 clusters liberados), Release (QA/homolog), WordPress (separado) |
| **Segregação**   | Prod no cluster de produção; QA/homolog no cluster de release               |
| **DEV na SME**   | Não existe mais — desenvolvimento local na máquina do dev                   |
| **Registry**     | `registry.sme.prefeitura.sp.gov.br`                                         |
| **Storage**      | NFS da Infra Física (PV/PVC, exemplo até **100 GB** para Vaga na Creche)    |
| **Proxy**        | IP VIP + **2 nós Nginx** (Infra Física) → Ingress K8s                       |




### 1.2 Kubernetes — Vaga na Creche


| Recurso                      | Configuração observada                                                                 |
| ---------------------------- | -------------------------------------------------------------------------------------- |
| **Namespace prod**           | `sme-vaganacreche`                                                                     |
| **Namespaces não-prod**      | `vaganacreche-dev`, `vaganacreche-hom`, `vaganacreche-hom2`                            |
| **Deployments**              | 2 — **FrontEnd** (Nginx + SPA React) e **API** (Nginx + Gunicorn/Django)               |
| **Pods em produção**         | **1 pod** por serviço (FE + API)                                                       |
| **Ingress**                  | Host `vaga-na-creche.sme.prefeitura.sp.gov.br` — `/` → FE; `/api`, `/admin` → API:8000 |
| **HPA / Cluster Autoscaler** | **Não habilitados** (restrição de recursos on-prem)                                    |
| **Requests/Limits**          | Não informados                                                                         |
| **Estratégia de deploy**     | Rolling Update (sem Blue/Green ou Canary)                                              |
| **Secrets**                  | K8s Secrets (sensíveis) + ConfigMaps (não sensíveis); Passbolt é possibilidade futura  |


**Capacidade do cluster de produção:** 16 nós (3 control planes + 13 workers).

**Capacidade interna da API (por pod):** Gunicorn com **8 workers**, timeout 120s.

### 1.3 Pipeline CI/CD

```
GitHub (push/webhook) → Jenkins → [Lint/Sonar*] → Docker Build → Registry SME → kubectl rollout restart → Telegram
```


| Branch          | Ambiente K8s        |
| --------------- | ------------------- |
| `develop`       | `vaganacreche-dev`  |
| `homolog`       | `vaganacreche-hom`  |
| `homolog-r2`    | `vaganacreche-hom2` |
| `master`/`main` | `sme-vaganacreche`  |


- **Deploy:** automatizado (~**5 min** em média)
- **Aprovação prod:** manual no Jenkins (hoje pelo dev sênior)
- **Rollback:** revert no GitHub + reexecução da esteira
- **Gap:** aplicações antigas **sem testes nem Quality Gate** na pipeline
- **Jenkinsfiles:** centralizados em repositório de pipelines (Infra/DevOps — Rodrigo/Bruna)



### 1.4 Banco de dados e dados


| Banco                       | Função                                   | Capacidade informada                            |
| --------------------------- | ---------------------------------------- | ----------------------------------------------- |
| **PostgreSQL aplicacional (`db_vaga`)** | Histórico de buscas (~1 GB)              | 16 vCPUs, 18 GiB RAM; crescimento ~**1 MB/mês** |
| **CIEDUDW**                 | Vagas, DREs, distritos (leitura)         | Compartilhado; sem pool na API                  |
| **Fila da Creche**          | Fila + PostGIS (porta 5433)              | `10.50.1.45`; alimentado pela DAG Airflow       |
| **Redis 3.2**               | Cache parcial (`/vaga/filtros/`, TTL 1h) | Sem HA informada                                |


**HA banco aplicacional `db_vaga` (prod):** replicação — 1 nó R/W + 1 nó read-only.  
**Backup:** dump diário; **sem PITR**.  
**Ambientes:** banco **não separado** por ambiente para Vaga na Creche.

### 1.5 Pipeline de dados (Airflow)


| Métrica                        | Valor                            |
| ------------------------------ | -------------------------------- |
| DAG                            | `fila_da_creche` — diária às 10h |
| Tasks                          | 11                               |
| Duração média                  | ~1 min 03 s                      |
| Taxa de sucesso histórica      | ~31.274 sucessos / ~156 falhas   |
| Últimas 25 runs (mai–jun/2026) | 100% sucesso                     |
| Estratégia                     | Full refresh (truncate + reload) |




### 1.6 Tráfego e utilização observada


| Métrica                 | Valor                                 |
| ----------------------- | ------------------------------------- |
| Acessos/dia (amostra)   | ~98–154 (HTTP 200)                    |
| Erros 500               | 6–8/dia (intermitentes, baixo volume) |
| Sazonalidade            | Pico no **fim do ano** (matrículas)   |
| CDN / fila / mensageria | **Não utilizados**                    |




### 1.7 Observabilidade operacional


| Ferramenta                     | Uso                                        |
| ------------------------------ | ------------------------------------------ |
| **Rancher/K8s**                | Logs de pods                               |
| **Grafana**                    | Dashboards HTTP (200/400/500), até 30 dias |
| **Telegram**                   | Alertas de build/deploy (Jenkins)          |
| **SonarQube**                  | Branch homolog (estático)                  |
| **Prometheus / APM / Tracing** | **Ausentes**                               |


---



## 2. Análise de Sustentabilidade — Próximos 5 Anos (2026–2031)



### 2.1 Sistema Vaga na Creche (aplicação)


| Dimensão                | Hoje                                                           | Projeção 5 anos                       | Risco       |
| ----------------------- | -------------------------------------------------------------- | ------------------------------------- | ----------- |
| **Stack**               | Python 3.7, Django 2.2, Node 12, React 16, Redis 3.2 — **EOL** | Sem patches oficiais; CVEs acumuladas | **Crítico** |
| **Segurança**           | SQL injection, CORS aberto, sem auth/rate limit                | Superfície de ataque crescente        | **Crítico** |
| **Performance**         | Connect-per-query; cache mínimo                                | Degradação em picos sazonais          | **Alto**    |
| **Testes**              | API: 1 teste; FE: zero                                         | Regressões não detectadas             | **Alto**    |
| **Observabilidade**     | Básica (Grafana HTTP)                                          | Incidentes difíceis de diagnosticar   | **Médio**   |
| **Dados aplicacionais** | ~~1 GB (+~~60 MB em 5 anos)                                    | Volume irrelevante                    | **Baixo**   |
| **Funcionalidade**      | Atende consulta pública                                        | Requisitos estáveis                   | **Baixo**   |


**Conclusão aplicação:** sustentável funcionalmente por volume de dados e tráfego atual, porém **insustentável tecnicamente** sem modernização da stack, correções de segurança e observabilidade até ~2027–2028.

### 2.2 Dados de infraestrutura


| Dimensão                | Hoje                                                             | Projeção 5 anos                                     | Risco     |
| ----------------------- | ---------------------------------------------------------------- | --------------------------------------------------- | --------- |
| **Capacidade compute**  | 16 nós prod; 1 pod/serviço; sem autoscale                        | Picos exigem intervenção manual ou novos servidores | **Alto**  |
| **Resiliência app**     | 1 réplica FE + 1 API                                             | SPOF por serviço                                    | **Alto**  |
| **Storage NFS**         | Dependência Infra Física                                         | Ponto único se não redundante                       | **Médio** |
| **Backup/DR**           | Dump diário; sem PITR                                            | RPO ~24h; RTO não definido                          | **Médio** |
| **Ferramentas**         | Rancher, Jenkins, K8s, Grafana, PostgreSQL, Redis, Airflow — OSS | Sem custo de licença; exige manutenção humana       | **Médio** |
| **Pipeline dados**      | Full refresh diário (~1 min)                                     | Volume estável                                      | **Médio** |
| **Equipe/conhecimento** | Sistema "arqueológico", pouca manutenção                         | Perda de conhecimento se não documentar             | **Alto**  |


**Conclusão infra:** plataforma OSS adequada ao modelo on-prem sem licenças, mas **capacidade e resiliência limitadas**. Sustentável para tráfego atual (~150 acessos/dia); **insustentável em picos** sem novos servidores, réplicas e autoscale controlado.

### 2.3 Roadmap mínimo para sustentabilidade (5 anos)


| Horizonte             | Ações essenciais                                                                       |
| --------------------- | -------------------------------------------------------------------------------------- |
| **Ano 1 (2026–27)**   | Segurança (SQL parametrizado, CORS, health checks), pooling, logging, 2+ réplicas prod |
| **Ano 2 (2027–28)**   | Upgrade stack (Python 3.12+, Django 4.2+, React 18+), cache expandido, Sentry, testes  |
| **Ano 3 (2028–29)**   | HPA controlado, novos servidores, PITR backup, alertas runtime                         |
| **Ano 4–5 (2029–31)** | Carga incremental Airflow, DR documentado, GA4, documentação operacional (runbooks)    |


---



## 3. Pontos Fortes, Fracos e Sugestões de Melhoria

> Contexto: on-premises, stack **100% open source**, sem serviços cloud pagos.



### 3.1 Pontos fortes


| #   | Ponto                           | Detalhe                                           |
| --- | ------------------------------- | ------------------------------------------------- |
| 1   | **CI/CD funcional**             | Jenkins + Docker + K8s + multi-ambiente           |
| 2   | **Custo de licenciamento zero** | Rancher, K8s, PostgreSQL, Redis, Grafana, Airflow |
| 3   | **Arquitetura simples**         | 2 serviços, fácil de entender e operar            |
| 4   | **Pipeline de dados estável**   | DAG ~99,5% sucesso histórico; 100% recente        |
| 5   | **Proxy redundante**            | VIP + 2 Nginx antes do cluster                    |
| 6   | **Control planes redundantes**  | 3 CP no cluster de produção                       |
| 7   | **Banco HA (prod)**             | Réplica read-only                                 |
| 8   | **Tráfego moderado**            | ~100–150 acessos/dia — pressão baixa sobre infra  |
| 9   | **Crescimento de dados mínimo** | ~1 MB/mês no banco aplicacional (`db_vaga`)         |




### 3.2 Pontos fracos


| #   | Ponto                             | Impacto                                       |
| --- | --------------------------------- | --------------------------------------------- |
| 1   | **Stack EOL**                     | Vulnerabilidades sem patch                    |
| 2   | **1 pod/serviço, sem HPA**        | Sem resiliência nem elasticidade              |
| 3   | **Restrição de recursos on-prem** | Impede crescimento automático                 |
| 4   | **SQL injection + CORS aberto**   | Risco crítico de segurança                    |
| 5   | **Connect-per-query**             | Latência e esgotamento de conexões            |
| 6   | **Cache insuficiente**            | Só `/vaga/filtros/` cacheado                  |
| 7   | **Observabilidade fraca**         | Sem APM, tracing, alertas runtime             |
| 8   | **Pipeline legada**               | Sem testes/Quality Gate                       |
| 9   | **Rollback manual**               | Revert Git + redeploy (~5 min)                |
| 10  | **Conhecimento escasso**          | Sistema pouco mantido, "arqueológico"         |
| 11  | **Erros 500 intermitentes**       | Tratamento de erro frágil                     |
| 12  | **Backup sem PITR**               | RPO de até 24h                                |
| 13  | **Full refresh Airflow**          | Janela de indisponibilidade parcial dos dados |
| 14  | **Dependência NFS Infra Física**  | Possível SPOF                                 |




### 3.3 Sugestões de melhoria (priorizadas, sem custo de licença)



#### Curto prazo (0–3 meses) — custo: esforço da equipe

1. Parametrizar SQL (eliminar injection)
2. Health checks `/health/live` e `/health/ready`
3. Restringir CORS às origens oficiais
4. Tratamento de erro consistente (HTTP 503)
5. Validar entrada (lat/lon, filtros)
6. Corrigir race condition e `.catch()` vazios no FE
7. Configurar **2 réplicas** FE e API em prod (Rolling Update já existe)



#### Médio prazo (3–12 meses)

1. Connection pooling (`psycopg2.pool` ou **PgBouncer** — OSS)
2. Expandir cache Redis (TTL 5–15 min nos endpoints críticos)
3. Logging JSON + **Loki** ou ELK (OSS)
4. Métricas com **Prometheus + Grafana** (já há Grafana)
5. Rate limiting (DRF throttling)
6. **Sentry self-hosted** ou alternativa OSS para error tracking
7. Requests/limits nos pods + documentar capacidade
8. Alertas Grafana para 5xx e latência



#### Longo prazo (1–3 anos)

1. Upgrade stack completo (Python, Django, Node, React)
2. HPA com limites conservadores após novos servidores
3. Carga incremental na DAG Airflow
4. Runbooks e documentação operacional
5. Quality Gate e testes na pipeline Jenkins
6. Integração Passbolt (OSS) para secrets

---



## 4. Estimativa de Custos



### 4.1 Premissas


| Premissa       | Valor                                                         |
| -------------- | ------------------------------------------------------------- |
| Infraestrutura | **R$ 0** de licença (hardware já existente na SME)            |
| Ferramentas    | 100% open source                                              |
| Equipe         | Dedicação parcial estimada em **40% FTE** médio por papel*    |
| Salários       | Referência mercado TI Brasil (CLT, jul/2026) — **estimativa** |
| Encargos       | ~80% sobre salário CLT (INSS, FGTS, 13º, férias, benefícios)  |


*Sistema de baixo tráfego e manutenção esporádica; percentual pode variar de 20% (steady-state) a 80% (projeto de modernização).*

### 4.2 Composição da equipe


| Papel            | Qtd   | Salário base mensal (estimado) | FTE estimado | Custo mensal (com encargos)* |
| ---------------- | ----- | ------------------------------ | ------------ | ---------------------------- |
| Arquiteto Sênior | 1     | R$ 28.000                      | 30%          | R$ 15.120                    |
| Tech Lead        | 1     | R$ 22.000                      | 40%          | R$ 15.840                    |
| DevOps           | 3     | R$ 15.000                      | 35%          | R$ 28.350                    |
| DBA              | 1     | R$ 18.000                      | 25%          | R$ 8.100                     |
| Desenvolvedor    | 1     | R$ 12.000                      | 50%          | R$ 10.800                    |
| Product Owner    | 1     | R$ 14.000                      | 20%          | R$ 5.040                     |
| **Total equipe** | **8** | —                              | —            | **R$ 83.250/mês**            |


*Fórmula: salário × FTE × 1,8 (encargos).*

### 4.3 Cenários anuais


| Cenário                                   | Descrição                             | Custo anual equipe | Infra/licenças | **Total anual**   |
| ----------------------------------------- | ------------------------------------- | ------------------ | -------------- | ----------------- |
| **A — Operação mínima**                   | 20% FTE médio; manutenção corretiva   | ~R$ 370.000        | R$ 0           | **~R$ 370.000**   |
| **B — Operação + evolução (recomendado)** | 40% FTE; segurança + observabilidade  | **~R$ 999.000**    | R$ 0           | **~R$ 999.000**   |
| **C — Modernização intensiva (ano 1–2)**  | 70% FTE; upgrade stack + testes + HPA | ~R$ 1.750.000      | R$ 0†          | **~R$ 1.750.000** |


†*Hardware adicional (novos servidores) citado no levantamento seria CAPEX da Infra Física, fora do escopo de licenças.*

### 4.4 Detalhamento por fase (Cenário B — 5 anos)


| Ano                          | Foco principal                                       | Custo estimado            |
| ---------------------------- | ---------------------------------------------------- | ------------------------- |
| **2026**                     | Segurança, health checks, pooling, 2 réplicas        | R$ 1,2 M                  |
| **2027**                     | Observabilidade, cache, testes, início upgrade stack | R$ 1,0 M                  |
| **2028**                     | Conclusão upgrade, HPA, PITR                         | R$ 900.000                |
| **2029**                     | Estabilização, runbooks, DR                          | R$ 700.000                |
| **2030–31**                  | Operação steady-state (~20% FTE)                     | R$ 370–500.000/ano        |
| **Total 5 anos (Cenário B)** | —                                                    | **~R$ 4,2 – 4,5 milhões** |




### 4.5 Custos evitados (benefício do modelo OSS on-prem)


| Item comercial         | Alternativa OSS atual       | Economia estimada/ano  |
| ---------------------- | --------------------------- | ---------------------- |
| AKS/EKS managed        | K8s + Rancher on-prem       | R$ 60–180.000          |
| Datadog/New Relic      | Prometheus + Grafana + Loki | R$ 50–120.000          |
| Redis Enterprise       | Redis OSS                   | R$ 30–80.000           |
| Sentry SaaS            | Sentry self-hosted          | R$ 15–40.000           |
| GitHub Actions minutes | Jenkins on-prem             | R$ 10–30.000           |
| **Total evitado**      | —                           | **R$ 165–450.000/ano** |




### 4.6 Riscos financeiros ocultos


| Risco                                  | Impacto potencial                                  |
| -------------------------------------- | -------------------------------------------------- |
| Incidente de segurança (SQL injection) | Indisponibilidade + horas extras + reputação       |
| Perda de dados (sem PITR)              | Retrabalho manual; possível perda de telemetria    |
| Pico sazonal sem autoscale             | Degradação; necessidade de intervenção emergencial |
| Turnover por stack legada              | Custo de recontratação e curva de aprendizado      |
| Hardware envelhecido                   | CAPEX não contabilizado acima                      |


---



## 5. Síntese Executiva


| Dimensão                    | Avaliação             | Comentário                                                         |
| --------------------------- | --------------------- | ------------------------------------------------------------------ |
| **Infra DevOps**            | Adequada (7/10)       | CI/CD maduro; falta autoscale, réplicas e observabilidade runtime  |
| **Capacidade atual**        | Suficiente para hoje  | ~150 acessos/dia; 1 pod/serviço aguenta, mas sem margem para picos |
| **Sustentabilidade 5 anos** | Condicional           | Viável com modernização programada; inviável se mantido "as-is"    |
| **Custo operacional**       | Baixo em licenças     | ~R$ 370K–1M/ano em pessoas, dependendo do nível de evolução        |
| **Maior risco**             | Segurança + stack EOL | Ação imediata recomendada                                          |
| **Maior oportunidade**      | Quick wins OSS        | Pooling, cache, health checks, Prometheus — alto ROI, zero licença |


---



## 6. Referências

- [DOCUMENTACAO_ARQUITETURAL_SISTEMA_VagasNaCreche.md](./DOCUMENTACAO_ARQUITETURAL_SISTEMA_VagasNaCreche.md)
- [RECOMENDACOES_PRIORITARIAS_SISTEMA_VagasNaCreche.md](./RECOMENDACOES_PRIORITARIAS_SISTEMA_VagasNaCreche.md)
- [Documento_Arquitetural_Fila_da_Creche_Arflow.md](./Documento_Arquitetural_Fila_da_Creche_Arflow.md)
- Perguntas para levantamento arquitetural.pdf

---

*Documento gerado com base no levantamento arquitetural de Julho/2026.*