/**
 * @description Excecao customizada para erros de integracao com APIs externas.
 *              Carrega codigo de erro e status HTTP para diagnostico.
 */
public class APIException extends Exception {

    private String errorCode;
    private Integer httpStatusCode;
    private String apiMessage;

    /**
     * @description Fabrica: Apex nao permite super(message) explicito,
     *              por isso a instancia usa o construtor base herdado.
     */
    public static APIException create(String errorCode, String message) {
        APIException e = new APIException(message);
        e.errorCode = errorCode;
        return e;
    }

    public static APIException create(String errorCode, String message, Integer httpStatusCode) {
        APIException e = create(errorCode, message);
        e.httpStatusCode = httpStatusCode;
        return e;
    }

    public String getErrorCode() {
        return errorCode;
    }

    public Integer getHttpStatusCode() {
        return httpStatusCode;
    }

    public String getApiMessage() {
        return apiMessage;
    }

    public void setApiMessage(String apiMessage) {
        this.apiMessage = apiMessage;
    }
}
