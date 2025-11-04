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

#
# Lista de parâmetros para extratores de log.
#
# Layout:
# texto a pesquisar | exibir X linhas após o padrão encontrado | exibir X linhas antes do padrão encontrado | nome do arquivo para salvar o resultado
#
declare -a extratoresArray=(
    'org.springframework.security.web.access.Exception|12|6|spring_security_access_exception.log'
    'java.lang.NullPointerException|25|10|null_pointer_exception.log'
    'br.ufrn.arq.erros.NegocioException|25|10|negocio_exception.log'
    'br.ufrn.arq.erros.ArqException|25|10|arq_exception.log'
    'br.ufrn.arq.erros.DAOException|25|10|dao_exception.log'
    'br.ufrn.arq.erros.SegurancaException|25|10|seguranca_exception.log'
    'javax.faces.application.ViewExpiredException|25|10|view_expired_exception.log'
    'javax.faces.event.AbortProcessingException|25|10|abort_processing_exception.log'
    'javax.faces.el.EvaluationException|25|10|evaluation_exception.log'
    'javax.faces.FacesException|25|10|faces_exception.log'
    'javax.servlet.ServletException|25|10|servlet_exception.log'
    'javax.el.ELException|25|10|el_exception.log'
    'org.apache.jasper.JasperException|25|10|jasper_exception.log'
    'org.apache.jasper.el.JspELException|25|10|jsp_el_exception.log'
    'JspServletWrapper.handleJspException|25|10|jsp_servlet_wrapper_exception.log'
    'org.hibernate.TransientObjectException|25|10|transient_object_exception.log'
    'org.hibernate.exception.JDBCException|25|10|hibernate_jdbc_exception.log'
    'org.hibernate.exception.GenericJDBCException|25|10|hibernate_generic_jdbc_exception.log'
    'org.hibernate.exception.JDBCConnectionException|25|10|hibernate_jdbc_connection_exception.log'
    'org.hibernate.exception.LockAcquisitionException|25|10|hibernate_lock_acquisition_exception.log'
    'org.hibernate.engine.jdbc.spi.SqlExceptionHelper|25|10|hibernate_sql_exception_helper.log'
    'java.sql.SQLTimeoutException|25|10|sql_timeout_exception.log'
    'java.sql.SQLTransientConnectionException|25|10|sql_transient_connection_exception.log'
    'java.sql.SQLNonTransientConnectionException|25|10|sql_non_transient_connection_exception.log'
    'java.sql.SQLRecoverableException|25|10|sql_recoverable_exception.log'
    'Could not open connection|25|10|could_not_open_connection.log'
    'Could not acquire connection from the pool|25|10|could_not_acquire_connection.log'
    'Unable to acquire JDBC Connection|25|10|unable_acquire_jdbc_connection.log'
    'Connection is not available, request timed out after|25|10|connection_not_available_timeout.log'
    'Timed out waiting for connection|25|10|timeout_waiting_connection.log'
    'No ManagedConnections available|25|10|no_managed_connections_available.log'
    'javax.resource.ResourceException: Timed out|25|10|resource_exception_timed_out.log'
    'javax.resource.ResourceException: Unable to get managed connection|25|10|resource_exception_unable_get_connection.log'
    'javax.resource.ResourceException: Could not enlist|25|10|resource_exception_could_not_enlist.log'
    'ERRORCODE=-|25|10|db_errorcode_entries.log'
    'SQLCODE=-|25|10|db_sqlcode_entries.log'
    'SQLSTATE=|25|10|db_sqlstate_entries.log'
    'XA_RBDEADLOCK|25|10|xa_rbdeadlock.log'
    'XAER_NOTA|25|10|xaer_nota.log'
    'SQLCODE=-911|25|10|db_deadlock_sqlcode_911.log'
    'SQLCODE=-913|25|10|db_deadlock_sqlcode_913.log'
    'Lock wait timeout exceeded|25|10|lock_wait_timeout.log'
    'deadlock detected|25|10|deadlock_detected.log'
    'Connection reset by peer|25|10|connection_reset_by_peer.log'
    'Broken pipe|25|10|broken_pipe.log'
    'Connection refused|25|10|connection_refused.log'
    'Communications link failure|25|10|communications_link_failure.log'
    'Pool empty|25|10|pool_empty.log'
    'Timeout waiting for idle object|25|10|timeout_waiting_idle_object.log'
    'Could not create connection to database server|25|10|could_not_create_connection_server.log'
    'javax.resource.ResourceException|25|10|resource_exception.log'
    'org.jboss.util.NestedSQLException|25|10|nested_sql_exception.log'
    'Transaction is not active|25|10|transaction_not_active.log'
    'object references an unsaved transient instance|25|10|unsaved_transient_instance.log'
    'JDBCExceptionReporter|25|10|jdbc_exception_reporter.log'
    'java.lang.ClassNotFoundException|25|10|class_not_found_exception.log'
    'java.lang.IllegalArgumentException|25|10|illegal_argument_exception.log'
    'java.lang.IllegalStateException|25|10|illegal_state_exception.log'
    'java.lang.NumberFormatException|25|10|number_format_exception.log'
    'View could not be restored|25|10|view_restore_failure.log'
    'JSF1054|15|6|jsf1054_restore_view.log'
    'Exception in the filter chain|20|10|jsf_filter_chain_exception.log'
    'Nova Senha n|25|10|senha_repetida_exception.log'
    'A senha digitada|25|10|senha_simples_exception.log'
    'A consulta retorna mais que 500 resultados|25|10|consulta_grande_exception.log'
    'BeanCreationException: Error creating bean|25|10|spring_bean_creation_exception.log'
    'BeanInstantiationException: Could not instantiate bean class|25|10|spring_bean_instantiation_exception.log'
    'TransactionImple < ac|20|10|transaction_imple_details.log'
    'Caused by: javax.resource.ResourceException|25|10|resource_exception_caused_by.log'
    'Caused by: org.jboss.util.NestedSQLException|25|10|nested_sql_caused_by.log'
    'Caused by: org.hibernate.TransientObjectException|25|10|transient_object_caused_by.log'
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
    'javax.resource.ResourceException: Timed out|ResourceException com timeout'
    'javax.resource.ResourceException: Unable to get managed connection|ResourceException sem conexao disponivel'
    'javax.resource.ResourceException: Could not enlist|ResourceException falha ao registrar transacao'
    'ERRORCODE=-|erros DB2 com ERRORCODE'
    'SQLCODE=-|erros DB2 com SQLCODE'
    'SQLSTATE=|erros SQLSTATE reportados'
    'XA_RBDEADLOCK|deadlocks distribuidos (XA_RBDEADLOCK)'
    'XAER_NOTA|eventos XAER_NOTA'
    'Lock wait timeout exceeded|timeouts de lock (Lock wait)'
    'deadlock detected|deadlocks detectados (mensagem generica)'
    'Connection reset by peer|resets de conexao por peer'
    'Broken pipe|erros Broken pipe (socket)'
    'Connection refused|conexoes recusadas'
    'Communications link failure|falhas de comunicacao com banco'
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
