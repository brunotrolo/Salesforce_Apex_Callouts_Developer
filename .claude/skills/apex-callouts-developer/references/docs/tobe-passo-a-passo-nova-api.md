# 06 - Guia de Escala: Adicionar Nova API (Procedimento Padrao)

Procedimento oficial para plugar uma nova API na arquitetura de referencia.
A ACME foi a primeira e serve de exemplo resolvido do inicio ao fim.

Regra de ouro: **1 API = 1 Connector + linhas na Lookup Table + 1 par de credenciais.**
Nada de Service separado, Controller separado ou DTO separado.

---

## Fase 0: Levantar o Contrato da API (antes de codar)

Preencha esta tabela com o time/dono da API. Sem isso, nao comece.

| Item | Homologacao | Producao | Exemplo ACME |
|------|-------------|----------|-------------|
| Base URL | | | `https://api.acmecorp.com` (igual nos 2) |
| Tipo de auth | | | OAuth2 `client_credentials` |
| Token endpoint | | | `POST /oauth/v1/access-token` + `grant_type/client_id/client_secret` |
| Operacao 1 | metodo + path + headers | | `GET /customers/v1/accounts/customer-data` + header `customerId: <CPF>` |
| Operacao 2 | | | (ACME: pendente — so entre com cURL real em maos) |
| client_id / client_secret | pedir | pedir | placeholders `SEU_CLIENT_ID` / `SEU_CLIENT_SECRET` |

Curls de referencia da ACME:

```bash
curl --location 'https://api.acmecorp.com/oauth/v1/access-token' \
--header 'Content-Type: application/json' \
--data '{"grant_type":"client_credentials","client_id":"SEU_CLIENT_ID","client_secret":"SEU_CLIENT_SECRET"}'

curl --location 'https://api.acmecorp.com/customers/v1/accounts/customer-data' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer SEU_ACCESS_TOKEN' \
--header 'customerId: 12345678900'
```

Convenções de nome (siga à risca):

| Artefato | Padrao | Exemplo ACME |
|----------|--------|-------------|
| Connector | `<API>Connector` | `ACMEConnector` |
| API_Name (Lookup) | `<API>_<Recurso>` | `ACME_CustomerData` |
| External Credential | `<API>_<Amb>[_EC]` | `ACME_Sandbox_EC` |
| Named Credential | `<API>_<Amb>` | `ACME_Sandbox` |
| Principal | `<API>_Principal` | `ACME_Principal` |
| Permission Set | `API_Integration` | `API_Integration` (unico para todas as APIs) |
| Scripts | `setup-<api>-auth.apex`, `smoke-<api>.apex` | `setup-bcp-auth.apex`, `smoke-acme.apex` |

---

## Passo 1: Auth (External Credential + Named Credential)

Copie `scripts/setup-bcp-auth.apex` para `scripts/setup-<api>-auth.apex` e troque os valores entre `<...>`.
O script e idempotente (pode rodar N vezes).

```apex
// 1. External Credential OAuth2 client_credentials (HML e PRD)
ConnectApi.ExternalCredentialInput ec = new ConnectApi.ExternalCredentialInput();
ec.developerName = '<API>_Homologacao_EC';   // ex: ACME_Sandbox_EC
ec.masterLabel = '<Label>';
ec.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.OAuth;
ec.authenticationProtocolVariant =
    ConnectApi.CredentialAuthenticationProtocolVariant.ClientCredentialsClientSecret;
ConnectApi.ExternalCredentialParameterInput token = new ConnectApi.ExternalCredentialParameterInput();
token.parameterName = 'AuthProviderUrl';
token.parameterType = ConnectApi.ExternalCredentialParameterType.AuthProviderUrl;
token.parameterValue = '<TOKEN_ENDPOINT_COMPLETO>';  // ex: https://.../oauth/v1/access-token
ec.parameters = new List<ConnectApi.ExternalCredentialParameterInput>{ token };
ConnectApi.ExternalCredentialPrincipalInput princ = new ConnectApi.ExternalCredentialPrincipalInput();
princ.principalName = '<API>_Principal';
princ.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
princ.sequenceNumber = 1;
ec.principals = new List<ConnectApi.ExternalCredentialPrincipalInput>{ princ };
ConnectApi.NamedCredentials.createExternalCredential(ec);

// 2. Named Credential apontando para a EC (HML e PRD)
ConnectApi.NamedCredentialInput nc = new ConnectApi.NamedCredentialInput();
nc.developerName = '<API>_Homologacao';      // ex: ACME_Sandbox
nc.masterLabel = '<Label>';
nc.type = ConnectApi.NamedCredentialType.SecuredEndpoint;
nc.calloutUrl = '<BASE_URL>';                // ex: https://api.acmecorp.com
ConnectApi.ExternalCredentialInput ref = new ConnectApi.ExternalCredentialInput();
ref.developerName = '<API>_Homologacao_EC';
nc.externalCredentials = new List<ConnectApi.ExternalCredentialInput>{ ref };
ConnectApi.NamedCredentialCalloutOptionsInput opt = new ConnectApi.NamedCredentialCalloutOptionsInput();
opt.allowMergeFieldsInBody = false;
opt.allowMergeFieldsInHeader = false;
opt.generateAuthorizationHeader = true;      // Salesforce injeta o Bearer sozinho
nc.calloutOptions = opt;
ConnectApi.NamedCredentials.createNamedCredential(nc);
```

 Rode e traga o metadata para o repo (vira fonte da verdade):

```bash
sf apex run --file scripts/setup-<api>-auth.apex --target-org YourOrg
sf project retrieve start --metadata NamedCredential:<API>_Homologacao \
  --metadata NamedCredential:<API>_Producao \
  --metadata ExternalCredential:<API>_Homologacao_EC \
  --metadata ExternalCredential:<API>_Producao_EC --target-org YourOrg
```

Secrets (placeholders primeiro, reais depois — segredo nunca vai em codigo):

```bash
# scripts/setup-<api>-secrets.apex usa ConnectApi.NamedCredentials.createCredential
# com authenticationProtocolVariant = ClientCredentialsClientSecret e o mapa
# {'clientId' => ..., 'clientSecret' => ...}. Rode 1x com placeholders.
sf apex run --file scripts/setup-<api>-secrets.apex --target-org YourOrg
```

Permission Set: adicione a classe em `API_Integration.permissionset-meta.xml` (permission set unico para todas as APIs):

```xml
<classAccesses>
    <apexClass><API>Connector</apexClass>
    <enabled>true</enabled>
</classAccesses>
<externalCredentialPrincipalAccesses>
    <enabled>true</enabled>
    <externalCredentialPrincipal><API>_Homologacao_EC-<API>_Principal</externalCredentialPrincipal>
</externalCredentialPrincipalAccesses>
<!-- repetir para Producao -->
```

```bash
sf project deploy start --source-dir force-app/main/default/permissionsets --target-org YourOrg
sf org assign permset --name API_Integration --target-org YourOrg --on-behalf-of <usuario>
```

> `API_Integration` e um permission set unico para todas as APIs: quando criar uma
> API nova, so adicione os `classAccesses` + `externalCredentialPrincipalAccesses`
> dela no mesmo arquivo (nao crie um segundo permission set).

### Passo 1.5: Ajustes manuais na UI (obrigatorio, 1 tela)

O org ignora via metadata/API: o checkbox **Enabled for Callouts** e os segredos
so entram pela interface. Faca 1x por credencial (`<API>_Homologacao` e `<API>_Producao`):

```
Setup → Named Credentials → <API>_Homologacao → Edit
├── Callout Options
│   └── [x] Enabled for Callouts            <- sem isso: "Callout blocked for named credential"
├── External Credential: <API>_Homologacao_EC / Principal: <API>_Principal
│   ├── Client ID: <cole o client_id real de Homologacao>
│   └── Client Secret: <cole o client_secret real de Homologacao>
└── Save

Repetir para <API>_Producao (com as credenciais de Producao).
```

Conferencia: na pagina da External Credential, o principal deve mostrar
Authentication Status = Authenticated apos a primeira chamada com sucesso.

---

## Passo 2: Lookup Table (via codigo, nada manual)

Adicione um `RowDef` por **operacao x ambiente** em `APIConfigSetup.ensureRows()`:

```apex
new RowDef(
    '<API_NAME>',        // ex: 'ACME_CustomerData'
    '<Homologacao|Producao>',
    '<operacao>',        // ex: 'getCustomerData' (deve ser igual ao usado no execute())
    '<API>_Homologacao', // Named Credential (sem 'callout:')
    '</path/relativo>'   // ex: '/customers/v1/accounts/customer-data'
),
```

Colunas fixas da matrix `API_Config` (nao mude): inputs `API_Name, Environment, Operation`;
outputs `NamedCredential, Endpoint, Method, Timeout, RetryEnabled, RetryCount, LogEnabled`
(todas Text; defaults no DAO: timeout 30000, retry off, log on).

```bash
sf project deploy start --source-dir force-app/main/default/classes --target-org YourOrg --test-level NoTestRun
sf apex run --file scripts/setup-lookup.apex --target-org YourOrg
```

Confira:

```bash
sf data query --query "SELECT Name FROM CalculationMatrixRow WHERE CalculationMatrixVersionId IN (SELECT Id FROM CalculationMatrixVersion WHERE CalculationMatrixId IN (SELECT Id FROM CalculationMatrix WHERE UniqueName='API_Config'))" --target-org YourOrg
```

---

## Passo 3: Connector (1 arquivo, tudo junto)

Copie `ACMEConnector.cls` para `<API>Connector.cls` e adapte os 4 pontos marcados.
Regras: `with sharing`, `API_NAME` = API_Name da Lookup, 1 metodo `@AuraEnabled`
por operacao, `buildHttpRequest` monta `callout:<NC><endpoint>`, `processResponse`
retorna `Object` no 2xx e lanca `APIException.create('<API>_ERROR', msg, status)` no erro.

```apex
public with sharing class <API>Connector extends APIConnector {

    private static final String API_NAME = '<API_NAME>';

    public <API>Connector() {
        super(API_NAME);
    }

    // 1. OPERACAO PUBLICA (uma por operacao da Fase 0 - chama direto da FlexCard)
    @AuraEnabled(cacheable=true)
    public static Object <operacao>(<params>) {
        try {
            return new <API>Connector().execute(
                '<operacao>',
                new Map<String, Object>{ '<param>' => <valor> }
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // 1b. OVERRIDE DE AMBIENTE (so para Execute Anonymous/teste manual)
    public Object call(String operacao, Map<String, Object> params, String environment) {
        this.currentEnvironment = environment;
        return this.execute(operacao, params);
    }

    // 2. REQUEST: endpoint da Lookup + headers/params especificos da API
    protected override HttpRequest buildHttpRequest(String operacao, Map<String, Object> params) {
        // validar operacao -> INVALID_OPERATION; validar params -> INVALID_PARAM
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + config.namedCredential + config.endpoint);
        request.setMethod(config.method == null ? 'GET' : config.method.toUpperCase());
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('X-Correlation-ID', correlationId);
        // ... headers especificos (ex ACME: request.setHeader('customerId', cpf.trim()))
        request.setTimeout(config.timeout);
        return request;
    }

    // 3. RESPONSE: 2xx -> Object; erro -> APIException.create com o detalhe da API
    protected override Object processResponse(String operacao, HttpResponse response) {
        // ... (igual ao ACMEConnector: tenta extrair 'message' do body de erro)
    }
}
```

```bash
sf project deploy start --source-dir force-app/main/default/classes --target-org YourOrg --test-level NoTestRun
```

---

## Passo 4: Testes (obrigatorio)

Copie `ACMEConnectorTest.cls`. Padrao: `APIConfigDAO.mockConfig` (sem DML),
`HttpCalloutMock` por cenario (sucesso + erro), classe `Assert`, `Test.startTest/stopTest`.
Cubra: sucesso por operacao, erro HTTP (codigo + status + mensagem via `execute`
da instancia), param invalido (via metodo estatico, assert so no **tipo**
`AuraHandledException` — `getMessage()` nao expoe texto em teste).

```bash
sf apex run test --class-names <API>ConnectorTest --class-names APIConfigDAOTest \
  --result-format human --code-coverage --target-org YourOrg --wait 10
```

Referencia real (org YourOrg): 9 testes, 100% passando.
Coverage: `ACMEConnector` 93%, `APIConnector` 71%, `APIException` 75%, `APIConfigDAO` 24%.

---

## Passo 5: Teste Manual (Developer Console, VS Code ou CLI)

Use a **instancia** (`new <API>Connector().execute(...)`), nunca o metodo estatico:
`AuraHandledException` so pode ser lancada em contexto Aura/Visualforce — no
Execute Anonymous ela quebra com `LimitException` e esconde o erro real.

### 5.1 Via Developer Console (web)

```
Developer Console → Debug → Open Execute Anonymous Window
→ cole o script → Execute → veja o resultado no Log (aba Logs, duplo clique)
```

### Testar HML (homologacao)

```apex
// Execute Anonymous — HML (ambiente forçado via call())
ACMEConnector connector = new ACMEConnector();
Map<String, Object> params = new Map<String, Object>();
params.put('cpf', '12345678900');
Object result = connector.call('getCustomerData', params, 'Homologacao');
System.debug('HML Dados Cliente: ' + JSON.serializePretty(result));
```

### Testar PRD (producao)

```apex
// Execute Anonymous — PRD (ambiente forçado via call())
ACMEConnector connector = new ACMEConnector();
Map<String, Object> params = new Map<String, Object>();
params.put('cpf', '12345678900');
Object result = connector.call('getCustomerData', params, 'Producao');
System.debug('PRD Dados Cliente: ' + JSON.serializePretty(result));
```

> `execute()` resolve o ambiente automaticamente por `Organization.IsSandbox`
> (sandbox real = `Homologacao`, producao = `Producao`). So que a org de validacao
> (FSC dev) reporta `IsSandbox=false`, entao o auto-detect cai em `Producao`.
> Para testar os dois com seguranca, use `call()` com o 3o parametro explicito
> `'Homologacao'` ou `'Producao'` — funciona em qualquer org, sem depender do flag.

Para a operacao 2 (quando existir o cURL real), troque so o nome da operacao.

Template generico para novas APIs (salve em `scripts/smoke-<api>.apex`) —
use `call()` com ambiente explicito, nao `execute()` (ver nota acima):

```apex
try {
    Object result = new <API>Connector().call(
        '<operacao>', new Map<String, Object>{ '<param>' => '<valor>' }, 'Homologacao'
    );
    System.debug('SMOKE HML: ' + JSON.serialize(result));
} catch (APIException e) {
    System.debug('SMOKE HML APIERROR [' + e.getErrorCode() + ']: ' + e.getMessage());
}

try {
    Object result = new <API>Connector().call(
        '<operacao>', new Map<String, Object>{ '<param>' => '<valor>' }, 'Producao'
    );
    System.debug('SMOKE PRD: ' + JSON.serialize(result));
} catch (APIException e) {
    System.debug('SMOKE PRD APIERROR [' + e.getErrorCode() + ']: ' + e.getMessage());
}
```

### 5.2 Via VS Code / CLI (mesmo script, sem abrir o browser)

```bash
sf apex run --file scripts/smoke-<api>.apex --target-org YourOrg
```

Sucesso = `SMOKE HML`/`SMOKE PRD` com o JSON. Sem secret real, o esperado
e falhar no token com `CALLOUT_ERROR`/`<API>_ERROR` — isso ja prova
DAO + Lookup Table + endpoint + auth antes de mexer na FlexCard.

---

## Passo 6: FlexCard / OmniScript

Remote Action apontando direto para o Connector (sem Apex intermediario):

```
FlexCard: <Nome>
├── Remote Action: <API>Connector.<operacao>   (ex: ACMEConnector.getCustomerData)
├── Parameters: <param> = {!record.<CAMPO>}    (ex: cpf = {!record.CPF})
└── Output: campos do JSON retornado
```

---

## Passo 7: Deploy e Checklist de Pronto

```bash
sf project deploy start --source-dir force-app/main/default/classes \
  --source-dir force-app/main/default/namedCredentials \
  --source-dir force-app/main/default/externalCredentials \
  --source-dir force-app/main/default/permissionsets --target-org YourOrg
```

- [ ] Contrato da Fase 0 preenchido
- [ ] EC + NC criados (script) e no repo (retrieve)
- [ ] Permission Set com classes + principals, atribuido
- [ ] Linhas HML + PRD na Lookup Table (query confere)
- [ ] Connector + testes (todos passando)
- [ ] Smoke test com `SMOKE RESULT` (ou falha so no token, com secret placeholder)
- [ ] Secrets reais + Enabled for Callouts (UI, HML e PRD)
- [ ] FlexCard/OmniScript chamando `<API>Connector.<operacao>`
- [ ] Smoke test final com secret real em Homologacao

---

## Diagnostico Rapido

| Erro | Causa provavel | Acao |
|------|----------------|------|
| `CONFIG_NOT_FOUND` | Linha ausente na Lookup (API/env/operacao nao batem) | Rodar `setup-lookup.apex`; conferir `API_NAME` e nome da operacao |
| `Callout blocked for named credential` | Checkbox Enabled for Callouts desligado | Ligar na UI (HML e PRD) |
| 401 no token | client_id/secret errados ou ausentes | Preencher na UI do EC principal |
| `<API>_ERROR` + HTTP 4xx/5xx | API rejeitou a chamada (param, header, path) | Comparar com o curl da Fase 0 |
| `CALLOUT_ERROR` | Rede/timeout/endpoint | Conferir `callout:<NC><endpoint>` e timeout |
| `INVALID_PARAM` | Parametro obrigatorio vazio | Validar entrada na FlexCard |
| `LimitException: Can only throw... Aura context` | Metodo estatico chamado no Anonymous | Usar instancia + `execute()` no smoke test |

---

## Fluxo de Autenticacao (referencia ACME)

1. Connector chama `callout:ACME_Sandbox/...`
2. Salesforce busca token em `POST /oauth/v1/access-token` (`client_credentials`)
3. Salesforce injeta `Authorization: Bearer ...` e envia a chamada
4. API retorna o JSON; `processResponse` devolve `Object` para a FlexCard
