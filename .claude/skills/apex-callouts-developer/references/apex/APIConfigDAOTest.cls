/**
 * @description Testes do APIConfigDAO (mock, ambiente, config ausente).
 */
@isTest
private class APIConfigDAOTest {

    @isTest
    static void shouldReturnMockConfig_WhenRunningTest() {
        // Given
        APIConfigDAO.APIConfig cfg = new APIConfigDAO.APIConfig();
        cfg.apiName = 'ACME_CustomerData';
        cfg.environment = 'Sandbox';
        cfg.operation = 'getCustomerData';
        cfg.namedCredential = 'ACME_Sandbox';
        cfg.endpoint = '/x';
        cfg.method = 'GET';
        cfg.timeout = 30000;
        cfg.retryEnabled = false;
        cfg.retryCount = 0;
        cfg.logEnabled = false;
        APIConfigDAO.mockConfig = cfg;

        // When
        Test.startTest();
        APIConfigDAO.APIConfig result = APIConfigDAO.getConfig(
            'ACME_CustomerData',
            'Sandbox',
            'getCustomerData'
        );
        Test.stopTest();

        // Then
        Assert.areEqual('ACME_Sandbox', result.namedCredential, 'Deve retornar o mock.');
        APIConfigDAO.mockConfig = null;
        APIConfigDAO.clearCache();
    }

    @isTest
    static void shouldReturnEnvironment_WhenAsked() {
        // When
        Test.startTest();
        String env = APIConfigDAO.getCurrentEnvironment();
        Test.stopTest();

        // Then
        Assert.isTrue(
            env == 'Sandbox' || env == 'Production',
            'Ambiente deve ser Sandbox ou Production: ' + env
        );
    }

    @isTest
    static void shouldThrowConfigNotFound_WhenNoLookupTable() {
        // Given: sem mock e sem dados de Lookup Table no teste
        APIConfigDAO.mockConfig = null;
        APIConfigDAO.clearCache();

        // When
        Test.startTest();
        try {
            APIConfigDAO.getConfig('API_INEXISTENTE', 'Sandbox', 'op');
            Assert.fail('Deveria lancar CONFIG_NOT_FOUND.');
        } catch (APIException e) {
            // Then
            Assert.areEqual('CONFIG_NOT_FOUND', e.getErrorCode(), 'Codigo deve ser CONFIG_NOT_FOUND.');
        }
        Test.stopTest();
    }
}
