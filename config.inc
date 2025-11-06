# Arquivo de configuração


# Lista de servidores com os caminhos dos logs
declare -a servidores=(
  "evertonagilar@164.41.121.115:/home/evertonagilar/devops/scanlog/logs-ufsm/*.log"
)

# Porta ssh
sshPort=22

# Chave privada para acessar as máquinas
chavePrivada=chaveprivada.key

# Pasta onde será armazenado o resultado do scan
stagePath="resultado"

# Arquivo de modelo com as regras a serem aplicadas
modeloArquivo="modelo_ufsm.inc"

# Indica se os logs precisam ser normalizados campos do Kubelet
normalizaLogs=false

# Remove quebra antes de processar
removeQuebras=false      # Remover \n\t 

# Normaliza quebra após processar para facilitar leitura
normalizaQuebra=true


