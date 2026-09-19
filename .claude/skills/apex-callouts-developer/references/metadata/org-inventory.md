# Inventário de Metadados na ORG YourOrg

ORG: `yourorg.my.salesforce.com` | Alias: `YourOrg` | API: 68.0

Este inventário evita retrabalho e duplicação de artefatos.
Antes de criar qualquer EC, NC ou coluna na Lookup Table, verificar aqui.

---

## External Credentials

| Label | Name (API) | Protocol | Papel |
|---|---|---|---|
| ACME HML Token | `ACME_SBX_Token_EC` | Custom | Injeta `Authorization: Basic` no request de token HML |
| ACME Homologacao | `ACME_Sandbox_EC` | OAuth 2.0 | EC OAuth criado durante exploração — **não usar** para o NC Token |
| ACME Homologacao Base | `ACME_Sandbox_Base_EC` | Custom | EC base para o NC de API HML (sem auth própria) |
| ACME Producao Base | `ACME_Production_Base_EC` | Custom | EC base para o NC de API PRD (sem auth própria) |

> **Atenção:** `ACME_Sandbox_EC` (OAuth) foi criado durante exploração da POC.
> O NC de token (`ACME_SBX_Token`) deve apontar para `ACME_SBX_Token_EC` (Custom), não para este.

### Principals registrados

| EC | Principal | Client ID | Status |
|---|---|---|---|
| `ACME_SBX_Token_EC` | `ACME_Principal` | `YOUR_CLIENT_ID` | Configured |
| `ACME_Sandbox_EC` | `ACME_Principal` | `YOUR_CLIENT_ID` | Configured |

---

## Named Credentials

| Label | Name (API) | URL | EC | Papel |
|---|---|---|---|---|
| ACME HML Token | `ACME_SBX_Token` | `https://api-sbx.acmecorp.com/oauth/v1/access-token` | `ACME_SBX_Token_EC` | Busca token HML |
| ACME Homologacao | `ACME_Sandbox` | `https://api-sbx.acmecorp.com` | `ACME_Sandbox_EC` | URL base da API HML |

> **Atenção:** `ACME_Sandbox` NC aponta atualmente para `ACME_Sandbox_EC` (OAuth).
> Para a arquitetura correta, deve apontar para `ACME_Sandbox_Base_EC` (Custom).
> Corrigir via UI ou deploy do XML corrigido.

---

## Permission Set: API_Integration

| Componente | Tipo |
|---|---|
| `APIConfigDAO` | Apex Class |
| `APIConfigSetup` | Apex Class |
| `APIConnector` | Apex Class |
| `APIException` | Apex Class |
| `ACMEConnector` | Apex Class |
| `ACME_Sandbox_EC-ACME_Principal` | External Credential Principal |
| `ACME_Production_EC-ACME_Principal` | External Credential Principal |
| `ACME_Sandbox_Base_EC-ACME_Principal` | External Credential Principal |
| `ACME_Production_Base_EC-ACME_Principal` | External Credential Principal |

> **Faltam adicionar ao Permission Set:** `ACME_SBX_Token_EC-ACME_Principal`

---

## Lookup Table: API_Config (CalculationMatrix)

- **Matrix Id:** `0lI000000000000AAA`
- **Version Id:** `0lN000000000000AAA` (v1, IsEnabled=true)
- **Colunas:** API_Name, Environment, Operation (inputs) + NamedCredential, Endpoint, Method, Timeout, RetryEnabled, RetryCount, LogEnabled, TokenNamedCredential (outputs)

**Rows ativas:**

| Row Name | API_Name | Environment | NamedCredential | Endpoint |
|---|---|---|---|---|
| `ACME_CustomerData_Sandbox_getCustomerData` | ACME_CustomerData | Homologacao | ACME_Sandbox | /customers/v1/accounts/customer-data |
| `ACME_CustomerData_Production_getCustomerData` | ACME_CustomerData | Producao | ACME_Production | /customers/v1/accounts/customer-data |

> **Nota:** `TokenNamedCredential` está vazio nas rows. Corrigir rodando `setup-lookup-table.apex`.

---

## Apex Classes deployadas

| Classe | Papel |
|---|---|
| `APIConnector` | Classe abstrata base — Template Method |
| `APIConfigDAO` | DAO da Lookup Table |
| `APIConfigSetup` | Cria/atualiza Lookup Table (idempotente) |
| `APIException` | Exception customizada de integração |
| `ACMEConnector` | Connector da API ACME dados do cliente |
| `ACMEConnectorTest` | Testes do ACMEConnector |
| `APIConfigDAOTest` | Testes do APIConfigDAO |

---

## Pendências conhecidas na ORG atual (POC)

| Pendência | Impacto | Como corrigir |
|---|---|---|
| `ACME_Sandbox` NC aponta para EC OAuth | Callout da API falha sem auth correta | UI: editar NC, trocar EC para `ACME_Sandbox_Base_EC` |
| `TokenNamedCredential` vazio nas rows | `getAccessToken()` não sabe qual NC de token usar | Deletar rows e rodar `setup-lookup-table.apex` |
| `ACME_SBX_Token_EC-ACME_Principal` fora do PS | Usuários não-admin sem acesso ao token | UI: Permission Sets > API_Integration > EC Principal Access |
| IPs Salesforce bloqueados no WAF Incapsula | Callout retorna 403 | Infra: liberar IPs Salesforce no WAF para `api-sbx.acmecorp.com` |
