#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# Modelo Microsoft PT-BR: WidescreenPresentation (categoria Empresarial / apresentacao basica em tela larga)
$TemplatePath = 'C:\Program Files\Microsoft Office\root\Templates\1046\WidescreenPresentation.potx'
$OutputPath   = 'c:\BEMOL\Arquivos\Spassu\Documentos\SME_VagasNaCreche_Apresentacao.pptx'
$DiagramDir   = 'c:\BEMOL\Arquivos\Spassu\Documentos\ppt_assets\diagramas'

# Placeholder types (PowerPoint)
$ppPlaceholderTitle    = 1
$ppPlaceholderBody     = 2
$ppPlaceholderSubtitle = 4

function Get-Layout {
    param($Pres, [string]$NamePart)
    for ($i = 1; $i -le $Pres.SlideMaster.CustomLayouts.Count; $i++) {
        $layout = $Pres.SlideMaster.CustomLayouts.Item($i)
        if ($layout.Name -like "*$NamePart*") { return $layout }
    }
    throw "Layout nao encontrado: $NamePart"
}

function Set-PlaceholderByType {
    param($Slide, [int]$Type, [string]$Text)
    for ($i = 1; $i -le $Slide.Shapes.Count; $i++) {
        $shape = $Slide.Shapes.Item($i)
        try {
            if ($shape.PlaceholderFormat.Type -eq $Type) {
                $shape.TextFrame.TextRange.Text = $Text
                return $true
            }
        } catch {}
    }
    return $false
}

function Add-TitleSlide {
    param($Pres, [string]$Title, [string]$Subtitle)
    $layout = Get-Layout $Pres 'Slide de T'
    $slide = $Pres.Slides.AddSlide($Pres.Slides.Count + 1, $layout)
    Set-PlaceholderByType $slide $ppPlaceholderTitle $Title | Out-Null
    Set-PlaceholderByType $slide $ppPlaceholderSubtitle $Subtitle | Out-Null
    return $slide
}

function Add-BulletSlide {
    param($Pres, [string]$Title, [string[]]$Bullets)
    $layout = Get-Layout $Pres 'Conte'
    $slide = $Pres.Slides.AddSlide($Pres.Slides.Count + 1, $layout)
    Set-PlaceholderByType $slide $ppPlaceholderTitle $Title | Out-Null
    for ($i = 1; $i -le $slide.Shapes.Count; $i++) {
        $shape = $slide.Shapes.Item($i)
        try {
            if ($shape.PlaceholderFormat.Type -eq $ppPlaceholderBody) {
                $range = $shape.TextFrame.TextRange
                $range.Text = ($Bullets -join "`r")
                $range.ParagraphFormat.Bullet.Type = 1
                break
            }
        } catch {}
    }
    return $slide
}

function Add-TextSlide {
    param($Pres, [string]$Title, [string]$Body)
    $layout = Get-Layout $Pres 'Conte'
    $slide = $Pres.Slides.AddSlide($Pres.Slides.Count + 1, $layout)
    Set-PlaceholderByType $slide $ppPlaceholderTitle $Title | Out-Null
    Set-PlaceholderByType $slide $ppPlaceholderBody $Body | Out-Null
    return $slide
}

function Add-DiagramSlide {
    param($Pres, [string]$Title, [string]$ImagePath, [string]$Footer = '')
    $layout = Get-Layout $Pres 'Somente T'
    $slide = $Pres.Slides.AddSlide($Pres.Slides.Count + 1, $layout)
    Set-PlaceholderByType $slide $ppPlaceholderTitle $Title | Out-Null

    if (Test-Path $ImagePath) {
        $pic = $slide.Shapes.AddPicture($ImagePath, 0, 1, 40, 100, -1, -1)
        $maxW = 880; $maxH = 380
        $ratio = [Math]::Min($maxW / $pic.Width, $maxH / $pic.Height)
        $pic.Width  = $pic.Width  * $ratio
        $pic.Height = $pic.Height * $ratio
        $pic.Left = 40 + ($maxW - $pic.Width) / 2
        $pic.Top  = 95
    }

    if ($Footer) {
        for ($i = 1; $i -le $slide.Shapes.Count; $i++) {
            $shape = $slide.Shapes.Item($i)
            try {
                if ($shape.PlaceholderFormat.Type -eq $ppPlaceholderBody) {
                    $shape.TextFrame.TextRange.Text = $Footer
                    $shape.TextFrame.TextRange.Font.Size = 11
                    break
                }
            } catch {}
        }
    }
    return $slide
}

function New-PresentationFromTemplate {
    param([string]$Template)
    $ppt = New-Object -ComObject PowerPoint.Application
    try { $ppt.Visible = 1 } catch {}
    # ReadOnly=True, Untitled=True -> nova apresentacao baseada no modelo
    $pres = $ppt.Presentations.Open($Template, $true, $true, $false)
    while ($pres.Slides.Count -gt 0) { $pres.Slides.Item(1).Delete() }
    return $ppt, $pres
}

$ppt, $pres = New-PresentationFromTemplate $TemplatePath

try {
    Add-TitleSlide $pres 'SME Vagas na Creche' @(
        'Levantamento Arquitetural, Infraestrutura e Sustentabilidade' + [char]13 +
        'Secretaria Municipal de Educacao de Sao Paulo' + [char]13 +
        'Spassu Tecnologia  |  Julho/2026' + [char]13 +
        'Sistema + Pipeline Airflow + Infraestrutura On-Premises'
    ) | Out-Null

    Add-BulletSlide $pres 'Agenda' @(
        'Contexto e objetivo do sistema',
        'Arquitetura da aplicacao',
        'Pipeline de dados (Airflow)',
        'Infraestrutura e DevOps',
        'Avaliacao consolidada e riscos',
        'Sustentabilidade (5 anos)',
        'Pontos fortes, fracos e recomendacoes',
        'Estimativa de custos',
        'Proximos passos'
    ) | Out-Null

    Add-TextSlide $pres 'Resumo Executivo' @"
Proposito: Portal publico de consulta de fila e vagas remanescentes em creches
Arquitetura: React + Django API + 3 bancos PostgreSQL + Redis + Airflow
Infraestrutura: On-premises, Kubernetes (Rancher), 100% open source
Trafego: ~100-150 acessos/dia; pico sazonal no fim do ano
DevOps: CI/CD maduro (Jenkins + Docker + K8s) - nota BOA
Seguranca: Riscos criticos (SQL injection, stack EOL) - acao imediata
Sustentabilidade: Viavel com modernizacao; insustentavel as-is

Mensagem-chave: sistema funcional e baixo custo de licenca, com divida tecnica e riscos que exigem plano de acao.
"@ | Out-Null

    Add-BulletSlide $pres 'O que e o Sistema?' @(
        'Consultar fila de espera por creches proximas a um endereco',
        'Consultar vagas remanescentes (DRE, distrito, subprefeitura)',
        'Visualizar escolas em mapa interativo (Leaflet / OpenStreetMap)',
        'Registrar telemetria de buscas (historico por coordenada)',
        'Repositorios: SME-VagasNaCreche-API + SME-VagasNaCreche-FrontEnd',
        'URL: vaga-na-creche.sme.prefeitura.sp.gov.br'
    ) | Out-Null

    Add-TextSlide $pres 'Componentes e Stack' @"
FrontEnd: React 16, Nginx, Node 12 (EOL)
API: Django 2.2, DRF, Gunicorn (8 workers) (EOL)
Banco aplicacional (db_vaga): PostgreSQL 12 (~1 GB)
Data Warehouse: CIEDUDW (PostgreSQL, leitura)
Fila da Creche: PostgreSQL + PostGIS (:5433), alimentado pelo Airflow
Cache: Redis 3.2 (1 endpoint) (EOL)
Orquestracao: Kubernetes + Rancher (OSS)
CI/CD: Jenkins + Docker (OSS)

Comunicacao: exclusivamente HTTP sincrono - sem mensageria, WebSocket ou filas.
"@ | Out-Null

    Add-DiagramSlide $pres 'Diagrama de Arquitetura' (Join-Path $DiagramDir '04-arquitetura-sistema.png') '2 deployments K8s | 3 bancos + Redis | CIEDUDW e Fila DB sao SPOFs' | Out-Null
    Add-DiagramSlide $pres 'Contexto: Sistema + Airflow' (Join-Path $DiagramDir '01-airflow-contexto.png') 'DAG fila_da_creche as 10h | API le Fila, CIEDUDW e db_vaga' | Out-Null
    Add-DiagramSlide $pres 'DAG fila_da_creche (11 tasks)' (Join-Path $DiagramDir '02-dag-fila-creche.png') 'Schedule 0 10 * * * | Duracao ~1 min | ~31.274 execucoes com sucesso' | Out-Null
    Add-DiagramSlide $pres 'Fluxo ETL Diario' (Join-Path $DiagramDir '03-fluxo-etl-diario.png') 'Extract -> Truncate -> Load -> PostGIS | Risco: janela truncate' | Out-Null

    Add-TextSlide $pres 'Fluxos de Negocio' @"
Consulta de Fila de Espera:
1. Cidadao informa endereco -> Pelias retorna coordenadas
2. FE chama GET /fila/espera_escola_raio/{lat}/{lon}/{serie}
3. API consulta Fila DB (PostGIS - raio geografico)
4. Retorna escolas + posicao na fila + mapa

Consulta de Vagas Remanescentes:
1. FE chama GET /vaga/filtros/ (cache Redis, TTL 1h)
2. Cidadao seleciona DRE/distrito/subprefeitura
3. FE chama GET /vaga/{serie}/?filtro=&busca=
4. API consulta CIEDUDW -> retorna escolas com vagas
"@ | Out-Null

    Add-TextSlide $pres 'Infraestrutura On-Premises' @"
Modelo: On-premises (Zen Orchestra + Hyper-V)
Orquestracao: Kubernetes via Rancher
Clusters: Producao (3 CP + 13 workers = 16 nos), Release (QA/homolog)
Segregacao: Prod no cluster prod; QA/homolog no cluster release
Proxy: IP VIP + 2 Nginx (Infra Fisica) -> Ingress K8s
Storage: NFS (PV/PVC ate 100 GB)
Plataforma: 100% OSS - zero custo de licenca

Trafego: vaga-na-creche.sme.prefeitura.sp.gov.br
/ -> FE  |  /api, /admin -> API:8000
"@ | Out-Null

    Add-TextSlide $pres 'Kubernetes: Vaga na Creche' @"
Namespace prod: sme-vaganacreche
Deployments: FrontEnd + API
Pods: 1 pod por servico (sem replica extra)
HPA / Autoscale: Desabilitado (restricao de recursos)
Deploy: Rolling Update (~5 min)
Rollback: Revert Git + reexecucao Jenkins
Secrets: K8s Secrets + ConfigMaps

Limitacao critica: 1 pod/servico = sem resiliencia; pico sazonal exige intervencao manual ou novos servidores.
"@ | Out-Null

    Add-DiagramSlide $pres 'Pipeline CI/CD' (Join-Path $DiagramDir '06-pipeline-cicd.png') 'GitHub -> Jenkins -> Registry -> K8s | Producao: aprovacao manual' | Out-Null

    Add-TextSlide $pres 'Banco de Dados' @"
db_vaga (PG aplicacional): Historico de buscas | 16 vCPUs, 18 GiB, ~1 GB (+1 MB/mes)
CIEDUDW: Vagas remanescentes | Compartilhado, leitura
Fila da Creche: Fila + PostGIS | Alimentado pelo Airflow
Redis 3.2: Cache /vaga/filtros/ | Sem HA informada

HA (prod): replica read-only no PG aplicacional
Backup: dump diario - sem PITR (RPO ~24h)
Ambientes: banco NAO separado por ambiente para Vaga na Creche
"@ | Out-Null

    Add-DiagramSlide $pres 'Matriz de Risco de Seguranca' (Join-Path $DiagramDir '05-matriz-risco-seguranca.png') 'Mitigar: SQL Injection, Stack EOL, CORS | Planejar: auth e rate limit' | Out-Null

    Add-BulletSlide $pres 'Principais Riscos Tecnicos' @(
        'SQL injection (queries nao parametrizadas)',
        'Stack EOL (Python 3.7, Django 2.2, React 16)',
        '1 pod/servico, sem HPA',
        'Connect-per-query nos DWs',
        'Cache insuficiente (apenas 1 endpoint)',
        'Observabilidade fraca (6-8 erros 500/dia)',
        'Conhecimento escasso - sistema arqueologico',
        'Full refresh Airflow - janela de dados vazios',
        'SPOFs: CIEDUDW, Fila DB, API (1 replica), NFS'
    ) | Out-Null

    Add-DiagramSlide $pres 'Avaliacao Consolidada' (Join-Path $DiagramDir '07-avaliacao-consolidada.png') 'Seguranca: CRITICA | DevOps: BOA | Resiliencia: BAIXA' | Out-Null

    Add-TextSlide $pres 'Observabilidade e Operacao' @"
Ferramentas atuais:
- Rancher/K8s: logs de pods
- Grafana: dashboards HTTP (200/400/500)
- Telegram: alertas de build/deploy
- SonarQube: analise estatica (branch homolog)

Ausente: Prometheus, APM, tracing, health checks, alertas runtime, Sentry

Trafego observado: ~98-154 acessos/dia; 6-8 erros HTTP 500 intermitentes
"@ | Out-Null

    Add-TextSlide $pres 'Sustentabilidade: Proximos 5 Anos' @"
Stack EOL -> insustentavel ~2027 sem upgrade
Seguranca critica -> risco crescente sem acao
Capacidade: 1 pod/servico -> falha em picos
Dados: ~1 GB (+60 MB/5 anos) -> sem impacto

Roadmap minimo:
Ano 1: Seguranca, health checks, pooling, 2 replicas
Ano 2: Upgrade stack, cache, testes, observabilidade
Ano 3: HPA, PITR, alertas runtime
Anos 4-5: Carga incremental Airflow, DR, runbooks, GA4
"@ | Out-Null

    Add-BulletSlide $pres 'Pontos Fortes' @(
        'CI/CD funcional - Jenkins + Docker + K8s + multi-ambiente',
        'Custo zero de licenca - plataforma 100% open source',
        'Arquitetura simples - 2 servicos, facil de operar',
        'Pipeline Airflow estavel - ~99,5% sucesso historico',
        'Proxy redundante - VIP + 2 Nginx',
        'Trafego moderado - ~150 acessos/dia',
        'Crescimento de dados minimo - ~1 MB/mes',
        'Cluster robusto - 3 control planes + 13 workers'
    ) | Out-Null

    Add-BulletSlide $pres 'Pontos Fracos' @(
        'Stack tecnologica EOL (sem patches de seguranca)',
        '1 pod/servico, sem autoscale',
        'SQL injection + CORS aberto',
        'Connect-per-query - performance degradada sob carga',
        'Cache Redis em apenas 1 endpoint',
        'Observabilidade insuficiente',
        'Pipeline legada sem testes/Quality Gate',
        'Backup sem PITR (RPO ~24h)',
        'Sistema pouco mantido - conhecimento escasso',
        'Full refresh Airflow - risco operacional'
    ) | Out-Null

    Add-TextSlide $pres 'Recomendacoes Prioritarias' @"
CURTO PRAZO (0-3 meses) - CRITICO:
1. Parametrizar SQL  2. Health checks  3. Restringir CORS
4. Tratamento de erro HTTP 503  5. Validar entrada
6. Corrigir race condition FE  7. Configurar 2 replicas prod

MEDIO PRAZO (3-6 meses) - ALTO:
Connection pooling | Cache Redis expandido | Logging JSON
Prometheus | Rate limiting | Sentry

LONGO PRAZO (6-12 meses) - PLANEJADO:
Upgrade stack | React Query | GA4 | Testes | Carga incremental Airflow
"@ | Out-Null

    Add-TextSlide $pres 'Estimativa de Custos (Equipe)' @"
Premissas: infraestrutura R$ 0 licenca | ferramentas OSS | dedicacao parcial

Equipe: 1 Arquiteto Senior | 1 Tech Lead | 3 DevOps | 1 DBA | 1 Dev | 1 PO

Cenario A - Operacao minima (20% FTE): ~R$ 370.000/ano
Cenario B - Operacao + evolucao (40% FTE): ~R$ 999.000/ano (RECOMENDADO)
Cenario C - Modernizacao intensiva (70% FTE): ~R$ 1.750.000/ano

5 anos (Cenario B): ~R$ 4,2 - 4,5 milhoes
Economia OSS vs SaaS: R$ 165-450.000/ano evitados em licencas
"@ | Out-Null

    Add-TextSlide $pres 'Quick Wins (Alto ROI, Zero Licenca)' @"
Parametrizar SQL        -> Elimina risco critico     (Esforco: Baixo)
Health checks           -> Operacao confiavel K8s   (Esforco: Baixo)
2 replicas prod         -> Resiliencia imediata     (Esforco: Baixo)
Connection pooling      -> Maior ganho performance  (Esforco: Medio)
Cache Redis expandido   -> Reduz carga nos DWs      (Esforco: Medio)
Prometheus + Grafana    -> Visibilidade runtime     (Esforco: Medio)
"@ | Out-Null

    Add-BulletSlide $pres 'Proximos Passos' @(
        'Aprovar plano de acao - priorizar itens de curto prazo (seguranca)',
        'Alocar equipe - definir FTE por papel (Cenario B recomendado)',
        'Solicitar novos servidores - ampliar capacidade on-prem',
        'Documentar runbooks - reduzir dependencia de conhecimento tacito',
        'Agendar revisao - acompanhamento trimestral do roadmap'
    ) | Out-Null

    Add-TextSlide $pres 'Encerramento / Perguntas' @"
1. O Vaga na Creche atende sua funcao publica com arquitetura simples e custo zero de licenca.

2. Existem riscos criticos de seguranca e stack EOL que exigem acao nos proximos 3 meses.

3. Com investimento moderado em equipe (~R$ 1M/ano) e melhorias OSS, o sistema e sustentavel por 5+ anos.

Documentacao completa disponivel em: Documentos/
"@ | Out-Null

    if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }
    $pres.SaveAs($OutputPath)
    Write-Output "Apresentacao criada com modelo WidescreenPresentation (Empresarial): $OutputPath"
    Write-Output "Total de slides: $($pres.Slides.Count)"
}
finally {
    if ($pres) { $pres.Close() }
    $ppt.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
