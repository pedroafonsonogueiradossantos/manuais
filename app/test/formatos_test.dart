import 'package:flutter_test/flutter_test.dart';
import 'package:manuais/util/formatos.dart';

void main() {
  test('tamanhoLegivel', () {
    expect(tamanhoLegivel(0), '0 B');
    expect(tamanhoLegivel(850), '850 B');
    expect(tamanhoLegivel(1536), '1,5 KB');
    expect(tamanhoLegivel(5 * 1024 * 1024), '5,0 MB');
    expect(tamanhoLegivel(250 * 1024 * 1024), '250 MB');
    expect(tamanhoLegivel(3 * 1024 * 1024 * 1024), '3,0 GB');
  });

  test('rotuloDoTipo', () {
    expect(rotuloDoTipo('diagrama_eletrico'), 'Diagrama elétrico');
    expect(rotuloDoTipo('desconhecido'), 'desconhecido');
  });
}
