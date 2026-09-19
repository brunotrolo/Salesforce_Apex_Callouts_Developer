---
name: apex-callouts-developer
description: >
  Refatora qualquer callout HTTP Apex legado para a arquitetura de referencia:
  Template Method + Lookup Table + Named Credential + External Credential Custom + Cache de Token.
  Aceita curl, classe Apex legada (.cls), Custom Metadata Type ou linguagem natural como input.
  Executa 4 fases com subagentes: Analyze AS IS → Spec (aprovavel) → Generate → Validate.
  ATIVAR quando o usuario mencionar: refatorar callout, migrar webservice, nova integracao,
  criar connector, curl de API, classe de callout legada, Custom Metadata de webservice.
metadata:
  version: "1.0"
  domains: ["Integration", "Apex", "TargetOrg", "Migration"]
  minApiVersion: "68.0"
  relatedSkills:
    - "platform-apex-generate"
---

# Apex Callouts Developer

> Transforma qualquer input de callout em artefatos completos prontos para deploy
> na ORG TargetOrg — com spec, Apex, XML de metadata, scripts e evidência de validação.

## Inputs Aceitos

| Input | Exemplo |
|---|---|
| curl | `curl -X POST .../access-token -H "Authorization: Basic ..."` |
| Apex legado | `LegacyCustomerDataService extends LegacyAPIConnector` |
| Custom Metadata | registro `IntegrationConfig__mdt` (o Custom Metadata de configuração do legado) |
| Linguagem natural | "preciso chamar a API de dados do cliente pelo CPF" |

## Outputs Gerados

| Artefato | Arquivo |
|---|---|
| Apex | `XConnector.cls` + `XConnectorTest.cls` (≥75% cobertura) |
| EC Token | `X_SBX_Token_EC.externalCredential-meta.xml` |
| EC Base | `X_Sandbox_Base_EC.externalCredential-meta.xml` |
| NC Token | `X_SBX_Token.namedCredential-meta.xml` |
| NC Base | `X_Sandbox.namedCredential-meta.xml` |
| Permission Set | delta para `API_Integration.permissionset-meta.xml` |
| Lookup Table | rows para `APIConfigSetup.ensureRows()` |
| Scripts | `setup-X-token-ec.apex` + `smoke-X.apex` |
| Spec | documento aprovável (Fase 2) |

---

## Fluxo Obrigatório — 4 Fases

> Nunca pular fases. Nunca gerar código sem spec aprovada.

### Fase 1 — Analyze AS IS (subagente: analyze-asis)

Classifica o padrão de autenticação do legado e extrai o contrato da API.

**Classificação por complexidade de autenticação:**

| Padrão | Mecanismo | Migrar? |
|--------|-----------|---------|
| A — Cache + Crypto | Org Cache particionado + criptografia + retry 401 | ❌ Manter |
| B — Token Construtor | Token obtido no construtor, sem cache | ⚠️ Avaliar |
| C — Serviço Delegado | Token manager separado + retry recursivo | ❌ Manter |
| D — Dois Tokens | Dois tokens simultâneos com retry independente | ❌ Manter |
| E — Token Hierárquico | Token parent → token específico (CPF, sessão) | ⚠️ Avaliar |
| F — NC Simples | Named Credential direto, sem token próprio | ✅ Migrar |

**Hard Stops — NÃO migrar se:**
- Usa `CryptoToken` para criptografar credenciais
- Usa dois tokens simultâneos com retry independente
- Tem lógica de negócio misturada no callout
- Tem mais de 3 filhas com comportamentos divergentes

**Output da Fase 1:**
```
ANÁLISE AS IS: <Fonte>
Padrão: <F>  |  Candidato: SIM / NÃO / AVALIAR
Motivo: <razão em 1 frase>

Contrato:
  API Name: <API>_<Recurso>
  Base URL SBX: https://...
  Token URL SBX: https://...
  Auth Token: Basic base64(clientId:secret)
  Auth API: Bearer <token>
  Método: GET/POST
  Endpoint: /path/relativo
  Headers: customerId, X-Custom, etc.
  Timeout: 30000ms
```

---

### Fase 2 — Spec (subagente: spec-callout)

Gera spec executável e aguarda APROVAÇÃO EXPLÍCITA antes de avançar.

```markdown
## Spec: <API_NAME> Connector v1.0
Status: RASCUNHO → APROVADA

### Identidade
Classe: XConnector | API_Name: X_Recurso

### URLs
| Ambiente | Base | Token |
|----------|------|-------|
| SBX | https://hml-base | https://hml-token |
| PRD | https://prd-base | https://prd-token |

### Auth
Token: POST JSON {"grant_type":"client_credentials"} + Authorization: Basic <b64>
API:   Authorization: Bearer <token>

### Operações
| Op | Método | Path | Headers | Resposta |
|----|--------|------|---------|----------|
| opName | GET | /path | customerId: {cpf} | JSON {...} |

### Lookup Table
| Campo | SBX | PRD |
|-------|-----|-----|
| NamedCredential | X_Sandbox | X_Production |
| TokenNamedCredential | X_SBX_Token | X_PRD_Token |
| Endpoint | /path | /path |
| Method | GET | GET |
| Timeout | 30000 | 30000 |
| RetryEnabled | true | true |
| RetryCount | 1 | 1 |

### Critérios de Aceitação
- Named Credential Id != null no log do smoke test
- Smoke test: HTTP 200 com JSON não vazio
- Testes: ≥ 75% cobertura, todos passando
- Sem governor limit violations
```

---

### Fase 3 — Generate TO BE (subagente: generate-tobe)

Gera todos os artefatos a partir da spec aprovada.

#### XConnector.cls (template)

```apex
public with sharing class <API>Connector extends APIConnector {

    private static final String API_NAME = '<API_NAME>';
    private static final String OP_<OP> = '<opName>';

    public <API>Connector() { super(API_NAME); }

    @AuraEnabled  // SEM cacheable=true — callout proibido em cached methods
    public static Object <opName>(<params>) {
        try {
            return new <API>Connector().execute(OP_<OP>, paramsFor(<args>));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public Object call(String operacao, Map<String, Object> params, String environment) {
        this.currentEnvironment = environment;
        return this.execute(operacao, params);
    }

    protected override HttpRequest buildHttpRequest(String operacao, Map<String, Object> params) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + config.namedCredential + config.endpoint);
        request.setMethod(config.method == null ? 'GET' : config.method.toUpperCase());
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('X-Correlation-ID', correlationId);
        // headers específicos da API aqui
        request.setTimeout(config.timeout);
        return request;
    }

    protected override Object processResponse(String operacao, HttpResponse response) {
        Integer status = response.getStatusCode();
        if (status >= 200 && status < 300) {
            return String.isBlank(response.getBody()) ? null
                : JSON.deserializeUntyped(response.getBody());
        }
        String detail = 'HTTP ' + status;
        try {
            Map<String, Object> err = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (err.containsKey('message')) detail = String.valueOf(err.get('message'));
        } catch (Exception ignored) {}
        throw APIException.create('<API>_ERROR',
            'Erro na operacao ' + operacao + ': ' + detail, status);
    }

    private static Map<String, Object> paramsFor(<params>) {
        return new Map<String, Object>{ '<param>' => <value> };
    }
}
```

#### XConnectorTest.cls (template)

```apex
@isTest
private class <API>ConnectorTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Assert.isTrue(request.getEndpoint().startsWith('callout:<API>_Sandbox/'),
                'Endpoint deve usar NC de homologacao.');
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('<JSON_REAL_DA_API>');
            return response;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(400);
            response.setBody('{"message":"Erro simulado"}');
            return response;
        }
    }

    private static void useMockConfig() {
        APIConfigDAO.APIConfig cfg = new APIConfigDAO.APIConfig();
        cfg.apiName = '<API_NAME>';
        cfg.environment = 'Sandbox';
        cfg.namedCredential = '<API>_Sandbox';
        cfg.tokenNamedCredential = '<API>_SBX_Token';
        cfg.endpoint = '<ENDPOINT>';
        cfg.method = 'GET';
        cfg.timeout = 30000;
        cfg.retryEnabled = false;
        cfg.retryCount = 0;
        cfg.logEnabled = false;
        APIConfigDAO.mockConfig = cfg;
    }

    @isTest static void shouldReturnData_WhenValid() {
        useMockConfig();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Object result = <API>Connector.<opName>(<testArgs>);
        Test.stopTest();
        Assert.isNotNull(result, 'Resultado nao pode ser nulo.');
    }

    @isTest static void shouldThrowAura_WhenApiError() {
        useMockConfig();
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        try {
            <API>Connector.<opName>(<testArgs>);
            Assert.fail('Deveria lancar excecao.');
        } catch (AuraHandledException e) {
            Assert.isInstanceOfType(e, AuraHandledException.class, 'Deve ser AuraHandledException.');
        }
        Test.stopTest();
    }

    @isTest static void shouldOverrideEnvironment_WhenUsingCall() {
        APIConfigDAO.APIConfig cfg = new APIConfigDAO.APIConfig();
        cfg.apiName = '<API_NAME>';
        cfg.environment = 'Production';
        cfg.namedCredential = '<API>_Production';
        cfg.endpoint = '<ENDPOINT>';
        cfg.method = 'GET';
        cfg.timeout = 30000;
        cfg.retryEnabled = false;
        cfg.logEnabled = false;
        APIConfigDAO.mockConfig = cfg;
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        Object result = new <API>Connector().call('<opName>',
            new Map<String, Object>{ '<param>' => '<value>' }, 'Production');
        Test.stopTest();
        Assert.isNotNull(result, 'Override de ambiente deve funcionar.');
    }
}
```

#### EC Token (Custom — criação manual obrigatória na UI)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ExternalCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- ATENÇÃO: Custom Headers NÃO são deployáveis via XML.
         Criar na UI: Setup > Named Credentials > External Credentials > New
         Protocol: Custom | Principal: <API>_Principal
         Custom Header: Authorization = Basic <base64(clientId:secret)>
         Depois: rodar scripts/setup-<api>-token-ec.apex para ativar o principal -->
    <authenticationProtocol>Custom</authenticationProtocol>
    <externalCredentialParameters>
        <parameterGroup><API>_Principal</parameterGroup>
        <parameterName><API>_Principal</parameterName>
        <parameterType>NamedPrincipal</parameterType>
        <sequenceNumber>1</sequenceNumber>
    </externalCredentialParameters>
    <label><API> SBX Token</label>
</ExternalCredential>
```

#### NC Token

```xml
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- allowMergeFieldsInHeader=true: EC injeta Authorization: Basic -->
    <!-- generateAuthorizationHeader=false: Apex injeta Bearer manualmente -->
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
    <allowMergeFieldsInHeader>true</allowMergeFieldsInHeader>
    <calloutStatus>Enabled</calloutStatus>
    <generateAuthorizationHeader>false</generateAuthorizationHeader>
    <label><API> SBX Token</label>
    <namedCredentialParameters>
        <parameterName>Url</parameterName>
        <parameterType>Url</parameterType>
        <parameterValue>https://<hml-domain>/<token-path></parameterValue>
    </namedCredentialParameters>
    <namedCredentialParameters>
        <externalCredential><API>_SBX_Token_EC</externalCredential>
        <parameterName>ExternalCredential</parameterName>
        <parameterType>Authentication</parameterType>
    </namedCredentialParameters>
    <namedCredentialType>SecuredEndpoint</namedCredentialType>
</NamedCredential>
```

#### NC Base (API)

```xml
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- generateAuthorizationHeader=false: Apex injeta Bearer via getAccessToken() -->
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
    <allowMergeFieldsInHeader>false</allowMergeFieldsInHeader>
    <calloutStatus>Enabled</calloutStatus>
    <generateAuthorizationHeader>false</generateAuthorizationHeader>
    <label><API> Sandbox</label>
    <namedCredentialParameters>
        <parameterName>Url</parameterName>
        <parameterType>Url</parameterType>
        <parameterValue>https://<hml-base-url></parameterValue>
    </namedCredentialParameters>
    <namedCredentialParameters>
        <externalCredential><API>_Sandbox_Base_EC</externalCredential>
        <parameterName>ExternalCredential</parameterName>
        <parameterType>Authentication</parameterType>
    </namedCredentialParameters>
    <namedCredentialType>SecuredEndpoint</namedCredentialType>
</NamedCredential>
```

#### Lookup Table rows

```apex
// Adicionar em APIConfigSetup.ensureRows():
new RowDef('<API_NAME>', 'Sandbox', '<opName>',
    '<API>_Sandbox', '<API>_SBX_Token', '<endpoint>'),
new RowDef('<API_NAME>', 'Production', '<opName>',
    '<API>_Production', '<API>_PRD_Token', '<endpoint>')
```

---

### Fase 4 — Validate (subagente: validate-tobe)

Valida todos os artefatos e entrega o comando de deploy completo.

#### Checklists

**Governor Limits:**
- [ ] Sem SOQL/DML em loop
- [ ] Timeout configurado (máx 120000ms)
- [ ] Sem `@future` (usar Queueable)
- [ ] `with sharing` em todas as classes

**Segurança:**
- [ ] Sem client_id/secret hardcoded no Apex
- [ ] Sem PII em `System.debug()`
- [ ] `AuraHandledException` em todos os `@AuraEnabled`
- [ ] `@AuraEnabled` sem `cacheable=true`

**Testes:**
- [ ] `APIConfigDAO.mockConfig` em todos os testes
- [ ] Mocks: sucesso + erro HTTP + param inválido + override ambiente
- [ ] Cobertura ≥ 75%

**Metadata:**
- [ ] NC Token: `allowMergeFieldsInHeader=true`, EC correto (Custom, não OAuth)
- [ ] NC Base: `generateAuthorizationHeader=false`
- [ ] Instrução de criação manual do Custom Header na UI incluída

#### Diagnóstico de Erros Comuns

| Erro no Log | Causa | Solução |
|---|---|---|
| `Named Credential Id=null` | Principal sem acesso ou EC errado | Verificar Permission Set e EC do NC Token |
| `Unable to fetch the OAuth token` | NC Token aponta para EC OAuth | Trocar para EC Custom |
| `credential isn't fully configured` | `generateAuthorizationHeader=true` sem OAuth | Setar `false` no NC |
| `We couldn't access the credential` | Principal não ativado | Rodar `setup-<api>-token-ec.apex` |
| `403 Incapsula/WAF` | IP Salesforce bloqueado no WAF | Liberar IPs no Incapsula — código está correto |
| `401` na API | Token inválido | Verificar Basic no Custom Header do EC Token |

#### Evidência Obrigatória

O log do smoke test deve conter:
```
NAMED_CREDENTIAL_RESPONSE|NamedCallout[Named Credential Id=<ID_REAL>, ...]
```
`Id=null` = deploy incompleto. `403 Incapsula` = código correto, problema de rede.

---

## Anti-Racionalizações

| Racionalização | Realidade |
|---|---|
| "O callout é simples, não precisa de spec" | 10 min de spec economiza horas de debug. Spec é obrigatória. |
| "Posso usar EC OAuth — é mais moderno" | A API ACME exige JSON no body do token. EC OAuth manda form-urlencoded. Custom EC é correto. |
| "Vou deployar o EC pelo XML com o Custom Header" | Custom Headers em EC Custom não são deployáveis via Metadata API. Criar na UI. |
| "Named Credential Id=null é bug do Salesforce" | É sinal de deploy incompleto: principal sem acesso, EC errado, ou permissão faltando. |
| "403 Incapsula significa que o código está errado" | Não. 403 Incapsula = NC resolveu corretamente (Id != null), WAF bloqueou o IP Salesforce. |
| "Não preciso de retry — a API é estável" | Token expira em produção. 401 é garantido. Retry com renovação de token é obrigatório. |

---

## Referências

Todos os artefatos de referência ficam em `references/` desta skill:

| Path | Conteúdo |
|---|---|
| `references/apex/APIConnector.cls` | Classe base com getAccessToken() e retry em 401 |
| `references/apex/ACMEConnector.cls` | Exemplo concreto validado em POC |
| `references/apex/ACMEConnectorTest.cls` | Template de testes — todos os cenários |
| `references/apex/APIConfigSetup.cls` | Como adicionar rows na Lookup Table |
| `references/metadata/` | ECs, NCs e Permission Set validados |
| `references/scripts/smoke-acme.apex` | Template de smoke test |
| `references/scripts/setup-acme-sbx-token-ec.apex` | Template de setup do EC Token |
| `references/docs/decisao-autenticacao.md` | ADR: por que Custom EC e não OAuth nativo |
| `references/docs/tobe-passo-a-passo-nova-api.md` | Guia operacional para nova API |
| `references/docs/tobe-arquitetura-integracoes.md` | Arquitetura completa TO BE |
