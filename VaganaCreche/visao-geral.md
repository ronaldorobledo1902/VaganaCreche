# Visão Geral

O **Vagas na Creche** é o portal público da SME-SP para transparência da **fila de espera** e das **vagas remanescentes** em creches da Rede Municipal de Educação. Diferentemente do EOL (matrícula operacional) ou do Escola Aberta (estatísticas da RME), o foco é consulta geográfica e territorial da demanda e da oferta de vagas na educação infantil — em linguagem acessível, **sem login**.

## O que o portal oferece

- Consulta de **fila de espera** por endereço e data de nascimento (série calculada no portal)
- Consulta de **vagas remanescentes** com filtros por DRE, distrito ou subprefeitura
- Mapa interativo (Leaflet / OpenStreetMap) com escolas no raio ou na localidade
- Geocodificação de endereços (Pelias)
- Registro de histórico de buscas (telemetria de uso)

## Como a solução está organizada

| Camada | Componentes |
|--------|-------------|
| **Apresentação** | SPA React (`SME-VagasNaCreche-FrontEnd`), servida por Nginx |
| **API** | Django REST (`SME-VagasNaCreche-API`) — consulta + telemetria |
| **Dados** | PostgreSQL `db_vaga` (histórico) · Fila DB (PostGIS) · CIEDUDW · Redis (filtros) |
| **Carga** | Airflow DAG `fila_da_creche` (diária às 10h) |
| **Runtime** | Kubernetes, CI/CD Jenkins, métricas Grafana (borda) |

## Premissas importantes

- Portal **público**, sem login do cidadão
- Sem BFF: o Front consome a API diretamente
- Dados da **fila** refletem o **último snapshot diário** do Airflow (não o instante corrente do EOL)
- **Vagas remanescentes** são lidas do CIEDUDW em tempo de requisição (filtros com cache Redis 1h)
- Somente **consulta** — matrícula e alteração de fila são domínio de outros sistemas
- Integrações de apoio: Pelias, OpenStreetMap, Google Analytics (UA legado)

## Onde aprofundar

| Seção | Conteúdo |
|-------|----------|
| [Visão de negócio](visao-negocio/index.md) | Personas, jornadas, escopo, riscos e indicadores |
| [Visão arquitetural](visao-arquitetural/index.md) | Documentação técnica do sistema e do Airflow |
| [Documentos](documentos/index.md) | Glossário, recomendações e demais artefatos |
| [Diagramas C4](diagramas/index.md) | Contexto, container e componentes |
| [Segurança](seguranca/index.md) | Controles, riscos e recomendações de segurança |

> Esta documentação apoia governança, onboarding técnico e comunicação com stakeholders de negócio e engenharia sobre o Vagas na Creche em operação (as-is) e suas evoluções propostas.
