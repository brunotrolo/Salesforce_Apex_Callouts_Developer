// Registra client_id e client_secret nos principals OAuth dos ECs.
// Rodar UMA VEZ apos o deploy dos ECs na ORG.
// Apos isso o Salesforce gerencia token automaticamente (busca, cacheia, renova).
//
// ACME HML:
//   client_id:     YOUR_CLIENT_ID
//   client_secret: YOUR_CLIENT_SECRET

try {
    ConnectApi.CredentialInput cred = new ConnectApi.CredentialInput();
    cred.externalCredential = 'ACME_Sandbox_EC';
    cred.principalName = 'ACME_Principal';
    cred.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
    cred.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.OAuth;
    cred.authenticationProtocolVariant = ConnectApi.CredentialAuthenticationProtocolVariant.ClientCredentialsClientSecret;
    ConnectApi.CredentialValueInput clientId = new ConnectApi.CredentialValueInput();
    clientId.value = 'YOUR_CLIENT_ID';
    clientId.encrypted = false;
    ConnectApi.CredentialValueInput clientSecret = new ConnectApi.CredentialValueInput();
    clientSecret.value = 'YOUR_CLIENT_SECRET';
    clientSecret.encrypted = true;
    cred.credentials = new Map<String, ConnectApi.CredentialValueInput>{
        'clientId'     => clientId,
        'clientSecret' => clientSecret
    };
    ConnectApi.NamedCredentials.createCredential(cred);
    System.debug('CREDENTIAL HML OK: ACME_Sandbox_EC');
} catch (Exception e) {
    System.debug('CREDENTIAL HML (ja existe ou erro): ' + e.getMessage());
}

// PRD: substitua pelos valores reais antes de rodar
try {
    ConnectApi.CredentialInput cred = new ConnectApi.CredentialInput();
    cred.externalCredential = 'ACME_Production_EC';
    cred.principalName = 'ACME_Principal';
    cred.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
    cred.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.OAuth;
    cred.authenticationProtocolVariant = ConnectApi.CredentialAuthenticationProtocolVariant.ClientCredentialsClientSecret;
    ConnectApi.CredentialValueInput clientId = new ConnectApi.CredentialValueInput();
    clientId.value = 'SEU_CLIENT_ID_PRD';
    clientId.encrypted = false;
    ConnectApi.CredentialValueInput clientSecret = new ConnectApi.CredentialValueInput();
    clientSecret.value = 'SEU_CLIENT_SECRET_PRD';
    clientSecret.encrypted = true;
    cred.credentials = new Map<String, ConnectApi.CredentialValueInput>{
        'clientId'     => clientId,
        'clientSecret' => clientSecret
    };
    ConnectApi.NamedCredentials.createCredential(cred);
    System.debug('CREDENTIAL PRD OK: ACME_Production_EC');
} catch (Exception e) {
    System.debug('CREDENTIAL PRD (ja existe ou erro): ' + e.getMessage());
}

System.debug('CREDENTIAL SETUP DONE');
