########################################################################################################
#
# Author: Everton de Vargas Agilar
# Date: 27/10/2024
#
# Modelo para o analisador de log ufsm-scanlog direcionado aos logs do JBoss 5.1
#
# Este modelo foi construido a partir dos arquivos presentes em ./logs, focando nas excecoes mais recorrentes,
# problemas de conexao com banco de dados, erros de seguranca e mensagens de negocio emitidas pelo servidor
# de aplicacao JBoss 5.1. Ajuste as listas abaixo caso novos padroes relevantes surjam nos logs.
#
# Historico
#
# Data       |  Quem           |  Mensagem
# -----------------------------------------------------------------------------------------------------
# 26/10/2024  Everton Agilar    Versao inicial para logs JBoss 5.1
# 27/10/2024  Everton Agilar    Revisao abrangente com extratores e contadores adicionais
########################################################################################################

# Lista de servidores com os caminhos dos logs
declare -a servidores=(
  "evertonagilar@164.41.121.115:/home/evertonagilar/devops/scanlog/logs-unb/*.log"
)

# Indica se os logs precisam ser normalizados campos do Kubelet
normalizaLogs=false

# Remove quebra antes de processar
removeQuebras=false      # Remover \n\t 

# Normaliza quebra após processar para facilitar leitura
normalizaQuebra=true

# Normaliza entradas do JBoss agrupando stacktrace em uma única linha
normalizaLogsJBoss=true

#
# Lista de parâmetros para extratores de log.
#
# Regex para identificar os serviços presentes nas mensagens de log.
patternNomeService='([A-Za-z0-9_.]+MBean)'

# Regex base para identificar pacote do próprio sistema
baseModule="br\.ufrn"

# Layout:
# texto a pesquisar | nome do arquivo para salvar o resultado
#
declare -a extratoresArray=(
    'org.springframework.security.web.access.Exception|spring_security_access_exception.log'
    'java.lang.NullPointerException|null_pointer_exception.log'
    'br.ufrn.arq.erros.NegocioException|negocio_exception.log'
    'br.ufrn.arq.erros.ArqException|arq_exception.log'
    'br.ufrn.arq.erros.DAOException|dao_exception.log'
    'br.ufrn.arq.erros.SegurancaException|seguranca_exception.log'
    'javax.faces.application.ViewExpiredException|view_expired_exception.log'
    'javax.faces.event.AbortProcessingException|abort_processing_exception.log'
    'javax.faces.el.EvaluationException|evaluation_exception.log'
    'javax.faces.FacesException|faces_exception.log'
    'javax.servlet.ServletException|servlet_exception.log'
    'javax.el.ELException|el_exception.log'
    'org.apache.jasper.JasperException|jasper_exception.log'
    'org.apache.jasper.el.JspELException|jsp_el_exception.log'
    'JspServletWrapper.handleJspException|jsp_servlet_wrapper_exception.log'
    'org.hibernate.TransientObjectException|transient_object_exception.log'
    'org.hibernate.exception.JDBCException|hibernate_jdbc_exception.log'
    'org.hibernate.exception.GenericJDBCException|hibernate_generic_jdbc_exception.log'
    'org.hibernate.exception.JDBCConnectionException|hibernate_jdbc_connection_exception.log'
    'org.hibernate.exception.LockAcquisitionException|hibernate_lock_acquisition_exception.log'
    'org.hibernate.engine.jdbc.spi.SqlExceptionHelper|hibernate_sql_exception_helper.log'
    'java.sql.SQLTimeoutException|sql_timeout_exception.log'
    'java.sql.SQLTransientConnectionException|sql_transient_connection_exception.log'
    'java.sql.SQLNonTransientConnectionException|sql_non_transient_connection_exception.log'
    'java.sql.SQLRecoverableException|sql_recoverable_exception.log'
    'Could not open connection|could_not_open_connection.log'
    'Could not acquire connection from the pool|could_not_acquire_connection.log'
    'Unable to acquire JDBC Connection|unable_acquire_jdbc_connection.log'
    'Connection is not available, request timed out after|connection_not_available_timeout.log'
    'Timed out waiting for connection|timeout_waiting_connection.log'
    'No ManagedConnections available|no_managed_connections_available.log'
    'javax.resource.ResourceException: Timed out|resource_exception_timed_out.log'
    'javax.resource.ResourceException: Unable to get managed connection|resource_exception_unable_get_connection.log'
    'javax.resource.ResourceException: Could not enlist|resource_exception_could_not_enlist.log'
    'ERRORCODE=-|db_errorcode_entries.log'
    'SQLCODE=-|db_sqlcode_entries.log'
    'SQLSTATE=|db_sqlstate_entries.log'
    'violates foreign key constraint|postgres_fk_violation.log'
    'duplicate key value violates unique constraint|postgres_duplicate_key.log'
    'invalid input syntax for type integer|postgres_invalid_integer.log'
    'value too long for type character varying|postgres_value_too_long.log'
    'PreparedStatementCallback; SQL|spring_preparedstatement_error.log'
    'SocketTimeoutException invoking|external_socket_timeout.log'
    'Read timed out|external_read_timeout.log'
    'No ManagedConnections available within configured blocking timeout|jboss_blocking_timeout.log'
    'postgres-ds.xml" is in error|jboss_postgres_ds_deploy_error.log'
    'XML document structures must start and end within the same entity|jboss_xml_entity_error.log'
    'XA_RBDEADLOCK|xa_rbdeadlock.log'
    'XAER_NOTA|xaer_nota.log'
    'SQLCODE=-911|db_deadlock_sqlcode_911.log'
    'SQLCODE=-913|db_deadlock_sqlcode_913.log'
    'Lock wait timeout exceeded|lock_wait_timeout.log'
    'deadlock detected|deadlock_detected.log'
    'Connection reset by peer|connection_reset_by_peer.log'
    'Broken pipe|broken_pipe.log'
    'Connection refused|connection_refused.log'
    'Communications link failure|communications_link_failure.log'
    'Pool empty|pool_empty.log'
    'Timeout waiting for idle object|timeout_waiting_idle_object.log'
    'Could not create connection to database server|could_not_create_connection_server.log'
    'javax.resource.ResourceException|resource_exception.log'
    'org.jboss.util.NestedSQLException|nested_sql_exception.log'
    'Transaction is not active|transaction_not_active.log'
    'object references an unsaved transient instance|unsaved_transient_instance.log'
    'JDBCExceptionReporter|jdbc_exception_reporter.log'
    'java.lang.ClassNotFoundException|class_not_found_exception.log'
    'java.lang.IllegalArgumentException|illegal_argument_exception.log'
    'java.lang.IllegalStateException|illegal_state_exception.log'
    'java.lang.NumberFormatException|number_format_exception.log'
    'View could not be restored|view_restore_failure.log'
    'JSF1054|jsf1054_restore_view.log'
    'Exception in the filter chain|jsf_filter_chain_exception.log'
    'Nova Senha n|senha_repetida_exception.log'
    'A senha digitada|senha_simples_exception.log'
    'A consulta retorna mais que 500 resultados|consulta_grande_exception.log'
    'BeanCreationException: Error creating bean|spring_bean_creation_exception.log'
    'BeanInstantiationException: Could not instantiate bean class|spring_bean_instantiation_exception.log'
    'TransactionImple < ac|transaction_imple_details.log'
    'Caused by: javax.resource.ResourceException|resource_exception_caused_by.log'
    'Caused by: org.jboss.util.NestedSQLException|nested_sql_caused_by.log'
    'Caused by: org.hibernate.TransientObjectException|transient_object_caused_by.log'
)

#
# Lista de parâmetros para indicadores de texto simples.
#
# Layout:
# texto a pesquisar | Mensagem do indicador
#
declare -a contadoresArray=(
    'org.springframework.security.web.access.Exception|falhas de autorizacao Spring Security'
    'java.lang.NullPointerException|ocorrencias de NullPointerException'
    'br.ufrn.arq.erros.NegocioException|erros de negocio (NegocioException)'
    'br.ufrn.arq.erros.ArqException|erros de infraestrutura (ArqException)'
    'br.ufrn.arq.erros.DAOException|erros DAO'
    'br.ufrn.arq.erros.SegurancaException|erros de seguranca (SegurancaException)'
    'javax.faces.application.ViewExpiredException|sessoes JSF expiradas'
    'javax.faces.event.AbortProcessingException|erros AbortProcessingException'
    'javax.faces.el.EvaluationException|EvaluationException em expressoes JSF'
    'javax.faces.FacesException|FacesException registradas'
    'javax.servlet.ServletException|ServletException registradas'
    'javax.el.ELException|ELException registradas'
    'org.apache.jasper.JasperException|erros JasperException'
    'org.apache.jasper.el.JspELException|erros JspELException'
    'JspServletWrapper.handleJspException|erros JspServletWrapper'
    'org.hibernate.TransientObjectException|TransientObjectException (Hibernate)'
    'org.hibernate.exception.JDBCException|JDBCException (Hibernate)'
    'org.hibernate.exception.GenericJDBCException|GenericJDBCException (Hibernate)'
    'org.hibernate.exception.JDBCConnectionException|falhas de conexao JDBC (Hibernate)'
    'org.hibernate.exception.LockAcquisitionException|erros LockAcquisitionException (Hibernate)'
    'org.hibernate.engine.jdbc.spi.SqlExceptionHelper|avisos SqlExceptionHelper'
    'java.sql.SQLTimeoutException|SQLTimeoutException registradas'
    'java.sql.SQLTransientConnectionException|SQLTransientConnectionException registradas'
    'java.sql.SQLNonTransientConnectionException|SQLNonTransientConnectionException registradas'
    'java.sql.SQLRecoverableException|SQLRecoverableException registradas'
    'Could not open connection|falhas ao abrir conexao com banco'
    'Could not acquire connection from the pool|falhas ao obter conexao do pool'
    'Unable to acquire JDBC Connection|falhas ao adquirir conexao JDBC'
    'Connection is not available, request timed out after|pool esgotado (timeout aguardando conexao)'
    'Timed out waiting for connection|timeout aguardando conexao (datasource)'
    'No ManagedConnections available|pool JCA sem conexoes (No ManagedConnections)'
    'No ManagedConnections available within configured blocking timeout|pool JCA esgotado por blocking timeout'
    'javax.resource.ResourceException: Timed out|ResourceException com timeout'
    'javax.resource.ResourceException: Unable to get managed connection|ResourceException sem conexao disponivel'
    'javax.resource.ResourceException: Could not enlist|ResourceException falha ao registrar transacao'
    'violates foreign key constraint|violacoes de chave estrangeira (Postgres)'
    'duplicate key value violates unique constraint|violacoes de constraint unica (Postgres)'
    'invalid input syntax for type integer|entradas invalidas para campos inteiros (Postgres)'
    'value too long for type character varying|valores acima do tamanho do campo varchar (Postgres)'
    'PreparedStatementCallback; SQL|falhas em PreparedStatementCallback (Spring JDBC)'
    'XA_RBDEADLOCK|deadlocks distribuidos (XA_RBDEADLOCK)'
    'XAER_NOTA|eventos XAER_NOTA'
    'Lock wait timeout exceeded|timeouts de lock (Lock wait)'
    'deadlock detected|deadlocks detectados (mensagem generica)'
    'Connection reset by peer|resets de conexao por peer'
    'Broken pipe|erros Broken pipe (socket)'
    'Connection refused|conexoes recusadas'
    'Communications link failure|falhas de comunicacao com banco'
    'SocketTimeoutException invoking|timeouts de socket em integracoes externas'
    'Read timed out|leituras expiradas em integracoes externas'
    'Pool empty|pool de conexoes vazio'
    'Timeout waiting for idle object|timeout aguardando objeto ocioso no pool'
    'Could not create connection to database server|falhas ao criar conexao com servidor banco'
    'javax.resource.ResourceException|ResourceException (pool/conexao)'
    'org.jboss.util.NestedSQLException|NestedSQLException registradas'
    'Transaction is not active|transacoes abortadas TransactionImple'
    'object references an unsaved transient instance|instancias transientes nao salvas'
    'JDBCExceptionReporter|avisos JDBCExceptionReporter'
    'java.lang.ClassNotFoundException|ClassNotFoundException registradas'
    'java.lang.IllegalArgumentException|IllegalArgumentException registradas'
    'java.lang.IllegalStateException|IllegalStateException registradas'
    'java.lang.NumberFormatException|NumberFormatException registradas'
    'Nova Senha n|trocas de senha rejeitadas (mesma senha)'
    'A senha digitada|senhas rejeitadas por complexidade'
    'A consulta retorna mais que 500 resultados|consultas com mais de 500 resultados'
    'BeanCreationException: Error creating bean|erros Spring BeanCreationException'
    'BeanInstantiationException: Could not instantiate bean class|erros Spring BeanInstantiationException'
    'postgres-ds.xml" is in error|falhas de deploy do datasource postgres-ds.xml'
    'XML document structures must start and end within the same entity|erros de parse em XML de configuracao'
    'Exception in the filter chain|erros na cadeia de filtros JSF/Ajax'
    'View could not be restored|views JSF nao restauradas'
    'TransactionImple < ac|detalhes de transacao abortada (TransactionImple)'
    'Caused by: javax.resource.ResourceException|ResourceException listadas como causa'
    'Caused by: org.jboss.util.NestedSQLException|NestedSQLException listadas como causa'
    'Caused by: org.hibernate.TransientObjectException|TransientObjectException listadas como causa'
)

#
# Lista de parâmetros para indicadores baseados em regex.
#
# Layout:
# regex#Mensagem do indicador
#
declare -a contadoresRegexArray=(
    'ERROR: insert or update on table "[^"]+" violates foreign key constraint "[^"]+"#violacoes de chave estrangeira (Postgres)'
    'ERROR: duplicate key value violates unique constraint "[^"]+"#violacoes de constraint unica (Postgres)'
    'ERROR: invalid input syntax for type integer: "[^"]+"#entradas invalidas para inteiro (Postgres)'
    'ERROR: value too long for type character varying\([0-9]+\)#valores acima do limite varchar (Postgres)'
    'PreparedStatementCallback; SQL \[.+\]; ERROR:#falhas em PreparedStatementCallback (Spring JDBC)'
    'SocketTimeoutException (invoking .+|: Read timed out)#timeouts de socket em integracoes externas'
    'No ManagedConnections available within configured blocking timeout \( *[0-9]+ \[ms\] \)#pool JCA esgotado (blocking timeout)'
    'postgres-ds\.xml" is in error#falhas ao carregar datasource postgres-ds.xml'
    'XML document structures must start and end within the same entity#XML malformado em configuracoes do servidor'
    'View /[^ ]+ could not be restored#paginas JSF nao restauradas (viewId)'
    'Nova Senha[^\\n]*Senha Atual#trocas de senha nao permitidas (mesma senha)'
    'A senha digitada [^\\n]*muito simples#senhas rejeitadas por complexidade (politica)'
    'NegocioException: A consulta retorna mais que 500 resultados#consultas maiores que 500 itens'
    'Transaction is not active: tx=TransactionImple#transacoes abortadas com TransactionImple'
    'object references an unsaved transient instance#instancias transientes nao salvas (Hibernate)'
    'javax\\.resource\\.ResourceException: Transaction is not active#ResourceException transaction not active'
    'org\\.jboss\\.util\\.NestedSQLException#NestedSQLException detectadas'
    'org\\.hibernate\\.exception\\.(JDBCException|GenericJDBCException)#erros JDBCException (Hibernate)'
    'ERRORCODE=-[0-9]+, SQLSTATE=[0-9A-Z]+#erros JDBC com ERRORCODE/SQLSTATE'
    'SQLCODE=-[0-9]+#ocorrencias SQLCODE diversas'
    'SQLSTATE=08[0-9]{3}#SQLSTATE 08xxx (falhas de conexao)'
    'SQLSTATE=40[0-9]{3}#SQLSTATE 40xxx (deadlock/rollback)'
    'XA_RB[A-Z]+#erros XA rollback (XA_RB*)'
    'XAER_[A-Z]+#erros XAER reportados'
    'br\\.ufrn\\.arq\\.erros\\.[A-Za-z]+Exception: .+#excecoes do pacote br.ufrn.arq.erros'
    'javax\\.faces\\.application\\.ViewExpiredException: viewId:[^ ]+#views expiradas com identificador'
    'org\\.apache\\.jasper\\.[A-Za-z]+Exception#excecoes JSP Jasper registradas'
    'java\\.lang\\.(ClassNotFoundException|IllegalArgumentException|IllegalStateException|NumberFormatException)#exceptions Java baseline'
)

#
# Lista de acumuladores (regex que extraem valores numéricos).
#
# Layout:
# regex principal | regex secundário (valor a acumular) | mensagem
#
declare -a acumuladoresArray=(
)

#
# Lista de contadores condicionais.
#
# Layout:
# regex|condição em bash usando $param1/$param2|arquivo de saída
#
declare -a contadoresCondicionaisArray=(
)

#
# Extratores de mensagens de negócio exibidas aos usuários.
#
declare -a extratorMensagemNegocioArray=(
    'br\.ufrn\.arq\.erros\.[A-Za-z]+Exception: .+'
)
