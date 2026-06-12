import { LightningElement, api, wire } from 'lwc';
import saveReview from '@salesforce/apex/DocumentReviewController.saveReview';
import getReview from '@salesforce/apex/DocumentReviewController.getReview';
import marcarComoRevisado from '@salesforce/apex/DocumentReviewController.marcarComoRevisado';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import guardarComentario from '@salesforce/apex/DocumentReviewController.guardarComentario';
import obtenerComentarios from '@salesforce/apex/DocumentReviewController.obtenerComentarios';
import obtenerPdf from '@salesforce/apex/DocumentReviewController.obtenerPdf';
import { refreshApex } from '@salesforce/apex';

export default class DocumentReviewer extends LightningElement {

    @api recordId;

    officialId = false;
    legible = false;
    valid = false;
    under600KB = false;
    nuevoComentario='';
    comentarios=[];
    wiredCommentsResult;
    pdfUrl;

    wiredReviewResult;

@wire(getReview, { reviewId: '$recordId' })
wiredReview(result) {

    this.wiredReviewResult = result;

    const { error, data } = result;

    if (data) {

        this.officialId = data.Official_ID__c;

        this.legible = data.Legible__c;

        this.valid = data.Valid__c;

        this.under600KB = data.Under_600KB__c;

    }

    else if (error) {

        console.error(error);

    }
}

    handleOfficialId(event) {
        this.officialId = event.target.checked;
    }

    handleLegible(event) {
        this.legible = event.target.checked;
    }

    handleValid(event) {
        this.valid = event.target.checked;
    }

    handleUnder600KB(event) {
        this.under600KB = event.target.checked;
    }

    save() {

   

    saveReview({

        reviewId: this.recordId,
        officialId: this.officialId,
        legible: this.legible,
        valid: this.valid,
        under600KB: this.under600KB

    })
    .then(() => {
        this.dispatchEvent(

            new ShowToastEvent({

                title: 'Éxito',

                message: 'Documento guardado.',

                variant: 'success'

            })

        );

           })
    .catch(error => {

        console.error(error);

        alert(
            JSON.stringify(error)
        );

    });

}

    handleMarcarComoRevisado() {

    marcarComoRevisado({

        reviewId: this.recordId

    })

    .then(() => {

        this.dispatchEvent(

            new ShowToastEvent({

                title: 'Éxito',

                message: 'Documento marcado como Revisado.',

                variant: 'success'

            })

        );

        return refreshApex(this.wiredReviewResult);

    })

    .catch(error => {

        this.dispatchEvent(

            new ShowToastEvent({

                title: 'Error',

                message: error.body.message,

                variant: 'error'

            })

        );

    });

}

    @wire(obtenerComentarios, { reviewId: '$recordId' })

wiredComentarios(result) {

    this.wiredComentariosResult = result;

    const { data, error } = result;

    if (data) {

        this.comentarios = data;

    }

    else if (error) {

        console.error(error);

    }

}
handleComentario(event){

    this.nuevoComentario=event.target.value;

}
guardarNuevoComentario() {

    guardarComentario({

        reviewId: this.recordId,

        comentario: this.nuevoComentario

    })

    .then(() => {

        this.dispatchEvent(

            new ShowToastEvent({

                title: 'Éxito',

                message: 'Comentario agregado correctamente.',

                variant: 'success'

            })

        );

        this.nuevoComentario = '';

        return refreshApex(this.wiredComentariosResult);

    })

    .catch(error => {

        this.dispatchEvent(

            new ShowToastEvent({

                title: 'Error',

                message: error.body.message,

                variant: 'error'

            })

        );

    });

}

@wire(obtenerPdf, { reviewId: '$recordId' })
wiredPdf({ data, error }) {

    if (data) {

        this.pdfUrl = data;

    } else if (error) {

        console.error(error);

    }
}

}