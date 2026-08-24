global class ConcurrentSessionsPolicyCondition implements TxnSecurity.PolicyCondition {
public static Integer MAX_ADMIN_USER_SESSIONS = 1;
public static Integer MAX_USER_SESSIONS = 5;

	public boolean evaluate(TxnSecurity.Event e){
		List<User> users = [SELECT ProfileId FROM User WHERE Id = :e.UserId];
		String profileId = (String)users.get(0).get('ProfileId');
		List<Profile> profiles = [SELECT Name FROM Profile WHERE Id = :profileId];
		String profileName = (String)profiles.get(0).get('Name');

		List<AuthSession> sessions
			= [SELECT Id, CreatedDate, LastModifiedDate, NumSecondsValid, SessionType
			  FROM AuthSession
			  WHERE UsersId = :e.UserId and ParentId = NULL];

		Map<String, String> sessionsToIgnore = (Map<String, String>)Auth.SessionManagement.ignoreForConcurrentSessionLimit(sessions); 
		Integer activeSessions = 0;
		for (AuthSession s : sessions) {
			DateTime d = (DateTime)s.get('LastModifiedDate');
			Integer n = (Integer)s.get('NumSecondsValid');
			String type = (String)s.get('SessionType');
			String sessionId = (String)s.get('Id');
			if(sessionsToIgnore.get(sessionId).equals('false')) {
				if(d.addSeconds(n) >= DateTime.now()) {
					activeSessions = activeSessions + 1;
				}
				if(profileName.equals('System Administrator')) {
					if(activeSessions >= MAX_ADMIN_USER_SESSIONS) {
						return true;
					}
				} else {
					if(activeSessions >= MAX_USER_SESSIONS) {
						return true;
					}
				}
			}
		}
		return false;

	}
}