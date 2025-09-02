/* Author - Shivesh Kumar
    Purpose - (Handler) Contains logic for Contact SSO provisioning, acts as bridge between Trigger and Queueable job. 
*/

 public class ContactTriggerHandlerForEntra {

 	public static void handleTrigger(List<Contact> newList, Map<Id, Contact> oldMap, Boolean isInsert, Boolean isUpdate) {
     	List<Id> eligibleContacts = new List<Id>(); // For invitations
     	List<Id> deactivateContacts = new List<Id>(); // For deactivation
     	List<Id> reactivateContactIds = new List<Id>(); // For reactivation
     	Map<Id, String> roleUpdateContactIdsToRoles = new Map<Id, String>(); // Current roles
     	Map<Id, String> roleUpdateContactIdsToOldRoles = new Map<Id, String>(); // Previous roles
     	Set<Id> accountId = new Set<Id>();
     	Set<Id> processedContactIds = new Set<Id>();// Track processed contacts to prevent duplicates

     	// Collect Account IDs
     	for (Contact con : newList) {
         	if (con.AccountId != null) {
             	accountId.add(con.AccountId);
         	}
     	}

     	// Query Accounts
     	Map<Id, Account> accountMap = new Map<Id, Account>(
         	[SELECT Id, Accumulator_Number__c, RecordTypeId
          	FROM Account
          	WHERE Id IN :accountId]
     	);

     	// Get Record Type IDs (Consider moving to custom metadata)
     	Id conHomeownerRecordType = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Homeowner').getRecordTypeId();
     	Id accDealerRecordType   = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Dealer').getRecordTypeId();

     	// Process Contacts
     	for (Contact con : newList) {
         	if (processedContactIds.contains(con.Id)) {
             	continue; // Skip if already processed in this transaction
         	}
         	processedContactIds.add(con.Id);

         	Set<String> rolesofcontact = new Set<String>();
         	if (con.Contact_Roles__c != null) {
             	rolesofcontact.addAll(con.Contact_Roles__c.split(';'));
         	}

         	Account acc = accountMap.get(con.AccountId);
         	if (acc == null) continue;

         	// Common eligibility criteria
         	Boolean isEligible = (
             	accDealerRecordType == acc.RecordTypeId &&
             	acc.Accumulator_Number__c != '648' &&
             	acc.Accumulator_Number__c != '612' &&
             	conHomeownerRecordType != con.RecordTypeId
         	);
         	if (!isEligible) continue;

         	// Define oldCon for use in update context
         	Contact oldCon = isUpdate ? oldMap.get(con.Id) : null;

         	// Invitation or reactivation check
         	if (con.Partners_Portal_Status__c == 'Active' &&
             	rolesofcontact.contains('Partners Portal User') &&
             	con.No_Longer_w_Company__c == false) {

             	if (isInsert || (isUpdate && oldCon != null &&
                 	(oldCon.Partners_Portal_Status__c != 'Active' ||
                  	oldCon.No_Longer_w_Company__c == true ||
                  	oldCon.SSO_Status__c == 'Deactivated'))) {

                 	if (con.SSO_Status__c == 'Deactivated') {
                     	reactivateContactIds.add(con.Id); // Reactivate existing user
                     	roleUpdateContactIdsToRoles.put(con.Id, con.Contact_Roles__c);
                     	roleUpdateContactIdsToOldRoles.put(con.Id, oldCon != null ? oldCon.Contact_Roles__c : null);
                 	} else {
                     	eligibleContacts.add(con.Id); // New user invitation
                 	}
             	}
         	}

         	// Deactivation check
         	else if (isUpdate &&
                  	(con.Partners_Portal_Status__c == 'Removed' || con.No_Longer_w_Company__c == true)) {
             	if (oldCon != null &&
                 	(oldCon.Partners_Portal_Status__c != con.Partners_Portal_Status__c ||
                  	oldCon.No_Longer_w_Company__c != con.No_Longer_w_Company__c)) {
                 	deactivateContacts.add(con.Id);
             	}
         	}

         	// Role update check
         	if (isInsert || (isUpdate && oldCon != null && oldCon.Contact_Roles__c != con.Contact_Roles__c)) {
             	roleUpdateContactIdsToRoles.put(con.Id, con.Contact_Roles__c);
             	roleUpdateContactIdsToOldRoles.put(con.Id, oldCon != null ? oldCon.Contact_Roles__c : null);
         	}
     	}

     	// Call handler only if not in future, batch, or queueable context
     	if ((!eligibleContacts.isEmpty() || !deactivateContacts.isEmpty() ||
          	!reactivateContactIds.isEmpty() || !roleUpdateContactIdsToRoles.isEmpty()) &&
         	!System.isFuture() && !System.isBatch() && !System.isQueueable()) {

         	enqueueContacts(
             	eligibleContacts,
             	deactivateContacts,
             	reactivateContactIds,
             	roleUpdateContactIdsToRoles,
             	roleUpdateContactIdsToOldRoles
         	);
     	}
 	}

 	private static void enqueueContacts(
     	List<Id> eligibleContacts,
     	List<Id> deactivateContacts,
     	List<Id> reactivateContactIds,
     	Map<Id, String> roleUpdateContactIdsToRoles,
     	Map<Id, String> roleUpdateContactIdsToOldRoles
 	) {
     	Set<Id> processedContacts = new Set<Id>();
     	try {
         	System.enqueueJob(new ContactQueueableForEntra(
             	eligibleContacts,
             	deactivateContacts,
             	reactivateContactIds,
             	roleUpdateContactIdsToRoles,
             	roleUpdateContactIdsToOldRoles,
             	processedContacts
         	));
     	} catch (Exception e) {
         	System.debug(LoggingLevel.ERROR, 'Failed to enqueue ContactQueueableForEntra: ' + e.getMessage());
     	}
 	}
 }

