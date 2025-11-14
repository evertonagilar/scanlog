# 🚀 scanlog

Ferramenta de análise automatizada para concentrar, normalizar e extrair indicadores de logs de aplicações Java (JBoss/WildFly/Payara). O `scanlog.sh` coleta arquivos via SSH/rsync, aplica diversos tratamentos (normalização de mensagens, unificação de stacktrace, remoção de ruídos) e gera relatórios textuais e um JSON consolidado.

## 🧰 Pré-requisitos
- 🔧 `rsync`, `ssh`, `jq`, `python3`, `grep`, `awk`, `sed`, `find`.
- 🔐 Acesso SSH aos servidores listados nos modelos e chave privada válida (`chaveprivada.key` por padrão).
- 💾 Permissão de leitura nos diretórios de log remotos e espaço em disco local para armazenar as cópias.

## ⚙️ Configuração
1. **Config global (`config.inc`)**  
   Ajuste porta SSH, caminho da chave (`chaveprivada.key`) e pasta de saída (`pastaResultado`).
2. **Modelos (`modelos/*.inc`)**  
   Cada modelo define servidores-alvo, normalizações e listas de extratores/contadores. Os modelos padrão são:

   | Modelo   | Descrição rápida |
   |----------|------------------|
   | `sigunb` | Modelo do SIGUNB |
   | `sieweb` | Modelo do SIEWEB |

   
## 🖥️ Execução local
```bash
./scanlog.sh --modelo=sigunb
```

## 📦 Build da imagem

```bash
docker build -t scanlog .
```

## 📦 Processar os logs
```bash
docker run -it --rm -v "$(pwd)":/opt/scan scanlog --modelo=sieweb
```
ou

```bash
docker run -it --rm -v "$(pwd)":/opt/scan scanlog --modelo=sigunb
```


## 📊 Dashboard

```bash
docker run -it --rm -v "$(pwd)":/opt/scan -p 8501:8501 scanlog --dashboard
```

