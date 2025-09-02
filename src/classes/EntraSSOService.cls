/*
 Author - Shivesh Kumar
 Purpose - (SSO Token Class) To authenticate Salesforce API callouts to Microsoft Graph by retrieving an access 
       token using client credentials.
 */
 
public class EntraSSOService {
 	public static String getAccessToken() {
     	SecureEntraAPIConfig__c config = SecureEntraAPIConfig__c.getOrgDefaults();
     	HttpRequest req = new HttpRequest();
     	req.setEndpoint(config.Token_URL__c.replace('{tenant-id}', config.TenantID__c));
     	req.setMethod('POST');
     	req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

     	String body = 'grant_type=client_credentials' +
                   	'&client_id=' + config.Client_ID__c +
                   	'&client_secret=' + config.Client_Secret__c +
             '&scope=' + 'https://graph.microsoft.com/.default';

     	req.setBody(body); 
     	HttpResponse res = new Http().send(req);
         
     	if (res.getStatusCode() == 200) {
         	Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
         	String accessToken = (String) result.get('access_token');
         	// Decode token to check audience
         	String[] tokenParts = accessToken.split('\\.');
         	if (tokenParts.size() > 1) {
             	String decodedPayload = EncodingUtil.base64Decode(tokenParts[1]).toString();
         	}
         	return accessToken;          
     	} else {
         	throw new CalloutException('OAuth Error: ' + res.getBody());
     	}
 	}
 }