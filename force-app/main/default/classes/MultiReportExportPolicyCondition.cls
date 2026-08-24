global class MultiReportExportPolicyCondition implements TxnSecurity.PolicyCondition {

 public boolean evaluate(TxnSecurity.Event e) {
  if(e.data.get('ApiType') == '3'){
   return true;
 }

 return false; 
}
 }