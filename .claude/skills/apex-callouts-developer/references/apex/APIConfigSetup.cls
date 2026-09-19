/**
 * @description Cria a Lookup Table API_Config (Business Rules Engine) 100% via codigo.
 *              Idempotente: pode rodar quantas vezes quiser sem duplicar dados.
 *              Uso: sf apex run -f scripts/setup-lookup.apex --target-org <alias>
 *                   ou Developer Console: APIConfigSetup.setup();
 *
 *              Colunas da tabela:
 *              INPUTS:  API_Name | Environment | Operation
 *              OUTPUTS: NamedCredential | TokenNamedCredential | Endpoint |
 *                       Method | Timeout | RetryEnabled | RetryCount | LogEnabled
 */
public with sharing class APIConfigSetup {

    private static final String MATRIX_LABEL       = 'API Config';
    private static final String MATRIX_UNIQUE_NAME = 'API_Config';
    private static final String VERSION_NAME       = 'v1';

    private class ColumnDef {
        String name; String type; Integer seq;
        ColumnDef(String name, String type, Integer seq) {
            this.name = name; this.type = type; this.seq = seq;
        }
    }

    private class RowDef {
        String apiName, environment, operation, namedCredential, tokenNamedCredential, endpoint;
        RowDef(String apiName, String environment, String operation,
               String namedCredential, String tokenNamedCredential, String endpoint) {
            this.apiName             = apiName;
            this.environment         = environment;
            this.operation           = operation;
            this.namedCredential     = namedCredential;
            this.tokenNamedCredential = tokenNamedCredential;
            this.endpoint            = endpoint;
        }
    }

    public static void setup() {
        Id matrixId  = ensureMatrix();
        ensureColumns(matrixId);
        Id versionId = ensureVersion(matrixId);
        ensureRows(versionId);
        ensureVersionEnabled(versionId);
        APIConfigDAO.clearCache();
        System.debug('APIConfigSetup.setup() concluido com sucesso.');
    }

    private static Id ensureMatrix() {
        List<CalculationMatrix> existing = [
            SELECT Id FROM CalculationMatrix WHERE UniqueName = :MATRIX_UNIQUE_NAME LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0].Id;
        CalculationMatrix m = new CalculationMatrix(
            Name        = MATRIX_LABEL,
            UniqueName  = MATRIX_UNIQUE_NAME,
            Description = 'Configuracao de integracoes por API + ambiente + operacao.'
        );
        insert m;
        return m.Id;
    }

    private static Id ensureVersion(Id matrixId) {
        List<CalculationMatrixVersion> all = [
            SELECT Id FROM CalculationMatrixVersion
            WHERE CalculationMatrixId = :matrixId ORDER BY VersionNumber DESC LIMIT 1
        ];
        if (!all.isEmpty()) return all[0].Id;
        CalculationMatrixVersion v = new CalculationMatrixVersion(
            Name = VERSION_NAME, CalculationMatrixId = matrixId,
            IsEnabled = false, VersionNumber = 1
        );
        insert v;
        return v.Id;
    }

    private static void ensureVersionEnabled(Id versionId) {
        CalculationMatrixVersion v = [
            SELECT Id, IsEnabled FROM CalculationMatrixVersion WHERE Id = :versionId LIMIT 1
        ];
        if (!v.IsEnabled) { v.IsEnabled = true; update v; }
    }

    private static void ensureColumns(Id matrixId) {
        List<ColumnDef> defs = new List<ColumnDef>{
            new ColumnDef('API_Name',             'Input',  1),
            new ColumnDef('Environment',          'Input',  2),
            new ColumnDef('Operation',            'Input',  3),
            new ColumnDef('NamedCredential',      'Output', 4),
            new ColumnDef('Endpoint',             'Output', 5),
            new ColumnDef('Method',               'Output', 6),
            new ColumnDef('Timeout',              'Output', 7),
            new ColumnDef('RetryEnabled',         'Output', 8),
            new ColumnDef('RetryCount',           'Output', 9),
            new ColumnDef('LogEnabled',           'Output', 10),
            new ColumnDef('TokenNamedCredential', 'Output', 11)
        };
        Map<String, Boolean> existing = new Map<String, Boolean>();
        for (CalculationMatrixColumn col : [
            SELECT ApiName FROM CalculationMatrixColumn WHERE CalculationMatrixId = :matrixId
        ]) { existing.put(col.ApiName, true); }

        List<CalculationMatrixColumn> toInsert = new List<CalculationMatrixColumn>();
        for (ColumnDef def : defs) {
            if (existing.containsKey(def.name)) continue;
            toInsert.add(new CalculationMatrixColumn(
                CalculationMatrixId = matrixId, Name = def.name,
                ApiName = def.name, ColumnType = def.type,
                DataType = 'Text', DisplaySequence = def.seq
            ));
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    private static void ensureRows(Id versionId) {
        // Padrao de nomes:
        //   NamedCredential      = <API>_<Ambiente>       (URL base da API)
        //   TokenNamedCredential = <API>_<Amb>_Token      (endpoint de token com Basic no header)
        List<RowDef> defs = new List<RowDef>{
            new RowDef('ACME_CustomerData', 'Sandbox', 'getCustomerData',
                'ACME_Sandbox', 'ACME_SBX_Token',
                '/customers/v1/accounts/customer-data'),
            new RowDef('ACME_CustomerData', 'Production', 'getCustomerData',
                'ACME_Production', 'ACME_PRD_Token',
                '/customers/v1/accounts/customer-data')
        };

        Set<String> existingKeys = new Set<String>();
        for (CalculationMatrixRow row : [
            SELECT InputData FROM CalculationMatrixRow
            WHERE CalculationMatrixVersionId = :versionId LIMIT 1000
        ]) {
            String k = keyOf(row.InputData);
            if (k != null) existingKeys.add(k);
        }

        List<CalculationMatrixRow> toInsert = new List<CalculationMatrixRow>();
        for (RowDef def : defs) {
            String key = def.apiName + '|' + def.environment + '|' + def.operation;
            if (existingKeys.contains(key)) continue;
            toInsert.add(new CalculationMatrixRow(
                Name = def.apiName + '_' + def.environment + '_' + def.operation,
                CalculationMatrixVersionId = versionId,
                InputData = JSON.serialize(new Map<String, Object>{
                    'API_Name' => def.apiName, 'Environment' => def.environment, 'Operation' => def.operation
                }),
                OutputData = JSON.serialize(new Map<String, Object>{
                    'NamedCredential'      => def.namedCredential,
                    'TokenNamedCredential' => def.tokenNamedCredential,
                    'Endpoint'             => def.endpoint,
                    'Method'               => 'GET',
                    'Timeout'              => '30000',
                    'RetryEnabled'         => 'true',
                    'RetryCount'           => '1',
                    'LogEnabled'           => 'true'
                })
            ));
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    private static String keyOf(String inputData) {
        if (String.isBlank(inputData)) return null;
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(inputData);
            if (!m.containsKey('API_Name') || !m.containsKey('Environment') || !m.containsKey('Operation')) return null;
            return String.valueOf(m.get('API_Name')) + '|' +
                   String.valueOf(m.get('Environment')) + '|' +
                   String.valueOf(m.get('Operation'));
        } catch (Exception e) { return null; }
    }
}
