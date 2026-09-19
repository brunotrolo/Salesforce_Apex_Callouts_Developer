// Smoke test: seleciona ambiente explicitamente via call().
// Nesta org de validacao IsSandbox=false -> execute() cairia em Producao.
// Use call() para forcar HML ou PRD.
Map<String, Object> params = new Map<String, Object>{ 'cpf' => '12345678900' };

try {
    Object hml = new ACMEConnector().call('getCustomerData', params, 'Homologacao');
    System.debug('HML RESULT: ' + JSON.serialize(hml));
} catch (APIException e) {
    System.debug('HML APIERROR [' + e.getErrorCode() + ']: ' + e.getMessage());
}

try {
    Object prd = new ACMEConnector().call('getCustomerData', params, 'Producao');
    System.debug('PRD RESULT: ' + JSON.serialize(prd));
} catch (APIException e) {
    System.debug('PRD APIERROR [' + e.getErrorCode() + ']: ' + e.getMessage());
}