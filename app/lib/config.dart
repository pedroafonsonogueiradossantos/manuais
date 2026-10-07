/// URL da API. Troque com `--dart-define=API_URL=https://...`.
/// O padrão (10.0.2.2) é a máquina host vista de dentro do emulador Android.
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
