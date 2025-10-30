# Arquivo de configuração


# Lista de servidores com os caminhos dos logs
# Pode ser caminho SSH, sendo que nesse caso é preciso ter chave ssh para o scan conseguir copiar os logs
declare -a servidores=(
  "evertonagilar@192.168.1.9:/home/evertonagilar/devops/ufsm/ufsm-scanlog/logs/prod-sieweb*.log"
)

# Porta ssh
sshPort=22

# Chave privada para acessar as máquinas
chavePrivada=chaveprivada.key

# Pasta onde será armazenado o resultado do scan
stagePath="/var/log/ufsm-scan"

