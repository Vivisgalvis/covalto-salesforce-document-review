public with sharing class DocumentReviewController {

    @AuraEnabled
    public static void saveReview(
        Id reviewId,
        Boolean officialId,
        Boolean legible,
        Boolean valid,
        Boolean under600KB
    ) 
    {
        System.debug('******** SAVE REVIEW EJECUTADO ********');
    System.debug('ReviewId: ' + reviewId);
    System.debug('OfficialId: ' + officialId);
    System.debug('Legible: ' + legible);
    System.debug('Valid: ' + valid);
    System.debug('Under600KB: ' + under600KB);
        Document_Review__c review = [
            SELECT Id,
                   Official_ID__c,
                   Legible__c,
                   Valid__c,
                   Under_600KB__c,
                   Status__c,
                   Lead__c
            FROM Document_Review__c
            WHERE Id = :reviewId
            LIMIT 1
        ];

        review.Official_ID__c = officialId;
        review.Legible__c = legible;
        review.Valid__c = valid;
        review.Under_600KB__c = under600KB;

        // Si todos los criterios se cumplen
        if (officialId && legible && valid && under600KB) {

            review.Status__c = 'Aprobado';

        } else {

            review.Status__c = 'Rechazado';

        }

        update review;

        // Si fue rechazado se envía correo
        if (review.Status__c == 'Rechazado') {

            enviarCorreo(review.Id);
            System.debug('******** ENVIAR CORREO EJECUTADO ********');

        }
    }

    @AuraEnabled
    public static void marcarComoRevisado(Id reviewId) {

        Document_Review__c review = [

            SELECT Id,
                   Status__c

            FROM Document_Review__c

            WHERE Id = :reviewId

            LIMIT 1
        ];

        review.Status__c = 'Revisado';

        update review;

        enviarCorreo(review.Id);
    }

    @AuraEnabled(cacheable=true)
    public static Document_Review__c getReview(Id reviewId) {

        return [
            SELECT Id,
                   Official_ID__c,
                   Legible__c,
                   Valid__c,
                   Under_600KB__c,
                   Status__c
            FROM Document_Review__c
            WHERE Id = :reviewId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static void guardarComentario(
        Id reviewId,
        String comentario
    ) {

        if (String.isBlank(comentario)) {

            return;

        }

        Review_Comment__c nuevo = new Review_Comment__c();

        nuevo.Document_Review__c = reviewId;
        nuevo.comentario__c = comentario;
        nuevo.fecha_comentario__c = System.now();

        insert nuevo;
    }

    @AuraEnabled(cacheable=true)
    public static List<Review_Comment__c> obtenerComentarios(
        Id reviewId
    ) {

        return [

            SELECT Id,
                   comentario__c,
                   fecha_comentario__c

            FROM Review_Comment__c

            WHERE Document_Review__c = :reviewId

            ORDER BY fecha_comentario__c DESC
        ];
    }

    private static void enviarCorreo(Id reviewId) {

    System.debug('===== INICIO ENVIO CORREO =====');
    System.debug('ReviewId recibido: ' + reviewId);

    Document_Review__c review = [

        SELECT Id,
               Status__c,
               Official_ID__c,
               Legible__c,
               Valid__c,
               Under_600KB__c,
               Lead__c,
               Lead__r.Name,
               Lead__r.Email

        FROM Document_Review__c

        WHERE Id = :reviewId

        LIMIT 1
    ];

    System.debug('Estado: ' + review.Status__c);
    System.debug('Lead: ' + review.Lead__r.Name);
    System.debug('Email: ' + review.Lead__r.Email);

    if (
        review.Lead__r == null ||
        String.isBlank(review.Lead__r.Email)
    ) {

        System.debug(
            'ERROR: El Lead no tiene correo electrónico.'
        );

        return;
    }

    Messaging.SingleEmailMessage correo =
        new Messaging.SingleEmailMessage();


    if (review.Status__c == 'Rechazado') {

        correo.setToAddresses(
        new String[]{
            review.Lead__r.Email
        }
    );

        String observaciones = '';

        if (!review.Official_ID__c) {

            observaciones +=
                '- No cumple validación de ID Oficial\n';

        }

        if (!review.Legible__c) {

            observaciones +=
                '- Documento ilegible\n';

        }

        if (!review.Valid__c) {

            observaciones +=
                '- Documento no vigente\n';

        }

        if (!review.Under_600KB__c) {

            observaciones +=
                '- Archivo superior a 600 KB\n';

        }

        correo.setSubject(
            'Observaciones sobre su documento'
        );

        correo.setPlainTextBody(

            'Estimado(a) '

            + review.Lead__r.Name +

            '\n\n'

            + 'Se detectaron las siguientes anomalías:\n\n'

            + observaciones +

            '\nPor favor cargue nuevamente el documento.'

            + '\n\nGracias.'
        );

    } else if (review.Status__c == 'Revisado') {

        correo.setTemplateId(
            '00Xfj00000CQw6HEAT'
            );
        correo.setTargetObjectId(
        review.Lead__c
        );

        correo.setSaveAsActivity(false);

    } else {

        System.debug(
            'No se enviará correo para el estado: '
            + review.Status__c
        );

        return;
    }

    System.debug(
        'Intentando enviar correo a: '
        + review.Lead__r.Email
    );

    Messaging.SendEmailResult[] resultados =
        Messaging.sendEmail(
            new Messaging.SingleEmailMessage[]{
                correo
            }
        );

    System.debug(
        'Cantidad resultados: '
        + resultados.size()
    );

    if (
        resultados != null &&
        resultados.size() > 0
    ) {

        System.debug(
            'Success: '
            + resultados[0].isSuccess()
        );

        if (!resultados[0].isSuccess()) {

            for (
                Messaging.SendEmailError err :
                resultados[0].getErrors()
            ) {

                System.debug(
                    'Codigo Error: '
                    + err.getStatusCode()
                );

                System.debug(
                    'Mensaje Error: '
                    + err.getMessage()
                );
            }
        }
    }

    System.debug('===== FIN ENVIO CORREO =====');
}
   @AuraEnabled(cacheable=true)
public static String obtenerPdf(Id reviewId) {

    Document_Review__c review = [

        SELECT Lead__c
        FROM Document_Review__c
        WHERE Id = :reviewId
        LIMIT 1
    ];

    List<ContentDocumentLink> archivos = [

        SELECT ContentDocument.LatestPublishedVersionId

        FROM ContentDocumentLink

        WHERE LinkedEntityId = :review.Lead__c

        LIMIT 1
    ];

    if (archivos.isEmpty()) {

        return null;

    }

    return '/sfc/servlet.shepherd/version/download/'
           + archivos[0].ContentDocument.LatestPublishedVersionId
           + '#view=FitH';
}
}