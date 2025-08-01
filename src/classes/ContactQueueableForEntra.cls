/*
 Author - Shivesh Kumar
Purpose - (Queueable Class) Processes contact operations (invitations, reactivations, deactivations, 
		   and role updates) asynchronously, making callouts to the Microsoft Graph API.
*/

public class ContactQueueableForEntra implements Queueable, Database.AllowsCallouts {
    private List<Id> eligibleContactIds;
    private List<Id> deactivateContactIds;
    private List<Id> reactivateContactIds;
    private Map<Id, String> roleUpdateContactIdsToRoles; // Map of Contact ID to current Contact_Roles__c
    private Map<Id, String> roleUpdateContactIdsToOldRoles; // Map of Contact ID to previous Contact_Roles__c
    private Set<Id> processedContacts;
 
    public ContactQueueableForEntra(
        List<Id> eligibleContactIds, 
        List<Id> deactivateContactIds,
        List<Id> reactivateContactIds,
        Map<Id, String> roleUpdateContactIdsToRoles,
        Map<Id, String> roleUpdateContactIdsToOldRoles,
        Set<Id> processedContacts
    ) {
        this.eligibleContactIds = eligibleContactIds != null ? eligibleContactIds : new List<Id>();
        this.deactivateContactIds = deactivateContactIds != null ? deactivateContactIds : new List<Id>();
        this.reactivateContactIds = reactivateContactIds != null ? reactivateContactIds : new List<Id>();
        this.roleUpdateContactIdsToRoles = roleUpdateContactIdsToRoles != null ? roleUpdateContactIdsToRoles : new Map<Id, String>();
        this.roleUpdateContactIdsToOldRoles = roleUpdateContactIdsToOldRoles != null ? roleUpdateContactIdsToOldRoles : new Map<Id, String>();
        this.processedContacts = processedContacts != null ? processedContacts : new Set<Id>();
    }
 
    public void execute(QueueableContext context) {
        // Query Contacts for all operations
        Set<Id> allContactIds = new Set<Id>();
        allContactIds.addAll(eligibleContactIds);
        allContactIds.addAll(deactivateContactIds);
        allContactIds.addAll(reactivateContactIds);
        allContactIds.addAll(roleUpdateContactIdsToRoles.keySet());
        if(allContactIds.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'No contacts to process.');
            return;
        }
        System.debug('Shivesh All contactId '+allContactIds);
 
        Map<Id, Contact> contactMap = new Map<Id, Contact>(
            [SELECT Id, Email, FirstName, LastName, Contact_Roles__c, SSO_Status__c,Customer_Number_Text__c
             FROM Contact 
             WHERE Id IN :allContactIds]
        );
 
        String token;
        try {
            token = EntraSSOService.getAccessToken();
            System.debug('Shivesh Access token present in execute Method Queueable '+token);
        } catch (Exception e) {
            updateSSOStatus(contactMap.values(), 'Token error: ' + e.getMessage());
            return;
        }
 
        // Role-to-group mapping 
        Map<String, String> roleToGroupIdMap = new Map<String, String>{
            'User' => 'abcdefghijklmnopqrstuvwxyz',
            'Admin' => 'abcdefghijklmnopqrstuvwxyz',
            'Super Admin' => 'abcdefghijklmnopqrstuvwxyz',
            'Dealer Admin' => 'abcdefghijklmnopqrstuvwxyz',
            'Partners Portal User' => 'abcdefghijklmnopqrstuvwxyz'
                    };
 
        // Process invitation
        for (Id contactId : eligibleContactIds) {
            Contact con = contactMap.get(contactId);
            if (con == null || processedContacts.contains(con.Id)) continue;
            processedContacts.add(con.Id);
 
            try {
                String userId = EntraUserAPI.getUserIdByEmail(con.Email, token);
                System.debug('Shivesh Get userId for Invitation '+userId);
                if (userId == null) {
                    // Create Guest User and update attributes
                    userId = EntraUserAPI.createGuestUser(
                        con.Email, 
                        con.FirstName + ' ' + con.LastName, 
                        token,
                        con.FirstName,
                        con.LastName,
                        con.Customer_Number_Text__c,
                        con.Id
                    );
                    con.SSO_Status__c = 'Invitation Sent';
                    System.debug('Shivesh userId After GuestUser Creation '+userId);
                } else {
                    // User already exists, no need to send invitation
                    con.SSO_Status__c = 'User Already Exists';
                }
                // Assign roles for new users
                //updateUserRoles(con, userId, con.Contact_Roles__c, null, roleToGroupIdMap, token);
            } catch (Exception e) {
                con.SSO_Status__c = 'Provisioning error: ' + e.getMessage();
            }
        }
        
        // Process reactivations
        for (Id contactId : reactivateContactIds) {
            Contact con = contactMap.get(contactId);
            if (con == null || processedContacts.contains(con.Id)) continue;
            processedContacts.add(con.Id);
            try {
                String userId = EntraUserAPI.getUserIdByEmail(con.Email, token);
                System.debug('Shivesh Get userId for Reactivation ' + userId);
                if (userId != null) {
                    EntraUserAPI.activateUser(userId, token);
                    con.SSO_Status__c = 'User Reactivated';
                    // Update roles during reactivation
                    //updateUserRoles(con, userId, con.Contact_Roles__c, null, roleToGroupIdMap, token);
                } else {
                    // If user doesn't exist, treat as new invitation
                    userId = EntraUserAPI.createGuestUser(
                        con.Email, 
                        con.FirstName + ' ' + con.LastName, 
                        token,
                        con.FirstName,
                        con.LastName,
                        con.Customer_Number_Text__c,
                        con.Id
                    );
                    con.SSO_Status__c = 'Invitation Sent';
                    // Assign roles for new user created during reactivation
                    //updateUserRoles(con, userId, con.Contact_Roles__c, null, roleToGroupIdMap, token);
                }
            } catch (Exception e) {
                con.SSO_Status__c = 'Reactivation error: ' + e.getMessage();
            }
        }
 
        // Process deactivations
        for (Id contactId : deactivateContactIds) {
            Contact con = contactMap.get(contactId);
            if (con == null || processedContacts.contains(con.Id)) continue;
			processedContacts.add(con.Id);
 
            try {
                String userId = EntraUserAPI.getUserIdByEmail(con.Email, token);
                System.debug('Shivesh Get userId for Deactivation '+userId);
                if (userId != null) {
                    EntraUserAPI.deactivateUser(userId, token);
                    con.SSO_Status__c = 'Deactivated';
                } else {
                    con.SSO_Status__c = 'Deactivation failed: User not found';
                }
            } catch (Exception e) {
                con.SSO_Status__c = 'Deactivation error: ' + e.getMessage();
            }
        }
 
        // Process role updates
        for (Id contactId : roleUpdateContactIdsToRoles.keySet()) {
            Contact con = contactMap.get(contactId);
            if (con == null || processedContacts.contains(con.Id)) continue;
			processedContacts.add(con.Id);
 
            try {
                String userId = EntraUserAPI.getUserIdByEmail(con.Email, token);
                System.debug('Shivesh Get userId for Role update '+userId);
                if (userId == null) {
                    con.SSO_Status__c = 'Role update failed: User not found';
                    continue;
                }              
                String newRolesString = roleUpdateContactIdsToRoles.get(contactId);
                System.debug('Shivesh newRolesString '+newRolesString);               
                String oldRolesString = roleUpdateContactIdsToOldRoles.get(contactId);
                System.debug('Shivesh oldRolesString '+oldRolesString);
               updateUserRoles(con, userId, newRolesString, oldRolesString, roleToGroupIdMap, token);
            } catch (Exception e) {
                con.SSO_Status__c = 'Error: ' + e.getMessage();
            }
        }
        // Update contact records
        updateSSOStatus(contactMap.values(), null);
    }
    // Helper method to update user roles
    private void updateUserRoles(Contact con, String userId, String newRolesString, String oldRolesString, Map<String, String> roleToGroupIdMap, String token) {
        Set<String> newRoles = new Set<String>();
        if (newRolesString != null) {
            newRoles.addAll(newRolesString.split(';'));
        }
        Set<String> oldRoles = new Set<String>();
        if (oldRolesString != null) {
            oldRoles.addAll(oldRolesString.split(';'));
        }
        System.debug('Shivesh Old roles: ' + oldRoles);
        System.debug('Shivesh New roles: ' + newRoles);
        // Determine roles to add or remove
        Set<String> rolesToAdd = new Set<String>(newRoles);
        rolesToAdd.removeAll(oldRoles);
        System.debug('Shivesh Roles to add: ' + rolesToAdd);
        Set<String> rolesToRemove = new Set<String>(oldRoles);
        rolesToRemove.removeAll(newRoles);
        System.debug('Shivesh Roles to remove: ' + rolesToRemove);
        // Add new group memberships
        for (String role : rolesToAdd) {
            if (roleToGroupIdMap.containsKey(role)) {
                EntraUserAPI.assignUserToGroup(userId, roleToGroupIdMap.get(role), token);
            }
        }
        // Remove old group memberships
        for (String role : rolesToRemove) {
            if (roleToGroupIdMap.containsKey(role)) {
                EntraUserAPI.removeUserFromGroup(userId, roleToGroupIdMap.get(role), token);
            }
        }
        // Update status if roles were changed
        if (!rolesToAdd.isEmpty() || !rolesToRemove.isEmpty()) {
            con.SSO_Status__c = 'Role update successful';
        }
    }
    // Helper method to update SSO status
    public static void updateSSOStatus(List<Contact> contacts, String defaultStatus) {
        List<Contact> contactsToUpdate = new List<Contact>();
        for (Contact c : contacts) {
            if (c.SSO_Status__c != null) {
                contactsToUpdate.add(c);
            } else if (defaultStatus != null) {
                c.SSO_Status__c = defaultStatus;
                contactsToUpdate.add(c);
            }
        }
        if (!contactsToUpdate.isEmpty()) {
            try {
                update contactsToUpdate;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to update SSO status: ' + e.getMessage());
            }
        }
    }
}