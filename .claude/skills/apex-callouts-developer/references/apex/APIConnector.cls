/**
 * @description Classe abstrata base para todas as integracoes de API.
 *              Implementa Template Method: execute() define o fluxo,
 *              cada Connector implementa buildHttpRequest() e processResponse().
 *              Configuracao vem da Lookup Table (APIConfigDAO).
 *
 *              DECISAO DE ARQUITETURA - AUTENTICACAO:
 *              A API ACME exige Authorization: Basic no header do token request
 *              com body JSON (nao form-urlencoded). O EC OAuth nativo do Salesforce
 *              nao suporta esse formato. Por isso o token e gerenciado aqui:
 *              1. Named Credential de token (ACME_HML_Token) carrega o Basic pre-computado
 *                 como Custom Header via External Credential Custom protocol.
 *              2. getAccessToken() faz o POST ao endpoint de token usando esse NC.
 *              3. O token e cacheado em Map estatico durante a transacao.
 *              4. O Named Credential da API (ACME_Homologacao) e usado so para a URL base,
 *                 sem generateAuthorizationHeader.
 *              Este padrao espelha exatamente o LegacyAPIConnector da LegacyOrg que funciona
 *              em producao.
 */
public abstract with sharing class APIConnector {

    protected final String apiName;
    protected final String correlationId;
    protected String currentEnvironment;
    protected APIConfigDAO.APIConfig config;

    @TestVisible
    private static final Map<String, CachedToken> TOKEN_CACHE = new Map<String, CachedToken>();

    private class CachedToken {
        String value;
        Datetime expiresAt;
        CachedToken(String value, Datetime expiresAt) {
            this.value = value;
            this.expiresAt = expiresAt;
        }
    }

    protected APIConnector(String apiName) {
        if (String.isBlank(apiName)) {
            throw APIException.create('INVALID_CONFIG', 'apiName nao pode ser vazio.');
        }
        this.apiName = apiName;
        this.currentEnvironment = APIConfigDAO.getCurrentEnvironment();
        this.correlationId = generateCorrelationId();
    }

    /**
     * @description Template Method: preProcess -> build -> send -> process -> log.
     */
    public Object execute(String operacao, Map<String, Object> params) {
        if (String.isBlank(operacao)) {
            throw APIException.create('INVALID_OPERATION', 'Operacao nao pode ser vazia.');
        }
        if (params == null) {
            params = new Map<String, Object>();
        }

        this.config = APIConfigDAO.getConfig(apiName, currentEnvironment, operacao);
        Datetime startTime = Datetime.now();
        HttpResponse httpResponse;

        try {
            preProcess(operacao, params);
            HttpRequest httpRequest = buildHttpRequest(operacao, params);
            if (String.isNotBlank(config.tokenNamedCredential)) {
                httpRequest.setHeader('Authorization', 'Bearer ' + getAccessToken(false));
            }
            httpResponse = sendRequest(httpRequest, config);
            Object result = processResponse(operacao, httpResponse);
            logIntegration(config, operacao, params, httpResponse, startTime, null);
            return result;
        } catch (APIException e) {
            logIntegration(config, operacao, params, httpResponse, startTime, e);
            throw e;
        } catch (Exception e) {
            APIException wrapped = APIException.create(
                'UNEXPECTED_ERROR',
                'Erro inesperado na operacao ' + operacao + ': ' + e.getMessage()
            );
            logIntegration(config, operacao, params, httpResponse, startTime, wrapped);
            throw wrapped;
        }
    }

    // =================================================================
    // ABSTRATOS - todo Connector implementa
    // =================================================================

    protected abstract HttpRequest buildHttpRequest(String operacao, Map<String, Object> params);

    protected abstract Object processResponse(String operacao, HttpResponse httpResponse);

    // =================================================================
    // VIRTUAL - sobrescrever somente se precisar
    // =================================================================

    protected virtual void preProcess(String operacao, Map<String, Object> params) {
    }

    // =================================================================
    // TOKEN - gerenciado no Apex pois a API exige JSON + Basic
    // =================================================================

    private String getAccessToken(Boolean forceRefresh) {
        String key = config.tokenNamedCredential;
        CachedToken cached = TOKEN_CACHE.get(key);
        if (!forceRefresh && cached != null && cached.expiresAt > Datetime.now()) {
            return cached.value;
        }

        // NC de token carrega o Basic pre-computado no Authorization header via Custom EC
        HttpRequest tokenRequest = new HttpRequest();
        tokenRequest.setEndpoint('callout:' + key);
        tokenRequest.setMethod('POST');
        tokenRequest.setHeader('Content-Type', 'application/json');
        tokenRequest.setBody('{"grant_type":"client_credentials"}');
        tokenRequest.setTimeout(30000);

        Http http = new Http();
        HttpResponse tokenResponse = http.send(tokenRequest);
        Integer status = tokenResponse.getStatusCode();
        if (status < 200 || status >= 300) {
            throw APIException.create(
                'TOKEN_ERROR',
                'Falha ao obter token (' + key + '): HTTP ' + status + ' - ' + tokenResponse.getBody()
            );
        }

        Map<String, Object> tokenBody = (Map<String, Object>) JSON.deserializeUntyped(tokenResponse.getBody());
        String token = tokenBody == null ? null : (String) tokenBody.get('access_token');
        if (String.isBlank(token)) {
            throw APIException.create('TOKEN_ERROR', 'Resposta de token sem access_token: ' + tokenResponse.getBody());
        }

        Integer ttl = 540;
        Object expiresObj = tokenBody.get('expires_in');
        if (expiresObj != null) {
            try {
                Integer parsed = Integer.valueOf(String.valueOf(expiresObj));
                ttl = Math.max(60, Math.min(parsed - 60, 3540));
            } catch (Exception ignoredException) {}
        }
        TOKEN_CACHE.put(key, new CachedToken(token, Datetime.now().addSeconds(ttl)));
        return token;
    }

    // =================================================================
    // SEND - com retry e renovacao de token em 401
    // =================================================================

    private HttpResponse sendRequest(HttpRequest httpRequest, APIConfigDAO.APIConfig cfg) {
        Integer attempts = 1 + (cfg.retryEnabled ? Math.max(0, cfg.retryCount) : 0);
        Http http = new Http();
        HttpResponse httpResponse;

        for (Integer i = 0; i < attempts; i++) {
            try {
                httpResponse = http.send(httpRequest);
            } catch (CalloutException e) {
                if (i == attempts - 1) {
                    throw APIException.create('CALLOUT_ERROR', 'Erro na chamada HTTP: ' + e.getMessage());
                }
                continue;
            }
            Integer status = httpResponse.getStatusCode();
            if (status >= 200 && status < 300) {
                return httpResponse;
            }
            if (status != 401 || i == attempts - 1) {
                return httpResponse;
            }
            // 401: invalida cache e renova token antes de reenviar
            if (String.isNotBlank(cfg.tokenNamedCredential)) {
                TOKEN_CACHE.remove(cfg.tokenNamedCredential);
                httpRequest.setHeader('Authorization', 'Bearer ' + getAccessToken(true));
            }
        }
        return httpResponse;
    }

    // =================================================================
    // LOG
    // =================================================================

    private void logIntegration(
        APIConfigDAO.APIConfig cfg,
        String operacao,
        Map<String, Object> params,
        HttpResponse response,
        Datetime startTime,
        Exception error
    ) {
        if (cfg == null || cfg.logEnabled != true) {
            return;
        }
        Long elapsedMs = Datetime.now().getTime() - startTime.getTime();
        System.debug(
            LoggingLevel.INFO,
            'INTEGRATION correlationId=' + correlationId +
            ' api=' + cfg.apiName +
            ' env=' + cfg.environment +
            ' operacao=' + operacao +
            ' endpoint=' + cfg.endpoint +
            ' method=' + cfg.method +
            ' status=' + (response != null ? String.valueOf(response.getStatusCode()) : 'N/A') +
            ' elapsedMs=' + elapsedMs +
            (error != null ? ' error=' + error.getMessage() : '')
        );
    }

    private String generateCorrelationId() {
        return UserInfo.getUserId() + '_' + Datetime.now().getTime() + '_' + Crypto.getRandomInteger();
    }
}
