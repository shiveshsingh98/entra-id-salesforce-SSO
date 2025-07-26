/*
 Author - Shivesh Kumar
 Purpose - (Handler) Acts as a bridge between the trigger and the queueable job, ensuring asynchronous 
       processing of contact operations.
 */
 
public class ContactTriggerHandlerForEntra {
     
 	public static void handleContacts(
     	List<Id> eligibleContacts,
     	List<Id> deactivateContacts,
     	List<Id> reactivateContactIds,
     	Map<Id, String> roleUpdateContactIdsToRoles,
     	Map<Id, String> roleUpdateContactIdsToOldRoles
 	) {
     	Set<Id> processedContacts = new Set<Id>(); 
     	if (!System.isQueueable()) {
         	try{
            	    System.enqueueJob(new ContactQueueableForEntra(
             	  eligibleContacts,
             	  deactivateContacts,
                 	reactivateContactIds,
             	  roleUpdateContactIdsToRoles,
             	  roleUpdateContactIdsToOldRoles,
             	  processedContacts
         	    )); 
         	  }catch (Exception e) {
             	  System.debug(LoggingLevel.ERROR, 'Failed to enqueue ContactQueueableForEntra: ' + e.getMessage());
             	}
             
     	} else {
         	System.debug(LoggingLevel.WARN, 'Cannot enqueue Queueable job from another Queueable context.');
             
     	}
 	}
 }