# 07 - Inventario de Artefatos (para empacotamento DevOps)

Lista completa dos artefatos criados e **deployados na org `YourOrg`** na
implementacao da arquitetura de integracoes (ACME como primeira API).

> Objetivo: servir de base para montar o package (DX / 2GP / unlocked) no futuro.
> Metadata abaixo = itens **empacotaveis**. "Data / setup" = itens criados em
> runtime (nao entram no package; entram num script de instalacao).

---

## 1. Apex Classes (metadata: `ApexClass`)

| Classe | Tipo | Responsabilidade |
|--------|------|------------------|
| `APIConnector` | abstrata (base) | Template Method: `execute()` -> preProcess/build/send/process/log |
| `APIException` | concreta | Excecao padronizada (`create()` factory + errorCode + httpStatus) |
| `APIConfigDAO` | concreta | Le a Lookup Table `API_Config` e resolve config por API+ambiente+operacao |
| `APIConfigSetup` | concreta | Cria a Lookup Table 100% via codigo (idempotente) |
| `ACMEConnector` | concreta (extends base) | Integracao ACME: `getCustomerData()` + `call()` (override de ambiente) |
| `ACMEConnectorTest` | teste | Testes do connector (sucesso, erro, param invalido, override ambiente) |
| `APIConfigDAOTest` | teste | Testes do DAO |

Cobertura real: `ACMEConnector` 93%, `APIConnector` 71%, `APIException` 75%, `APIConfigDAO` 24% (9/9 testes passando).

---

## 2. External Credentials (metadata: `ExternalCredential`)

OAuth2 `client_credentials` (o token e buscado/cacheado/renovado automaticamente pela Named Credential).

| Developer Name | AuthProviderUrl (token endpoint) | Principal |
|----------------|-----------------------------------|-----------|
| `ACME_Sandbox_EC` | `https://api.acmecorp.com/oauth/v1/access-token` | `ACME_Principal` |
| `ACME_Production_EC` | `https://api.acmecorp.com/oauth/v1/access-token` | `ACME_Principal` |

> Os **secrets** (client_id / client_secret) nao sao empacotaveis — entram pela UI
> do principal (ver Passo 1.5 do doc 06), ou via `setup-acme-secrets.apex` com placeholders.

---

## 3. Named Credentials (metadata: `NamedCredential`)

Tipo `SecuredEndpoint`, `generateAuthorizationHeader=true` (o Salesforce injeta o `Bearer`).

| Developer Name | External Credential | Callout URL |
|----------------|---------------------|-------------|
| `ACME_Sandbox` | `ACME_Sandbox_EC` | `https://api.acmecorp.com` |
| `ACME_Production` | `ACME_Production_EC` | `https://api.acmecorp.com` |

> Atencao packaging: o checkbox **Enabled for Callouts** e UI-only (o org ignora
> metadata/API/bulk). Apos instalar o package, ligar manualmente nas 2 credenciais.

---

## 4. Permission Set (metadata: `PermissionSet`)

| Name | Label | Concede |
|------|-------|---------|
| `API_Integration` | API Integration | Acesso as classes + principals OAuth2 de **todas** as APIs |

`classAccesses`: `APIConfigDAO`, `APIConnector`, `APIException`, `ACMEConnector`
`externalCredentialPrincipalAccesses`: `ACME_Sandbox_EC-ACME_Principal`, `ACME_Production_EC-ACME_Principal`

> E um Permission Set **unico** para todas as APIs: cada API nova so acrescenta o
> `classAccesses` (<API>Connector) e os principals dela neste mesmo arquivo.

---

## 5. Lookup Table (data: `CalculationMatrix` / `CalculationMatrixVersion` / `CalculationMatrixColumn` / `CalculationMatrixRow`)

Business Rules Engine (objetos standard), **criado via codigo** em runtime — nao entra no package.
Empacotar apenas o `APIConfigSetup.cls`; a criacao/atualizacao e feita pelo `setup()` no install.

| Objeto | Name / UniqueName | Estado |
|--------|-------------------|--------|
| CalculationMatrix | `API Config` / `API_Config` | ativo |
| CalculationMatrixVersion | `v1` | enabled, VersionNumber 1 |
| 10 columns | ver abaixo | Input (3) + Output (7) |
| 2 rows | `getCustomerData` x {Homologacao, Producao} | ativas |

Colunas (todas `DataType=Text`):

| # | ApiName | ColumnType |
|---|---------|------------|
| 1 | `API_Name` | Input |
| 2 | `Environment` | Input |
| 3 | `Operation` | Input |
| 4 | `NamedCredential` | Output |
| 5 | `Endpoint` | Output |
| 6 | `Method` | Output |
| 7 | `Timeout` | Output |
| 8 | `RetryEnabled` | Output |
| 9 | `RetryCount` | Output |
| 10 | `LogEnabled` | Output |

Linhas atuais:

| API_Name | Environment | Operation | NamedCredential | Endpoint |
|----------|-------------|-----------|-----------------|----------|
| `ACME_CustomerData` | Homologacao | `getCustomerData` | `ACME_Sandbox` | `/customers/v1/accounts/customer-data` |
| `ACME_CustomerData` | Producao | `getCustomerData` | `ACME_Production` | `/customers/v1/accounts/customer-data` |

---

## 6. Scripts de apoio (repo, nao empacotados)

Ferramentas de setup/smoke. Ficam em `scripts/` e nao vao para o package.

| Arquivo | Funcao |
|---------|--------|
| `scripts/setup-lookup.apex` | Roda `APIConfigSetup.setup()` (cria/atualiza Lookup Table) |
| `scripts/setup-bcp-auth.apex` | Cria EC + NC via `ConnectApi.NamedCredentials` (idempotente) |
| `scripts/setup-acme-secrets.apex` | Preenche client_id/secret (comeca com placeholders) |
| `scripts/smoke-acme.apex` | Smoke test fim-a-fim HML + PRD (via `call()`) |

---

## 7. Mapa de empacotamento (resumo)

| Camada | Item | Vai no package? |
|--------|------|-----------------|
| Codigo | `APIConnector`, `APIException`, `APIConfigDAO`, `APIConfigSetup`, `ACMEConnector` + testes | Sim (`ApexClass`) |
| Auth | `ACME_Sandbox_EC`, `ACME_Production_EC` | Sim (`ExternalCredential`) |
| Auth | `ACME_Sandbox`, `ACME_Production` | Sim (`NamedCredential`) |
| Permissao | `API_Integration` | Sim (`PermissionSet`) |
| Config | Lookup Table `API_Config` (matrix/version/columns/rows) | Nao — data; criar via `APIConfigSetup.setup()` no install |
| Segredos | client_id/secret | Nao — UI/script no pos-install |
| UI-only | Enabled for Callouts | Nao — ligar manualmente no pos-install |

---

## 8. Passos pos-install (robo DevOps / instrucao)

1. Executar `scripts/setup-lookup.apex` (cria a Lookup Table via `APIConfigSetup.setup()`).
2. Preencher secrets reais em `ACME_Sandbox_EC` e `ACME_Production_EC` (UI ou `setup-acme-secrets.apex`).
3. Ligar **Enabled for Callouts** em `ACME_Sandbox` e `ACME_Production` (UI).
4. Rodar `scripts/smoke-acme.apex` (deve retornar JSON em HML e PRD).
5. Atribuir `API_Integration` ao usuario via `sf org assign permset --name API_Integration ...`.