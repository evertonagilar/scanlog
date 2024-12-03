########################################################################################################
#
# Author: Everton de Vargas Agilar
# Date: 10/08/2024
#
# Modelo para o analisador de log sieweb-scanlog
#
# Este modelo é utilizado pela ferramenta sieweb-scanlog que ainda encontra-se em desenvolvimento ativo e pode conter bugs.
#
#
# Para que a ferramenta possa extrair informações úteis nos logs do SIEWEB na forma de extratores de logs e indicadores,
# os portais devem instrumentar os logs com o máximo de detalhe possíveis, a exemplo do portal documentos e
# a funcionalidde de recarga pix do RU.
#
#
# O modelo é composto por vários parâmetros divididos em classes:
# - extratoresArray                 -> gera extratores a partir de padrões de texto simples
# - contadoresArray                 -> gera indicadores a partir de padrões de texto simples
# - contadoresRegexArray            -> gera indicadores a partir de padrões com regex
# - acumuladoresArray               -> gera indicadores com acmulador a partir de padrões com regex
# - contadoresCondicionaisArray     -> gera indicadores a partir de padrões com regex condicionais
# - extratorMensagemNegocioArray    -> gera tabela com todas mensagens exibidas aos usuários
#
# Caso você deseja gerar novos extratores ou indicadores, leia os parâmetros do modelo para ter uma ideia de como
# instrumentar o código dos portais da melhor maneira possível e solicite a equipe DEVOPS. Usar textos ou termos fixos
# na instrumentação dos logs auxilia muito na coleta de padrões.
#
#
# ATENÇÃO: O modelo usa pipe | ou # como separador
#
#
# Histórico
#
# Data       |  Quem           |  Mensagem
# -----------------------------------------------------------------------------------------------------
# 10/08/2024  Everton Agilar    Versão inicial
########################################################################################################

#
# Lista de parâmetros para extratores de log.
#
# Layout:
# texto a pesquisar | exibir X linhas após o padrão encontrado | exibir X linhas antes do padrão encontrado | nome do arquivo para salvar o resultado
#
#

declare -a extratoresArray=(
    '[PERFORMANCE]|0|0|alert_performance_warning.log'
    'MUITO ALTO (>5s)|0|0|alert_serializacao_muito_alto.log'
    'NullPointerException|24|2|null_pointer_exceptions.log'
    'ConstraintViolationException|18|5|all_erros_contraints.log'
    'EJBException: Row was updated|18|2|rows_updated.log'
    'value_not_set|4|2|filtros_hbm_value_not_set.log'
    'StaleObjectStateException|18|170|hibernate_stale_objects.log'
    'could not extract ResultSet|25|6|extract_resultset.log'
    'javax.ejb.EJB|20|6|all_ejb_exception.log'
    'DB2 SQL Error: SQLCODE=|15|2|all_errorcode_exception.log'
    'SQLCODE=-407, SQLSTATE=23502|24|2|cannot_containt_null_exception.log'
    'SQLCODE=-803, SQLSTATE=23505|15|2|pk_contraint_violation_exception.log'
    'SQLCODE=-171, SQLSTATE=42815|15|2|datatype_invalid_exception.log'
    'SQLCODE=-302, SQLSTATE=22001|45|25|exceeds_column_size_exception.log'
    'query did not return a unique result|25|3|query_not_return_unique_exception.log'
    'javax.mail.MessagingException: 503|25|2|smtp_exception.log'
    'Usuario nulo|25|2|usuario_nulo_exception.log'
    'Dados para identificar o problema|25|2|planilha_chamada_exception.log'
    'Destino inicial não encontrado|25|2|tramitacao_sem_fluxo_inicial_exception.log'
    'SilentRegraNegocioRuntimeException: Nenhum fluxo configurado|15|8|fluxo_nao_configurado_exception.log'
    'GroovyCastException|15|8|groovy_cast_exception.log'
    'User not found in ldap: UFSM|25|2|user_not_found_ldap.log'
    'org.xml.sax.SAXParseException|32|2|parser_xml_exception.log'
    'EntityNotFoundException: Unable to find br.ufsm.cpd.sie.core.pessoa.Pessoa|32|4|pessoa_not_found_exception.log'
    'EntityNotFoundException: Turma não encontrada|5|2|turma_nao_encontrada_exception.log'
    'javax.ejb.EJBTransactionRolledbackException: Exception thrown from bean: br.ufsm.cpd.sie.core.pen.exception.PenException|32|2|barramento_pen_exception.log'
    'Tipo desconhecido:|12|2|tipo_desconhecido_exception.log'
    'Verifique os campos [from|2|2|campos_email_invalido.log'
    'ClassCastException|25|2|class_cast_exception.log'
    'AcessoNegadoException|3|2|gca_acesso_nao_autorizado.log'
    'IndexOutOfBoundsException|25|3|index_out_of_bounds_exception.log'
    'Sem entidade a ser buscada. Esse metodo deve ser sobrescrito|3|3|planilha_sobrescrever_metodo_buscar_entidade.log'
    'Erro ao fazer download do bugget AWS: Write timeout exceeded when trying to flush the data|12|3|S3_bucket_write_timeout_exception.log'
    'br.ufsm.cpd.commons.exception.ParameterNotFoundException|12|2|parameter_not_found_exception.log'
    'java.rmi.ServerError|25|5|rmi_server_error.log'
    'java.rmi.MarshalException|25|5|rmi_marshall_exception.log'
    'Transaction aborted|35|6|transaction_aborted_exception.log'
    'Erro ao realizar solicitação junto ao serviço de pagamento|35|8|recarga_pix_solicita_exception.log'
    'at br.ufsm.cpd.sie.biblioteca.controller.MinhaBibliotecaController.getAuthenticatedUrl|20|4|minha_biblioreca_temporariamente_indisponivel.log'
    'javax.ejb.EJBException: null identifier|50|2|null_identifier_exception.log'
    'at org.hibernate.Hibernate.initialize|35|25|initialize_property_hibernate_exception.log'
    '504 Gateway Time-out|12|2|gateway_externo_timeout_504.log'
    '(502) Bad Gateway|20|8|gateway_externo_bad_502.log'
    'org.hibernate.QueryException: could not resolve property|12|2|query_could_not_resolve_property.log'
    'com.google.api.client.googleapis.json.GoogleJsonResponseException|12|2|google_json_response_exception.log'
    'Fluxo de dispensa de disciplina configurado incorretamente|40|4|fluxo_dispensa_configurado_incorretamente.log'
    'Fluxo para requisitar processo não configurado|40|4|fluxo_requisitar_processo_nao_configurado.log'
    'WARNING: An illegal reflective access operation has occurred|8|0|illegal_reflective_access_operation.log'
    'A soft-locked cache entry was expired by the underlying Ehcache|8|0|ehcache_soft_locked_expired.log'
    'Error in post-ejbTimeout timer processing|8|0|ejb_timer_error_posttimeout.log'
    'but failed to remove it when the web application was stopped|8|0|portal_threadvar_potential_memory_leak.log'
    'ERRORCODE=-4461, SQLSTATE=42815|15|2|sqlsynxtax_param_out_of_range_exception.log'
    'Caused by: org.apache.commons.fileupload.MultipartStream|25|12|fileupload_multpart_stream_exception.log'
    'Could not parse multipart servlet request; nested exception is org.apache.commons.fileupload.FileUploadException: java.util.concurrent.TimeoutException|25|12|fileupload_multpart_timeout_exception.log'
    'Token gov.br inválido: code|2|2|login_govbr_invalid_or_expired_token.log'
    'Unexpected error forwarding or redirecting to login page|10|2|forward_or_redirect_invalid.log'
    'java.net.ConnectException: Error opening socket to server|10|2|network_exception.log'
    'RAR5074 : Table based validation detected invalid connection. Querying the table SYSIBM.SYSDUMMY1 failed|15|2|database_table_validation_detect_invalid_connection.log'
    'ERRORCODE=-4499, SQLSTATE=08001|25|8|database_connection_refuse.log'
    'SQLCODE=-911, SQLSTATE=40001|20|8|database_ts_rollback_because_deadlock.log'
    'Server returned XA_RBDEADLOCK. ERRORCODE=-4203|20|8|database_deadloack_detected.log'
    'Server returned XAER_NOTA. ERRORCODE=-4203|20|6|database_param_LOCKTIMEOUT_should_be_increased_hint.log'
    'SQLCODE=-10, SQLSTATE=42603|18|4|database_use_bind_parameter.log'
    'SQLCODE=-203, SQLSTATE=42702|18|6|database_sql_unqualified_column_name.log'
    'SQLCODE=-206, SQLSTATE=42703|18|6|database_sql_undefined_column_name.log'
    'JavaEETransactionManagerJTSDelegate.rollbackDistributedTransaction|30|15|rollback_distributed_ts_exception.log'
    'org.hibernate.PropertyAccessException: Exception occurred inside setter|15|4|hibernate_property_access_exception.log'
    'Caused by: java.lang.IllegalStateException: Duplicate key|20|4|merge_duplicated_id_hibernate_context.log'
    'SQLCODE=-952, SQLSTATE=57014|25|4|database_long_running_statement_cancelled_exception.log'
    'ERRORCODE=-4470, SQLSTATE=08003|18|4|database_connection_closed_exception.log'
    'Caused by: org.apache.commons.fileupload.FileUploadBase$IOFileUploadException: Processing of multipart/form-data request failed. java.lang.InterruptedException|18|4|fileupload_interrupted_exception.log'
    'Caused by: java.lang.ClassNotFoundException|25|18|class_not_found_exception.log'
    'RegraNegocioRuntimeException: Fluxo com mais de um destino padrão|18|6|tramitacao_fluxo_com_mais_de_um_destino_padrao.log'
    'BeanCreationException: Error creating bean with name|18|4|bean_creation_with_name_exception.log'
    'BeanCreationException: Could not autowire field|18|4|bean_could_not_autowire_field_exception.log'
    'Connection failure: socketType: IIOP_CLEAR_TEXT|18|4|ejb_connection_IIOP_exception.log'
    'java.text.DecimalFormat threw exception java.lang.IllegalArgumentException: Cannot format given Object as a Number|18|6|cannot_format_object_as_number_exception.log'
    'SQLCODE=-20423, SQLSTATE=38H10|18|6|textsearch_offline_exception.log'
)



#
# Lista de parâmetros para indicadores de texto simples.
#
# Layout:
# texto a pesquisar | Mensagem do indicador
#
#

declare -a contadoresArray=(
    'Usuário válido autenticado|logins SIE bem sucedidos'
    'javax.security.auth.login.FailedLoginException: |logins com falha (usuário/senha inválidos)'
    'AccountExpiredException|logins com falha porque a conta está bloqueada'
    'Fazendo logout no servidor|logouts efetuados pelo usuário antes de fechar o browser'
    'Tentativa de login sem usuário|logins sem campo usuário bloqueados'
    'Tentativa de login sem password|logins sem campo senha bloqueados'
    'AcessoRestritoException|erros AcessoRestritoException'
    'found (and removed)|sessões invalidadas por inatividade'
    'Usuário gov.br autenticado com sucesso|logins bem-sucedidos no gov.br'
    'Usuário não está cadastrado no SIE|logins bem sucedido no gov.br mas não tinha usuário cadastrado no SIE'
    'Referer: https://portal.ufsm.br/usuario/loginunico/escolhe_usuario.html|logins bem-sucedidos no gov.br de CPF com mais de um usuário no SIE'
    'User not found in ldap|usuário não encontrado no LDAP'
    'Invocando método doPost para tramitar|tramitações totais enviadas'
    'Invocando método tramitaPen|tramitações do tipo PEN enviadas'
    'Tem erro validação\? true|tramitações não enviadas pois houve erros de validação'
    'Sem fluxo definido|tramitações sem fluxo definido'
    'SilentRegraNegocioRuntimeException: Nenhum fluxo configurado|erros por não ter fluxo configurado'
    'Gerando próximo número do processo|NUPs gerados'
    'autenticado. Identificador gerado|despachos de documentos oficiais'
    'javax.mail.MessagingException: 503|SMTP exceptions'
    'ERRORCODE=-4499, SQLSTATE=08001|Database temporariamente indisponível'
    '[PERFORMANCE]|alertas de desempenho ([PERFORMANCE])'
    'NullPointerException|null pointers exceptions (NPE)'
    'ConstraintViolationException|violações de contraints (ConstraintViolationException)'
    'EJBException: Row was updated|erros EJB Row was updated'
    'value_not_set|filtros hbm não aplicados (value_not_set)'
    'StaleObjectStateException|objetos em cache obsoletos (StaleObjectStateException)'
    'could not extract ResultSet|erros ao extrair o resultset'
    'SQLCODE=-407, SQLSTATE=23502|erros cannot_containt_null'
    'SQLCODE=-803, SQLSTATE=23505|erros pk_ins_contraint'
    'SQLCODE=-171, SQLSTATE=42815|erros datatype_invalid_exception'
    'SQLCODE=-302, SQLSTATE=22001|erros exceeds_column_size'
    'query did not return a unique result|erros query_not_return_unique'
    'Usuario nulo|erros usuário nulo'
    'Dados para identificar o problema|erros ao chamar planilha'
    'Destino inicial não encontrado|erros destino inicial não encontrado nos processos'
    'GroovyCastException|erros de cast no Groovy'
    'javax.ejb.EJBTransactionRolledbackException: Exception thrown from bean: br.ufsm.cpd.sie.core.pen.exception.PenException|erros barramento PEN'
    'Tipo desconhecido|erros de tipo desconhecidos'
    'Buscando Notificacoes|chamadas ao NotificacaoTimerBean para verificar se há notificações a serem processadas'
    'Verifique os campos [from|e-mails não enviados devido a campos inválidos'
    'RegistroPontoException: Intervalo entre registros não pode ser inferior a 30 minutos|tentaram bater o ponto com menos de 30min de intervalo'
    'Caused by: java.io.IOException: Connection reset by peer|usuário saiu da página antes de ser completamente carregada'
    'Not all bytes were read from the S3ObjectInputStream, aborting HTTP connection|usuário saiu da página antes do bucket ser completamente lido'
    'Pagamento por pix criado no serviço de pagamento: transação gerada|Recarga PIX para recarga'
    'de Aguardando pagamento para Pago|Recarga PIX processadas de aguardando para pago'
    'erro na resposta do serviço de pagamento|Recarga PIX que falharam na resposta do serviço'
    'pix cobrança imediata e não foi paga em 24hrs|Recarga PIX cancelada pois não foi paga em 24hrs'
    'AcessoNegadoException|erros AcessoNegadoException (várias mensagens)'
    'EntityNotFoundException: Unable to find br.ufsm.cpd.sie.core.pessoa.Pessoa|pessoas não encontradas (EntityNotFoundException)'
    'EntityNotFoundException: Turma não encontrada|turmas não encontrada (EntityNotFoundException)'
    'br.ufsm.cpd.sie.core.exception.SilentRegraNegocioException: Inscrição fora do prazo|tentativa inscrição fora do prazo'
    'java.rmi.ServerError|erros rmi.ServerError'
    'java.rmi.MarshalException|erros rmi.MarshallException'
    'Transaction aborted|transações database abortadas'
    'Caused by: org.hibernate.AssertionFailure: null identifier|assertivas null identifier do Hibernate'
    'firstResult/maxResults specified with collection fetch; applying in memory|operação maxResults specified com coleção feita em memória'
    'retornou mais de um resultado. Assumindo o primeiro|coleção retornou mais de um resultado. Assumindo o primeiro'
    '504 Gateway Time-out|servidor gateway temporariamente indisponível (algum serviço que o SIE tentou acessar)'
    'org.hibernate.QueryException: could not resolve property|Query HQL/JPQL falhou pois não resolveu property'
    'Fluxo de dispensa de disciplina configurado incorretamente|Fluxo dispensa configurado incorretamente'
    'Fluxo para requisitar processo não configurado|Fluxo para requisitar processo não configurado'
    'WARNING: An illegal reflective access operation has occurred|acessos ilegais com reflection'
    'A soft-locked cache entry was expired by the underlying Ehcache|soft-locked expirado pelo ehcache'
    'but failed to remove it when the web application was stopped|possível memory leak em threadvar detectado durante deployment de portal'
    'ERRORCODE=-4461, SQLSTATE=42815|sql com erro de sintáxe out of range'
    'Caused by: org.apache.commons.fileupload.MultipartStream|fileupload multipart exception'
    'Could not parse multipart servlet request; nested exception is org.apache.commons.fileupload.FileUploadException: java.util.concurrent.TimeoutException|fileupload multpart timeout'
    'Token gov.br inválido: code|tentativa de uso de token login único gov.br expirado ou inválido'
    'Unexpected error forwarding or redirecting to login page|forward ou redirect inválido para página de login'
    'java.net.ConnectException: Error opening socket to server|erro de abertura de socket'
    'SQLCODE=-911, SQLSTATE=40001|transação sofreu rollback por causa de deadlock'
    'Server returned XA_RBDEADLOCK. ERRORCODE=-4203|deadlock detectados'
    'JavaEETransactionManagerJTSDelegate.rollbackDistributedTransaction|rollback de transações distribuidas'
    'org.hibernate.PropertyAccessException: Exception occurred inside setter|exception ocorreu dentro de método set de objeto'
    'Caused by: java.lang.IllegalStateException: Duplicate key|merge de id em context hibernate duplicado'
    'Server returned XAER_NOTA. ERRORCODE=-4203|carga de trabalho longa em andamento'
    'SQLCODE=-952, SQLSTATE=57014|carga de trabalho longa cancelada por timeout'
    'ERRORCODE=-4470, SQLSTATE=08003|conexão com banco fechada inesperadamente'
    'Caused by: org.apache.commons.fileupload.FileUploadBase$IOFileUploadException: Processing of multipart/form-data request failed. java.lang.InterruptedException|upload multipart interrompido inesperadamente'
    'Caused by: java.lang.ClassNotFoundException|classe não encontrada'
    'RegraNegocioRuntimeException: fluxo com mais de um destino padrão|fluxo com mais de um destino padrão detectado'
    'BeanCreationException: Error creating bean with name|exception de criação de bean na injeção de dependência'
    'BeanCreationException: Could not autowire field|exception de autowire de field na injeção de dependência'
    'Connection failure: socketType: IIOP_CLEAR_TEXT|exception IIOP em chamada remota de EJB'
    'SQLCODE=-10, SQLSTATE=42603|exception devido a consulta não ter parâmetros bind'
    'SQLCODE=-203, SQLSTATE=42702|unqualified column em consulta sql (possivelmente falta incluir dbsm.)'
    'SQLCODE=-206, SQLSTATE=42703|undefined column em consulta sql'
    'java.text.DecimalFormat threw exception java.lang.IllegalArgumentException: Cannot format given Object as a Number|falha de conversão de objeto para decimal'
    'SQLCODE=-20423, SQLSTATE=38H10|textsearch DB2 indisponível'
    'RAR5074 : Table based validation detected invalid connection. Querying the table SYSIBM.SYSDUMMY1 failed|healthcheck Payara detectou conexão inválida via sql na tabela SYSIBM.SYSDUMMY1'
)

#
# Lista de parâmetros para indicadores com regex.
#
# Layout:
# pattern regex a pesquisar # Mensagem do indicador
#
#

declare -a contadoresRegexArray=(
    'iniciando download arquivo [0-9]* do repositório#downloads do bucket independente de formato de arquivo'
    'iniciando download arquivo [0-9]* do repositório\. TipoArquivo: video/mp4#downloads video/mp4 do bucket'
    'iniciando download arquivo [0-9]* do repositório\. TipoArquivo: audio/mpeg#downloads audio/mpeg do bucket'
    'iniciando download arquivo [0-9]* do repositório\. TipoArquivo: application/pdf#downloads application/pdf do bucket'
    'iniciando download arquivo [0-9]* do repositório\. TipoArquivo: text/html#downloads text/html do bucket'
    'iniciando download arquivo [0-9]* do repositório\. TipoArquivo: image/jpeg#downloads image/jpeg do bucket'
    'iniciando download arquivo [0-9]* do repositório\. TipoArquivo: .+officedocument#downloads Office do bucket'
    'findTransacaoGatewayPagamento: Status da resposta: (?!200)#Recarga PIX com status resposta diferente de 200'
)

#
# Lista de parâmetros para indicadores com acumulador e regex.
#
# Layout:
# pattern regex a pesquisar | pattern ler acumulador | Mensagem do indicador
#
#

declare -a acumuladoresArray=(
    "Processamento encerrado. [0-9,]{1,3} notificações processadas|[0-9]{1,3}|timer/notificações processadas"
    "Buscando [0-9]{1,3} mensagens a enviar|[0-9]{1,3}|e-mails enviados via MensagemTimerBean"
    "Iniciando processamento de [0-9]{1,3} empenhos|[0-9]{1,3}|timer/empenhos processados"
    "[0-9]{1,3} producoes encontradas para carga|[0-9]{1,3}|produções para carga no Lattes"
)


#
# Lista de parâmetros para indicadores condicionais.
#
# Layout:
# pattern regex a pesquisar | condição bash like | Arquivo para salvar o resultado
#
# param1 -> primeiro grupo
# param2 -> segundo grupo
#

declare -a contadoresCondicionaisArray=(
    '\[PERFORMANCE\].+ Execucao do metodo <(.+)> demorou <([0-9]{1,5})ms>|$param2 -gt 60000|alert_metodos_tempo_execucao_muito_alto.log'
)


#
# Lista de parâmetros para extrair mensagens exibidas ao usuário.
#
# Layout:
# pattern regex a pesquisar
#
#

declare -a extratorMensagemNegocioArray=(
    'br\.ufsm\.cpd\.sie\.core\.exception\.SilentRegraNegocioException: .+'
    'br\.ufsm\.cpd\.sie\.core\.exception\.SilentRegraNegocioRuntimeException: .+'
    'javax\.ejb\.EJBException: .+'
    'br\.ufsm\.cpd\..+Exception: .+'
)
