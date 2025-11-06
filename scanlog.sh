#!/bin/bash

########################################################################################################
#
# Author: Everton de Vargas Agilar
# Date: 10/08/2024
#
# Ferramenta analisador de log scanlog
#
#
# Histórico
#
# Data       |  Quem           |  Mensagem
# -----------------------------------------------------------------------------------------------------
# 10/08/2024  Everton Agilar    Versão inicial
########################################################################################################

VERSAO_SCRIPT='1.1.0'
CURRENT_DATE=$(date '+%d/%m/%Y %H:%M:%S')
WORKDIR="$(pwd)"
MODELOS_DIR="$WORKDIR/modelos"

# Carrega as variáveis de configuração dos IPs dos servidores
source "$WORKDIR/config.inc"

modeloSelecionado=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --modelo=*)
            modeloSelecionado="${1#--modelo=}"
            shift
            ;;
        --modelo)
            if [[ -n "${2:-}" ]]; then
                modeloSelecionado="$2"
                shift 2
            else
                echo "O parâmetro --modelo=sigunb|sieweb é necessário."
                exit 1
            fi
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$modeloSelecionado" ]]; then
    echo "O parâmetro --modelo=sigunb|sieweb é necessário."
    exit 1
fi

modeloArquivo="${MODELOS_DIR}/${modeloSelecionado}.inc"

if [[ -z "${normalizaLogs:-}" ]]; then
    normalizaLogs="true"
fi

if [[ -z "${removeQuebras:-}" ]]; then
    removeQuebras="false"
fi

if [[ -z "${normalizaQuebra:-}" ]]; then
    normalizaQuebra="false"
fi

if [[ -z "${normalizaLogsJBoss:-}" ]]; then
    normalizaLogsJBoss="false"
fi

if [[ -z "${baseModule:-}" ]]; then
    baseModule="br\.ufsm\.cpd\.sie"
fi

if [[ ! -f "$modeloArquivo" ]]; then
    echo "❌ Arquivo de modelo '${modeloArquivo}' nao encontrado."
    exit 1
fi

source "$modeloArquivo"

if [[ -z "${patternNomeService:-}" ]]; then
    patternNomeService='([A-Za-z0-9_.]+MBean)'
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ A dependência obrigatória 'jq' não foi encontrada no PATH."
    exit 1
fi

# Função para validar o formato de data
is_valid_date() {
    date -d "$1" +"%Y-%m-%d" >/dev/null 2>&1
}

# Normaliza valores numéricos removendo caracteres que não são dígitos
normalizaNumero() {
    local valor="${1//[^0-9]/}"
    if [[ -z "$valor" ]]; then
        echo "0"
    else
        echo "$valor"
    fi
}

formatArquivoComoTabela(){
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    # Cabeçalho da tabela
    echo "Quantidade      | Descrição do contador" > "$arquivoSaida"
    echo "--------------- | ----------------------------------------" >> "$arquivoSaida"

    # Lê cada linha do arquivo de entrada
    while IFS="=" read -r chave valor; do
        local chave=$(echo "$chave" | sed 's/^[ \t]*//;s/[ \t]*$//')
        local valor=$(echo "$valor" | sed 's/^[ \t]*//;s/[ \t]*$//')
        printf "%15s | %s\n" "$valor" "$chave" >> "$arquivoSaida"
    done < "$arquivoEntrada"
}

processaAcum(){
  local line="$1"
  local regex="$2"
  local arquivo="$3"
  local condicao="$4"

  if [[ $line =~ $regex ]]; then
      local param1="${BASH_REMATCH[1]}"
      local param2Original="${BASH_REMATCH[2]}"
      local param2Normalizado
      param2Normalizado=$(normalizaNumero "$param2Original")
      local expr="${condicao//\$param2/$param2Normalizado}"
      expr="${expr//\$param1/$param1}"
      if eval "[[ $expr ]]"; then
         echo "${param2Normalizado}|${param1} (${param2Original}ms)" >> "$arquivo"
      fi
  fi
}

# Função para copiar logs dos servidores configurados
copiar_logs_servidores() {
    local data="$1"
    local pastaLogs="$2"
    echo -e "\nObtendo os arquivos de logs dos servidores configurados..."
    for servidor in "${servidores[@]}"; do
        local host_path="${servidor%:*}"
        local pastaServidor="$pastaLogs/$host_path"
        mkdir -p "$pastaServidor"
        echo "📂 Copiando logs de $host_path para $pastaServidor usando key $chavePrivada"
        echo "Comando: rsync -avL -e \"ssh -p $sshPort -i $chavePrivada -o StrictHostKeyChecking=no\" $servidor $pastaServidor"
        rsync -avL -e "ssh -p $sshPort -i $chavePrivada -o StrictHostKeyChecking=no" "$servidor" "$pastaServidor"
        if [ $? -eq 0 ]; then
            echo "✅ Logs copiados com sucesso de $host_path."
        else
            echo "❌ Falha ao copiar logs de $host_path."
            exit 1
        fi
    done
}


# Função para extrair somente o campo LogMessage (ou equivalente) e gerar uma cópia normalizada
normalizar_logs_mensagens() {
    local pastaOrigem="$1"
    local pastaDestino="$2"

    echo -e "\n🧹 Extraindo mensagens do campo LogMessage..."
    rm -rf "$pastaDestino"
    mkdir -p "$pastaDestino"

    find "$pastaOrigem" -type f -name "*.log" -print0 | while IFS= read -r -d '' arquivo; do
        local caminhoRel="${arquivo#$pastaOrigem/}"
        local arquivoDestino="$pastaDestino/$caminhoRel"
        mkdir -p "$(dirname "$arquivoDestino")"

        awk '{
            if (match($0, /\{.*$/)) {
                print substr($0, RSTART)
            }
        }' "$arquivo" \
        | jq -r -R 'fromjson? | select(.) |
            if (.LogMessage? and (.LogMessage|type=="string") and (.LogMessage|length>0)) then .LogMessage
            elif (.Throwable? and (.Throwable.Exception? and (.Throwable.Exception|type=="string") and (.Throwable.Exception|length>0))) then
                .Throwable.Exception + (if (.Throwable.StackTrace? and (.Throwable.StackTrace|type=="string") and (.Throwable.StackTrace|length>0)) then "\n" + .Throwable.StackTrace else "" end)
            elif (.Message? and (.Message|type=="string") and (.Message|length>0)) then .Message
            else empty end' > "$arquivoDestino"

        # Remove arquivos vazios gerados por eventos sem mensagem relevante
        if [[ ! -s "$arquivoDestino" ]]; then
            rm -f "$arquivoDestino"
        fi
    done
}

remover_quebras_logs() {
    local pastaOrigem="$1"
    local pastaDestino="$2"

    echo -e '\n🪚 Removendo quebras dos logs...'
    rm -rf "$pastaDestino"
    mkdir -p "$pastaDestino"

    find "$pastaOrigem" -type f -print0 | while IFS= read -r -d '' arquivo; do
        local caminhoRel="${arquivo#$pastaOrigem/}"
        local arquivoDestino="$pastaDestino/$caminhoRel"
        mkdir -p "$(dirname "$arquivoDestino")"
        sed -e 's/\\n\\t/ /g' -e 's/\\n/ /g' -e 's/\\t/ /g' "$arquivo" | tr '\t' ' ' > "$arquivoDestino"
    done
}

normalizar_logs_jboss() {
    local pastaOrigem="$1"
    local pastaDestino="$2"

    echo -e "\n🪄 Unificando entradas dos logs JBoss..."
    rm -rf "$pastaDestino"
    mkdir -p "$pastaDestino"

    find "$pastaOrigem" -type f -name "*.log" -print0 | while IFS= read -r -d '' arquivo; do
        local caminhoRel="${arquivo#$pastaOrigem/}"
        local arquivoDestino="$pastaDestino/$caminhoRel"
        mkdir -p "$(dirname "$arquivoDestino")"

        python3 - "$arquivo" "$arquivoDestino" <<'PY'
import pathlib
import re
import sys

origem = pathlib.Path(sys.argv[1])
destino = pathlib.Path(sys.argv[2])

try:
    linhas = origem.read_text(encoding='utf-8', errors='ignore').splitlines()
except Exception as exc:  # noqa: BLE001
    print(f'⚠️ Não foi possível ler {origem}: {exc}')
    destino.write_text('', encoding='utf-8')
    sys.exit(0)

timestamp_re = re.compile(
    r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3}\s+\w+\s+\[[^\]]+\]\s+\([^)]*\)\s+.*'
)
prefix_re = re.compile(
    r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3}\s+\w+\s+\[[^\]]+\]\s+\([^)]*\)\s*'
)

def formata_bloco(bloco):
    if not bloco:
        return ''
    primeira = bloco[0].rstrip().replace('\r', '').replace('\t', ' ')
    primeira = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', primeira)
    acumulado = primeira
    for linha in bloco[1:]:
        marcador_stack = 'STACK::'
        if linha.startswith(marcador_stack):
            texto = linha[len(marcador_stack):].rstrip()
        else:
            texto = linha.rstrip()
        if not texto:
            continue
        texto = prefix_re.sub('', texto, count=1)
        texto = texto.lstrip().replace('\r', '').replace('\t', ' ')
        texto = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', texto)
        if not texto:
            continue
        if texto.startswith('at ') or texto.startswith('Caused by') or texto.startswith('...'):
            acumulado += r'\n\t' + texto
        else:
            acumulado += ' ' + texto
    return acumulado

blocos = []
bloco_atual = []

for linha in linhas:
    match = timestamp_re.match(linha)
    if match:
        resto = prefix_re.sub('', linha, count=1).lstrip()
        if bloco_atual and resto and (resto.startswith('at ') or resto.startswith('Caused by') or resto.startswith('...')):
            bloco_atual.append('STACK::' + resto)
            continue
        if bloco_atual:
            blocos.append(formata_bloco(bloco_atual))
        bloco_atual = [linha]
    else:
        if bloco_atual:
            conteudo = linha.lstrip()
            if conteudo.startswith('at ') or conteudo.startswith('Caused by') or conteudo.startswith('...'):
                bloco_atual.append('STACK::' + conteudo)
            else:
                bloco_atual.append(linha)
        else:
            bloco_atual = [linha]

if bloco_atual:
    blocos.append(formata_bloco(bloco_atual))

destino.write_text('\n'.join(blocos) + ('\n' if blocos else ''), encoding='utf-8')
PY
    done
}

normalizar_quebras_arquivos() {
    local pastaBase="$1"
    local descricao="$2"

    if [[ ! -d "$pastaBase" ]]; then
        return
    fi

    echo -e "\n🔁 Normalizando quebras nos arquivos de ${descricao}..."

    find "$pastaBase" -type f -name "*.log" -print0 | while IFS= read -r -d '' arquivo; do
        sed -i 's@\\n\\t@\n\t@g' "$arquivo";
        sed -i 's@\\nCaused@\n\tCaused@g' "$arquivo";
        sed -i 's@\\n"}}@"\n}}@g' "$arquivo";
        sed -i 's@\\nbr\.@\n\tbr\.@g' "$arquivo";
        sed -i 's@\\n@\n@g' "$arquivo";
        sed -i 's@"Throwable"@\n"Throwable"@g' "$arquivo";
        sed -i 's@"StackTrace"@\n"StackTrace"@g' "$arquivo";
    done
}


gerar_top_metodos_pesados() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Classificando métodos pesados..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        touch "$arquivoSaida"
        return
    fi

    local tmpAggregated
    local tmpTop
    tmpAggregated="$(mktemp)"
    tmpTop="$(mktemp)"

    awk -F':' -v baseModuleRegex="$baseModule" '
    function trim(str) {
        sub(/^[[:space:]]+/, "", str)
        sub(/[[:space:]]+$/, "", str)
        return str
    }
    {
        line = $0
        if (line ~ /^--$/) next
        if (index(line, ":") > 0) {
            sub(/^[^:]*:/, "", line)
        }
        line = trim(line)
        if (line ~ /Execucao do metodo / && line ~ /demorou </) {
            metodo = line
            sub(/^.*Execucao do metodo </, "", metodo)
            sub(/> demorou <.*$/, "", metodo)

            tempo = line
            sub(/^.*demorou </, "", tempo)
            sub(/ms>.*/, "", tempo)
            gsub(/[^0-9]/, "", tempo)
            if (tempo == "") next

            tempo += 0
            count[metodo]++
            total[metodo] += tempo
            if (tempo > max[metodo]) {
                max[metodo] = tempo
            }
        }
    }
    END {
        for (metodo in count) {
            media_ms = total[metodo] / count[metodo]
            media_s = media_ms / 1000
            max_s = max[metodo] / 1000
            printf "%s|%d|%.6f|%.6f\n", metodo, count[metodo], media_s, max_s
        }
    }
    ' "$arquivoEntrada" > "$tmpAggregated"

    if [[ ! -s "$tmpAggregated" ]]; then
        touch "$arquivoSaida"
        rm -f "$tmpAggregated" "$tmpTop"
        return
    fi

    sort -t'|' -k3,3nr -k4,4nr "$tmpAggregated" 2>/dev/null | head -n 60 > "$tmpTop"

    awk -F'|' '
    BEGIN {
        printf "%-4s | %-8s | %-11s | %-10s | %s\n", "Rank", "Chamadas", "Média (seg)", "Máx (seg)", "Método"
        printf "%-4s-+-%-8s-+-%-11s-+-%-10s-+-%s\n", "----", "--------", "-----------", "---------", "------"
    }
    {
        printf "%4d | %8d | %11.3f | %10.3f | %s\n", NR, $2, $3, $4, $1
    }
    ' "$tmpTop" > "$arquivoSaida"

    rm -f "$tmpAggregated" "$tmpTop"
}


gerar_top_classes_usadas() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Classificando classes mais acionadas..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        touch "$arquivoSaida"
        return
    fi

    local tmpAggregated
    local tmpTop
    tmpAggregated="$(mktemp)"
    tmpTop="$(mktemp)"

    awk -F':' -v baseModuleRegex="$baseModule" '
    function trim(str) {
        sub(/^[[:space:]]+/, "", str)
        sub(/[[:space:]]+$/, "", str)
        return str
    }
    {
        line = $0
        if (line ~ /^--$/) next
        if (index(line, ":") > 0) {
            sub(/^[^:]*:/, "", line)
        }
        line = trim(line)
        if (line ~ /Execucao do metodo / && line ~ /demorou </) {
            metodo = line
            sub(/^.*Execucao do metodo </, "", metodo)
            sub(/> demorou <.*$/, "", metodo)

            classe = metodo
            sub(/\.[^.]*\(.*/, "", classe)
            if (baseModuleRegex != "") {
                gsub("^" baseModuleRegex "\\.", "", classe)
            }

            tempo = line
            sub(/^.*demorou </, "", tempo)
            sub(/ms>.*/, "", tempo)
            gsub(/[^0-9]/, "", tempo)
            if (tempo == "") next

            tempo += 0
            count[classe]++
            total[classe] += tempo
            if (tempo > max[classe]) {
                max[classe] = tempo
            }
        }
    }
    END {
        for (classe in count) {
            media_ms = total[classe] / count[classe]
            total_s = total[classe] / 1000
            media_s = media_ms / 1000
            max_s = max[classe] / 1000
            printf "%s|%d|%.6f|%.6f|%.6f\n", classe, count[classe], total_s, media_s, max_s
        }
    }
    ' "$arquivoEntrada" > "$tmpAggregated"

    if [[ ! -s "$tmpAggregated" ]]; then
        touch "$arquivoSaida"
        rm -f "$tmpAggregated" "$tmpTop"
        return
    fi

    sort -t'|' -k3,3nr -k4,4nr "$tmpAggregated" 2>/dev/null | head -n 60 > "$tmpTop"

    awk -F'|' '
    BEGIN {
        printf "%-4s | %-8s | %-12s | %-11s | %-10s | %s\n", "Rank", "Chamadas", "Total (seg)", "Média (seg)", "Máx (seg)", "Classe"
        printf "%-4s-+-%-8s-+-%-12s-+-%-11s-+-%-10s-+-%s\n", "----", "--------", "------------", "------------", "----------", "------"
    }
    {
        printf "%4d | %8d | %12.3f | %11.3f | %10.3f | %s\n", NR, $2, $3, $4, $5, $1
    }
    ' "$tmpTop" > "$arquivoSaida"

    rm -f "$tmpAggregated" "$tmpTop"
}


gerar_top_modulos_pesados() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Classificando módulos com maior tempo total..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        touch "$arquivoSaida"
        return
    fi

    local tmpAggregated
    local tmpTop
    tmpAggregated="$(mktemp)"
    tmpTop="$(mktemp)"

    awk -F':' -v baseModuleRegex="$baseModule" '
    function trim(str) {
        sub(/^[[:space:]]+/, "", str)
        sub(/[[:space:]]+$/, "", str)
        return str
    }
    {
        line = $0
        if (line ~ /^--$/) next
        if (index(line, ":") > 0) {
            sub(/^[^:]*:/, "", line)
        }
        line = trim(line)
        if (line ~ /Execucao do metodo / && line ~ /demorou </) {
            metodo = line
            sub(/^.*Execucao do metodo </, "", metodo)
            sub(/> demorou <.*$/, "", metodo)

            base = metodo
            sub(/:.*/, "", base)
            modulo = base
            sub(/\.[^.]*$/, "", modulo)
            sub(/\.[^.]*$/, "", modulo)
            if (baseModuleRegex != "") {
                gsub("^" baseModuleRegex "\\.", "", modulo)
            }

            tempo = line
            sub(/^.*demorou </, "", tempo)
            sub(/ms>.*/, "", tempo)
            gsub(/[^0-9]/, "", tempo)
            if (tempo == "") next

            tempo += 0
            count[modulo]++
            total[modulo] += tempo
            if (tempo > max[modulo]) {
                max[modulo] = tempo
            }
        }
    }
    END {
        for (modulo in count) {
            media_ms = total[modulo] / count[modulo]
            total_s = total[modulo] / 1000
            media_s = media_ms / 1000
            max_s = max[modulo] / 1000
            printf "%s|%d|%.6f|%.6f|%.6f\n", modulo, count[modulo], total_s, media_s, max_s
        }
    }
    ' "$arquivoEntrada" > "$tmpAggregated"

    if [[ ! -s "$tmpAggregated" ]]; then
        touch "$arquivoSaida"
        rm -f "$tmpAggregated" "$tmpTop"
        return
    fi

    sort -t'|' -k3,3nr -k4,4nr "$tmpAggregated" 2>/dev/null | head -n 60 > "$tmpTop"

    awk -F'|' '
    BEGIN {
        printf "%-4s | %-8s | %-12s | %-11s | %-10s | %s\n", "Rank", "Chamadas", "Total (seg)", "Média (seg)", "Máx (seg)", "Módulo"
        printf "%-4s-+-%-8s-+-%-12s-+-%-11s-+-%-10s-+-%s\n", "----", "--------", "------------", "------------", "----------", "------"
    }
    {
        printf "%4d | %8d | %12.3f | %11.3f | %10.3f | %s\n", NR, $2, $3, $4, $5, $1
    }
    ' "$tmpTop" > "$arquivoSaida"

    rm -f "$tmpAggregated" "$tmpTop"
}


gerar_top_uso_metodos() {
    local pastaLogs="$1"
    local arquivoSaida="$2"
    local baseModuleRegex="${baseModule:-}"

    echo "⏳ Classificando métodos mais invocados..."

    if [[ ! -d "$pastaLogs" ]]; then
        touch "$arquivoSaida"
        return
    fi

    python3 - "$pastaLogs" "$arquivoSaida" "$baseModuleRegex" <<'PY'
import sys
import pathlib
import re
from collections import Counter

logs_dir = pathlib.Path(sys.argv[1])
saida = pathlib.Path(sys.argv[2])
base_regex = sys.argv[3]

if not logs_dir.exists():
    saida.touch()
    sys.exit(0)

if base_regex:
    pattern = re.compile(r'at\s+(' + base_regex + r'[A-Za-z0-9_$.]*\.[A-Za-z0-9_$<>]+)\s*\(')
else:
    pattern = re.compile(r'at\s+([A-Za-z0-9_$.]+\.[A-Za-z0-9_$<>]+)\s*\(')

contador = Counter()

for log_path in sorted(logs_dir.rglob('*.log')):
    try:
        with log_path.open(encoding='utf-8', errors='ignore') as handle:
            for line in handle:
                match = pattern.search(line)
                if match:
                    contador[match.group(1)] += 1
    except OSError:
        continue

top = sorted(contador.items(), key=lambda item: (-item[1], item[0]))[:100]

with saida.open('w', encoding='utf-8') as out:
    if not top:
        out.write('')
        sys.exit(0)
    out.write(f"{'Rank':>4} | {'Chamadas':>8} | Metodo\n")
    out.write(f"{'----':>4}-+-{'--------':>8}-+-{'-' * 40}\n")
    for idx, (metodo, total) in enumerate(top, start=1):
        out.write(f"{idx:4d} | {total:8d} | {metodo}\n")
PY
}


gerar_percentis_performance() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Calculando percentis de desempenho..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        touch "$arquivoSaida"
        return
    fi

    local tmpDuracoes
    local tmpOrdenado
    tmpDuracoes="$(mktemp)"
    tmpOrdenado="$(mktemp)"

    awk -F':' '
    function trim(str) {
        sub(/^[[:space:]]+/, "", str)
        sub(/[[:space:]]+$/, "", str)
        return str
    }
    {
        line = $0
        if (line ~ /^--$/) next
        if (index(line, ":") > 0) {
            sub(/^[^:]*:/, "", line)
        }
        line = trim(line)
        if (line ~ /demorou </) {
            tempo = line
            sub(/^.*demorou </, "", tempo)
            sub(/ms>.*/, "", tempo)
            gsub(/[^0-9]/, "", tempo)
            if (tempo == "") next
            print tempo
        }
    }
    ' "$arquivoEntrada" > "$tmpDuracoes"

    if [[ ! -s "$tmpDuracoes" ]]; then
        touch "$arquivoSaida"
        rm -f "$tmpDuracoes" "$tmpOrdenado"
        return
    fi

    sort -n "$tmpDuracoes" > "$tmpOrdenado"
    local total
    total=$(wc -l < "$tmpOrdenado")

    local p50_index p95_index p99_index
    p50_index=$(python3 - "$total" <<'PY'
import math, sys
total = int(sys.argv[1])
print(max(1, math.ceil(total * 0.5)))
PY
)
    p95_index=$(python3 - "$total" <<'PY'
import math, sys
total = int(sys.argv[1])
print(max(1, math.ceil(total * 0.95)))
PY
)
    p99_index=$(python3 - "$total" <<'PY'
import math, sys
total = int(sys.argv[1])
print(max(1, math.ceil(total * 0.99)))
PY
)

    local p50_value p95_value p99_value min_value max_value
    p50_value=$(sed -n "${p50_index}p" "$tmpOrdenado")
    p95_value=$(sed -n "${p95_index}p" "$tmpOrdenado")
    p99_value=$(sed -n "${p99_index}p" "$tmpOrdenado")
    min_value=$(head -n 1 "$tmpOrdenado")
    max_value=$(tail -n 1 "$tmpOrdenado")

    local media
    media=$(awk '{s+=$1} END { if (NR) printf "%.2f", s/NR; }' "$tmpOrdenado")

    {
        echo "Total de medições: $total"
        echo "Média (ms): $media"
        echo "Mínimo (ms): $min_value"
        echo "Máximo (ms): $max_value"
        echo "Percentil 50 (ms): $p50_value"
        echo "Percentil 95 (ms): $p95_value"
        echo "Percentil 99 (ms): $p99_value"
    } > "$arquivoSaida"

    rm -f "$tmpDuracoes" "$tmpOrdenado"
}



gerar_erros_mbean() {
    local pastaLogs="$1"
    local pastaSaida="$2"
    local patternRegex="${patternNomeService:-([A-Za-z0-9_.]+MBean)}"

    echo "⏳ Gerando extracoes por MBean..."
    find "$pastaSaida" -maxdepth 1 -name 'mbean_*.log' -type f -delete 2>/dev/null || true

    python3 - "$pastaLogs" "$pastaSaida" "$patternRegex" <<'PY'
import pathlib
import re
import sys
from collections import defaultdict

pasta_logs = pathlib.Path(sys.argv[1])
pasta_saida = pathlib.Path(sys.argv[2])
pattern_raw = sys.argv[3] if len(sys.argv) > 3 else r'([A-Za-z0-9_.]+MBean)'
pasta_saida.mkdir(parents=True, exist_ok=True)

pattern = re.compile(pattern_raw)
context_pre = 12
context_post = 12

acumulado = defaultdict(list)

for log_path in sorted(pasta_logs.rglob("*.log")):
    try:
        lines = log_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        continue

    total = len(lines)
    for idx, line in enumerate(lines):
        matches = pattern.findall(line)
        if not matches:
            continue

        start = max(0, idx - context_pre)
        end = min(total, idx + context_post + 1)
        trecho = "\n".join(lines[start:end])
        header = f"# Arquivo: {log_path}\n"
        bloco = f"{header}{trecho}\n\n"

        for match in matches:
            nome = match.split(".")[-1]
            seguro = re.sub(r"[^A-Za-z0-9_-]", "_", nome)
            acumulado[seguro].append(bloco)

for nome_mbean, blocos in acumulado.items():
    destino = pasta_saida / f"mbean_{nome_mbean}.log"
    destino.write_text("".join(blocos), encoding="utf-8")
PY
}


gerar_top_modulos_subsistema() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Classificando módulos/subsistemas com maior tempo total..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        touch "$arquivoSaida"
        return
    fi

    local tmpAggregated
    local tmpTop
    tmpAggregated="$(mktemp)"
    tmpTop="$(mktemp)"

    awk -F':' '
    function trim(str) {
        sub(/^[[:space:]]+/, "", str)
        sub(/[[:space:]]+$/, "", str)
        return str
    }
    {
        line = $0
        if (line ~ /^--$/) next
        if (index(line, ":") > 0) {
            sub(/^[^:]*:/, "", line)
        }
        line = trim(line)
        if (line ~ /Execucao do metodo / && line ~ /demorou </) {
            metodo = line
            sub(/^.*Execucao do metodo </, "", metodo)
            sub(/> demorou <.*$/, "", metodo)

            chave = metodo
            if (baseModuleRegex != "") {
                gsub("^" baseModuleRegex "\\.", "", chave)
            }
            split(chave, partes, "\\.")
            if (length(partes) < 3) next
            modulo = partes[1]
            subsistema = partes[2]
            identificador = modulo "/" subsistema

            tempo = line
            sub(/^.*demorou </, "", tempo)
            sub(/ms>.*/, "", tempo)
            gsub(/[^0-9]/, "", tempo)
            if (tempo == "") next

            tempo += 0
            count[identificador]++
            total[identificador] += tempo
            if (tempo > max[identificador]) {
                max[identificador] = tempo
            }
        }
    }
    END {
        for (identificador in count) {
            media_ms = total[identificador] / count[identificador]
            total_s = total[identificador] / 1000
            media_s = media_ms / 1000
            max_s = max[identificador] / 1000
            printf "%s|%d|%.6f|%.6f|%.6f\n", identificador, count[identificador], total_s, media_s, max_s
        }
    }
    ' "$arquivoEntrada" > "$tmpAggregated"

    if [[ ! -s "$tmpAggregated" ]]; then
        touch "$arquivoSaida"
        rm -f "$tmpAggregated" "$tmpTop"
        return
    fi

    sort -t'|' -k3,3nr -k4,4nr "$tmpAggregated" 2>/dev/null | head -n 60 > "$tmpTop"

    awk -F'|' '
    BEGIN {
        printf "%-4s | %-8s | %-12s | %-11s | %-10s | %s\n", "Rank", "Chamadas", "Total (seg)", "Média (seg)", "Máx (seg)", "Módulo/Subsistema"
        printf "%-4s-+-%-8s-+-%-12s-+-%-11s-+-%-10s-+-%s\n", "----", "--------", "------------", "------------", "----------", "-------------------"
    }
    {
        printf "%4d | %8d | %12.3f | %11.3f | %10.3f | %s\n", NR, $2, $3, $4, $5, $1
    }
    ' "$tmpTop" > "$arquivoSaida"

    rm -f "$tmpAggregated" "$tmpTop"
}

gerar_report_data() {
    local pastaBase="$1"
    local dataExecucao="$2"
    local pastaResult="$pastaBase/result"
    local pastaReport="$pastaBase/report"
    local destino="$pastaReport/data/report-data.json"

    echo "⏳ Gerando arquivo JSON para o relatório..."

    if [[ ! -d "$pastaResult" ]]; then
        echo "⚠️ Pasta de resultados \"$pastaResult\" não encontrada; relatório não gerado."
        return
    fi

    if [[ ! -d "$pastaReport" ]]; then
        echo "⚠️ Pasta de relatório \"$pastaReport\" não encontrada; relatório não gerado."
        return
    fi

    mkdir -p "$(dirname "$destino")"

    python3 - "$pastaResult" "$destino" "$dataExecucao" <<'PY'
import json
import re
import sys
import datetime
from pathlib import Path

base_dir = Path(sys.argv[1])
destino = Path(sys.argv[2])
execucao = sys.argv[3]

def parse_table(path: Path, columns):
    rows = []
    if not path.exists():
        return rows
    pattern_int = re.compile(r'^-?\d+$')
    with path.open(encoding='utf-8', errors='ignore') as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith('-') or '|' not in raw_line:
                continue
            parts = [piece.strip() for piece in raw_line.split('|')]
            if len(parts) < len(columns):
                continue
            if columns[0].startswith('int:') and not pattern_int.match(parts[0]):
                continue
            row = {}
            try:
                for idx, name in enumerate(columns):
                    value = parts[idx]
                    if name.startswith('int:'):
                        row[name.split(':', 1)[1]] = int(value)
                    elif name.startswith('float:'):
                        row[name.split(':', 1)[1]] = float(value.replace(',', '.'))
                    else:
                        row[name] = value
            except ValueError:
                continue
            rows.append(row)
    return rows

def parse_performance(path: Path):
    data = {}
    if not path.exists():
        return data
    pattern = re.compile(r'(.*?):\s*(.*)')
    with path.open(encoding='utf-8', errors='ignore') as handle:
        for line in handle:
            match = pattern.match(line.strip())
            if not match:
                continue
            key, value = match.groups()
            mapping = {
                'Total de medições': 'total_medicoes',
                'Média (ms)': 'media_ms',
                'Mínimo (ms)': 'min_ms',
                'Máximo (ms)': 'max_ms',
                'Percentil 50 (ms)': 'p50_ms',
                'Percentil 95 (ms)': 'p95_ms',
                'Percentil 99 (ms)': 'p99_ms',
            }
            key_norm = mapping.get(key, key)
            try:
                parsed = float(value.replace(',', '.')) if '.' in value or ',' in value else int(value)
            except ValueError:
                parsed = value
            data[key_norm] = parsed
    return data

def parse_ranked(path: Path, schema):
    rows = []
    if not path.exists():
        return rows
    with path.open(encoding='utf-8', errors='ignore') as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith('Rank') or set(line) <= {'-', '+', ' '} or '|' not in raw_line:
                continue
            parts = [piece.strip() for piece in raw_line.split('|')]
            if len(parts) < len(schema):
                continue
            row = {}
            skip = False
            for part, (kind, key) in zip(parts, schema):
                try:
                    if kind == 'int':
                        row[key] = int(part)
                    elif kind == 'float':
                        row[key] = float(part.replace(',', '.'))
                    else:
                        row[key] = part
                except ValueError:
                    skip = True
                    break
            if not skip:
                rows.append(row)
    return rows

report_data = {
    'fonte': str(base_dir),
    'geradoEm': datetime.datetime.now().isoformat(timespec='seconds'),
    'execucao': execucao,
    'contadores': parse_table(base_dir / 'indicadores' / 'tabela-contadores.txt', ['int:quantidade', 'descricao']),
    'mensagensNegocio': parse_table(base_dir / 'indicadores' / 'tabela-mensagens-negocio.txt', ['int:quantidade', 'mensagem']),
    'desempenho': parse_performance(base_dir / 'extracoes' / 'stats_performance_percentis.log'),
    'topClasses': parse_ranked(base_dir / 'extracoes' / 'top_classes_usadas.log', [
        ('int', 'rank'), ('int', 'chamadas'), ('float', 'total_s'), ('float', 'media_s'), ('float', 'max_s'), ('str', 'classe')
    ]),
    'topMetodos': parse_ranked(base_dir / 'extracoes' / 'top_metodos_pesados.log', [
        ('int', 'rank'), ('int', 'chamadas'), ('float', 'media_s'), ('float', 'max_s'), ('str', 'metodo')
    ]),
    'topUsoMetodos': parse_ranked(base_dir / 'extracoes' / 'top_uso_metodo.log', [
        ('int', 'rank'), ('int', 'chamadas'), ('str', 'metodo')
    ]),
    'topModulos': parse_ranked(base_dir / 'extracoes' / 'top_modulos_pesados.log', [
        ('int', 'rank'), ('int', 'chamadas'), ('float', 'total_s'), ('float', 'media_s'), ('float', 'max_s'), ('str', 'modulo')
    ]),
    'topModulosSubsistema': parse_ranked(base_dir / 'extracoes' / 'top_modulos_subsistema.log', [
        ('int', 'rank'), ('int', 'chamadas'), ('float', 'total_s'), ('float', 'media_s'), ('float', 'max_s'), ('str', 'modulo_subsistema')
    ]),
}

destino.write_text(json.dumps(report_data, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Relatório consolidado em {destino}')
PY
    local status=$?
    if [[ $status -eq 0 ]]; then
        echo "✅ Arquivo $destino atualizado."
    else
        echo "❌ Falha ao gerar $destino."
    fi
}


# Função para processar logs para uma data específica
process_logs() {
    local data=$(date +"%Y-%m-%d")
    local pastaBase="$WORKDIR/$stagePath/logs-$data"
    local pastaLogs="$pastaBase/logs"
    local pastaLogsNormalizados="$pastaBase/logs-normalizados"
    local pastaLogsSemQuebra="$pastaBase/logs-sem-quebra"
    local pastaLogsJBossUnificados="$pastaBase/logs-jboss-unificados"
    local pastaBaseResult="$pastaBase/result"
    local pastaBaseIndicadores="$pastaBaseResult/indicadores"
    local pastaBaseExtracoes="$pastaBaseResult/extracoes"
    local pastaReportTemplate="$WORKDIR/report"
    local pastaReportDestino="$pastaBase/report"
    local nomeArquivoContador="$(mktemp)"
    local nomeArquivoContadorTmp2="$(mktemp)"
    local nomeArquivoContadorTabela="$pastaBaseIndicadores/tabela-contadores.txt"
    local nomeArquivoMensagensNegocio="$pastaBaseIndicadores/tabela-mensagens-negocio.txt"
    local pastaFonteLogs
    local pasta

    echo -e "\n🧯 Iniciando a análise em $data\n"
    echo "Pasta destino dos logs: $pastaLogs"

    rm -rf "$stagePath"
    mkdir -p "$stagePath"
    mkdir -p "$pastaBase"
    mkdir -p "$pastaLogs"
    mkdir -p "$pastaBaseExtracoes"
    mkdir -p "$pastaBaseIndicadores"

    if [[ -d "$pastaReportTemplate" ]]; then
        cp -R "$pastaReportTemplate" "$pastaBase/"
    else
        echo "⚠️ Template de relatório não encontrado em \"$pastaReportTemplate\"."
    fi

    ############################# Coleta dos logs #############################################

    copiar_logs_servidores "$data" "$pastaLogs"

    pastaFonteLogs="$pastaLogs"

    if [[ "${normalizaLogsJBoss,,}" == "true" ]]; then
        normalizar_logs_jboss "$pastaFonteLogs" "$pastaLogsJBossUnificados"
        pastaFonteLogs="$pastaLogsJBossUnificados"
    fi

    if [[ "${normalizaLogs,,}" == "true" ]]; then
        normalizar_logs_mensagens "$pastaFonteLogs" "$pastaLogsNormalizados"
        pastaFonteLogs="$pastaLogsNormalizados"
    fi

    if [[ "${removeQuebras,,}" == "true" ]]; then
        remover_quebras_logs "$pastaFonteLogs" "$pastaLogsSemQuebra"
        pastaFonteLogs="$pastaLogsSemQuebra"
    fi

    ############################# Inicio extrações #############################################

    echo -e "\n 🔥 Fazendo as extrações...\n"

    echo "⏳ Processando extratores de texto simples..."
    for entry in "${extratoresArray[@]}"; do
        IFS='|' read -r termo arquivo <<< "$entry"
        echo "Comando: grep -ri -F \"$termo\" \"$pastaFonteLogs\" > $pastaBaseExtracoes/$arquivo"
        grep -ri -F "$termo" "$pastaFonteLogs" > "$pastaBaseExtracoes/$arquivo"
    done
    gerar_top_metodos_pesados "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/top_metodos_pesados.log"
    gerar_top_uso_metodos "$pastaFonteLogs" "$pastaBaseExtracoes/top_uso_metodo.log"
    gerar_top_classes_usadas "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/top_classes_usadas.log"
    gerar_top_modulos_pesados "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/top_modulos_pesados.log"
    gerar_top_modulos_subsistema "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/top_modulos_subsistema.log"
    gerar_percentis_performance "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/stats_performance_percentis.log"
    #gerar_erros_mbean "$pastaFonteLogs" "$pastaBaseExtracoes"

    ##########################################################################################

    echo "⏳ Processando contadores de texto simples..."
    rm -f "$nomeArquivoContador"
    for entry in "${contadoresArray[@]}"; do
        IFS='|' read -r termo msg <<< "$entry"
        echo  "Comando: total=\$(grep -ri -c -F \"$termo\" \"$pastaFonteLogs\" | awk -F':' '{s+=$2} END {print s}')"
        local total=$(grep -ri -c -F "$termo" "$pastaFonteLogs" | awk -F':' '{s+=$2} END {print s}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done

    ##########################################################################################

    echo "⏳ Processando contadores de regex..."
    for entry in "${contadoresRegexArray[@]}"; do
        IFS='#' read -r termo msg <<< "$entry"
        echo "Comando total=\$(grep -ri -c -E \"$termo\" \"$pastaFonteLogs\" | awk -F':' '{s+=$2} END {print s}')"
        local total=$(grep -ri -c -E "$termo" "$pastaFonteLogs" | awk -F':' '{s+=$2} END {print s}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done

    ##########################################################################################

    echo "⏳ Processando acumuladores de regex..."
    for entry in "${acumuladoresArray[@]}"; do
        IFS='|' read -r termo termo2 msg <<< "$entry"
        echo "Comando: total=\$(grep -ri -E -o \"$termo\" \"$pastaFonteLogs\" | grep -E -o \"$termo2\" | awk '{s+=\$1} END {print (s ? s : 0)}')"
        local total=$(grep -ri -E -o "$termo" "$pastaFonteLogs" | grep -E -o "$termo2" | awk '{s+=$1} END {print (s ? s : 0)}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done


    ##########################################################################################


    echo "⏳ Ordenando contadores..."
    cat "$nomeArquivoContador" | sort > "$nomeArquivoContadorTmp2"
    formatArquivoComoTabela "$nomeArquivoContadorTmp2" "$nomeArquivoContadorTabela"
    rm -f "$nomeArquivoContador"
    rm -f "$nomeArquivoContadorTmp2"

   ##########################################################################################

    echo "⏳ Processando indicadores de regex condicionais..."
    for entry in "${contadoresCondicionaisArray[@]}"; do
        IFS='|' read -r regex condicao nomeArquivoAcumCond <<< "$entry"
        local nomeArquivoAcumCondTmp1="$(mktemp)"
        rm -f "$nomeArquivoAcumCondTmp1"
        rm -f "$nomeArquivoAcumCond"
        while IFS= read -r line; do
            processaAcum "$line" "$regex" "$nomeArquivoAcumCondTmp1" "$condicao"
        done < <(grep -E -ri "$regex" "$pastaFonteLogs")
        if [ -f "$nomeArquivoAcumCondTmp1" ]; then
          uniq "$nomeArquivoAcumCondTmp1" | sort -n -r > "$pastaBaseExtracoes/$nomeArquivoAcumCond"
          rm -f "$nomeArquivoAcumCondTmp1"
        fi
    done

    echo "-----------------------------------------------------------------------------------"

    if [[ "${normalizaQuebra,,}" == "true" ]]; then
        normalizar_quebras_arquivos "$pastaBaseExtracoes" "extrações"
        normalizar_quebras_arquivos "$pastaBaseIndicadores" "indicadores"
    fi

    gerar_report_data "$pastaBase" "$data"
}

################################ MAIN ##########################################################


echo -e "\033[01;33mAnalisador de logs scanlog\033[01;37m ( Versão: $VERSAO_SCRIPT Data: $CURRENT_DATE )"
process_logs
