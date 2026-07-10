# Recomendações Prioritárias — SME Vagas na Creche

**Sistema:** SME Vagas na Creche  
**Documento base:** [DOCUMENTACAO_ARQUITETURAL_SME_VagasNaCreche.md](./DOCUMENTACAO_ARQUITETURAL_SME_VagasNaCreche.md)  
**Data:** Julho/2026  
**Versão:** 1.0  
**Público-alvo:** Equipe técnica, gestão de produto e stakeholders de operação

---

## 1. Contexto

Este documento consolida as **ações prioritárias** identificadas na análise arquitetural do sistema SME Vagas na Creche, com um breve resumo do **motivo** de cada recomendação. Inclui também a análise de **degradação de performance** relacionada ao padrão de conexão com os bancos externos (CIEDUDW e Fila da Creche).

---



## 2. Análise de Degradação de Performance



### 2.1 — Situação atual

A API utiliza **três modelos distintos** de acesso a dados:


| Banco                               | Padrão de conexão                 | Pool de conexões?                                      |
| ----------------------------------- | --------------------------------- | ------------------------------------------------------ |
| PostgreSQL aplicacional (`db_vaga`) | Django ORM                        | Não (`CONN_MAX_AGE` ausente — fecha após cada request) |
| CIEDUDW (Data Warehouse)            | `psycopg2.connect()` a cada query | **Não**                                                |
| Fila da Creche                      | `psycopg2.connect()` a cada query | **Não**                                                |


Nas classes `CIEDUDWConnection` e `FilaDBConnection`, cada chamada ao método `querie()` executa o ciclo completo: **abrir conexão TCP → autenticar → executar SQL → fechar conexão**. Esse padrão é conhecido como **connect-per-query** e é ineficiente em ambientes de produção com carga recorrente.

### 2.2 — Por que isso degrada a performance



#### Overhead fixo repetido em cada query

Abrir uma conexão PostgreSQL costuma consumir entre **5 e 50 ms ou mais**, dependendo da latência de rede até o servidor. Esse custo é pago **por query**, e não apenas uma vez por requisição HTTP.

**Conexões abertas por endpoint:**


| Endpoint                                              | Conexões por request                       |
| ----------------------------------------------------- | ------------------------------------------ |
| `GET /fila/espera_escola_raio/{lat}/{lon}/{cd_serie}` | **3** no banco Fila da Creche              |
| `GET /vaga/filtros/` (cache miss)                     | **3** no CIEDUDW                           |
| `GET /vaga/{cd_serie}/?filtro=&busca=`                | **1** no CIEDUDW + **1** na Fila da Creche |


No endpoint de fila, com ~20 ms de overhead por conexão, são aproximadamente **60 ms gastos só em handshake**, antes da execução de qualquer SQL.

#### Queries sequenciais sem reutilização de conexão

O endpoint de fila executa três funções independentes (`get_espera`, `get_fila_por_escolas`, `get_dt_atualizacao`), cada uma instanciando `FilaDBConnection()` separadamente. Uma única conexão reutilizada poderia executar as três queries; hoje ocorrem **três ciclos completos** de connect → query → disconnect.

#### Risco de esgotamento de conexões sob carga

A API roda com **8 workers Gunicorn** por pod. Em cenário de pico:

- 8 requests simultâneos em `/fila/...` → até **24 conexões** no banco Fila da Creche
- Com 3 réplicas no Kubernetes → até **72 conexões** apenas desse endpoint

PostgreSQL costuma operar com `max_connections` entre 100 e 200. Sem pool, a API compete com outros consumidores dos mesmos bancos e pode atingir o limite, causando falhas em cascata.

#### Queries pesadas somadas ao overhead de conexão

Além do custo de conexão, as queries em si são custosas:

- **Fila da Creche:** `ST_DWithin` com PostGIS, `JOIN` e `GROUP BY` em tabelas de solicitação de matrícula
- **CIEDUDW:** `JOIN` em três tabelas do schema `dw_dims`, filtros dinâmicos e ordenação
- **Python:** `fetchall()` com conversão linha a linha para dicionários, carregando todo o resultado em memória

O timeout de **120 segundos** configurado no Gunicorn indica que queries lentas já são esperadas no ambiente atual.

#### Cache insuficiente nos endpoints críticos

Apenas `GET /vaga/filtros/` utiliza Redis (TTL de 1 hora). Os endpoints de maior impacto para o cidadão — **fila de espera** e **vagas por escola** — consultam os bancos externos **a cada requisição**, sem qualquer camada de cache.

### 2.3 — Quando o impacto se torna perceptível


| Cenário                                  | Impacto esperado                                                                       |
| ---------------------------------------- | -------------------------------------------------------------------------------------- |
| Tráfego baixo, horário normal            | Baixo — o tempo de execução do SQL domina; o overhead de conexão é quase imperceptível |
| Pico de acesso / campanha pública        | **Alto** — latência crescente, fila de conexões e timeouts                             |
| Múltiplos pods no Kubernetes             | **Muito alto** — conexões se multiplicam linearmente com o número de réplicas          |
| Bancos remotos com alta latência de rede | **Alto** — o custo de TCP e autenticação pesa proporcionalmente mais                   |




### 2.4 — O que não é o problema principal

- Ter **dois bancos separados** (CIEDUDW e Fila da Creche) é uma decisão arquitetural válida, adequada à separação de domínios.
- Usar **SQL bruto** nos data warehouses é prática comum e aceitável para consultas analíticas de leitura.
- O Django ORM no banco aplicacional (`db_vaga`) é adequado para a telemetria de histórico de buscas.

O gargalo não está na existência de múltiplos bancos, e sim em **como** a API se conecta a eles.

### 2.5 — Comparativo do padrão atual vs. ideal

```
Hoje (connect-per-query):
  Request → [connect → query → disconnect] × N  →  overhead × N + tempo SQL

Ideal (pool / conexão reutilizada):
  Request → [pega do pool → query → query → query → devolve ao pool]  →  overhead mínimo + tempo SQL
```



### 2.6 — Conclusão da análise

**Sim, o padrão atual de conexão degrada a performance**, especialmente sob carga. Para um portal público com tráfego moderado o sistema pode operar; porém, para escalar com estabilidade ou reduzir latência em picos, esse modelo é um dos principais limitadores — junto com queries pesadas e ausência de cache nos endpoints principais.

As recomendações de **connection pooling** (médio prazo) e **expansão de cache Redis** (médio prazo) abordam diretamente esses pontos e estão detalhadas na seção 4 deste documento.

---



## 3. Curto Prazo (0–3 meses) — Segurança e Estabilidade



### 3.1 — Parametrizar todas as queries SQL

**Por quê:** Hoje parâmetros de URL e query string (`lat`, `lon`, `cd_serie`, `filtro`, `busca`) são interpolados diretamente nas strings SQL via f-strings. Isso expõe a API a **SQL Injection**, permitindo que um atacante leia, altere ou indisponibilize dados nos bancos CIEDUDW e Fila da Creche. A parametrização com placeholders (`%s`) do `psycopg2` separa dados de código SQL, eliminando essa vulnerabilidade crítica.

**Localização:** `fila_da_creche/queries/`, `vaga_remanescente/queries/`

---



### 3.2 — Implementar health checks (`/health/live`, `/health/ready`)

**Por quê:** O Kubernetes não possui hoje um mecanismo confiável para verificar se a API e suas dependências (CIEDUDW, FilaDB, Redis, banco aplicacional `db_vaga`) estão saudáveis. Sem probes de liveness e readiness, pods com falhas parciais continuam recebendo tráfego, e indisponibilidades de banco externo só são detectadas quando o usuário final recebe erro. Health checks permitem restart automático de pods defeituosos e exclusão de instâncias não prontas do balanceamento.

---



### 3.3 — Restringir CORS às origens do FrontEnd em produção

**Por quê:** A configuração atual `CORS_ORIGIN_ALLOW_ALL = True` permite que **qualquer site** faça requisições à API a partir do navegador de um usuário. Embora seja um portal público sem autenticação, isso facilita abuso (scraping automatizado, consumo indevido de recursos) e amplifica riscos de ataques cross-origin. Restringir às origens oficiais do FrontEnd reduz a superfície de ataque sem impactar o uso legítimo.

**Localização:** `webapp/core/settings.py`

---



### 3.4 — Corrigir tratamento de erros nas classes de conexão

**Por quê:** Em falha de conexão com CIEDUDW ou Fila da Creche, as classes retornam uma tupla ou string `'ERROR'` em vez da estrutura `{'results': [...]}` esperada pelas views. Isso causa `KeyError` e **crash em cascata** — a API retorna erro 500 genérico em vez de um HTTP 503 informando indisponibilidade temporária do banco externo. Corrigir o retorno e padronizar o código de resposta melhora a resiliência e a experiência do usuário em falhas parciais.

**Localização:** `webapp/utils/ciedudw_connection.py`, `webapp/utils/db_fila_creche_connection.py`

---



### 3.5 — Adicionar validação de entrada (coordenadas, filtros, série)

**Por quê:** Parâmetros como `lat` e `lon` chegam como strings na URL sem validação de range (-90/90, -180/180). Valores inválidos ou maliciosos são repassados diretamente ao SQL e ao PostGIS, podendo causar erros inesperados ou comportamento indefinido. Validar entrada na camada da API é a primeira linha de defesa antes mesmo da parametrização SQL, reduzindo erros operacionais e vetores de ataque.

**Localização:** Views em `fila_da_creche/views.py` e `vaga_remanescente/views.py`

---



### 3.6 — Corrigir race condition no FrontEnd e erros silenciados

**Por quê:** O componente `Creches.js` utiliza `UNSAFE_componentWillMount` combinado com `componentDidMount`, o que pode disparar chamadas à API com coordenadas `undefined` antes que o geocoding termine — resultando em buscas vazias ou erros intermitentes para o cidadão. Além disso, blocos `.catch()` vazios nas chamadas Axios engolem falhas silenciosamente, tornando problemas de API invisíveis tanto para o usuário quanto para a operação. Corrigir esses pontos melhora a confiabilidade percebida do portal.

**Localização:** `src/componentes/Creches/Creches.js` e demais componentes com chamadas Axios

---



## 4. Médio Prazo (3–6 meses) — Observabilidade e Resiliência



### 4.1 — Implementar logging estruturado (JSON) + centralização

**Por quê:** Hoje a API não utiliza o módulo `logging` do Python de forma estruturada; os únicos logs são stdout/stderr do Gunicorn. Sem logs centralizados (ELK, Loki, CloudWatch), é impossível correlacionar erros, investigar incidentes ou entender padrões de uso em produção. Logging estruturado em JSON facilita busca, alertas e auditoria operacional.

---



### 4.2 — Adicionar APM (latência por endpoint, taxa de erro)

**Por quê:** Não há hoje visibilidade de quanto tempo cada endpoint leva, qual banco é o gargalo, ou qual a taxa de erro em runtime. APM (Application Performance Monitoring) permite identificar degradações antes que afetem o usuário, priorizar otimizações com dados reais e acompanhar o impacto das melhorias implementadas.

---



### 4.3 — Connection pooling para CIEDUDW e FilaDB

**Por quê:** Conforme detalhado na seção 2 deste documento, cada query abre e fecha uma conexão TCP completa. Connection pooling (`psycopg2.pool` na aplicação ou PgBouncer na infraestrutura) reutiliza conexões já autenticadas, reduzindo drasticamente o overhead por request e o risco de esgotar `max_connections` nos bancos externos. É a recomendação de **maior impacto em performance** com esforço moderado.

**Localização:** `webapp/utils/ciedudw_connection.py`, `webapp/utils/db_fila_creche_connection.py`

---



### 4.4 — Expandir cache Redis para endpoints de leitura frequente

**Por quê:** Apenas `/vaga/filtros/` é cacheado hoje (TTL 1 hora). Os endpoints `/fila/espera_escola_raio/` e `/vaga/{serie}/` — os de maior volume e impacto para o cidadão — consultam bancos externos a cada request. Cachear essas respostas com TTL curto (5–15 minutos), segmentado por parâmetros de busca, reduz carga nos bancos legados e melhora o tempo de resposta sem comprometer significativamente a atualidade dos dados.

**Localização:** `webapp/fila_da_creche/views.py`, `webapp/vaga_remanescente/views.py`

---



### 4.5 — Rate limiting nos endpoints públicos (DRF throttling)

**Por quê:** Sem limite de requisições por IP ou por janela de tempo, a API está vulnerável a abuso automatizado (scraping, DDoS de camada aplicação) que pode sobrecarregar os bancos externos compartilhados. Rate limiting via throttling do Django REST Framework protege a infraestrutura sem bloquear o uso legítimo do portal público.

**Localização:** `webapp/core/settings.py` (configuração `REST_FRAMEWORK`)

---



### 4.6 — Integrar Sentry no FrontEnd e na API

**Por quê:** Erros em produção hoje são silenciados no FrontEnd (`.catch()` vazios) e não rastreados na API. Sentry captura exceções automaticamente, agrupa por frequência, notifica o time e fornece stack trace com contexto — permitindo correção proativa antes que o volume de reclamações cresça.

---



## 5. Longo Prazo (6–12 meses) — Modernização



### 5.1 — Upgrade de stack (Python, Django, Node, React)

**Por quê:** A stack atual está em **End of Life**: Python 3.7, Django 2.2, Node 12, React 16 e Redis 3.2 não recebem mais patches de segurança. Manter versões sem suporte expõe o sistema a vulnerabilidades conhecidas sem correção disponível e dificulta a contratação/manutenção por desenvolvedores acostumados com versões atuais.


| Componente | Versão atual | Versão alvo |
| ---------- | ------------ | ----------- |
| Python     | 3.7          | 3.12+       |
| Django     | 2.2.6        | 4.2+ / 5.x  |
| Node.js    | 12.13.0      | 20+         |
| React      | 16.11.0      | 18+         |


---



### 5.2 — Migrar FrontEnd para Vite ou Next.js com React Query

**Por quê:** Create React App 3 e React 16 limitam performance de build, hot reload e recursos modernos (Suspense, Concurrent Mode). React Query (ou equivalente) traria cache de API no cliente, deduplicação de requests e estados de loading/error padronizados — eliminando parte dos problemas atuais de race condition e erros silenciados de forma estrutural.

---



### 5.3 — Substituir pubsub-js por React Context ou Zustand

**Por quê:** O `pubsub-js` usado para comunicação mapa ↔ tabela ↔ menu não possui mecanismo de unsubscribe consistente, causando **memory leaks** em sessões longas (`Mapa.jsx`, `MenuPrincipal.js`). Context API ou Zustand integram-se ao ciclo de vida do React, com cleanup automático e melhor rastreabilidade do fluxo de dados.

---



### 5.4 — Migrar Google Analytics UA → GA4 com tracking de rotas

**Por quê:** O Universal Analytics (UA) foi descontinuado pelo Google e não processa mais novos dados. O tracking atual registra apenas o pageview inicial, sem capturar navegação entre rotas da SPA — subestimando o uso real do portal. GA4 com tracking de mudança de rota fornece métricas de negócio confiáveis para decisões de produto.

---



### 5.5 — Aumentar cobertura de testes automatizados (API + FrontEnd)

**Por quê:** A API possui apenas 1 teste (verificação do Swagger 200) e o FrontEnd possui zero testes. Sem cobertura automatizada, qualquer alteração — inclusive as correções de segurança e performance deste plano — corre risco de regressão não detectada antes de chegar à produção.

---



### 5.6 — Revisar rota de manutenção — unificar rotas de vagas remanescentes

**Por quê:** O menu principal aponta para `/vagas-remanescentes`, que exibe página de manutenção, enquanto o fluxo funcional está em `/vagas-remanescentes-alternativo`. Essa inconsistência confunde o cidadão e pode gerar percepção de sistema indisponível ou mal mantido, mesmo com a funcionalidade operando na rota alternativa.

---



## 6. Resumo Executivo


| Horizonte                | Foco                          | Qtd. itens | Prioridade geral                                                                      |
| ------------------------ | ----------------------------- | ---------- | ------------------------------------------------------------------------------------- |
| Curto prazo (0–3 meses)  | Segurança e estabilidade      | 6          | **Crítica** — riscos ativos de SQL injection, CORS aberto e crashes em falha de banco |
| Médio prazo (3–6 meses)  | Observabilidade e resiliência | 6          | **Alta** — performance, monitoramento e proteção contra abuso                         |
| Longo prazo (6–12 meses) | Modernização                  | 6          | **Planejada** — sustentabilidade técnica e experiência do usuário                     |


**Destaques de maior impacto imediato:**

1. **Parametrização SQL** — elimina vulnerabilidade crítica de segurança
2. **Connection pooling** — maior ganho de performance com esforço moderado
3. **Health checks** — habilita operação confiável no Kubernetes
4. **Cache Redis expandido** — reduz carga nos bancos legados e melhora latência

---

## 7. Referência

Documento arquitetural completo: [DOCUMENTACAO_ARQUITETURAL_SME_VagasNaCreche.md](./DOCUMENTACAO_ARQUITETURAL_SME_VagasNaCreche.md)

---

