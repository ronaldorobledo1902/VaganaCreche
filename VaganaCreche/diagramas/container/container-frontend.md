# Container — vaganacreche-frontend

```{image} ../assets/05-sistema-arquitetura.svg
:width: 100%
:alt: FrontEnd no diagrama de containers do Vagas na Creche
```

## Processamento de FrontEnd (SME-VagasNaCreche-FrontEnd)

O container **vaganacreche-frontend** é a SPA pública do cidadão. É construído com **React 16** (Create React App 3), empacotado em imagem **Nginx**, e implantado no Kubernetes no namespace `sme-vaganacreche` (produção).

### Responsabilidades

* Renderizar jornadas de **fila de espera** e **vagas remanescentes**
* Geocodificar endereços (Pelias) e calcular a série a partir da data de nascimento
* Sincronizar mapa ↔ tabela ↔ menu via **pubsub-js**
* Persistir preferências de busca (série, endereço, coordenadas, acessibilidade) em `localStorage`
* Registrar histórico de busca via API (`POST /pesquisa/historico_busca_end/`)

### Comunicação

| Destino | Protocolo | Uso |
|---------|-----------|-----|
| API Vagas na Creche (`API_URL`) | HTTP REST (Axios) | Fila, vagas, filtros, histórico |
| Pelias (`API_ENDERECO`) | HTTPS | Autocomplete / geocodificação |
| OpenStreetMap | HTTPS | Tiles Leaflet |
| Google Analytics | HTTPS | Pageview |

### Runtime

* Variáveis injetadas no `entrypoint.sh` (`API_URL`, `API_ENDERECO`, `URL_VIDEO`)
* Basename / path do SPA: `/vaga-na-creche`
* Service Worker / PWA: **desabilitado**
* Cliente HTTP centralizado em `ConectarApi.js` (wrapper Axios sem interceptors)

### Fronteira

O FrontEnd **não** acessa PostgreSQL, CIEDUDW, Fila DB, Redis nem Airflow. Toda consulta de domínio passa pela API (exceto geocodificação, tiles e analytics, que são diretos do browser).
