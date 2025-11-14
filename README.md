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

## 📦 Execução em container

```bash
docker build -t scanlog .
docker run -it --rm -v "$(pwd)":/opt/scan scanlog ./scanlog.sh --modelo=sieweb
```

> **Nota:** o container precisa conseguir acessar os servidores via SSH. Monte também sua chave ou utilize variáveis/volumes apropriados.

## 🗂️ Estrutura dos resultados
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

## 📊 Dashboard Streamlit
O arquivo `dashboard_streamlit.py` oferece uma interface web para navegar pelos indicadores, tabelas e arquivos em `result/extracoes`.

1. Crie/ative o ambiente virtual (opcional, mas recomendado):
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install --upgrade pip streamlit
   ```
2. Execute o dashboard:
   ```bash
   streamlit run dashboard_streamlit.py --server.port 8501
   ```
3. Escolha o modelo e a execução no painel lateral. A tabela de extrações permite abrir cada arquivo e baixar o conteúdo completo.

### 🔐 Execução com TLS

- Para gerar um par autoassinado para testes:
  ```bash
  openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout key.pem \
    -out cert.pem \
    -subj "/CN=scanlog.local"
  ```

O Streamlit suporta TLS nativamente. Forneça os caminhos para o certificado e para a chave:
```bash
streamlit run --server.port=9500 \
              --server.address 0.0.0.0 \
              --server.sslCertFile cert.pem \
              --server.sslKeyFile key.pem dashboard_streamlit.py
```

