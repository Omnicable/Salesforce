/**
 * @description Copies {@link ContentDocumentLink} rows from {@link QuotesOrdersCredits_Header__c}
 *              onto {@link Order} records that reference the header via
 *              {@link Order#Quote_Order_Credit__c}. Also keeps those Order links in sync when header
 *              file links are inserted, updated, or deleted.
 * @group QOC Sync
 * @see OrderTrigger
 * @see ContentDocumentLinkTrigger
 * @see OrderContentDocumentLinkDml
 */
public without sharing class OrderContentDocumentLinkHandler {
    /**
     * @description Syncs Order {@link ContentDocumentLink} rows when header file links change.
     *              Insert copies the file onto related Orders, update applies Visibility, and
     *              delete removes the matching Order links. Non-header LinkedEntity rows are ignored.
     * @param newLinks {@code Trigger.new} on insert/update; null on delete.
     * @param oldLinks {@code Trigger.old} on update/delete; null on insert.
     */
    public static void syncFromQocHeaderLinks(
        List<ContentDocumentLink> newLinks,
        List<ContentDocumentLink> oldLinks
    ) {
        List<ContentDocumentLink> headerNew = filterQocHeaderLinks(newLinks);
        List<ContentDocumentLink> headerOld = filterQocHeaderLinks(oldLinks);
        if (headerNew.isEmpty() && headerOld.isEmpty()) {
            return;
        }

        Map<Id, List<Id>> headerIdToOrderIds = ordersByHeaderId(
            unionLinkedEntityIds(headerNew, headerOld)
        );
        if (headerIdToOrderIds.isEmpty()) {
            return;
        }

        if (headerOld.isEmpty()) {
            OrderContentDocumentLinkDml.insertCopiedOrderLinks(headerNew, headerIdToOrderIds);
            return;
        }
        if (headerNew.isEmpty()) {
            OrderContentDocumentLinkDml.deleteCopiedOrderLinks(headerOld, headerIdToOrderIds);
            return;
        }
        updateCopiedOrderLinks(headerNew, headerOld, headerIdToOrderIds);
    }

    /**
     * @description For each Order with {@link Order#Quote_Order_Credit__c} set, inserts Order
     *              {@link ContentDocumentLink} rows that match the header's files. Skips links
     *              that already exist on the Order. Uses {@code ShareType = 'V'}.
     * @param orders Newly inserted Orders (typically {@code Trigger.new}).
     */
    public static void copyFromQocHeaders(List<Order> orders) {
        if (orders == null || orders.isEmpty()) {
            return;
        }

        Map<Id, List<Id>> headerIdToOrderIds = collectHeaderToOrderIds(orders);
        if (headerIdToOrderIds.isEmpty()) {
            return;
        }

        OrderContentDocumentLinkDml.insertCopiedOrderLinks(
            [
                SELECT ContentDocumentId, LinkedEntityId, Visibility
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :headerIdToOrderIds.keySet()
            ],
            headerIdToOrderIds
        );
    }

    /**
     * @description Returns only links whose {@link ContentDocumentLink#LinkedEntityId} is a QOC header.
     * @param links Trigger new or old; null yields an empty list.
     * @return Header file links from the trigger set.
     */
    private static List<ContentDocumentLink> filterQocHeaderLinks(List<ContentDocumentLink> links) {
        List<ContentDocumentLink> headerLinks = new List<ContentDocumentLink>();
        if (links == null) {
            return headerLinks;
        }
        for (ContentDocumentLink link : links) {
            if (isQocHeaderLink(link)) {
                headerLinks.add(link);
            }
        }
        return headerLinks;
    }

    /**
     * @description True when the link is attached to a {@link QuotesOrdersCredits_Header__c} row.
     * @param link ContentDocumentLink from the trigger set.
     * @return True for header file links.
     */
    private static Boolean isQocHeaderLink(ContentDocumentLink link) {
        return link != null
            && link.LinkedEntityId != null
            && link.LinkedEntityId.getSObjectType() == QuotesOrdersCredits_Header__c.SObjectType;
    }

    /**
     * @description Distinct LinkedEntity Ids from both trigger lists.
     * @param first Typically filtered {@code Trigger.new}.
     * @param second Typically filtered {@code Trigger.old}.
     * @return Header Ids referenced by either list.
     */
    private static Set<Id> unionLinkedEntityIds(
        List<ContentDocumentLink> first,
        List<ContentDocumentLink> second
    ) {
        Set<Id> ids = new Set<Id>();
        ids.addAll(linkedEntityIds(first));
        ids.addAll(linkedEntityIds(second));
        return ids;
    }

    /**
     * @description LinkedEntity Ids from a link list.
     * @param links Filtered header links.
     * @return Distinct LinkedEntity Ids.
     */
    private static Set<Id> linkedEntityIds(List<ContentDocumentLink> links) {
        Set<Id> ids = new Set<Id>();
        for (ContentDocumentLink link : links) {
            if (link.LinkedEntityId != null) {
                ids.add(link.LinkedEntityId);
            }
        }
        return ids;
    }

    /**
     * @description Loads Orders that reference the given QOC headers.
     * @param headerIds Header Ids from the trigger set.
     * @return Map of header Id to related Order Ids.
     */
    private static Map<Id, List<Id>> ordersByHeaderId(Set<Id> headerIds) {
        Map<Id, List<Id>> headerIdToOrderIds = new Map<Id, List<Id>>();
        if (headerIds == null || headerIds.isEmpty()) {
            return headerIdToOrderIds;
        }
        for (Order o : [
            SELECT Id, Quote_Order_Credit__c
            FROM Order
            WHERE Quote_Order_Credit__c IN :headerIds
        ]) {
            if (!headerIdToOrderIds.containsKey(o.Quote_Order_Credit__c)) {
                headerIdToOrderIds.put(o.Quote_Order_Credit__c, new List<Id>());
            }
            headerIdToOrderIds.get(o.Quote_Order_Credit__c).add(o.Id);
        }
        return headerIdToOrderIds;
    }

    /**
     * @description Reparents or updates Visibility on Order links to match header file link changes.
     * @param headerNew Updated header links ({@code Trigger.new}).
     * @param headerOld Prior header links ({@code Trigger.old}).
     * @param headerIdToOrderIds Header Id to related Order Ids.
     */
    private static void updateCopiedOrderLinks(
        List<ContentDocumentLink> headerNew,
        List<ContentDocumentLink> headerOld,
        Map<Id, List<Id>> headerIdToOrderIds
    ) {
        Map<Id, ContentDocumentLink> oldById = new Map<Id, ContentDocumentLink>(headerOld);
        List<ContentDocumentLink> identityOld = new List<ContentDocumentLink>();
        List<ContentDocumentLink> identityNew = new List<ContentDocumentLink>();
        List<ContentDocumentLink> visibilityNew = new List<ContentDocumentLink>();
        for (ContentDocumentLink newLink : headerNew) {
            ContentDocumentLink oldLink = oldById.get(newLink.Id);
            if (oldLink == null) {
                identityNew.add(newLink);
                continue;
            }
            if (linkIdentityChanged(oldLink, newLink)) {
                identityOld.add(oldLink);
                identityNew.add(newLink);
                continue;
            }
            if (newLink.Visibility != oldLink.Visibility) {
                visibilityNew.add(newLink);
            }
        }
        OrderContentDocumentLinkDml.deleteCopiedOrderLinks(identityOld, headerIdToOrderIds);
        OrderContentDocumentLinkDml.insertCopiedOrderLinks(identityNew, headerIdToOrderIds);
        OrderContentDocumentLinkDml.applyVisibilityToOrderLinks(visibilityNew, headerIdToOrderIds);
    }

    /**
     * @description True when the file or parent entity of a header link changed.
     * @param oldLink Prior header link.
     * @param newLink Updated header link.
     * @return True when Order links should be deleted and recreated.
     */
    private static Boolean linkIdentityChanged(ContentDocumentLink oldLink, ContentDocumentLink newLink) {
        return oldLink.ContentDocumentId != newLink.ContentDocumentId
            || oldLink.LinkedEntityId != newLink.LinkedEntityId;
    }

    /**
     * @description Groups inserted Order Ids by their related QOC header Id.
     * @param orders Newly inserted Orders.
     * @return Map of header Id to Order Ids that reference that header.
     */
    private static Map<Id, List<Id>> collectHeaderToOrderIds(List<Order> orders) {
        Map<Id, List<Id>> headerIdToOrderIds = new Map<Id, List<Id>>();
        for (Order o : orders) {
            if (!isHeaderLinkedOrder(o)) {
                continue;
            }
            if (!headerIdToOrderIds.containsKey(o.Quote_Order_Credit__c)) {
                headerIdToOrderIds.put(o.Quote_Order_Credit__c, new List<Id>());
            }
            headerIdToOrderIds.get(o.Quote_Order_Credit__c).add(o.Id);
        }
        return headerIdToOrderIds;
    }

    /**
     * @description True when the Order has an Id and a related QOC header.
     * @param o Order from the trigger set.
     * @return True when header-file copy applies to this row.
     */
    private static Boolean isHeaderLinkedOrder(Order o) {
        return o != null && o.Id != null && o.Quote_Order_Credit__c != null;
    }
}