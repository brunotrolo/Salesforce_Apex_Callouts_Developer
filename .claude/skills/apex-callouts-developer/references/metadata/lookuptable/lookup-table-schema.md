# Lookup Table — API_Config (CalculationMatrix)

Dados extraídos diretamente da ORG `YourOrg` (yourorg.my.salesforce.com).

## Objeto: CalculationMatrix

| Campo | Valor |
|---|---|
| Id | `0lI000000000000AAA` |
| Name | `API Config` |
| UniqueName | `API_Config` |
| Description | Configuracao de integracoes por API + ambiente + operacao (arquitetura de referencia). |

## Versão Ativa: CalculationMatrixVersion

| Campo | Valor |
|---|---|
| Id | `0lN000000000000AAA` |
| Name | `API Config V1` |
| VersionNumber | 1 |
| IsEnabled | true |

## Colunas: CalculationMatrixColumn

| # | ApiName | ColumnType | DataType |
|---|---------|-----------|---------|
| 1 | `API_Name` | Input | Text |
| 2 | `Environment` | Input | Text |
| 3 | `Operation` | Input | Text |
| 4 | `NamedCredential` | Output | Text |
| 5 | `Endpoint` | Output | Text |
| 6 | `Method` | Output | Text |
| 7 | `Timeout` | Output | Text |
| 8 | `RetryEnabled` | Output | Text |
| 9 | `RetryCount` | Output | Text |
| 10 | `LogEnabled` | Output | Text |
| 11 | `TokenNamedCredential` | Output | Text |

> **Nota:** A coluna `TokenNamedCredential` (seq 11) existe na ORG mas não está preenchida
> nas rows atuais — as rows foram criadas antes da última revisão do `APIConfigSetup`.
> O `APIConfigSetup.setup()` correto já inclui essa coluna e a preenche nas rows.
> Para corrigir: deletar as rows atuais na ORG e rodar `setup-lookup-table.apex` novamente.

## Rows: CalculationMatrixRow (dados reais da ORG)

### Row 1 — ACME HML

| Campo | Valor |
|---|---|
| Id | `9mt000000000000AAA` |
| Name | `ACME_CustomerData_Sandbox_getCustomerData` |

**InputData:**
```json
{
  "API_Name": "ACME_CustomerData",
  "Environment": "Homologacao",
  "Operation": "getCustomerData"
}
```

**OutputData:**
```json
{
  "NamedCredential": "ACME_Sandbox",
  "Endpoint": "/customers/v1/accounts/customer-data",
  "Method": "GET",
  "Timeout": "30000",
  "RetryEnabled": "true",
  "RetryCount": "1",
  "LogEnabled": "true"
}
```

### Row 2 — ACME PRD

| Campo | Valor |
|---|---|
| Id | `9mt000000000000BBB` |
| Name | `ACME_CustomerData_Production_getCustomerData` |

**InputData:**
```json
{
  "API_Name": "ACME_CustomerData",
  "Environment": "Producao",
  "Operation": "getCustomerData"
}
```

**OutputData:**
```json
{
  "NamedCredential": "ACME_Production",
  "Endpoint": "/customers/v1/accounts/customer-data",
  "Method": "GET",
  "Timeout": "30000",
  "RetryEnabled": "true",
  "RetryCount": "1",
  "LogEnabled": "true"
}
```

---

## Como adicionar nova API

Acrescentar em `APIConfigSetup.ensureRows()`:

```apex
new RowDef(
    'NOVA_API_Recurso',    // API_Name — ex: Consorcio_Cotas
    'Homologacao',
    'nomeOperacao',        // ex: getCotas
    'NOVAAPI_Homologacao', // NamedCredential (NC base)
    'NOVAAPI_HML_Token',   // TokenNamedCredential (NC de token)
    '/path/relativo'       // Endpoint
),
new RowDef(
    'NOVA_API_Recurso',
    'Producao',
    'nomeOperacao',
    'NOVAAPI_Producao',
    'NOVAAPI_PRD_Token',
    '/path/relativo'
)
```

Rodar após alterar: `sf apex run --file scripts/setup-lookup-table.apex --target-org <alias>`
