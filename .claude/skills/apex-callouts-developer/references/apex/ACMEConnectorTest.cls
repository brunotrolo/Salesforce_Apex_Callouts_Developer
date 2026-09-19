/**
 * @description Testes do ACMEConnector (sucesso, erro HTTP, param invalido).
 */
@isTest
private class ACMEConnectorTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Assert.areEqual('GET', request.getMethod(), 'Metodo deve ser GET.');
            Assert.isTrue(
                request.getEndpoint().startsWith('callout:ACME_Sandbox/'),
                'Endpoint deve usar o Named Credential de homologacao.'
            );
            Assert.areEqual('12345678900', request.getHeader('customerId'), 'Header customerId deve levar o CPF.');
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"cpf":"12345678900","nome":"Joao Silva","email":"joao@email.com"}');
            return response;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(400);
            response.setBody('{"message":"CPF invalido"}');
            return response;
        }
    }

    private static void useMockConfig() {
        APIConfigDAO.APIConfig cfg = new APIConfigDAO.APIConfig();
        cfg.apiName = 'ACME_CustomerData';
        cfg.environment = 'Homologacao';
        cfg.namedCredential = 'ACME_Sandbox';
        cfg.endpoint = '/customers/v1/accounts/customer-data';
        cfg.method = 'GET';
        cfg.timeout = 30000;
        cfg.retryEnabled = false;
        cfg.retryCount = 0;
        cfg.logEnabled = false;
        APIConfigDAO.mockConfig = cfg;
    }

    @isTest
    static void shouldReturnClientData_WhenValidCpf() {
        // Given
        useMockConfig();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        // When
        Test.startTest();
        Object result = ACMEConnector.getCustomerData('12345678900');
        Test.stopTest();

        // Then
        Assert.isNotNull(result, 'Resultado nao pode ser nulo.');
        Map<String, Object> data = (Map<String, Object>) result;
        Assert.areEqual('Joao Silva', data.get('nome'), 'Nome deve vir da API.');
    }

    @isTest
    static void shouldThrowAuraException_WhenApiReturnsError() {
        // Given
        useMockConfig();
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        // When
        Test.startTest();
        try {
            ACMEConnector.getCustomerData('00000000000');
            Assert.fail('Deveria lancar excecao.');
        } catch (AuraHandledException e) {
            // Then: AuraHandledException nao expoe getMessage() em teste;
            // o tipo da excecao ja prova o caminho de erro da API.
            Assert.isInstanceOfType(e, AuraHandledException.class, 'Deve ser AuraHandledException.');
        }
        Test.stopTest();
    }

    @isTest
    static void shouldCarryApiMessage_WhenApiReturnsError() {
        // Given
        useMockConfig();
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        // When
        Test.startTest();
        try {
            new ACMEConnector().execute('getCustomerData', new Map<String, Object>{ 'cpf' => '00000000000' });
            Assert.fail('Deveria lancar APIException.');
        } catch (APIException e) {
            // Then
            Assert.areEqual('ACME_ERROR', e.getErrorCode(), 'Codigo deve ser ACME_ERROR.');
            Assert.areEqual(400, e.getHttpStatusCode(), 'Status deve ser 400.');
            Assert.isTrue(
                e.getMessage().contains('CPF invalido'),
                'Mensagem deve repassar o erro da API: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void shouldThrowAuraException_WhenCpfIsBlank() {
        // Given
        useMockConfig();

        // When
        Test.startTest();
        try {
            ACMEConnector.getCustomerData('');
            Assert.fail('Deveria lancar excecao para CPF vazio.');
        } catch (AuraHandledException e) {
            // Then: tipo da excecao prova a validacao de CPF obrigatorio.
            Assert.isInstanceOfType(e, AuraHandledException.class, 'Deve ser AuraHandledException.');
        }
        Test.stopTest();
    }

    @isTest
    static void shouldExposeErrorCode_WhenApiException() {
        // Given
        APIException e = APIException.create('ACME_ERROR', 'Falha', 500);

        // Then
        Assert.areEqual('ACME_ERROR', e.getErrorCode(), 'Error code deve ser preservado.');
        Assert.areEqual(500, e.getHttpStatusCode(), 'Status HTTP deve ser preservado.');
    }

    @isTest
    static void shouldOverrideEnvironment_WhenUsingCall() {
        // Given
        APIConfigDAO.APIConfig cfg = new APIConfigDAO.APIConfig();
        cfg.apiName = 'ACME_CustomerData';
        cfg.environment = 'Producao';
        cfg.namedCredential = 'ACME_Production';
        cfg.endpoint = '/customers/v1/accounts/customer-data';
        cfg.method = 'GET';
        cfg.timeout = 30000;
        cfg.retryEnabled = false;
        cfg.retryCount = 0;
        cfg.logEnabled = false;
        APIConfigDAO.mockConfig = cfg;
        Test.setMock(HttpCalloutMock.class, new ProducaoMock());

        // When
        Test.startTest();
        Object result = new ACMEConnector().call(
            'getCustomerData',
            new Map<String, Object>{ 'cpf' => '12345678900' },
            'Producao'
        );
        Test.stopTest();

        // Then
        Assert.isNotNull(result, 'Resultado nao pode ser nulo.');
    }

    private class ProducaoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            Assert.isTrue(
                request.getEndpoint().startsWith('callout:ACME_Production/'),
                'Override deve usar o Named Credential de producao.'
            );
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"cpf":"12345678900","nome":"Joao Silva"}');
            return response;
        }
    }
}
