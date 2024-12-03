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


# Função para processar logs para uma data específica
process_logs() {
    local data=$(date +"%Y-%m-%d")
    local pastaBase="$stagePath/logs-$data"
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

    ############################# Coleta dos logs #############################################

    copiar_logs_servidores "$data" "$pastaLogs"

    ############################# Inicio extrações #############################################

    echo -e "\n 🔥 Fazendo as extrações...\n"

    echo "⏳ Processando extratores de texto simples..."
    for entry in "${extratoresArray[@]}"; do
        IFS='|' read -r termo contexto_a contexto_b arquivo <<< "$entry"
        echo "Comando: grep -ri -F \"$termo\" -A \"$contexto_a\" -B \"$contexto_b\" \"$pastaLogs\" > $pastaBaseExtracoes/$arquivo"
        grep -ri -F "$termo" -A "$contexto_a" -B "$contexto_b" "$pastaLogs" > "$pastaBaseExtracoes/$arquivo"
    done

    ##########################################################################################

    echo "⏳ Processando contadores de texto simples..."
    rm -f "$nomeArquivoContador"
    for entry in "${contadoresArray[@]}"; do
        IFS='|' read -r termo msg <<< "$entry"
        echo  "Comando: total=\$(grep -ri -c -F \"$termo\" \"$pastaLogs\" | awk -F':' '{s+=$2} END {print s}')"
        local total=$(grep -ri -c -F "$termo" "$pastaLogs" | awk -F':' '{s+=$2} END {print s}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done

    ##########################################################################################

    echo "⏳ Processando contadores de regex..."
    for entry in "${contadoresRegexArray[@]}"; do
        IFS='#' read -r termo msg <<< "$entry"
        echo "Comando total=\$(grep -ri -c -E \"$termo\" \"$pastaLogs\" | awk -F':' '{s+=$2} END {print s}')"
        local total=$(grep -ri -c -E "$termo" "$pastaLogs" | awk -F':' '{s+=$2} END {print s}')
        echo "$msg = $total" >> "$nomeArquivoContador"
    done

    ##########################################################################################

    echo "⏳ Processando acumuladores de regex..."
    for entry in "${acumuladoresArray[@]}"; do
        IFS='|' read -r termo termo2 msg <<< "$entry"
        echo "Comando: total=\$(grep -ri -E -o \"$termo\" \"$pastaLogs\" | grep -E -o "$termo2" | awk '{s+=$1} END {print (s ? s : 0)}')"
        local total=$(grep -ri -E -o "$termo" "$pastaLogs" | grep -E -o "$termo2" | awk '{s+=$1} END {print (s ? s : 0)}')
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
            resultadosArray+=("$resultado")  # Adiciona o item ao array
        done < <(grep -ri -E -o "$padrao" "$pastaLogs" | tr -d '(){}|' | awk -F':' '{print $3}' | grep -E -v "(Caused by|ConstraintViolationException|org\.hibernate|javax\.persistence|javax\.ejb|thrown from|Row was updated|codigoErro|query|return|unique|ResultSet|Transaction|aborted|exception|failure|underlying|java\.rmi|null identifier|Unable to find|property|googleapis|attempted merging)" | sort | uniq)
    done
    printf "%10s | %-50s\n" "Quantidade" "Mensagens de negócio" > "$nomeArquivoMensagensNegocio"
    printf "%10s | %-50s\n" "----------" "--------------------------------------------------" >> "$nomeArquivoMensagensNegocio"
    for termo in "${resultadosArray[@]}"; do
        echo "Comando: total=\$(grep -ri -c -E \"$termo\" \"$pastaLogs\" | awk -F':' '{s+=$2} END {print s}')"
        total=$(grep -ri -c -E "$termo" "$pastaLogs" | awk -F':' '{s+=$2} END {print s}')
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
            echo aqui
            echo "$line" "$regex" "$nomeArquivoAcumCondTmp1"
            processaAcum "$line" "$regex" "$nomeArquivoAcumCondTmp1"
        done < <(grep -E -ri "$regex" "$pastaLogs")
        if [ -f "$nomeArquivoAcumCondTmp1" ]; then
          uniq "$nomeArquivoAcumCondTmp1" | sort -n -r > "$pastaBaseExtracoes/$nomeArquivoAcumCond"
          rm -f $nomeArquivoAcumCondTmp1
        fi
    done

    echo "-----------------------------------------------------------------------------------"
}

################################ MAIN ##########################################################


echo -e "\033[01;33mAnalisador de logs sieweb-scanlog\033[01;37m ( Versão: $VERSAO_SCRIPT Data: $CURRENT_DATE )"
process_logs

