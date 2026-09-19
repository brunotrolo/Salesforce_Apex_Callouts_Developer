// =============================================================
// LOOKUP TABLE — Criacao via Apex (Business Rules Engine)
// =============================================================
// Executa: sf apex run --file scripts/setup-lookup-table.apex --target-org <alias>
// ou Developer Console: cole e execute
//
// Idempotente: pode rodar N vezes sem duplicar dados.
// Estrutura da tabela:
//   INPUTS:  API_Name | Environment | Operation
//   OUTPUTS: NamedCredential | TokenNamedCredential | Endpoint |
//            Method | Timeout | RetryEnabled | RetryCount | LogEnabled
//
// Para adicionar nova API: adicionar novo RowDef abaixo e rodar novamente.
// =============================================================

APIConfigSetup.setup();
System.debug('LOOKUP TABLE criada/atualizada com sucesso.');

// Verificacao: lista as linhas criadas
List<CalculationMatrix> matrices = [
    SELECT Id, Name FROM CalculationMatrix WHERE UniqueName = 'API_Config' LIMIT 1
];
if (!matrices.isEmpty()) {
    List<CalculationMatrixVersion> versions = [
        SELECT Id FROM CalculationMatrixVersion
        WHERE CalculationMatrixId = :matrices[0].Id AND IsEnabled = true LIMIT 1
    ];
    if (!versions.isEmpty()) {
        List<CalculationMatrixRow> rows = [
            SELECT Name, InputData, OutputData FROM CalculationMatrixRow
            WHERE CalculationMatrixVersionId = :versions[0].Id
        ];
        System.debug('Linhas na Lookup Table: ' + rows.size());
        for (CalculationMatrixRow r : rows) {
            System.debug('ROW: ' + r.Name + ' | INPUT: ' + r.InputData + ' | OUTPUT: ' + r.OutputData);
        }
    }
}
