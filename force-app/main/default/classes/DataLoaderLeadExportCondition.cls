global class DataLoaderLeadExportCondition implements TxnSecurity.PolicyCondition {
	public boolean evaluate(TxnSecurity.Event e){
		// The event data is a Map<String, String>.
		// We need to call the valueOf() method on appropriate data types to use them in our logic.
		Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
		Long executionTimeMillis = Long.valueOf(e.data.get('ExecutionTime'));
		String entityName = e.data.get('EntityName');

		// Trigger the policy only if and export on leads, where we are downloading more than 2000
		// records or it took more than 1 second (1000ms).
		if('Lead'.equals(entityName)){
			if(numberOfRecords > 2000 || executionTimeMillis > 1000){
				return true;
			}
		}

		// For everything else don't trigger the policy.
		return false;
	}
}