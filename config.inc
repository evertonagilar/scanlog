# config.inc
# Arquivo de configuração para armazenar IPs dos servidores

# Lista de servidores com os caminhos dos logs para extrair
# Pode ser caminho SSH, sendo que nesse caso é preciso ter chave ssh para o scan conseguir copiar os logs
declare -a servidores=(
  "wportal04:/var/log/containers/prod-sieweb*.log"
  "wportal05:/var/log/containers/prod-sieweb*.log"
)

# Porta ssh
sshPort=2222

# Quando true, o scan irá obter os arquivos de logs para via ssh
copyWithSSH=false

# Pasta onde será armazenado o resultado do scan
stagePath="/home/$(whoami)/Desktop"

