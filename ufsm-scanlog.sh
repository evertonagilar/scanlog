#!/bin/bash

########################################################################################################
#
# Author: Everton de Vargas Agilar
# Date: 10/08/2024
#
# Ferramenta analisador de log sieweb-scanlog
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

# Carrega as variáveis de configuração dos IPs dos servidores
source config.inc
source modelo.inc

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


gerar_top_metodos_pesados() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Classificando métodos pesados..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        echo "Sem dados de desempenho encontrados para gerar ranking." > "$arquivoSaida"
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
            media = total[metodo] / count[metodo]
            printf "%s|%d|%.2f|%d\n", metodo, count[metodo], media, max[metodo]
        }
    }
    ' "$arquivoEntrada" > "$tmpAggregated"

    if [[ ! -s "$tmpAggregated" ]]; then
        echo "Sem dados de desempenho encontrados para gerar ranking." > "$arquivoSaida"
        rm -f "$tmpAggregated" "$tmpTop"
        return
    fi

    sort -t'|' -k3,3nr -k4,4nr "$tmpAggregated" 2>/dev/null | head -n 30 > "$tmpTop"

    awk -F'|' '
    BEGIN {
        printf "%-4s | %-8s | %-11s | %-10s | %s\n", "Rank", "Chamadas", "Média (ms)", "Máx (ms)", "Método"
        printf "%-4s-+-%-8s-+-%-11s-+-%-10s-+-%s\n", "----", "--------", "-----------", "----------", "------"
    }
    {
        printf "%4d | %8d | %11.2f | %10d | %s\n", NR, $2, $3, $4, $1
    }
    ' "$tmpTop" > "$arquivoSaida"

    rm -f "$tmpAggregated" "$tmpTop"
}


gerar_top_classes_usadas() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Classificando classes mais acionadas..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        echo "Sem dados de desempenho encontrados para gerar ranking de classes." > "$arquivoSaida"
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

            classe = metodo
            sub(/\.[^.]*\(.*/, "", classe)

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
            media = total[classe] / count[classe]
            printf "%s|%d|%d|%.2f|%d\n", classe, count[classe], total[classe], media, max[classe]
        }
    }
    ' "$arquivoEntrada" > "$tmpAggregated"

    if [[ ! -s "$tmpAggregated" ]]; then
        echo "Sem dados de desempenho encontrados para gerar ranking de classes." > "$arquivoSaida"
        rm -f "$tmpAggregated" "$tmpTop"
        return
    fi

    sort -t'|' -k3,3nr -k4,4nr "$tmpAggregated" 2>/dev/null | head -n 30 > "$tmpTop"

    awk -F'|' '
    BEGIN {
        printf "%-4s | %-8s | %-12s | %-11s | %-10s | %s\n", "Rank", "Chamadas", "Total (ms)", "Média (ms)", "Máx (ms)", "Classe"
        printf "%-4s-+-%-8s-+-%-12s-+-%-11s-+-%-10s-+-%s\n", "----", "--------", "------------", "-----------", "----------", "------"
    }
    {
        printf "%4d | %8d | %12d | %11.2f | %10d | %s\n", NR, $2, $3, $4, $5, $1
    }
    ' "$tmpTop" > "$arquivoSaida"

    rm -f "$tmpAggregated" "$tmpTop"
}


gerar_top_modulos_pesados() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Classificando módulos com maior tempo total..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        echo "Sem dados de desempenho encontrados para gerar ranking de módulos." > "$arquivoSaida"
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

            base = metodo
            sub(/:.*/, "", base)
            modulo = base
            sub(/\.[^.]*$/, "", modulo)
            sub(/\.[^.]*$/, "", modulo)

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
            media = total[modulo] / count[modulo]
            printf "%s|%d|%d|%.2f|%d\n", modulo, count[modulo], total[modulo], media, max[modulo]
        }
    }
    ' "$arquivoEntrada" > "$tmpAggregated"

    if [[ ! -s "$tmpAggregated" ]]; then
        echo "Sem dados de desempenho encontrados para gerar ranking de módulos." > "$arquivoSaida"
        rm -f "$tmpAggregated" "$tmpTop"
        return
    fi

    sort -t'|' -k3,3nr -k4,4nr "$tmpAggregated" 2>/dev/null | head -n 30 > "$tmpTop"

    awk -F'|' '
    BEGIN {
        printf "%-4s | %-8s | %-12s | %-11s | %-10s | %s\n", "Rank", "Chamadas", "Total (ms)", "Média (ms)", "Máx (ms)", "Módulo"
        printf "%-4s-+-%-8s-+-%-12s-+-%-11s-+-%-10s-+-%s\n", "----", "--------", "------------", "-----------", "----------", "------"
    }
    {
        printf "%4d | %8d | %12d | %11.2f | %10d | %s\n", NR, $2, $3, $4, $5, $1
    }
    ' "$tmpTop" > "$arquivoSaida"

    rm -f "$tmpAggregated" "$tmpTop"
}


gerar_percentis_performance() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Calculando percentis de desempenho..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        echo "Sem dados de desempenho encontrados para calcular percentis." > "$arquivoSaida"
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
        echo "Sem dados de desempenho encontrados para calcular percentis." > "$arquivoSaida"
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


gerar_motivos_gateway_pix() {
    local pastaLogs="$1"
    local arquivoSaida="$2"

    echo "⏳ Consolidando motivos de erro do gateway PIX..."

    local tmp
    tmp="$(mktemp)"

    grep -R -h "motivo:" "$pastaLogs" 2>/dev/null | \
        awk '
        {
            texto = $0
            split(texto, arr, "motivo:")
            if (length(arr) < 2) next
            msg = arr[2]
            gsub(/[][]/, "", msg)
            gsub(/[,}].*$/, "", msg)
            gsub(/[[:space:]]+$/, "", msg)
            gsub(/^[[:space:]]+/, "", msg)
            if (msg == "") next
            count[msg]++
        }
        END {
            for (msg in count) {
                printf "%d|%s\n", count[msg], msg
            }
        }' > "$tmp"

    if [[ ! -s "$tmp" ]]; then
        echo "Nenhum motivo de erro PIX encontrado." > "$arquivoSaida"
        rm -f "$tmp"
        return
    fi

    {
        printf "%-8s | %s\n", "Ocorr.", "Motivo"
        printf "%-8s-+-%s\n", "--------", "-----------------------------------------------"
        sort -t'|' -k1,1nr "$tmp" | awk -F'|' '{ printf "%8d | %s\n", $1, $2 }'
    } > "$arquivoSaida"

    rm -f "$tmp"
}


gerar_colecoes_assumindo_primeiro() {
    local pastaLogs="$1"
    local arquivoSaida="$2"

    echo "⏳ Consolidando mensagens de coleção duplicada..."

    local tmp
    tmp="$(mktemp)"

    grep -R -h "retornou mais de um resultado. Assumindo o primeiro" "$pastaLogs" 2>/dev/null | \
        awk '
        {
            texto = $0
            sub(/^.*Colecao de[[:space:]]+/, "", texto)
            sub(/[[:space:]]+retornou.*/, "", texto)
            if (texto == "") next
            count[texto]++
        }
        END {
            for (texto in count) {
                printf "%d|%s\n", count[texto], texto
            }
        }' > "$tmp"

    if [[ ! -s "$tmp" ]]; then
        echo "Nenhuma coleção com múltiplos resultados identificada." > "$arquivoSaida"
        rm -f "$tmp"
        return
    fi

    {
        printf "%-8s | %s\n", "Ocorr.", "Coleção"
        printf "%-8s-+-%s\n", "--------", "-----------------------------------------------"
        sort -t'|' -k1,1nr "$tmp" | awk -F'|' '{ printf "%8d | %s\n", $1, $2 }'
    } > "$arquivoSaida"

    rm -f "$tmp"
}


gerar_top_modulos_subsistema() {
    local arquivoEntrada="$1"
    local arquivoSaida="$2"

    echo "⏳ Classificando módulos/subsistemas com maior tempo total..."

    if [[ ! -f "$arquivoEntrada" || ! -s "$arquivoEntrada" ]]; then
        echo "Sem dados de desempenho encontrados para gerar ranking de módulos/subsistemas." > "$arquivoSaida"
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
            sub(/br\.ufsm\.cpd\.sie\./, "", chave)
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
            media = total[identificador] / count[identificador]
            printf "%s|%d|%d|%.2f|%d\n", identificador, count[identificador], total[identificador], media, max[identificador]
        }
    }
    ' "$arquivoEntrada" > "$tmpAggregated"

    if [[ ! -s "$tmpAggregated" ]]; then
        echo "Sem dados de desempenho encontrados para gerar ranking de módulos/subsistemas." > "$arquivoSaida"
        rm -f "$tmpAggregated" "$tmpTop"
        return
    fi

    sort -t'|' -k3,3nr -k4,4nr "$tmpAggregated" 2>/dev/null | head -n 30 > "$tmpTop"

    awk -F'|' '
    BEGIN {
        printf "%-4s | %-8s | %-12s | %-11s | %-10s | %s\n", "Rank", "Chamadas", "Total (ms)", "Média (ms)", "Máx (ms)", "Módulo/Subsistema"
        printf "%-4s-+-%-8s-+-%-12s-+-%-11s-+-%-10s-+-%s\n", "----", "--------", "------------", "-----------", "----------", "-------------------"
    }
    {
        printf "%4d | %8d | %12d | %11.2f | %10d | %s\n", NR, $2, $3, $4, $5, $1
    }
    ' "$tmpTop" > "$arquivoSaida"

    rm -f "$tmpAggregated" "$tmpTop"
}

gerar_report_data() {
    local pastaBase="$1"
    local dataExecucao="$2"
    local pastaResult="$pastaBase/result"
    local destino="report/data/report-data.json"

    echo "⏳ Gerando arquivo JSON para o relatório..."

    if [[ ! -d "$pastaResult" ]]; then
        echo "⚠️ Pasta de resultados \"$pastaResult\" não encontrada; relatório não gerado."
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
        ('int', 'rank'), ('int', 'chamadas'), ('int', 'total_ms'), ('float', 'media_ms'), ('int', 'max_ms'), ('str', 'classe')
    ]),
    'topMetodos': parse_ranked(base_dir / 'extracoes' / 'top_metodos_pesados.log', [
        ('int', 'rank'), ('int', 'chamadas'), ('float', 'media_ms'), ('int', 'max_ms'), ('str', 'metodo')
    ]),
    'topModulos': parse_ranked(base_dir / 'extracoes' / 'top_modulos_pesados.log', [
        ('int', 'rank'), ('int', 'chamadas'), ('int', 'total_ms'), ('float', 'media_ms'), ('int', 'max_ms'), ('str', 'modulo')
    ]),
    'topModulosSubsistema': parse_ranked(base_dir / 'extracoes' / 'top_modulos_subsistema.log', [
        ('int', 'rank'), ('int', 'chamadas'), ('int', 'total_ms'), ('float', 'media_ms'), ('int', 'max_ms'), ('str', 'modulo')
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
    local pastaBase="$stagePath/logs-$data"
    local pastaLogs="$pastaBase/logs"
    local pastaLogsNormalizados="$pastaBase/logs-normalizados"
    local pastaBaseIndicadores="$pastaBase/result/indicadores"
    local pastaBaseExtracoes="$pastaBase/result/extracoes"
    local nomeArquivoContador="$(mktemp)"
    local nomeArquivoContadorTmp2="$(mktemp)"
    local nomeArquivoContadorTabela="$pastaBaseIndicadores/tabela-contadores.txt"
    local nomeArquivoMensagensNegocio="$pastaBaseIndicadores/tabela-mensagens-negocio.txt"
    local pasta

    echo -e "\n🧯 Iniciando a análise em $data\n"
    echo "Pasta destino dos logs: $pastaLogs"

    mkdir -p "$pastaBase"
    mkdir -p "$pastaLogs"
    mkdir -p "$pastaBaseExtracoes"
    mkdir -p "$pastaBaseIndicadores"
    rm -f "$pastaBaseExtracoes"/*.log
    rm -f "$pastaBaseIndicadores"/*.txt
    rm -rf "$pastaLogsNormalizados"

    ############################# Coleta dos logs #############################################

    copiar_logs_servidores "$data" "$pastaLogs"
    normalizar_logs_mensagens "$pastaLogs" "$pastaLogsNormalizados"

    ############################# Inicio extrações #############################################

    echo -e "\n 🔥 Fazendo as extrações...\n"

    echo "⏳ Processando extratores de texto simples..."
    for entry in "${extratoresArray[@]}"; do
        IFS='|' read -r termo contexto_a contexto_b arquivo <<< "$entry"
        echo "Comando: grep -ri -F \"$termo\" -A \"$contexto_a\" -B \"$contexto_b\" \"$pastaLogsNormalizados\" > $pastaBaseExtracoes/$arquivo"
        grep -ri -F "$termo" -A "$contexto_a" -B "$contexto_b" "$pastaLogsNormalizados" > "$pastaBaseExtracoes/$arquivo"
    done
    gerar_top_metodos_pesados "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/top_metodos_pesados.log"
    gerar_top_classes_usadas "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/top_classes_usadas.log"
    gerar_top_modulos_pesados "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/top_modulos_pesados.log"
    gerar_top_modulos_subsistema "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/top_modulos_subsistema.log"
    gerar_percentis_performance "$pastaBaseExtracoes/alert_performance_warning.log" "$pastaBaseExtracoes/stats_performance_percentis.log"
    gerar_motivos_gateway_pix "$pastaLogsNormalizados" "$pastaBaseExtracoes/motivos_gateway_pix.log"
    gerar_colecoes_assumindo_primeiro "$pastaLogsNormalizados" "$pastaBaseExtracoes/colecoes_assumindo_primeiro.log"

    ##########################################################################################

    echo "⏳ Processando contadores de texto simples..."
    rm -f "$nomeArquivoContador"
    for entry in "${contadoresArray[@]}"; do
        IFS='|' read -r termo msg <<< "$entry"
        echo  "Comando: total=\$(grep -ri -c -F \"$termo\" \"$pastaLogsNormalizados\" | awk -F':' '{s+=$2} END {print s}')"
        local total=$(grep -ri -c -F "$termo" "$pastaLogsNormalizados" | awk -F':' '{s+=$2} END {print s}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done

    ##########################################################################################

    echo "⏳ Processando contadores de regex..."
    for entry in "${contadoresRegexArray[@]}"; do
        IFS='#' read -r termo msg <<< "$entry"
        echo "Comando total=\$(grep -ri -c -E \"$termo\" \"$pastaLogsNormalizados\" | awk -F':' '{s+=$2} END {print s}')"
        local total=$(grep -ri -c -E "$termo" "$pastaLogsNormalizados" | awk -F':' '{s+=$2} END {print s}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done

    ##########################################################################################

    echo "⏳ Processando acumuladores de regex..."
    for entry in "${acumuladoresArray[@]}"; do
        IFS='|' read -r termo termo2 msg <<< "$entry"
        echo "Comando: total=\$(grep -ri -E -o \"$termo\" \"$pastaLogsNormalizados\" | grep -E -o \"$termo2\" | awk '{s+=\$1} END {print (s ? s : 0)}')"
        local total=$(grep -ri -E -o "$termo" "$pastaLogsNormalizados" | grep -E -o "$termo2" | awk '{s+=$1} END {print (s ? s : 0)}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done


    ##########################################################################################


    echo "⏳ Ordenando contadores..."
    cat "$nomeArquivoContador" | sort > "$nomeArquivoContadorTmp2"
    formatArquivoComoTabela "$nomeArquivoContadorTmp2" "$nomeArquivoContadorTabela"
    rm -f "$nomeArquivoContador"
    rm -f "$nomeArquivoContadorTmp2"

    ##########################################################################################

    echo "⏳ Processando mensagens de negócio..."
    local resultadosArray=()
    rm -f "$nomeArquivoMensagensNegocio"
    for padrao in "${extratorMensagemNegocioArray[@]}"; do
        while IFS= read -r resultado; do
            [[ -z "$resultado" ]] && continue
            resultadosArray+=("$resultado")  # Adiciona o item ao array
        done < <(grep -ri -h -E -o "$padrao" "$pastaLogsNormalizados" \
            | tr -d '(){}|' \
            | sed 's/^[[:space:]]*//' \
            | grep -E -v "(Caused by|ConstraintViolationException|org\.hibernate|javax\.persistence|javax\.ejb|thrown from|Row was updated|codigoErro|query|return|unique|ResultSet|Transaction|aborted|exception|failure|underlying|java\.rmi|null identifier|Unable to find|property|googleapis|attempted merging)" \
            | sort -u)
    done
    printf "%10s | %-50s\n" "Quantidade" "Mensagens de negócio" > "$nomeArquivoMensagensNegocio"
    printf "%10s | %-50s\n" "----------" "--------------------------------------------------" >> "$nomeArquivoMensagensNegocio"
    for termo in "${resultadosArray[@]}"; do
        echo "Comando: total=\$(grep -ri -c -F \"$termo\" \"$pastaLogsNormalizados\" | awk -F':' '{s+=$2} END {print s}')"
        total=$(grep -ri -c -F "$termo" "$pastaLogsNormalizados" | awk -F':' '{s+=$2} END {print s}')
        printf "%10s | %-50s\n" "$total" "$termo" >> "$nomeArquivoMensagensNegocio"
    done

    ##########################################################################################

    echo "⏳ Processando indicadores de regex condicionais..."
    for entry in "${contadoresCondicionaisArray[@]}"; do
        IFS='|' read -r regex condicao nomeArquivoAcumCond <<< "$entry"
        local nomeArquivoAcumCondTmp1="$(mktemp)"
        rm -f "$nomeArquivoAcumCondTmp1"
        rm -f "$nomeArquivoAcumCond"
        while IFS= read -r line; do
            processaAcum "$line" "$regex" "$nomeArquivoAcumCondTmp1" "$condicao"
        done < <(grep -E -ri "$regex" "$pastaLogsNormalizados")
        if [ -f "$nomeArquivoAcumCondTmp1" ]; then
          uniq "$nomeArquivoAcumCondTmp1" | sort -n -r > "$pastaBaseExtracoes/$nomeArquivoAcumCond"
          rm -f "$nomeArquivoAcumCondTmp1"
        fi
    done

    echo "-----------------------------------------------------------------------------------"

    gerar_report_data "$pastaBase" "$data"
}

################################ MAIN ##########################################################


echo -e "\033[01;33mAnalisador de logs sieweb-scanlog\033[01;37m ( Versão: $VERSAO_SCRIPT Data: $CURRENT_DATE )"
process_logs
