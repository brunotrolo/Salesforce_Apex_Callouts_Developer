// =============================================================
// SETUP MANUAL DO EC ACME_SBX_Token_EC
// =============================================================
// IMPORTANTE: Este script NAO cria o EC completo via Apex.
// O EC Custom com Custom Headers NAO e suportado pela Metadata API.
// Use este script APENAS para ativar o principal apos criacao manual na UI.
//
// PASSO 1 (MANUAL NA UI):
//   Setup > Named Credentials > External Credentials > New
//   Label: ACME HML Token | Name: ACME_SBX_Token_EC | Protocol: Custom > Save
//   Principals > New: ACME_Principal (Sequence 1) > Save
//   Custom Headers > New:
//     Name: Authorization
//     Value: Basic <base64(clientId:clientSecret)>
//     Sequence: 2 > Save
//
// PASSO 2 (ESTE SCRIPT — ativa o principal):
// =============================================================

// Calcula o Basic para referencia (nao usado no script, apenas documentacao)
String clientId     = 'YOUR_CLIENT_ID'; // HML
String clientSecret = 'YOUR_CLIENT_SECRET'; // HML
String basic = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(clientId + ':' + clientSecret));
System.debug('Basic para o Custom Header: ' + basic);

// Ativa o principal no EC
try {
    ConnectApi.CredentialInput cred = new ConnectApi.CredentialInput();
    cred.externalCredential = 'ACME_SBX_Token_EC';
    cred.principalName = 'ACME_Principal';
    cred.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
    cred.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.Custom;
    cred.credentials = new Map<String, ConnectApi.CredentialValueInput>();
    ConnectApi.NamedCredentials.createCredential(cred);
    System.debug('PRINCIPAL ATIVADO: ACME_SBX_Token_EC');
} catch (Exception e) {
    System.debug('Principal (ja existe ou erro): ' + e.getMessage());
}

// Adiciona ao Permission Set API_Integration
System.debug('PROXIMO PASSO: Setup > Permission Sets > API Integration');
System.debug('> External Credential Principal Access > Edit');
System.debug('> Marcar: ACME_SBX_Token_EC - ACME_Principal > Save');
