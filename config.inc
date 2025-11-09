# Arquivo de configuração

# Porta ssh
sshPort=22

# Chave privada para acessar as máquinas
chavePrivada=chaveprivada.key
# Pasta onde será armazenado o resultado do scan
stagePath="resultado"

# Indica se os logs precisam ser normalizados campos do Kubelet
normalizaLogs=false

# Remove quebra antes de processar
removeQuebras=false      # Remover \n\t 

# Normaliza quebra após processar para facilitar leitura
normalizaQuebra=true

# Normaliza entradas do JBoss agrupando stacktrace em uma única linha
normalizaLogsJBoss=true
