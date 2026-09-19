# Checklist — Nova API

Preencha antes de iniciar a skill para garantir o máximo de contexto.

## 1. Contrato da API
- Nome / sistema: ___
- Base URL SBX: https://___
- Base URL PRD: https://___
- Endpoints: `GET /path` / `POST /path`
- Auth: OAuth Client Credentials | API Key | Basic fixo | Sem auth
- Token endpoint: https://___
- Client ID SBX: ___ | Client Secret SBX: ___
- Headers obrigatórios: customerId, X-Custom...

## 2. Exemplo curl SBX

```bash
curl --location 'https://...' \
  --header 'Authorization: Basic <base64>' \
  --header 'Content-Type: application/json' \
  --data '{"grant_type":"client_credentials"}'
```

## 3. Exemplo de Resposta 200

```json
{ "campo": "valor" }
```

## 4. Contexto de Uso
- Produto: Consórcio | Conta Digital | Cartão | Massificados
- Acionado por: FlexCard | OmniScript | Flow | Trigger
- Dados sensíveis: SIM (CPF, saldo) | NÃO

## 5. Classe Legada (se migração)
- Nome da classe: ___
- Classe base: CachedTokenAPI | LegacyAPIConnector | SimpleNCConnector | outra
- Número de filhas: ___

## 6. Nomenclatura TO BE
- API_Name: `<SISTEMA>_<Recurso>` ex: `ACME_CustomerData`
- Connector: `<Sistema>Connector`
- EC Token SBX: `<Sistema>_SBX_Token_EC`
- NC Token SBX: `<Sistema>_SBX_Token`
- EC Base SBX: `<Sistema>_Sandbox_Base_EC`
- NC Base SBX: `<Sistema>_Sandbox`
