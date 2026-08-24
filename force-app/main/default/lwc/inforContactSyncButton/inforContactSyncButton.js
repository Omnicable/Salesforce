import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncService from '@salesforce/apex/InforBaseAPIService.syncService';

export default class InforContactSyncButton extends LightningElement {
    @api recordId;

    isSyncing = false;
    statusMessage;
    statusVariant;

    get isDisabled() {
        return this.isSyncing || !this.recordId;
    }

    get showStatus() {
        return !!this.statusMessage;
    }

    get statusClass() {
        return this.statusVariant === 'error'
            ? 'slds-text-color_error slds-m-top_x-small'
            : 'slds-text-color_success slds-m-top_x-small';
    }

    async handleSync() {
        if (this.isDisabled) {
            return;
        }

        this.isSyncing = true;
        this.statusMessage = undefined;
        this.statusVariant = undefined;

        try {
            const jobId = await syncService({ contactId: this.recordId });
            this.statusVariant = 'success';
            this.statusMessage = `Infor sync started successfully (Job ${jobId}).`;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Contact Synced',
                    message: this.statusMessage,
                    variant: 'success'
                })
            );
        } catch (error) {
            const message = this.reduceError(error);
            this.statusVariant = 'error';
            this.statusMessage = message;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Infor Sync Failed',
                    message,
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isSyncing = false;
        }
    }

    reduceError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        return 'Unexpected error starting Infor sync.';
    }
}