# Arquivo de configuração


# Lista de servidores com os caminhos dos logs
# Pode ser caminho SSH, sendo que nesse caso é preciso ter chave ssh para o scan conseguir copiar os logs
declare -a servidores=(
  "interno@wportal04.si.ufsm.br:/var/log/containers/prod-sieweb*.log"
)

# Porta ssh
sshPort=2222

# Chave privada para acessar as máquinas
chavePrivada=chaveprivada.key

# Pasta onde será armazenado o resultado do scan
stagePath="/var/log/ufsm-scan"

