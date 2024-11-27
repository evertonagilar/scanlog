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

VERSAO_SCRIPT='1.0.0'
CURRENT_DATE=$(date '+%d/%m/%Y %H:%M:%S')

# Carrega as variáveis de configuração dos IPs dos servidores
source config.inc
source modelo.inc

# Função para validar o formato de data
is_valid_date() {
    date -d "$1" +"%Y-%m-%d" >/dev/null 2>&1
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
  if [[ $line =~ $regex ]] ; then
      local param1="${BASH_REMATCH[1]}"
      local param2="${BASH_REMATCH[2]}"
      local expr=$(echo $condicao | sed "s/\$param2/$param2/")
    if eval "[[ $expr ]]"; then
       echo "$param2|$param1" >> "$arquivo"
    fi
  fi
}

# Função para copiar logs dos servidores configurados
copiar_logs_servidores() {
    local data="$1"
    local pastaLogs="$2"
    echo -e "\nObtendo os arquivos de logs dos servidores configurados..."
    for servidor in "${servidores[@]}"; do
        local ip_log_path="${servidor%:*}"
        local remote_path="${servidor#*:}"
        local pastaServidor="$pastaLogs/$(echo "$ip_log_path" | tr '.' '_')"
        mkdir -p "$pastaServidor"
        echo "📂 Copiando logs de $ip_log_path..."
        scp -P $sshPort "$ip_log_path:$remote_path" "$pastaServidor/"
        if [ $? -eq 0 ]; then
            echo "✅ Logs copiados com sucesso de $ip_log_path."
        else
            echo "❌ Falha ao copiar logs de $ip_log_path."
        fi
    done
}


# Função para processar logs para uma data específica
process_logs_for_date() {
    local data="$1"
    local pastaBase="$stagePath/logs/logs-$data"
    local pastaLogs="$pastaBase/logs"
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
    mkdir -p "$pastaBaseExtracoes"
    mkdir -p "$pastaBaseIndicadores"
    rm -f "$pastaBaseExtracoes"/*.log
    rm -f "$pastaBaseIndicadores"/*.txt
    cp modelo.inc "$pastaBase/modelo-sieweb-scanlog-para-consulta.inc"

    ############################# Coleta dos logs #############################################

    copiar_logs_servidores "$data" "$pastaLogs"

    ############################# Inicio extrações #############################################

    echo -e "\n 🔥 Fazendo as extrações...\n"

    echo "⏳ Processando extratores de texto simples..."
    for entry in "${extratoresArray[@]}"; do
        IFS='|' read -r termo contexto_a contexto_b arquivo <<< "$entry"
        (cd "$pastaLogs" && grep -ri -F "$termo" -A "$contexto_a" -B "$contexto_b" > "$pastaBaseExtracoes/$arquivo")
    done

    ##########################################################################################

    echo "⏳ Processando contadores de texto simples..."
    rm -f "$nomeArquivoContador"
    for entry in "${contadoresArray[@]}"; do
        IFS='|' read -r termo msg <<< "$entry"
        local total=$(cd "$pastaLogs" && grep -ri -c -F "$termo" | awk -F':' '{s+=$2} END {print s}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done

    ##########################################################################################

    echo "⏳ Processando contadores de regex..."
    for entry in "${contadoresRegexArray[@]}"; do
        IFS='#' read -r termo msg <<< "$entry"
        local total=$(cd "$pastaLogs" && grep -ri -c -E "$termo" | awk -F':' '{s+=$2} END {print s}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done

    ##########################################################################################

    echo "⏳ Processando acumuladores de regex..."
    for entry in "${acumuladoresArray[@]}"; do
        IFS='|' read -r termo termo2 msg <<< "$entry"
        local total=$(grep -ri -E -o "$termo" "$pastaLogs/timers" | grep -E -o "$termo2" | awk '{s+=$1} END {print (s ? s : 0)}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done


    ##########################################################################################


    # Ordena os contadores
    cat "$nomeArquivoContador" | sort > "$nomeArquivoContadorTmp2"
    formatArquivoComoTabela "$nomeArquivoContadorTmp2" "$nomeArquivoContadorTabela"
    rm -f "$nomeArquivoContador"
    rm -f "$nomeArquivoContadorTmp2"

    ##########################################################################################

    local resultadosArray=()
    rm -f "$nomeArquivoMensagensNegocio"
    for padrao in "${extratorMensagemNegocioArray[@]}"; do
        while IFS= read -r resultado; do
            resultadosArray+=("$resultado")  # Adiciona o item ao array
        done < <(grep -ri -E -o "$padrao" "$pastaLogs" | tr -d '(){}|' | awk -F':' '{print $3}' | grep -E -v "(Caused by|ConstraintViolationException|org\.hibernate|javax\.persistence|javax\.ejb|thrown from|Row was updated|codigoErro|query|return|unique|ResultSet|Transaction|aborted|exception|failure|underlying|java\.rmi|null identifier|Unable to find|property|googleapis|attempted merging)" | sort | uniq)
    done
    printf "%10s | %-50s\n" "Quantidade" "Mensagens de negócio" > "$nomeArquivoMensagensNegocio"
    printf "%10s | %-50s\n" "----------" "--------------------------------------------------" >> "$nomeArquivoMensagensNegocio"
    for termo in "${resultadosArray[@]}"; do
        total=$(cd "$pastaLogs" && grep -ri -c -E "$termo" | awk -F':' '{s+=$2} END {print s}')
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
            processaAcum "$line" "$regex" "$nomeArquivoAcumCondTmp1"
        done < <(grep -E -ri "$regex" "$pastaLogs")
        uniq "$nomeArquivoAcumCondTmp1" | sort -n -r > "$pastaBaseExtracoes/$nomeArquivoAcumCond"
        rm -f $nomeArquivoAcumCondTmp1
    done

    echo "-----------------------------------------------------------------------------------"
}

################################ MAIN ##########################################################


echo -e "\033[01;33mAnalisador de logs sieweb-scanlog\033[01;37m ( Versão: $VERSAO_SCRIPT Data: $CURRENT_DATE )"

# Definir a data padrão para ontem
data=$(date -d "yesterday" +"%Y-%m-%d")

# Verifica se um argumento foi passado
if [ -n "$1" ]; then
    # Verifica se o argumento é um intervalo de dias (formato DD-DD)
    if [[ "$1" =~ ^([0-9]{1,2})-([0-9]{1,2})$ ]]; then
        start_day=${BASH_REMATCH[1]}
        end_day=${BASH_REMATCH[2]}
        # Loop para processar cada dia no intervalo
        for day in $(seq "$start_day" "$end_day"); do
            dia=$(printf '%02d' "$day")
            data=$(date +"%Y-%m-$dia")
            if is_valid_date "$data"; then
                process_logs_for_date "$data"
            else
                echo "Data inválida: $data"
            fi
        done
    # Verifica se o argumento é uma data completa no formato YY-MM-DD
    elif [[ "$1" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
        data="20$1" # Adiciona o prefixo "20" para o ano
        if is_valid_date "$data"; then
            process_logs_for_date "$data"
        else
            echo "Data inválida: $data"
            exit 1
        fi
    # Verifica se o argumento é apenas um dia (2 dígitos)
    elif [[ "$1" =~ ^[0-9]{1,2}$ ]]; then
        dia=$(printf '%02d' "$1")
        data=$(date +"%Y-%m-$dia")
        if is_valid_date "$data"; then
            process_logs_for_date "$data"
        else
            echo "Data inválida: $data"
            exit 1
        fi
    else
        echo "Formato de data inválido. Use YY-MM-DD, DD, ou um intervalo DD-DD."
        exit 1
    fi
else
    # Sem argumentos: processa a data padrão (ontem)
    process_logs_for_date "$data"
fi
