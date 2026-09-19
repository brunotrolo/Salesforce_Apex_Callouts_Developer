/**
 * @description DAO de configuracao das integracoes.
 *              Le a Lookup Table (Business Rules Engine - CalculationMatrix)
 *              UniqueName 'API_Config' e resolve a configuracao por
 *              API + ambiente + operacao. Sem Custom Object, sem hardcode.
 */
public with sharing class APIConfigDAO {

    public static final String MATRIX_UNIQUE_NAME = 'API_Config';

    public class APIConfig {
        public String apiName;
        public String environment;
        public String operation;
        public String namedCredential;
        public String tokenNamedCredential;
        public String endpoint;
        public String method;
        public Integer timeout;
        public Boolean retryEnabled;
        public Integer retryCount;
        public Boolean logEnabled;
    }

    @TestVisible
    private static APIConfig mockConfig;

    private static Map<String, APIConfig> cache = new Map<String, APIConfig>();

    public static APIConfig getConfig(String apiName, String environment, String operation) {
        String key = apiName + '|' + environment + '|' + operation;
        if (cache.containsKey(key)) {
            return cache.get(key);
        }
        if (Test.isRunningTest() && mockConfig != null) {
            cache.put(key, mockConfig);
            return mockConfig;
        }

        List<CalculationMatrix> matrices = [
            SELECT Id FROM CalculationMatrix WHERE UniqueName = :MATRIX_UNIQUE_NAME LIMIT 1
        ];
        if (matrices.isEmpty()) {
            throw APIException.create(
                'CONFIG_NOT_FOUND',
                'Lookup Table API_Config nao encontrada. Execute APIConfigSetup.setup().'
            );
        }

        List<CalculationMatrixVersion> versions = [
            SELECT Id FROM CalculationMatrixVersion
            WHERE CalculationMatrixId = :matrices[0].Id AND IsEnabled = true
            ORDER BY VersionNumber DESC LIMIT 1
        ];
        if (versions.isEmpty()) {
            throw APIException.create('CONFIG_NOT_FOUND', 'Nenhuma versao ativa na Lookup Table API_Config.');
        }

        List<CalculationMatrixRow> rows = [
            SELECT InputData, OutputData FROM CalculationMatrixRow
            WHERE CalculationMatrixVersionId = :versions[0].Id LIMIT 1000
        ];
        for (CalculationMatrixRow row : rows) {
            Map<String, Object> input = parseJson(row.InputData);
            if (input == null) continue;
            if (
                String.valueOf(input.get('API_Name'))    == apiName &&
                String.valueOf(input.get('Environment')) == environment &&
                String.valueOf(input.get('Operation'))   == operation
            ) {
                APIConfig cfg = buildConfig(apiName, environment, operation, parseJson(row.OutputData));
                cache.put(key, cfg);
                return cfg;
            }
        }

        throw APIException.create(
            'CONFIG_NOT_FOUND',
            'Configuracao nao encontrada: ' + apiName + ' / ' + environment + ' / ' + operation
        );
    }

    public static void clearCache() {
        cache.clear();
    }

    public static String getCurrentEnvironment() {
        try {
            Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
            return org.IsSandbox ? 'Homologacao' : 'Producao';
        } catch (Exception e) {
            return 'Homologacao';
        }
    }

    private static APIConfig buildConfig(String apiName, String environment, String operation, Map<String, Object> output) {
        if (output == null) {
            throw APIException.create('CONFIG_NOT_FOUND', 'Linha sem OutputData: ' + apiName + ' / ' + environment + ' / ' + operation);
        }
        APIConfig cfg = new APIConfig();
        cfg.apiName              = apiName;
        cfg.environment          = environment;
        cfg.operation            = operation;
        cfg.namedCredential      = toText(output.get('NamedCredential'));
        cfg.tokenNamedCredential = toText(output.get('TokenNamedCredential'));
        cfg.endpoint             = toText(output.get('Endpoint'));
        cfg.method               = toText(output.get('Method'));
        cfg.timeout              = toInteger(output.get('Timeout'), 30000);
        cfg.retryEnabled         = toBoolean(output.get('RetryEnabled'), false);
        cfg.retryCount           = toInteger(output.get('RetryCount'), 0);
        cfg.logEnabled           = toBoolean(output.get('LogEnabled'), true);

        if (String.isBlank(cfg.namedCredential) || String.isBlank(cfg.endpoint)) {
            throw APIException.create('CONFIG_NOT_FOUND',
                'Config incompleta (NamedCredential/Endpoint): ' + apiName + ' / ' + environment + ' / ' + operation);
        }
        return cfg;
    }

    private static Map<String, Object> parseJson(String body) {
        if (String.isBlank(body)) return null;
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            return null;
        }
    }

    private static String toText(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Integer toInteger(Object value, Integer defaultValue) {
        if (value == null) return defaultValue;
        try {
            return Integer.valueOf(String.valueOf(value).trim());
        } catch (Exception e) {
            return defaultValue;
        }
    }

    private static Boolean toBoolean(Object value, Boolean defaultValue) {
        if (value == null) return defaultValue;
        String text = String.valueOf(value).trim().toLowerCase();
        if (text == 'true'  || text == '1') return true;
        if (text == 'false' || text == '0') return false;
        return defaultValue;
    }
}
