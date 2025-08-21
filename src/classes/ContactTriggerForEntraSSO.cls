/* Author - Shivesh Kumar 
Purpose - (Trigger) Executes after insert or update of Contact records to manage user provisioning, activation, deactivation, and role updates in Microsoft Entra (Azure AD).
 */
trigger ContactTriggerForEntraSSO on Contact (after insert, after update) 
{ 
	if(Trigger.isAfter)
	{ 
		ContactTriggerHandlerForEntra.handleTrigger(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate); 
	}
}
