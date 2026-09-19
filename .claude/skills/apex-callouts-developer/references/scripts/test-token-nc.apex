HttpRequest req = new HttpRequest();
req.setEndpoint('callout:ACME_SBX_Token');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setBody('{"grant_type":"client_credentials"}');
Http http = new Http();
HttpResponse res = http.send(req);
System.debug('TOKEN_NC_STATUS: ' + res.getStatusCode());
System.debug('TOKEN_NC_BODY: ' + res.getBody());
