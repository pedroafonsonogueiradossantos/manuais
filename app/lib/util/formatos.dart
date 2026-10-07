/// Tamanho de arquivo legível: "850 B", "1,5 MB".
String tamanhoLegivel(int bytes) {
  const unidades = ['B', 'KB', 'MB', 'GB'];
  var valor = bytes.toDouble();
  var i = 0;
  while (valor >= 1024 && i < unidades.length - 1) {
    valor /= 1024;
    i++;
  }
  final texto = i == 0 || valor >= 100
      ? valor.round().toString()
      : valor.toStringAsFixed(1).replaceAll('.', ',');
  return '$texto ${unidades[i]}';
}

const tiposDeDocumento = {
  'manual_servico': 'Manual de serviço',
  'diagrama_eletrico': 'Diagrama elétrico',
  'foto': 'Foto',
  'outro': 'Outro',
};

String rotuloDoTipo(String tipo) => tiposDeDocumento[tipo] ?? tipo;
