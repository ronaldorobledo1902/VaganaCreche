# Contexto — Fila de Espera (Demanda)

## Contexto

A jornada de **fila de espera** é o ponto de entrada principal do Vagas na Creche. O cidadão informa um **endereço** e a **data de nascimento** da criança; o portal geocodifica o endereço, calcula a **série** de ensino e consulta escolas no **raio geográfico**, exibindo a **posição na fila** em **tabela + mapa interativo**.

---

## Objetivos

- Permitir que famílias entendam a demanda por creches próximas a um endereço
- Exibir escolas e posição na fila sem conhecimento técnico de bases de dados
- Registrar telemetria de buscas (onde os cidadãos procuram vagas)

---

## Escopo

### Em escopo

- Geocodificação via Pelias (`/v1/search`)
- Cálculo de série a partir da data de nascimento (no FrontEnd)
- Consulta `GET /fila/espera_escola_raio/{lat}/{lon}/{cd_serie}`
- Consulta espacial PostGIS (`ST_DWithin`)
- Resultado em tabela + mapa Leaflet / OpenStreetMap
- `POST /pesquisa/historico_busca_end/` (telemetria)

### Fora de escopo

- Matrícula ou inscrição na fila
- Alteração da posição na fila
- Autenticação do usuário
- Edição cadastral da unidade

---

## Fluxo resumido

```text
Cidadão → FrontEnd → [Pelias] → calcula série → API → Fila DB (PostGIS)
                                              ↓
                                    POST histórico (db_vaga)
                                              ↓
                                    Tabela + Mapa Leaflet/OSM
```

---

## Sistemas envolvidos

| Sistema | Interação |
|---------|-----------|
| FrontEnd React | Orquestra endereço, série, mapa e tabela |
| Pelias | Endereço → coordenadas |
| API Django | Endpoint `/fila/espera_escola_raio/` |
| Fila da Creche DB | SQL + PostGIS (raio geográfico) |
| db_vaga | Persistência do histórico de buscas |
| OpenStreetMap | Tiles do mapa |

---

## Considerações

- A API é pública; não há login nesta jornada
- Dados da fila refletem o **último snapshot diário** do Airflow (ver [contexto-dados](contexto-dados.md))
- Regras de publicação na carga: anonimização, status ativo, espera > 30 dias, distância máxima de 2 km
- Race condition conhecida no Front (`Creches.js`) pode gerar buscas com coordenadas `undefined` — ver recomendações prioritárias
