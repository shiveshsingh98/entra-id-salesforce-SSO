/*
 Author - Shivesh Kumar
 Purpose - (API Utility Class) Provides methods to interact with the Microsoft Graph API for user and group management.
 */
 
public class EntraUserAPI {
 	public static String getUserIdByEmail(String email, String token) {
     	HttpRequest req = new HttpRequest();
     	String filter = 'mail eq \'' + email + '\'';
     	String encodedFilter = EncodingUtil.urlEncode(filter, 'UTF-8');
     	req.setEndpoint('https://graph.microsoft.com/v1.0/users?$filter=' + encodedFilter);
     	req.setMethod('GET');
     	req.setHeader('Authorization', 'Bearer ' + token);
     	req.setHeader('Content-Type', 'application/json');
     	req.setHeader('Accept', 'application/json');

     	try {
         	HttpResponse res = new Http().send(req);
         	if (res.getStatusCode() == 200) {
             	Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
             	List<Object> users = (List<Object>) result.get('value');
             	if (!users.isEmpty()) {
                 	return (String)((Map<String, Object>) users[0]).get('id');
             	}
             	return null;
         	} else {
             	System.debug(LoggingLevel.ERROR, 'Failed to get user ID for email: ' + email + ', Status: ' + res.getStatusCode() + ', Body: ' + res.getBody());
             	throw new CalloutException('Unexpected status code: ' + res.getStatusCode() + ', ' + res.getBody());
         	}
     	} catch (Exception e) {
         	System.debug(LoggingLevel.ERROR, 'Error getting user ID for email: ' + email + ', Error: ' + e.getMessage());
         	throw e;
     	}
 	}

 	public static String createGuestUser(String email, String displayName, String token, String firstName, String lastName, String customerNumber, String sfid2) {
     	Http http = new Http();
     	HttpRequest request = new HttpRequest();
     request.setEndpoint('https://graph.microsoft.com/v1.0/invitations');
     	request.setMethod('POST');
     	request.setHeader('Authorization', 'Bearer ' + token);
     	request.setHeader('Content-Type', 'application/json');

     	Map<String, Object> payload = new Map<String, Object>{
         	'invitedUserEmailAddress' => email,
         	'invitedUserDisplayName' => displayName,
       'inviteRedirectUrl' => 'https://your-redirect-url.com',
         	'sendInvitationMessage' => true
     	};

     	request.setBody(JSON.serialize(payload));
         
     	try {
         	HttpResponse response = http.send(request);
         	if (response.getStatusCode() == 201) {
             	Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
             	Map<String, Object> invitedUser = (Map<String, Object>) responseBody.get('invitedUser');
             	String userId = (String) invitedUser.get('id');
                 
             	// Update user attributes
             	if (userId != null) {
                 	updateUserAttributes(userId, firstName, lastName, customerNumber, sfid2, token);
             	}
                 
             	return userId;
         	} else {
             	throw new CalloutException('Failed to create guest user: ' + response.getBody());
         	}
     	} catch (Exception e) {
         	throw new CalloutException('Error creating guest user: ' + e.getMessage());
     	}
 	}

 	private static void updateUserAttributes(String userId, String firstName, String lastName, String customerNumber, String sfid2, String token) {
     	Http http = new Http();
     	HttpRequest request = new HttpRequest();
     request.setEndpoint('https://graph.microsoft.com/v1.0/users/' + userId);
     	request.setMethod('PATCH');
     	request.setHeader('Authorization', 'Bearer ' + token);
     	request.setHeader('Content-Type', 'application/json');

     	Map<String, Object> payload = new Map<String, Object>{
         	'givenName' => firstName,
         	'surname' => lastName,
         	'extension_595ee58901_customernumber' => customerNumber,
         	'extension_595ee58901_sfid2' => sfid2,
         	'accountEnabled' => true
     	};

     	request.setBody(JSON.serialize(payload));
         
     	try {
         	HttpResponse response = http.send(request);
         	if (response.getStatusCode() != 204) {
             	System.debug(LoggingLevel.ERROR, 'Failed to update user attributes: ' + response.getBody());
             	throw new CalloutException('Failed to update user attributes: ' + response.getBody());
         	}
     	} catch (Exception e) {
         	System.debug(LoggingLevel.ERROR, 'Error updating user attributes: ' + e.getMessage());
         	throw new CalloutException('Error updating user attributes: ' + e.getMessage());
     	}
 	}

 	public static void activateUser(String userId, String token) {
     	HttpRequest req = new HttpRequest();
     	req.setEndpoint('https://graph.microsoft.com/v1.0/users/' + userId);
     	req.setMethod('PATCH');
     	req.setHeader('Authorization', 'Bearer ' + token);
     	req.setHeader('Content-Type', 'application/json');
     	req.setBody('{"accountEnabled": true}');

     	try {
         	HttpResponse res = new Http().send(req);
         	if (res.getStatusCode() >= 400) {
             	System.debug(LoggingLevel.ERROR, 'Failed to activate user: ' + userId + ', Status: ' + res.getStatusCode() + ', Body: ' + res.getBody());
             	throw new CalloutException('Unexpected status code: ' + res.getStatusCode() + ', ' + res.getBody());
         	}
     	} catch (Exception e) {
         	System.debug(LoggingLevel.ERROR, 'Error activating user: ' + userId + ', Error: ' + e.getMessage());
         	throw e;
     	}
 	}

 	public static void deactivateUser(String userId, String token) {
     	HttpRequest req = new HttpRequest();
     	req.setEndpoint('https://graph.microsoft.com/v1.0/users/' + userId);
     	req.setMethod('PATCH');
     	req.setHeader('Authorization', 'Bearer ' + token);
     	req.setHeader('Content-Type', 'application/json');
     	req.setBody('{"accountEnabled": false}');

     	try {
         	HttpResponse res = new Http().send(req);
         	if (res.getStatusCode() >= 400) {
             	System.debug(LoggingLevel.ERROR, 'Failed to deactivate user: ' + userId + ', Status: ' + res.getStatusCode() + ', Body: ' + res.getBody());
             	throw new CalloutException('Unexpected status code: ' + res.getStatusCode() + ', ' + res.getBody());
         	}
     	} catch (Exception e) {
         	System.debug(LoggingLevel.ERROR, 'Error deactivating user: ' + userId + ', Error: ' + e.getMessage());
         	throw e;
     	}
 	}

 	public static void assignUserToGroup(String userId, String groupId, String token) {
     	HttpRequest req = new HttpRequest();
     	req.setEndpoint('https://graph.microsoft.com/v1.0/groups/' + groupId + '/members/$ref');
     	req.setMethod('POST');
     	req.setHeader('Authorization', 'Bearer ' + token);
     	req.setHeader('Content-Type', 'application/json');
     	Map<String, Object> body = new Map<String, Object>{
         	'@odata.id' => 'https://graph.microsoft.com/v1.0/directoryObjects/' + userId
     	};
     	req.setBody(JSON.serialize(body));

     	try {
         	HttpResponse res = new Http().send(req);
         	if (res.getStatusCode() >= 400) {
             	System.debug(LoggingLevel.ERROR, 'Failed to assign user to group: ' + userId + ', Group: ' + groupId + ', Status: ' + res.getStatusCode() + ', Body: ' + res.getBody());
             	throw new CalloutException('Unexpected status code: ' + res.getStatusCode() + ', ' + res.getBody());
         	}
     	} catch (Exception e) {
         	System.debug(LoggingLevel.ERROR, 'Error assigning user to group: ' + userId + ', Error: ' + e.getMessage());
         	throw e;
     	}
 	}

 	public static void removeUserFromGroup(String userId, String groupId, String token) {
     	HttpRequest req = new HttpRequest();
     	req.setEndpoint('https://graph.microsoft.com/v1.0/groups/' + groupId + '/members/' + userId + '/$ref');
     	req.setMethod('DELETE');
     	req.setHeader('Authorization', 'Bearer ' + token);
     	req.setHeader('Content-Type', 'application/json');

     	try {
         	HttpResponse res = new Http().send(req);
         	if (res.getStatusCode() >= 400) {
             	System.debug(LoggingLevel.ERROR, 'Failed to remove user from group: ' + userId + ', Group: ' + groupId + ', Status: ' + res.getStatusCode() + ', Body: ' + res.getBody());
             	throw new CalloutException('Unexpected status code: ' + res.getStatusCode() + ', ' + res.getBody());
         	}
     	} catch (Exception e) {
         	System.debug(LoggingLevel.ERROR, 'Error removing user from group: ' + userId + ', Error: ' + e.getMessage());
         	throw e;
     	}
 	}
 }