/*
 Author - Shivesh Kumar
 Purpose - (Trigger) Executes after insert or update of Contact records to manage user provisioning, activation, deactivation, 
       and role updates in Microsoft Entra (Azure AD).
 */
 trigger ContactTriggerForEntraSSO on Contact (after insert, after update) {
 	List<Id> eligibleContacts = new List<Id>(); // For invitations
 	List<Id> deactivateContacts = new List<Id>(); // For deactivation
 	List<Id> reactivateContactIds = new List<Id>(); // For reactivation
 	Map<Id, String> roleUpdateContactIdsToRoles = new Map<Id, String>(); // Current roles
 	Map<Id, String> roleUpdateContactIdsToOldRoles = new Map<Id, String>(); // Previous roles
 	Set<Id> accountId = new Set<Id>();
   Set<Id> processedContactIds = new Set<Id>(); // Track processed contacts to prevent duplicates
     
 	// Collect Account IDs
   for (Contact con : Trigger.new) {
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
 	Id accDealerRecordType = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Dealer').getRecordTypeId();

 	// Process Contacts
   for (Contact con : Trigger.new) {
     	if (processedContactIds.contains(con.Id)) {
         	continue; // Skip if contact already processed in this transaction
     	}
     processedContactIds.add(con.Id);
     	Set<String> rolesofcontact = new Set<String>();
     	if (con.Contact_Roles__c != null) {
         	rolesofcontact.addAll(con.Contact_Roles__c.split(';'));
         	System.debug('Shivesh Roles of Contact '+rolesofcontact);
     	}

     	Account acc = accountMap.get(con.AccountId);
     	if (acc == null) continue; // Skip if no associated Account

     	// Common eligibility criteria
     	Boolean isEligible = (
         	accDealerRecordType == acc.RecordTypeId &&
         	acc.Accumulator_Number__c != '648' &&
         	acc.Accumulator_Number__c != '612' &&
         	conHomeownerRecordType != con.RecordTypeId
     	);

     	if (!isEligible) continue;

     	// Define oldCon for use in update context
     Contact oldCon = Trigger.isUpdate ? Trigger.oldMap.get(con.Id) : null;

     	// Invitation or reactivation check
     	if (con.Partners_Portal_Status__c == 'Active' &&
         	rolesofcontact.contains('Partners Portal User') &&
         	con.No_Longer_w_Company__c == false) {
         if (Trigger.isInsert || (Trigger.isUpdate && oldCon != null &&
             	(oldCon.Partners_Portal_Status__c != 'Active' ||
              	oldCon.No_Longer_w_Company__c == true ||
              	oldCon.SSO_Status__c == 'Deactivated'))) {
             	  if (con.SSO_Status__c == 'Deactivated') {
             reactivateContactIds.add(con.Id); // Reactivate existing user
                 	  System.debug('Shivesh reactivateContactIds ' + reactivateContactIds);
                     	// Add to role updates to ensure roles are synced
                 	  roleUpdateContactIdsToRoles.put(con.Id, con.Contact_Roles__c);
                 	  roleUpdateContactIdsToOldRoles.put(con.Id, oldCon != null ? oldCon.Contact_Roles__c : null);
                     	System.debug('Shivesh roleUpdateContactIdsToRoles in Reactivate  '+roleUpdateContactIdsToRoles);
             	    System.debug('Shivesh roleUpdateContactIdsToOldRoles in Reactivate  '+roleUpdateContactIdsToOldRoles);
             	  } else
             	  {
             eligibleContacts.add(con.Id); // New user invitation
                 	  System.debug('Shivesh eligibleContacts Invitation ' + eligibleContacts);
             	  }
         	  }
     	}
     	// Deactivation check (only in after update context)
     	else if (Trigger.isUpdate &&
              	(con.Partners_Portal_Status__c == 'Removed' || con.No_Longer_w_Company__c == true)) {
         	if (oldCon != null &&
             	(oldCon.Partners_Portal_Status__c != con.Partners_Portal_Status__c ||
              	oldCon.No_Longer_w_Company__c != con.No_Longer_w_Company__c) &&
              	(con.SSO_Status__c == 'Invitation Sent' || 
               	  con.SSO_Status__c == 'User Already Exists' ||
      	      con.SSO_Status__c == 'Role Provisioned Successfully' ||
      	      con.SSO_Status__c == 'User Reactivated' ||
      	      con.SSO_Status__c == 'Role update successful')) {
           deactivateContacts.add(con.Id);
                 	System.debug('Shivesh deactivateContacts Deactivation '+deactivateContacts);
         	}
     	}

     	// Role update check (on insert or if Contact_Roles__c changed)
     	if (Trigger.isInsert ||
         	(Trigger.isUpdate && oldCon != null && oldCon.Contact_Roles__c != con.Contact_Roles__c)) {
         roleUpdateContactIdsToRoles.put(con.Id, con.Contact_Roles__c);
         roleUpdateContactIdsToOldRoles.put(con.Id, oldCon != null ? oldCon.Contact_Roles__c : null);
             	System.debug('Shivesh roleUpdateContactIdsToRoles  '+roleUpdateContactIdsToRoles);
             	System.debug('Shivesh roleUpdateContactIdsToOldRoles  '+roleUpdateContactIdsToOldRoles);
     	}
 	}

 	// Call handler only if not in future, batch, or queueable context
 	if ((!eligibleContacts.isEmpty() || !deactivateContacts.isEmpty() || !reactivateContactIds.isEmpty() || !roleUpdateContactIdsToRoles.isEmpty()) &&
     	!System.isFuture() && !System.isBatch() && !System.isQueueable()) {
     	ContactTriggerHandlerForEntra.handleContacts(
         	eligibleContacts,
         	deactivateContacts,
         	reactivateContactIds,
         	roleUpdateContactIdsToRoles,
         	roleUpdateContactIdsToOldRoles
     	);
 	} else if (!eligibleContacts.isEmpty() || !deactivateContacts.isEmpty() || !reactivateContactIds.isEmpty() || !roleUpdateContactIdsToRoles.isEmpty()) {
     	System.debug(LoggingLevel.WARN, 'Cannot call async method from future, batch, or queueable context. ' +
                  	'Eligible Contacts: ' + eligibleContacts +
                  	', Deactivate Contacts: ' + deactivateContacts +
                  	', Reactivate Contacts: ' + reactivateContactIds +
                  	', Role Update Contacts: ' + roleUpdateContactIdsToRoles.keySet());
 	}
 }
