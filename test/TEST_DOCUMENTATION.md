# Testes para Bluetooth Scanner

## Documentação dos Testes

Este diretório contém testes abrangentes para o módulo `bluetooth_scanner.dart`. Os testes cobrem funcionalidades, edge cases e cenários realistas de uso.

## Arquivos de Teste

### 1. **bluetooth_scanner_test.dart**
Testes fundamentais que cobrem todas as funcionalidades básicas:

- **scan()**: Verificar retorno de stream, timeout, rejeção de scan duplicado, atualização de status
- **startScan()**: Verificar retorno de lista de dispositivos e respeito ao timeout
- **stopScan()**: Parar scan com sucesso, tratamento de erros
- **Streams**:
  - `scanResults`: Emissão de resultados atualizados, broadcast
  - `isScanning`: Transições de estado, broadcast
- **dispose()**: Fechamento de controladores, múltiplas chamadas
- **BluetoothDevice Parsing**: Parse de JSON, valores nulos
- **Edge Cases**: Dispositivos sem endereço, capitalizações, cancelamento

### 2. **bluetooth_scanner_advanced_test.dart**
Testes avançados com mocks e integração profunda:

- **Integração com MethodChannel**: Verificar chamadas corretas
- **Comportamento de Duplicatas**: Não duplicar dispositivos, atualizar existentes
- **Gerenciamento de Recursos**: Liberação correta, múltiplos scanners coexistentes
- **Timeout**: Padrão (5s) e customizado
- **BluetoothDevice Model**: Conversão JSON, effectiveType
- **Tratamento de Erros**: Erro durante scan, BluetoothPrintException
- **Interface Contract**: Implementação correta de IBluetoothScanner

### 3. **bluetooth_scanner_scenarios_test.dart**
Testes de cenários realistas de uso:

- **Fluxo de Escaneamento Básico**: Iniciar e parar scan
- **Filtros e Processamento**: Filtrar impressoras, agrupar por tipo, contar únicos
- **Monitoramento de Status**: Transições, múltiplos listeners
- **Resultados Acumulados**: Histórico de descoberta, sem duplicatas
- **Controle de Lifecycle**: Reiniciar scan, limpeza após dispose
- **Edge Cases**: Timeouts curtos, sem resultados, duplicatas ignoradas
- **Integração com UI**: StreamBuilder, mudanças em tempo real

## Como Executar os Testes

### Executar todos os testes
```bash
flutter test
```

### Executar um arquivo específico
```bash
flutter test test/bluetooth_scanner_test.dart
flutter test test/bluetooth_scanner_advanced_test.dart
flutter test test/bluetooth_scanner_scenarios_test.dart
```

### Executar testes com padrão
```bash
flutter test --name="scan()"
flutter test --name="shouldCall"
```

### Executar com cobertura
```bash
flutter test --coverage
```

## Cobertura de Testes

### Funcionalidades Testadas

| Funcionalidade | Testes | Status |
|---|---|---|
| `scan()` | 9 testes | ✓ |
| `startScan()` | 3 testes | ✓ |
| `stopScan()` | 4 testes | ✓ |
| `scanResults` stream | 4 testes | ✓ |
| `isScanning` stream | 5 testes | ✓ |
| `dispose()` | 4 testes | ✓ |
| BluetoothDevice parsing | 5 testes | ✓ |
| Duplicata handling | 3 testes | ✓ |
| Error handling | 4 testes | ✓ |
| Resource management | 4 testes | ✓ |
| Timeout behavior | 4 testes | ✓ |
| Interface contract | 5 testes | ✓ |
| Realistic scenarios | 18 testes | ✓ |
| **Total** | **73 testes** | **✓** |

## Casos de Teste Principais

### Cenários Positivos
- ✓ Scan inicia e completa com sucesso
- ✓ Dispositivos são detectados e retornados
- ✓ Status de scanning atualiza corretamente
- ✓ Recursos são liberados adequadamente
- ✓ Streams broadcast funcionam com múltiplos listeners

### Cenários Negativos
- ✓ Rejeição de scan duplicado
- ✓ Timeout respeitado
- ✓ Erros propagados corretamente
- ✓ Edge cases tratados (valores nulos, vazios)

### Cenários de Edge Case
- ✓ Dispositivos sem MAC address ignorados
- ✓ Capitalizações diferentes unificadas
- ✓ Timeout muito curto
- ✓ Sem resultados retornados
- ✓ Dupli

catas não adicionadas

## Exemplo de Uso em Testes

```dart
// Teste básico de scan
test('deve retornar stream de dispositivos', () async {
  final devices = <BluetoothDevice>[];
  
  await scanner
    .scan(timeout: Duration(milliseconds: 100))
    .forEach(devices.add);
    
  expect(devices, isA<List<BluetoothDevice>>());
});

// Teste com assertions em streams
test('deve atualizar isScanning durante scan', () async {
  final statuses = <bool>[];
  
  final statusSub = scanner.isScanning.listen(statuses.add);
  final deviceScan = scanner.scan(timeout: Duration(milliseconds: 100))
    .listen((_) {});
    
  await Future.delayed(Duration(milliseconds: 150));
  
  await statusSub.cancel();
  await deviceScan.cancel();
  
  expect(statuses, contains(true));
});
```

## Debugging de Testes

### Modo Verbose
```bash
flutter test -v
```

### Debugger
Adicione `debugger();` no teste:
```dart
test('exemplo', () {
  debugger();
  // seu código
});
```

### Logs Personalizados
```dart
test('exemplo', () {
  print('Iniciando teste...');
  // seu código
  print('Teste completado');
});
```

## Dependências de Teste

Os testes usam as seguintes dependências:
- `flutter_test` - Framework de testes do Flutter
- `flutter/services` - Para MethodChannel
- Pacotes internos do projeto

## Melhorias Futuras

- [ ] Adicionar testes de performance
- [ ] Mockar resposta do MethodChannel com dados reais
- [ ] Adicionar testes de integração com hardware real
- [ ] Cobertura de 100% do código
- [ ] Testes parametrizados para múltiplos tipos de dispositivos

## Troubleshooting

### Testes não executam
```bash
flutter pub get
flutter test --verbose
```

### Erro "Unimplemented Instance"
Verifique se o MethodChannel está sendo mockado corretamente.

### Timeout nos testes
Aumente o timeout padrão:
```dart
flutter test --test-randomize-ordering-seed=12345 --timeout=120s
```

## Scripts Úteis

### Executar e gerar relatório
```bash
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html && start coverage/html/index.html
```

### Executar com watch mode (requer package)
```bash
dart pub global activate watcher
dart pub run watcher watch -- flutter test
```

## Contato e Discussões

Para discussões sobre os testes, abra uma issue no repositório.
