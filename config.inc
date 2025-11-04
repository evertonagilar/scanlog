# Arquivo de configuração


# Lista de servidores com os caminhos dos logs
# Pode ser caminho SSH, sendo que nesse caso é preciso ter chave ssh para o scan conseguir copiar os logs
declare -a servidores=(
  "evertonagilar@localhost:/home/evertonagilar/devops/ufsm/ufsm-scanlog/logs/*.log"
)

# Porta ssh
sshPort=22

# Chave privada para acessar as máquinas
chavePrivada=chaveprivada.key

# Pasta onde será armazenado o resultado do scan
stagePath="resultado"

# Arquivo de modelo com as regras a serem aplicadas
modeloArquivo="modelo_ufsm.inc"

# Indica se os logs precisam ser normalizados (formato Kubelet)
normalizaLogs=false

# Regex base do pacote para remover prefixos ao agrupar módulos/classes
baseModule="br\.ufsm\.cpd\.sie"
#baseModule="br\.ufrn"
