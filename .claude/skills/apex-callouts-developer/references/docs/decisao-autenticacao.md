# Decisão Arquitetural — Autenticação em Callouts FSC

## Contexto

Durante a POC de migração Service Cloud → FSC, foi necessário integrar a API ACME
(dados do cliente) usando Named Credentials e External Credentials do Salesforce.

## O Problema

A API ACME exige o seguinte formato para obter o access token:

```bash
curl POST https://api-sbx.acmecorp.com/oauth/v1/access-token
  -H "Content-Type: application/json"
  -H "Authorization: Basic base64(clientId:clientSecret)"
  -d '{"grant_type":"client_credentials"}'
```

**Isso é OAuth 2.0 Client Credentials com uma não-conformidade:** o `grant_type` vem
no body como **JSON**, e não como `application/x-www-form-urlencoded` (exigido pelo RFC 6749).

## Por que o EC OAuth Nativo Não Funciona

O External Credential com `Authentication Protocol = OAuth 2.0` e
`Client Credentials with Client Secret Flow` do Salesforce envia as credenciais como:

```
Content-Type: application/x-www-form-urlencoded
Body: grant_type=client_credentials&client_id=X&client_secret=Y
```

ou com `Pass client credentials in request body` desmarcado:

```
Authorization: Basic base64(clientId:clientSecret)
Body: grant_type=client_credentials  (form-urlencoded)
```

Em ambos os casos, a API ACME retorna `400 - Missing required parameter 'grant_type'`
porque não aceita form-urlencoded, apenas JSON.

## Decisão Adotada — Custom EC + Token no Apex

Arquitetura validada espelhando o padrão `AcmeBankV2_API` da LegacyOrg (que funciona em produção):

```
┌─────────────────────────────────────────────────────┐
│                    AUTENTICAÇÃO                      │
│                                                      │
│  ACME_Sandbox_EC (Custom)                         │
│  └── AuthHeader: Basic base64(clientId:secret)       │
│       associado a ACME_SBX_Token NC                   │
│                                                      │
│  ACME_SBX_Token NC                                    │
│  └── URL: .../oauth/v1/access-token          │
│  └── allowMergeFieldsInHeader: true                  │
│  └── generateAuthorizationHeader: false              │
└─────────────────────────────────────────────────────┘
          │
          │ APIConnector.getAccessToken()
          │ POST com body JSON + Basic do EC
          ▼
┌─────────────────────────────────────────────────────┐
│                  CACHE DE TOKEN                      │
│  TOKEN_CACHE (Map estático por transação)            │
│  TTL = expires_in - 60s (máx 3540s)                 │
│  Renovação automática em 401                         │
└─────────────────────────────────────────────────────┘
          │
          │ setHeader('Authorization', 'Bearer ' + token)
          ▼
┌─────────────────────────────────────────────────────┐
│                  CHAMADA DA API                      │
│  ACME_Sandbox NC                                  │
│  └── URL: https://api-sbx.acmecorp.com │
│  └── generateAuthorizationHeader: false              │
│  └── EC: ACME_Sandbox_Base_EC (sem auth própria)  │
│                                                      │
│  callout:ACME_Sandbox + /conta/bl/.../customer-data│
│  + Header customerId: <cpf>                           │
└─────────────────────────────────────────────────────┘
```

## Artefatos por Papel

| Artefato | Papel | Observação |
|---|---|---|
| `ACME_Sandbox_EC` | Carrega o Basic do token HML | `authenticationProtocol=Custom`, `AuthHeader` |
| `ACME_Production_EC` | Carrega o Basic do token PRD | Atualizar `parameterValue` antes do deploy PRD |
| `ACME_SBX_Token` NC | Aponta para o endpoint de token HML | `allowMergeFieldsInHeader=true` |
| `ACME_PRD_Token` NC | Aponta para o endpoint de token PRD | idem |
| `ACME_Sandbox_Base_EC` | Principal sem auth — container | Necessário para o NC base funcionar |
| `ACME_Sandbox` NC | URL base da API HML | `generateAuthorizationHeader=false` |
| `ACME_Production` NC | URL base da API PRD | idem |
| `API_Integration` Permission Set | Acesso às classes e principals | Atribuir ao usuário de integração |

## Para Adicionar uma Nova API (padrão ACME)

1. Criar `<API>_Homologacao_EC` com Basic base64 do ambiente HML
2. Criar `<API>_HML_Token` NC apontando para o token endpoint
3. Criar `<API>_Homologacao_Base_EC` (Custom sem parâmetros)
4. Criar `<API>_Homologacao` NC com URL base da API
5. Adicionar linhas na Lookup Table via `APIConfigSetup`
6. Criar `<API>Connector` estendendo `APIConnector`
7. Adicionar principals ao Permission Set `API_Integration`

## Limitação da POC

O bloqueio observado via WAF (Incapsula/Imperva) na POC ocorre porque chamadas HTTP diretas
de Apex saem de IPs Salesforce não homologados. Em ORG oficial com whitelist aprovada,
o padrão `callout:ACME_SBX_Token` funciona sem o bloqueio do WAF.

**Esta arquitetura está pronta para produção** — o código, ECs e NCs estão corretos.
O único pré-requisito operacional é a liberação dos IPs Salesforce no WAF da infraestrutura.
