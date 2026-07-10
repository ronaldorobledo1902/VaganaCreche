# Glossário e Explicações Resumidas — SME Vagas na Creche

**Data:** Julho/2026  
**Público-alvo:** Stakeholders técnicos e de negócio  
**Fontes:** Documentação arquitetural, questionário de levantamento e análise de infraestrutura

---

## Parte 1 — Explicações Resumidas (FAQ)

Perguntas frequentes sobre termos que aparecem nas documentações, com respostas objetivas para apresentações e reuniões.

---

### O que é plataforma OSS?

**OSS = Open Source Software** (software de código aberto).

**Plataforma OSS** significa que a infraestrutura e as ferramentas do sistema são montadas com software **gratuito, sem licença paga** — por exemplo: Kubernetes, PostgreSQL, Redis, Grafana, Jenkins e Airflow.

> **Frase para apresentação:** *"Usamos uma plataforma 100% open source, sem custo de licenciamento de software."*

---

### O que é PV / PVC?

No **Kubernetes**:

| Termo | Significado |
|-------|-------------|
| **PV (Persistent Volume)** | "Disco" reservado no storage (ex.: NFS) |
| **PVC (Persistent Volume Claim)** | Pedido da aplicação para usar esse disco |

> **Frase para apresentação:** *"A aplicação solicita espaço persistente via PVC, e o cluster entrega via PV conectado ao storage NFS."*

---

### Como explicar: IP VIP + 2 nós Nginx → Ingress K8s?

Antes de chegar ao Kubernetes, o tráfego passa por uma camada de rede da Infra Física:

```
Internet → IP VIP (endereço fixo) → 2 servidores Nginx (redundantes) → Ingress do Kubernetes → Pods (FrontEnd ou API)
```

- **VIP (Virtual IP):** um único endereço IP que aponta para os dois Nginx; se um cair, o outro atende.
- **Ingress K8s:** roteador interno do cluster que direciona `/` para o front-end e `/api` para a API.

> **Frase para apresentação:** *"O tráfego entra por um IP fixo, passa por dois Nginx redundantes e só então chega ao Kubernetes, que distribui para front-end ou API."*

---

### Como explicar: 16 nós (3 control planes + 13 workers)?

O cluster Kubernetes de produção tem **16 máquinas virtuais (nós)**:

| Tipo | Qtd | Função |
|------|-----|--------|
| **Control plane** | 3 | "Cérebro" do cluster — gerencia pods, rede e configurações |
| **Workers** | 13 | Executam as aplicações (pods do Vaga na Creche e demais sistemas) |

> **Frase para apresentação:** *"São 16 servidores virtuais: 3 controlam o Kubernetes e 13 rodam as aplicações."*

---

### O que quer dizer "Sem HA informada"?

**HA = High Availability** (alta disponibilidade) — réplicas, failover automático ou redundância.

**"Sem HA informada"** significa que, no levantamento arquitetural, **não ficou documentado** se aquele componente (ex.: Redis) possui redundância. Não confirma que não existe — apenas que **não foi verificado ou informado**.

---

### Storage NFS — "ponto único se não redundante"

**NFS (Network File System)** = armazenamento de arquivos compartilhado na rede, gerenciado pela Infra Física.

Os dados persistentes da aplicação (PV/PVC) ficam nesse storage. Se o NFS **não tiver cópia ou backup automático**, vira um **ponto único de falha (SPOF)**: se o storage cair, tudo que depende dele para de funcionar.

> **Frase para apresentação:** *"Os arquivos persistentes ficam num storage NFS compartilhado. Se ele não for redundante, uma falha no storage derruba todos os serviços que dependem dele."*

---

### O que é RPO ~24h e RTO não definido?

| Sigla | Nome | Significado no contexto |
|-------|------|-------------------------|
| **RPO** | Recovery Point Objective | Quanto dado se **aceita perder** em um desastre |
| **RTO** | Recovery Time Objective | Quanto tempo leva para **voltar ao ar** após um desastre |

- **RPO ~24h:** backup é dump diário → pode perder até **1 dia** de dados.
- **RTO não definido:** não há meta acordada/documentada de tempo de recuperação.

> **Frase para apresentação:** *"Em caso de desastre, podemos perder até 24 horas de dados, e o tempo para restaurar o sistema ainda não está formalmente definido."*

---

### Carga incremental (Airflow)

Hoje a DAG `fila_da_creche` faz **full refresh** — apaga e recarrega todas as tabelas diariamente.

**Carga incremental** = atualizar **somente o que mudou** desde a última execução. É mais rápido, consome menos recursos e reduz risco de indisponibilidade parcial dos dados.

---

### DR documentado

**DR = Disaster Recovery** (recuperação de desastres).

**DR documentado** = plano escrito com passos, responsáveis e tempos para restaurar o sistema após uma falha grave (ex.: perda de servidor, corrupção de banco).

---

### GA4

**GA4 = Google Analytics 4** — versão atual do Google Analytics.

O front-end usa **Universal Analytics (UA)**, que foi **descontinuado**. Migrar para GA4 permite medir acessos, rotas e uso real do portal.

---

### Runbooks (documentação operacional)

**Runbooks** = manuais operacionais do tipo *"se acontecer X, faça Y"*.

Exemplos: como reiniciar um pod, como reprocessar a DAG, como investigar erro 500, quem acionar em incidente.

---

## Parte 2 — Glossário Completo

Termos técnicos, siglas e abreviações utilizados nas documentações do projeto SME Vagas na Creche.

> Ordenação alfabética. Siglas aparecem primeiro quando aplicável.

---

### A

| Termo | Significado |
|-------|-------------|
| **Airflow** | Plataforma open source (Apache) para orquestrar pipelines de dados (ETL). Executa DAGs agendadas. |
| **AKS** | Azure Kubernetes Service — serviço gerenciado de Kubernetes na Azure (não utilizado; referência comparativa de custo). |
| **AllowAny** | Permissão DRF que libera acesso sem autenticação a um endpoint. |
| **APM** | Application Performance Monitoring — monitoramento de performance da aplicação (latência, erros por endpoint). |
| **API** | Application Programming Interface — interface de programação; no contexto, a API REST Django do Vaga na Creche. |
| **API Key** | Chave única usada para autenticação entre serviços (mencionada no levantamento). |
| **Autoscale** | Escalonamento automático de pods ou nós conforme demanda (HPA / Cluster Autoscaler). Atualmente **desabilitado**. |

---

### B

| Termo | Significado |
|-------|-------------|
| **Backup / Dump** | Cópia de segurança do banco. No Vaga na Creche: dump diário do PostgreSQL aplicacional (`db_vaga`). |
| **Blue/Green** | Estratégia de deploy com dois ambientes idênticos; troca instantânea entre versões. **Não utilizada** — usa Rolling Update. |
| **Branch** | Ramo do repositório Git (`develop`, `homolog`, `master`) associado a um ambiente K8s. |

---

### C

| Termo | Significado |
|-------|-------------|
| **Canary** | Deploy gradual para uma fração dos usuários antes de liberar para todos. **Não utilizado**. |
| **CAPEX** | Capital Expenditure — investimento em hardware/infraestrutura (ex.: novos servidores). |
| **Catchup** | Configuração Airflow para reprocessar execuções passadas que foram perdidas. |
| **CDC** | Change Data Capture — captura contínua de alterações no banco para replicação incremental. Recomendação de longo prazo. |
| **CDN** | Content Delivery Network — rede de distribuição de conteúdo estático. **Não utilizada**. |
| **CI/CD** | Continuous Integration / Continuous Delivery — integração e entrega contínuas via Jenkins. |
| **CIEDUDW / CIEDU_DW** | Data Warehouse educacional da SME com dados de vagas, unidades escolares, DREs e distritos. |
| **CLT** | Consolidação das Leis do Trabalho — regime de contratação usado nas estimativas de custo. |
| **ConfigMap** | Objeto Kubernetes para variáveis de ambiente **não sensíveis**. |
| **Connect-per-query** | Padrão ineficiente em que cada query SQL abre e fecha uma conexão TCP nova. Usado nos bancos CIEDUDW e Fila. |
| **Connection pooling** | Reutilização de conexões de banco já abertas, reduzindo latência e consumo de recursos. |
| **Control plane (CP)** | Nós do Kubernetes que gerenciam o cluster (API server, scheduler, etcd). |
| **CORS** | Cross-Origin Resource Sharing — controle de quais domínios podem acessar a API. Atualmente aberto (`ALLOW_ALL`). |
| **CP** | Abreviação de Control Plane. |
| **CQRS** | Command Query Responsibility Segregation — padrão arquitetural (não utilizado). |
| **CRA** | Create React App — ferramenta de scaffolding do front-end React (versão 3). |
| **CSRF** | Cross-Site Request Forgery — proteção contra requisições falsas; middleware Django ativo. |
| **CVE** | Common Vulnerabilities and Exposures — catálogo de vulnerabilidades de segurança conhecidas. |

---

### D

| Termo | Significado |
|-------|-------------|
| **DAG** | Directed Acyclic Graph — fluxo de tarefas no Airflow. Ex.: `fila_da_creche` (11 tasks, execução diária às 10h). |
| **Data Warehouse (DW)** | Repositório analítico com dados consolidados. No projeto: CIEDUDW. |
| **db_vaga / Banco aplicacional** | Banco PostgreSQL próprio da aplicação Vagas na Creche (`POSTGRES_DB=db_vaga`). Armazena telemetria de buscas na tabela `pesq_historico_busca_endereco`. |
| **DBA** | Database Administrator — profissional responsável por bancos de dados. |
| **Deployment** | Recurso Kubernetes que define e gerencia pods de uma aplicação (FE e API). |
| **DevOps** | Prática/equipe que integra desenvolvimento e operação (CI/CD, K8s, Jenkins). |
| **DR** | Disaster Recovery — plano e capacidade de recuperação após desastre. |
| **DRF** | Django REST Framework — biblioteca Python para construir APIs REST. |
| **DRE** | Diretoria Regional de Educação — unidade administrativa da SME usada como filtro no portal. |

---

### E

| Termo | Significado |
|-------|-------------|
| **EKS** | Elastic Kubernetes Service — Kubernetes gerenciado na AWS (referência comparativa). |
| **ELK** | Elasticsearch + Logstash + Kibana — stack open source para centralização de logs. |
| **EOL** | End of Life — versão de software sem suporte oficial de segurança (ex.: Python 3.7, Django 2.2). |
| **ETL** | Extract, Transform, Load — processo de extração, transformação e carga de dados (realizado pelo Airflow). |
| **EOL / RAW** | Camadas de dados brutos na origem do pipeline (mencionadas na DAG). |

---

### F

| Termo | Significado |
|-------|-------------|
| **FE** | FrontEnd — aplicação React servida por Nginx. |
| **FilaDB / Fila da Creche DB** | Banco PostgreSQL + PostGIS com dados de fila de espera, alimentado pela DAG Airflow. |
| **FTE** | Full-Time Equivalent — equivalente de tempo integral; mede dedicação parcial da equipe (ex.: 40% FTE). |
| **Full refresh** | Estratégia de carga que apaga (truncate) e recarrega todas as tabelas. Usada na DAG atual. |

---

### G

| Termo | Significado |
|-------|-------------|
| **GA / UA** | Google Analytics / Universal Analytics — ferramenta de métricas web. UA está **descontinuado**. |
| **GA4** | Google Analytics 4 — versão atual do Analytics; recomendada como substituta do UA. |
| **GiB** | Gibibyte — unidade de memória (ex.: 18 GiB RAM no servidor de banco). |
| **Grafana** | Plataforma open source de dashboards e visualização de métricas (HTTP 200/400/500). |
| **GraphQL** | Linguagem de consulta para APIs (não utilizada no sistema). |
| **gRPC** | Framework RPC de alta performance (não utilizado). |
| **Gunicorn** | Servidor WSGI Python que executa a API Django (8 workers, timeout 120s). |

---

### H

| Termo | Significado |
|-------|-------------|
| **HA** | High Availability — alta disponibilidade via redundância, réplicas ou failover. |
| **Health check** | Endpoint ou probe que verifica se a aplicação e suas dependências estão saudáveis (`/health/live`, `/health/ready`). |
| **Homolog / Hom** | Ambiente de homologação (testes pré-produção). Namespace: `vaganacreche-hom`. |
| **HPA** | Horizontal Pod Autoscaler — escala automática de pods conforme CPU/memória. **Não habilitado**. |
| **HTTP / HTTPS** | Protocolos de comunicação web (REST, mapas, Analytics). |
| **HSTS** | HTTP Strict Transport Security — header que força HTTPS. Configurado com valor baixo (60s). |
| **Hyper-V** | Hypervisor Microsoft para virtualização Windows (parte da infra on-premises). |

---

### I

| Termo | Significado |
|-------|-------------|
| **Ingress** | Recurso Kubernetes que roteia tráfego HTTP externo para serviços internos (FE e API). |
| **Ingress Controller** | Componente que implementa o Ingress no cluster (tipo específico não informado). |

---

### J

| Termo | Significado |
|-------|-------------|
| **Jenkins** | Servidor de automação CI/CD que executa pipelines de build, teste e deploy. |
| **Jenkinsfile** | Arquivo que define o pipeline CI/CD (centralizado em repositório de pipelines). |
| **JWT** | JSON Web Token — padrão de autenticação (não implementado na API). |

---

### K

| Termo | Significado |
|-------|-------------|
| **K8s** | Abreviação de Kubernetes. |
| **Keycloak** | Plataforma open source de identidade e acesso (IAM). **Não utilizada**. |
| **Kubernetes (K8s)** | Plataforma open source de orquestração de containers. |

---

### L

| Termo | Significado |
|-------|-------------|
| **Leaflet** | Biblioteca JavaScript open source para mapas interativos (usa tiles do OpenStreetMap). |
| **Liveness probe** | Verificação K8s se o pod está vivo; reinicia se falhar. |
| **Loki** | Sistema open source de agregação de logs (alternativa ao ELK). |

---

### M

| Termo | Significado |
|-------|-------------|
| **Migration** | Script que altera o schema do banco de dados (Django migrations). |

---

### N

| Termo | Significado |
|-------|-------------|
| **Namespace** | Divisão lógica dentro do Kubernetes (ex.: `sme-vaganacreche`). |
| **NFS** | Network File System — storage compartilhado em rede usado para volumes persistentes. |
| **Nginx** | Servidor web/reverse proxy usado no FE, na API e na camada de Infra Física (2 nós + VIP). |
| **Node (nó)** | Máquina virtual ou física que compõe o cluster Kubernetes. |
| **Node Pool** | Grupo de nós com características similares (não detalhado no levantamento). |

---

### O

| Termo | Significado |
|-------|-------------|
| **OAuth2** | Protocolo de autorização (não implementado). |
| **OIDC** | OpenID Connect — camada de identidade sobre OAuth2 (não implementado). |
| **On-premises / On-prem** | Infraestrutura instalada nos datacenters da organização, não em cloud pública. |
| **OpenStreetMap (OSM)** | Mapa open source; fornece tiles para o Leaflet. |
| **OpenTelemetry** | Padrão open source para observabilidade (tracing, métricas). **Não utilizado**. |
| **ORM** | Object-Relational Mapping — camada Django que mapeia objetos Python para tabelas SQL. |
| **OSS** | Open Source Software — software de código aberto, sem licença paga. |

---

### P

| Termo | Significado |
|-------|-------------|
| **Passbolt** | Gerenciador open source de senhas/secrets (possibilidade futura). |
| **Pelias** | API open source de geocodificação de endereços (`/v1/search`). |
| **PgBouncer** | Pooler open source de conexões PostgreSQL. |
| **pgBackRest** | Ferramenta open source de backup PostgreSQL com suporte a PITR. |
| **Pickle** | Formato de serialização Python usado no cache Redis (risco de segurança se Redis for comprometido). |
| **PITR** | Point-in-Time Recovery — restauração do banco para um momento exato no tempo. **Não disponível** (apenas dump diário). |
| **PO** | Product Owner — responsável pelo produto e prioridades de negócio. |
| **Pod** | Menor unidade executável no Kubernetes (contém um ou mais containers). |
| **PostgreSQL** | SGBD relacional open source usado em todos os bancos do sistema. |
| **PostGIS** | Extensão geoespacial do PostgreSQL (consultas por raio com `ST_DWithin`). |
| **Prod** | Ambiente de produção. Namespace: `sme-vaganacreche`. |
| **Prometheus** | Sistema open source de coleta de métricas (não implementado; Grafana já existe). |
| **Proxy reverso** | Servidor que recebe requisições externas e as encaminha para serviços internos (Nginx). |
| **psycopg2** | Driver Python para conexão com PostgreSQL. |
| **PV** | Persistent Volume — volume de storage provisionado no Kubernetes. |
| **PVC** | Persistent Volume Claim — solicitação de storage persistente por uma aplicação. |
| **PWA** | Progressive Web App — aplicação web instalável. Service Worker **desabilitado** no FE. |

---

### Q

| Termo | Significado |
|-------|-------------|
| **QA** | Quality Assurance — ambiente/cluster de testes e homologação. |
| **Quality Gate** | Critério de qualidade no pipeline (ex.: SonarQube) que bloqueia deploy se não atingido. **Ausente** em apps legadas. |

---

### R

| Termo | Significado |
|-------|-------------|
| **Rancher** | Plataforma open source de gerenciamento de clusters Kubernetes. |
| **Rate limiting / Throttling** | Limite de requisições por IP/período para evitar abuso (não implementado). |
| **React** | Biblioteca JavaScript para interfaces (versão 16 no FE). |
| **React Query / SWR** | Bibliotecas de cache de API no cliente (não utilizadas). |
| **Readiness probe** | Verificação K8s se o pod está pronto para receber tráfego. |
| **Redis** | Banco in-memory open source usado como cache (versão 3.2 — EOL). |
| **Registry** | Repositório de imagens Docker (`registry.sme.prefeitura.sp.gov.br`). |
| **REST** | Representational State Transfer — estilo de API HTTP usado pelo sistema. |
| **Rolling Update** | Estratégia de deploy que substitui pods gradualmente, sem downtime total. |
| **RPO** | Recovery Point Objective — quantidade máxima de dados que se aceita perder (atual: ~24h). |
| **RTO** | Recovery Time Objective — tempo máximo para restaurar o serviço (não definido). |
| **Runbook** | Manual operacional com procedimentos para incidentes e tarefas recorrentes. |
| **R/W** | Read/Write — nó de banco com permissão de leitura e escrita. |

---

### S

| Termo | Significado |
|-------|-------------|
| **Secret (K8s)** | Objeto Kubernetes para armazenar dados sensíveis (senhas, tokens). |
| **Sentry** | Plataforma de rastreamento de erros (SaaS ou self-hosted). **Não implementado**. |
| **Service** | Recurso Kubernetes que expõe pods com IP/DNS estável dentro do cluster. |
| **Service Mesh** | Camada de comunicação entre serviços (Istio, Linkerd). **Não utilizada**. |
| **SLA** | Service Level Agreement — acordo formal de nível de serviço. **Não informado**. |
| **SLO** | Service Level Objective — meta interna de disponibilidade/performance. **Não informado**. |
| **SME** | Secretaria Municipal de Educação de São Paulo. |
| **SonarQube** | Ferramenta de análise estática de código (executada na branch homolog). |
| **SPA** | Single Page Application — aplicação web de página única (React). |
| **SPOF** | Single Point of Failure — componente único cuja falha derruba o sistema inteiro. |
| **SQL Injection** | Ataque que injeta código SQL malicioso via parâmetros não validados. **Risco crítico identificado**. |
| **ST_DWithin** | Função PostGIS que verifica se geometrias estão dentro de um raio geográfico. |
| **Swagger / drf-yasg** | Documentação interativa da API REST (exposta publicamente na raiz `/`). |
| **SWOT** | Strengths, Weaknesses, Opportunities, Threats — análise de pontos fortes e fracos. |

---

### T

| Termo | Significado |
|-------|-------------|
| **Task (Airflow)** | Unidade de trabalho individual dentro de uma DAG (ex.: `copy_solicitacao_matricula_grade_dw`). |
| **TCP** | Transmission Control Protocol — protocolo de rede usado nas conexões com bancos. |
| **Tech Lead** | Líder técnico da equipe de desenvolvimento. |
| **Telegram** | Mensageiro usado para notificações de build/deploy do Jenkins. |
| **TLS** | Transport Layer Security — criptografia HTTPS (certificados não detalhados no levantamento). |
| **Truncate** | Comando SQL que apaga todos os registros de uma tabela (usado no full refresh da DAG). |
| **TTL** | Time To Live — tempo de validade de um dado em cache (ex.: 1 hora no Redis para filtros). |

---

### V

| Termo | Significado |
|-------|-------------|
| **VIP** | Virtual IP — endereço IP flutuante que aponta para servidores redundantes (2 Nginx). |
| **vCPU** | Virtual CPU — processador virtual (ex.: 16 vCPUs no servidor de banco). |

---

### W

| Termo | Significado |
|-------|-------------|
| **WAL-G** | Ferramenta open source de backup PostgreSQL baseada em WAL (alternativa ao pgBackRest). |
| **Webhook** | Callback HTTP que dispara o Jenkins automaticamente após push no GitHub. |
| **WebSocket** | Protocolo de comunicação bidirecional em tempo real (não utilizado). |
| **Worker (nó)** | Nó Kubernetes que executa pods de aplicação (13 workers no cluster de produção). |
| **WSGI** | Web Server Gateway Interface — padrão Python entre Gunicorn e Django. |

---

### Z

| Termo | Significado |
|-------|-------------|
| **Zen Orchestra** | Plataforma de virtualização Linux usada na infra on-premises da SME. |
| **zlib** | Biblioteca de compressão usada na serialização do cache Redis. |
| **Zustand** | Biblioteca leve de gerenciamento de estado React (sugerida como alternativa ao pubsub-js). |

---

## Parte 3 — Referências

- [DOCUMENTACAO_ARQUITETURAL_SISTEMA_VagasNaCreche.md](./DOCUMENTACAO_ARQUITETURAL_SISTEMA_VagasNaCreche.md)
- [ANALISE_INFRA_SUSTENTABILIDADE_CUSTOS_VagasNaCreche.md](./ANALISE_INFRA_SUSTENTABILIDADE_CUSTOS_VagasNaCreche.md)
- [RECOMENDACOES_PRIORITARIAS_SISTEMA_VagasNaCreche.md](./RECOMENDACOES_PRIORITARIAS_SISTEMA_VagasNaCreche.md)
- [Documento_Arquitetural_Fila_da_Creche_Arflow.md](./Documento_Arquitetural_Fila_da_Creche_Arflow.md)
- Perguntas para levantamento arquitetural.pdf

---

*Documento gerado em Julho/2026 para apoio a apresentações e onboarding técnico.*
