# scanlog

Ferramenta de análise automatizada para concentrar, normalizar e extrair indicadores de logs de aplicações Java (JBoss/WildFly/Payara). O `scanlog.sh` coleta arquivos via SSH/rsync, aplica diversos tratamentos (normalização de mensagens, unificação de stacktrace, remoção de ruídos) e gera relatórios textuais e um JSON consolidado.

## Pré-requisitos
- `rsync`, `ssh`, `jq`, `python3`, `grep`, `awk`, `sed`, `find`.
- Acesso SSH aos servidores listados nos modelos e chave privada válida (`chaveprivada.key` por padrão).
- Permissão de leitura nos diretórios de log remotos e espaço em disco local para armazenar as cópias.

## Configuração
1. **Config global (`config.inc`)**  
   Ajuste porta SSH, caminho da chave (`chaveprivada.key`) e pasta de saída (`pastaResultado`).
2. **Modelos (`modelos/*.inc`)**  
   Cada modelo define servidores-alvo, normalizações e listas de extratores/contadores. Os modelos padrão são:

   | Modelo   | Descrição rápida |
   |----------|------------------|
   | `sigunb` | Modelo do SIGUNB |
   | `sieweb` | Modelo do SIEWEB |

   
3. **Chave SSH**  
   Garanta que o arquivo referencia um par válido e permissões adequadas (`chmod 600 chaveprivada.key`).

## Execução local
```bash
./scanlog.sh --modelo=sigunb
```

## Execução em container

```bash
docker build -t scanlog .
docker run -it --rm \
  --workdir /opt/scan \
  -v "$(pwd)":/opt/scan \
  scanlog ./scanlog.sh --modelo=sieweb
```

> **Nota:** o container precisa conseguir acessar os servidores via SSH. Monte também sua chave ou utilize variáveis/volumes apropriados.

## Estrutura dos resultados
```
resultado/
└── <modelo>/
    └── analise-AAAA-MM-DD/
        ├── logs/                      # cópia bruta dos servidores
        ├── logs-jboss-unificados/     # normalização opcional
        ├── logs-normalizados/
        ├── result/
        │   ├── extracoes/             # arquivos gerados pelos extratores/contadores
        │   └── indicadores/           # tabelas agregadas
        └── report/
            └── data/report-data.json  # base para dashboards/HTML
```

