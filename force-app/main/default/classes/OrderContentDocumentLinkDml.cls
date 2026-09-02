/**
 * @description DML helpers that insert, delete, and update {@link Order} {@link ContentDocumentLink}
 *              rows copied from {@link QuotesOrdersCredits_Header__c} files.
 * @group QOC Sync
 * @see OrderContentDocumentLinkHandler
 */
public without sharing class OrderContentDocumentLinkDml {
    /**
     * @description Inserts Order links that match the given header file links.
     *              Skips links that already exist on the Order. Uses {@code ShareType = 'V'}.
     * @param headerLinks Header {@link ContentDocumentLink} rows to copy.
     * @param headerIdToOrderIds Header Id to related Order Ids.
     */
    public static void insertCopiedOrderLinks(
        List<ContentDocumentLink> headerLinks,
        Map<Id, List<Id>> headerIdToOrderIds
    ) {
        Set<String> existingKeys = existingLinkKeys(flattenOrderIds(headerIdToOrderIds));
        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        for (ContentDocumentLink headerLink : headerLinks) {
            addLinksForHeaderFile(headerLink, headerIdToOrderIds, existingKeys, toInsert);
        }
        if (!toInsert.isEmpty()) {
            Database.insert(toInsert, false);
        }
    }

    /**
     * @description Deletes Order links that match the given header file links.
     * @param headerLinks Header {@link ContentDocumentLink} rows that were removed or reparented.
     * @param headerIdToOrderIds Header Id to related Order Ids.
     */
    public static void deleteCopiedOrderLinks(
        List<ContentDocumentLink> headerLinks,
        Map<Id, List<Id>> headerIdToOrderIds
    ) {
        Set<String> keysToRemove = new Set<String>();
        Set<Id> docIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();
        for (ContentDocumentLink headerLink : headerLinks) {
            List<Id> targets = headerIdToOrderIds.get(headerLink.LinkedEntityId);
            if (targets == null || headerLink.ContentDocumentId == null) {
                continue;
            }
            docIds.add(headerLink.ContentDocumentId);
            for (Id orderId : targets) {
                orderIds.add(orderId);
                keysToRemove.add(linkKey(headerLink.ContentDocumentId, orderId));
            }
        }
        if (keysToRemove.isEmpty()) {
            return;
        }

        List<ContentDocumentLink> toDelete = new List<ContentDocumentLink>();
        for (ContentDocumentLink orderLink : queryOrderLinks(docIds, orderIds)) {
            if (keysToRemove.contains(linkKey(orderLink.ContentDocumentId, orderLink.LinkedEntityId))) {
                toDelete.add(orderLink);
            }
        }
        if (!toDelete.isEmpty()) {
            Database.delete(toDelete, false);
        }
    }

    /**
     * @description Copies Visibility from header file links onto matching Order links.
     * @param headerLinks Header links whose Visibility changed.
     * @param headerIdToOrderIds Header Id to related Order Ids.
     */
    public static void applyVisibilityToOrderLinks(
        List<ContentDocumentLink> headerLinks,
        Map<Id, List<Id>> headerIdToOrderIds
    ) {
        Map<String, String> visibilityByKey = new Map<String, String>();
        Set<Id> docIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();
        for (ContentDocumentLink headerLink : headerLinks) {
            List<Id> targets = headerIdToOrderIds.get(headerLink.LinkedEntityId);
            if (targets == null || headerLink.ContentDocumentId == null) {
                continue;
            }
            docIds.add(headerLink.ContentDocumentId);
            for (Id orderId : targets) {
                orderIds.add(orderId);
                visibilityByKey.put(linkKey(headerLink.ContentDocumentId, orderId), headerLink.Visibility);
            }
        }
        if (visibilityByKey.isEmpty()) {
            return;
        }

        List<ContentDocumentLink> toUpdate = new List<ContentDocumentLink>();
        for (ContentDocumentLink orderLink : queryOrderLinks(docIds, orderIds)) {
            String visibility = visibilityByKey.get(linkKey(orderLink.ContentDocumentId, orderLink.LinkedEntityId));
            if (visibility == null || orderLink.Visibility == visibility) {
                continue;
            }
            orderLink.Visibility = visibility;
            toUpdate.add(orderLink);
        }
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }

    /**
     * @description Order {@link ContentDocumentLink} rows for the given files and Orders.
     * @param docIds ContentDocument Ids.
     * @param orderIds Order Ids.
     * @return Matching Order file links; empty when either Id set is empty.
     */
    private static List<ContentDocumentLink> queryOrderLinks(Set<Id> docIds, Set<Id> orderIds) {
        if (docIds.isEmpty() || orderIds.isEmpty()) {
            return new List<ContentDocumentLink>();
        }
        return [
            SELECT Id, ContentDocumentId, LinkedEntityId, Visibility
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :docIds AND LinkedEntityId IN :orderIds
        ];
    }

    /**
     * @description Collects all Order Ids from the header-to-order map.
     * @param headerIdToOrderIds Header Id to related Order Ids.
     * @return Distinct Order Ids.
     */
    private static Set<Id> flattenOrderIds(Map<Id, List<Id>> headerIdToOrderIds) {
        Set<Id> orderIds = new Set<Id>();
        for (List<Id> ids : headerIdToOrderIds.values()) {
            orderIds.addAll(ids);
        }
        return orderIds;
    }

    /**
     * @description Existing ContentDocument-to-Order link keys for duplicate detection.
     * @param orderIds Order Ids in the current insert set.
     * @return Keys in {@code ContentDocumentId:LinkedEntityId} form.
     */
    private static Set<String> existingLinkKeys(Set<Id> orderIds) {
        Set<String> keys = new Set<String>();
        for (ContentDocumentLink existing : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :orderIds
        ]) {
            keys.add(linkKey(existing.ContentDocumentId, existing.LinkedEntityId));
        }
        return keys;
    }

    /**
     * @description Adds Order links for one header file, skipping duplicates.
     * @param headerLink Header {@link ContentDocumentLink} to copy.
     * @param headerIdToOrderIds Header Id to related Order Ids.
     * @param existingKeys Keys already present or queued in this run.
     * @param toInsert Accumulator for new Order links.
     */
    private static void addLinksForHeaderFile(
        ContentDocumentLink headerLink,
        Map<Id, List<Id>> headerIdToOrderIds,
        Set<String> existingKeys,
        List<ContentDocumentLink> toInsert
    ) {
        List<Id> targetOrderIds = headerIdToOrderIds.get(headerLink.LinkedEntityId);
        if (targetOrderIds == null || headerLink.ContentDocumentId == null) {
            return;
        }
        for (Id orderId : targetOrderIds) {
            String key = linkKey(headerLink.ContentDocumentId, orderId);
            if (existingKeys.contains(key)) {
                continue;
            }
            existingKeys.add(key);
            toInsert.add(newOrderLink(headerLink, orderId));
        }
    }

    /**
     * @description Duplicate-detection key for a ContentDocument on a given entity.
     * @param contentDocumentId File Id.
     * @param linkedEntityId Order or header Id.
     * @return {@code ContentDocumentId:LinkedEntityId}.
     */
    private static String linkKey(Id contentDocumentId, Id linkedEntityId) {
        return contentDocumentId + ':' + linkedEntityId;
    }

    /**
     * @description Viewer-share Order link for a header file.
     * @param headerLink Source header link (Visibility is copied when present).
     * @param orderId Order to attach the file to.
     * @return New {@link ContentDocumentLink} for insert.
     */
    private static ContentDocumentLink newOrderLink(ContentDocumentLink headerLink, Id orderId) {
        String visibility = headerLink.Visibility;
        if (visibility == null) {
            visibility = 'AllUsers';
        }
        return new ContentDocumentLink(
            ContentDocumentId = headerLink.ContentDocumentId,
            LinkedEntityId = orderId,
            ShareType = 'V',
            Visibility = visibility
        );
    }
}