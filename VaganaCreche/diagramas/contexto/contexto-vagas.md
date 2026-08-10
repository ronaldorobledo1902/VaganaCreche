# Contexto — Vagas Remanescentes

## Contexto

A jornada de **vagas remanescentes** permite ao cidadão localizar creches com **vagas disponíveis**, filtrando por **série/categoria** e por **localidade** (DRE, distrito ou subprefeitura), com resultado em **tabela + mapa**.

---

## Objetivos

- Facilitar a consulta pública de vagas ainda disponíveis na educação infantil
- Oferecer recortes territoriais alinhados à organização da SME (DRE / distrito / subprefeitura)
- Apresentar o resultado de forma geográfica (mapa) e tabular

---

## Escopo

### Em escopo

- Listagem de filtros: `GET /vaga/filtros/` (DREs, distritos, subprefeituras)
- Consulta de vagas: `GET /vaga/{cd_serie}/?filtro=&busca=`
- Cache Redis dos filtros (chave `filtros_vaga`, TTL 1 hora)
- Visualização em tabela + mapa Leaflet / OpenStreetMap

### Fora de escopo

- Reserva ou matrícula na vaga
- Edição de oferta de vagas pelo cidadão
- Substituição de ferramentas internas de gestão de vagas da SME

---

## Fluxo resumido

```text
Cidadão → FrontEnd → API /vaga/filtros/ → Redis (hit) ou CIEDUDW (miss)
                ↓
         API /vaga/{serie}/ → CIEDUDW
                ↓
         Tabela + Mapa Leaflet/OSM
```

---

## Sistemas envolvidos

| Sistema | Interação |
|---------|-----------|
| FrontEnd | Seleção de série/localidade, mapa e tabela |
| API Django | Endpoints `/vaga/filtros/` e `/vaga/{serie}/` |
| Redis | Cache dos filtros territoriais |
| CIEDUDW | Origem das vagas e dimensões territoriais |
| OpenStreetMap | Tiles do mapa |

---

## Considerações

- Diferente da fila, as vagas remanescentes são lidas **diretamente do CIEDUDW** em tempo de requisição (não do snapshot da Fila)
- Apenas os filtros são cacheados; a consulta de vagas por escola não usa Redis
- Rota de menu inconsistente: `/vagas-remanescentes` (manutenção) vs `/vagas-remanescentes-alternativo` (fluxo funcional) — unificação recomendada
