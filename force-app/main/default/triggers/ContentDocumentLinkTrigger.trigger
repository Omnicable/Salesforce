/**
 * @description After insert/update/delete on {@link ContentDocumentLink}. Copies header file links
 *              onto related {@link Order} records and keeps those Order links in sync.
 * @see OrderContentDocumentLinkHandler
 */
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert, after update, after delete) {
    OrderContentDocumentLinkHandler.syncFromQocHeaderLinks(Trigger.new, Trigger.old);
}