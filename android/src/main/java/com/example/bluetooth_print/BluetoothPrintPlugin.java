package com.example.bluetooth_print;

import android.Manifest;
import android.app.Activity;
import android.app.Application;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.util.Log;

import androidx.annotation.RequiresApi;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.activity.result.ActivityResultCallback;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;

import com.gprinter.command.FactoryCommand;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.*;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Plugin BluetoothPrint - Responsável por gerenciar a comunicação com
 * impressoras Bluetooth
 * 
 * Este plugin permite:
 * - Escanear dispositivos Bluetooth
 * - Conectar/desconectar de impressoras
 * - Enviar comandos de impressão
 * - Monitorar o estado da conexão Bluetooth
 * 
 * @author thon
 */
public class BluetoothPrintPlugin
        implements FlutterPlugin, ActivityAware, MethodCallHandler, RequestPermissionsResultListener {
    // Tag para logs
    private static final String TAG = "BluetoothPrintPlugin";

    // Objeto para sincronização durante inicialização
    private Object initializationLock = new Object();

    // Contexto da aplicação
    private Context context;

    // Pool de threads para operações assíncronas
    private ThreadPool threadPool;

    // Endereço MAC do dispositivo conectado atualmente
    private String curMacAddress;

    // Namespace para os canais de comunicação
    private static final String NAMESPACE = "bluetooth_print";

    // Canais de comunicação com o Flutter
    private MethodChannel channel;
    private EventChannel stateChannel;

    // Gerenciadores Bluetooth
    private BluetoothManager mBluetoothManager;
    private BluetoothAdapter mBluetoothAdapter;

    // Bindings do plugin e atividade
    private FlutterPluginBinding pluginBinding;
    private ActivityPluginBinding activityBinding;

    // Aplicação e atividade atual
    private Application application;
    private Activity activity;

    // Chamadas e resultados pendentes (usados durante solicitação de permissões)
    private MethodCall pendingCall;
    private Result pendingResult;

    // Códigos de requisição
    private static final int REQUEST_FINE_LOCATION_PERMISSIONS = 1452;
    private static final int REQUEST_ENABLE_BT = 1451;

    // Permissões necessárias para o Bluetooth
    private static String[] PERMISSIONS_LOCATION = {
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.ACCESS_FINE_LOCATION
    };

    /**
     * Construtor padrão
     */
    public BluetoothPrintPlugin() {
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        pluginBinding = binding;
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        pluginBinding = null;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activityBinding = binding;

        // Configura o listener para resultados de atividade (como ativação do
        // Bluetooth)
        activityBinding.addActivityResultListener((requestCode, resultCode, data) -> {
            if (requestCode == REQUEST_ENABLE_BT) {
                if (resultCode == Activity.RESULT_OK) {
                    // Se o usuário ativou o Bluetooth, continua com o scan pendente
                    if (pendingCall != null && pendingResult != null) {
                        startScan(pendingCall, pendingResult);
                    }
                } else {
                    // Usuário recusou ativar o Bluetooth
                    if (pendingResult != null) {
                        pendingResult.error("bluetooth_disabled", "Ativação do Bluetooth foi negada pelo usuário",
                                null);
                    }
                }
                return true;
            }
            return false;
        });

        // Configura o plugin com os bindings necessários
        setup(
                pluginBinding.getBinaryMessenger(),
                (Application) pluginBinding.getApplicationContext(),
                activityBinding.getActivity(),
                activityBinding);
    }

    @Override
    public void onDetachedFromActivity() {
        tearDown();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    /**
     * Configura o plugin com os componentes necessários
     * 
     * @param messenger       Mensageiro binário para comunicação com Flutter
     * @param application     Aplicação Android
     * @param activity        Atividade Android atual
     * @param activityBinding Binding da atividade
     */
    private void setup(
            final BinaryMessenger messenger,
            final Application application,
            final Activity activity,
            final ActivityPluginBinding activityBinding) {
        synchronized (initializationLock) {
            Log.i(TAG, "setup");
            this.activity = activity;
            this.application = application;
            this.context = application;

            // Configura os canais de método e estado
            channel = new MethodChannel(messenger, NAMESPACE + "/methods");
            channel.setMethodCallHandler(this);
            stateChannel = new EventChannel(messenger, NAMESPACE + "/state");
            stateChannel.setStreamHandler(stateHandler);

            // Obtém os serviços Bluetooth
            mBluetoothManager = (BluetoothManager) application.getSystemService(Context.BLUETOOTH_SERVICE);
            mBluetoothAdapter = mBluetoothManager.getAdapter();

            // Adiciona listener para resultados de permissão
            activityBinding.addRequestPermissionsResultListener(this);
        }
    }

    /**
     * Limpa os recursos do plugin
     */
    private void tearDown() {
        Log.i(TAG, "teardown");
        context = null;
        activityBinding.removeRequestPermissionsResultListener(this);
        activityBinding = null;
        channel.setMethodCallHandler(null);
        channel = null;
        stateChannel.setStreamHandler(null);
        stateChannel = null;
        mBluetoothAdapter = null;
        mBluetoothManager = null;
        application = null;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        // Verifica se o dispositivo tem Bluetooth (exceto para o método isAvailable)
        if (mBluetoothAdapter == null && !"isAvailable".equals(call.method)) {
            result.error("bluetooth_unavailable", "O dispositivo não possui Bluetooth", null);
            return;
        }

        // Trata cada método chamado do Flutter
        switch (call.method) {
            case "state":
                state(result);
                break;
            case "isAvailable":
                result.success(mBluetoothAdapter != null);
                break;
            case "isOn":
                result.success(mBluetoothAdapter.isEnabled());
                break;
            case "isConnected":
                result.success(threadPool != null);
                break;
            case "startScan": {
                // Verifica permissões antes de escanear
                if (ContextCompat.checkSelfPermission(context,
                        Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                    ActivityCompat.requestPermissions(activityBinding.getActivity(), PERMISSIONS_LOCATION,
                            REQUEST_FINE_LOCATION_PERMISSIONS);
                    pendingCall = call;
                    pendingResult = result;
                    break;
                }

                startScan(call, result);
                break;
            }
            case "stopScan":
                stopScan();
                result.success(null);
                break;
            case "connect":
                connect(call, result);
                break;
            case "disconnect":
                result.success(disconnect());
                break;
            case "destroy":
                result.success(destroy());
                break;
            case "print":
            case "printReceipt":
            case "printLabel":
                print(call, result);
                break;
            case "printTest":
                printTest(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    /**
     * Obtém a lista de dispositivos Bluetooth pareados
     * 
     * @param result Resultado a ser retornado para o Flutter
     */
    private void getDevices(Result result) {
        List<Map<String, Object>> devices = new ArrayList<>();
        for (BluetoothDevice device : mBluetoothAdapter.getBondedDevices()) {
            Map<String, Object> ret = new HashMap<>();
            ret.put("address", device.getAddress());
            ret.put("name", device.getName());
            ret.put("type", device.getType());
            devices.add(ret);
        }

        result.success(devices);
    }

    /**
     * Obtém o estado atual do Bluetooth
     * 
     * @param result Resultado a ser retornado para o Flutter
     */
    private void state(Result result) {
        try {
            switch (mBluetoothAdapter.getState()) {
                case BluetoothAdapter.STATE_OFF:
                    result.success(BluetoothAdapter.STATE_OFF);
                    break;
                case BluetoothAdapter.STATE_ON:
                    result.success(BluetoothAdapter.STATE_ON);
                    break;
                case BluetoothAdapter.STATE_TURNING_OFF:
                    result.success(BluetoothAdapter.STATE_TURNING_OFF);
                    break;
                case BluetoothAdapter.STATE_TURNING_ON:
                    result.success(BluetoothAdapter.STATE_TURNING_ON);
                    break;
                default:
                    result.success(0);
                    break;
            }
        } catch (SecurityException e) {
            result.error("invalid_argument", "argumento 'address' não encontrado", null);
        }
    }

    /**
     * Inicia a varredura de dispositivos Bluetooth
     * 
     * @param call   Chamada do método
     * @param result Resultado a ser retornado para o Flutter
     */
    private void startScan(MethodCall call, Result result) {
        Log.d(TAG, "iniciando varredura");

        // Verifica se o Bluetooth está ativado
        if (!mBluetoothAdapter.isEnabled()) {
            pendingCall = call;
            pendingResult = result;

            // Solicita ativação do Bluetooth ao usuário
            Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            activity.startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT);
            return;
        }

        // Impressoras conectadas via Classic BT param de anunciar via BLE após a
        // conexão, fazendo com que sumam do próximo scan. Para cobrir esse caso,
        // reemite dispositivos pareados que já foram usados via este plugin na
        // sessão atual (registrados em deviceConnFactoryManagers). Isso evita
        // mostrar todos os dispositivos pareados do aparelho.
        try {
            java.util.Set<String> knownAddresses =
                    DeviceConnFactoryManager.getDeviceConnFactoryManagers().keySet();
            if (!knownAddresses.isEmpty()) {
                for (BluetoothDevice device : mBluetoothAdapter.getBondedDevices()) {
                    if (device.getName() != null && knownAddresses.contains(device.getAddress())) {
                        invokeMethodUIThread("ScanResult", device);
                    }
                }
            }
        } catch (SecurityException e) {
            Log.w(TAG, "Sem permissão para listar dispositivos pareados", e);
        }

        try {
            startScan();
            result.success(null);
        } catch (Exception e) {
            result.error("startScan", e.getMessage(), e);
        }
    }

    /**
     * Invoca um método no thread da UI
     * 
     * @param name   Nome do método a ser invocado
     * @param device Dispositivo Bluetooth relacionado
     */
    private void invokeMethodUIThread(final String name, final BluetoothDevice device) {
        final Map<String, Object> ret = new HashMap<>();
        ret.put("address", device.getAddress());
        ret.put("name", device.getName());
        ret.put("type", device.getType());

        activity.runOnUiThread(
                new Runnable() {
                    @Override
                    public void run() {
                        channel.invokeMethod(name, ret);
                    }
                });
    }

    // Callback para resultados de varredura Bluetooth
    private ScanCallback mScanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            BluetoothDevice device = result.getDevice();
            if (device != null && device.getName() != null) {
                invokeMethodUIThread("ScanResult", device);
            }
        }
    };

    /**
     * Inicia a varredura Bluetooth
     * 
     * @throws IllegalStateException Se o adaptador Bluetooth não estiver disponível
     */
    private void startScan() throws IllegalStateException {
        BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
        if (scanner == null) {
            throw new IllegalStateException("getBluetoothLeScanner() retornou nulo. O adaptador está ativado?");
        }

        // Configurações da varredura (modo de baixa latência)
        ScanSettings settings = new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build();
        scanner.startScan(null, settings, mScanCallback);
    }

    /**
     * Para a varredura Bluetooth
     */
    private void stopScan() {
        BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
        if (scanner != null) {
            scanner.stopScan(mScanCallback);
        }
    }

    /**
     * Conecta a uma impressora Bluetooth
     * 
     * @param call   Chamada do método contendo o endereço MAC
     * @param result Resultado a ser retornado para o Flutter
     */
    private void connect(MethodCall call, Result result) {
        try {
            // Verifica argumentos
            if (call.arguments() == null) {
                throw new IllegalArgumentException("Argumentos não podem ser nulos");
            }

            Map<String, Object> args = call.arguments();
            if (!args.containsKey("address")) {
                throw new IllegalArgumentException("Argumento 'address' não encontrado");
            }

            final String address = (String) args.get("address");
            if (address == null || address.isEmpty()) {
                throw new IllegalArgumentException("Endereço MAC inválido");
            }

            this.curMacAddress = address;

            // Desconecta qualquer conexão existente
            try {
                disconnect();
            } catch (Exception e) {
                Log.w(TAG, "Não foi possível desconectar conexão existente", e);
            }

            // Configura a fábrica de conexão
            try {
                new DeviceConnFactoryManager.Build()
                        .setConnMethod(DeviceConnFactoryManager.CONN_METHOD.BLUETOOTH)
                        .setMacAddress(address)
                        .build();
            } catch (Exception e) {
                throw new RuntimeException("Falha ao configurar conexão: " + e.getMessage(), e);
            }

            // Cria thread pool se necessário
            if (threadPool == null) {
                threadPool = ThreadPool.getInstantiation();
            }

            // Executa a conexão em background
            threadPool.addSerialTask(new Runnable() {
                @Override
                public void run() {
                    DeviceConnFactoryManager deviceConn = null;
                    try {
                        deviceConn = DeviceConnFactoryManager.getDeviceConnFactoryManagers().get(address);
                        if (deviceConn == null) {
                            throw new RuntimeException("Gerenciador de conexão não encontrado");
                        }

                        // Tenta conectar com timeout
                        final long startTime = System.currentTimeMillis();
                        final long TIMEOUT_MS = 15000; // 15 segundos

                        // Modificado: openPort() retorna void, então chamamos diretamente
                        deviceConn.openPort();

                        // Aguarda conexão ser estabelecida ou timeout
                        while (!deviceConn.getConnState() &&
                                (System.currentTimeMillis() - startTime) < TIMEOUT_MS) {
                            Thread.sleep(100);
                        }

                        final boolean isConnected = deviceConn.getConnState();
                        final String statusMessage = isConnected ? "Conectado com sucesso" : "Timeout na conexão";

                        Log.i(TAG, statusMessage + " - Dispositivo: " + address);

                        // Retorna resultado para o Flutter
                        activity.runOnUiThread(() -> {
                            if (isConnected) {
                                result.success(true);
                            } else {
                                result.error("connection_timeout",
                                        "Falha ao estabelecer conexão após " + TIMEOUT_MS + "ms",
                                        null);
                            }
                        });

                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        activity.runOnUiThread(() -> {
                            result.error("connection_interrupted",
                                    "Conexão interrompida: " + e.getMessage(),
                                    null);
                        });
                    } catch (Exception e) {
                        activity.runOnUiThread(() -> {
                            result.error("connection_error",
                                    "Erro durante a conexão: " + e.getMessage(),
                                    null);
                        });

                        // Fecha a conexão se houve falha
                        if (deviceConn != null) {
                            try {
                                deviceConn.closePort();
                            } catch (Exception ex) {
                                Log.e(TAG, "Erro ao limpar conexão falha", ex);
                            }
                        }
                    }
                }
            });

        } catch (IllegalArgumentException e) {
            result.error("invalid_argument", e.getMessage(), null);
        } catch (Exception e) {
            result.error("connection_failed", "Erro inicial na conexão: " + e.getMessage(), null);
        }
    }

    /**
     * Desconecta da impressora atual
     * 
     * @return true se a desconexão foi bem-sucedida
     */
    private boolean disconnect() {
        if (curMacAddress == null) {
            return true;
        }

        try {
            DeviceConnFactoryManager deviceConnFactoryManager = DeviceConnFactoryManager.getDeviceConnFactoryManagers()
                    .get(curMacAddress);

            if (deviceConnFactoryManager != null) {
                if (deviceConnFactoryManager.reader != null) {
                    deviceConnFactoryManager.reader.cancel();
                }
                deviceConnFactoryManager.closePort();
                deviceConnFactoryManager.mPort = null;
                return true;
            }
            return false;
        } catch (Exception e) {
            Log.e(TAG, "Erro ao desconectar", e);
            return false;
        }

    }

    /**
     * Destrói todos os recursos e conexões
     * 
     * @return true se a operação foi bem-sucedida
     */
    private boolean destroy() {
        DeviceConnFactoryManager.closeAllPort();
        if (threadPool != null) {
            threadPool.stopThreadPool();
        }

        return true;
    }

    /**
     * Envia um comando de teste para a impressora
     * 
     * @param result Resultado a ser retornado para o Flutter
     */
    private void printTest(Result result) {
        final DeviceConnFactoryManager deviceConnFactoryManager = DeviceConnFactoryManager
                .getDeviceConnFactoryManagers().get(curMacAddress);
        if (deviceConnFactoryManager == null || !deviceConnFactoryManager.getConnState()) {
            result.error("not connect", "estado da conexão inválido", null);
        }

        threadPool = ThreadPool.getInstantiation();
        threadPool.addSerialTask(new Runnable() {
            @Override
            public void run() {
                assert deviceConnFactoryManager != null;
                PrinterCommand printerCommand = deviceConnFactoryManager.getCurrentPrinterCommand();

                // Envia o comando de teste de acordo com o tipo de impressora
                if (printerCommand == PrinterCommand.ESC) {
                    deviceConnFactoryManager
                            .sendByteDataImmediately(FactoryCommand.printSelfTest(FactoryCommand.printerMode.ESC));
                } else if (printerCommand == PrinterCommand.TSC) {
                    deviceConnFactoryManager
                            .sendByteDataImmediately(FactoryCommand.printSelfTest(FactoryCommand.printerMode.TSC));
                } else if (printerCommand == PrinterCommand.CPCL) {
                    deviceConnFactoryManager
                            .sendByteDataImmediately(FactoryCommand.printSelfTest(FactoryCommand.printerMode.CPCL));
                }
            }
        });
    }

    /**
     * Envia dados para impressão
     * 
     * @param call   Chamada do método contendo configurações e dados
     * @param result Resultado a ser retornado para o Flutter
     */
    @SuppressWarnings("unchecked")
    private void print(MethodCall call, Result result) {
        Map<String, Object> args = call.arguments();

        final DeviceConnFactoryManager deviceConnFactoryManager = DeviceConnFactoryManager
                .getDeviceConnFactoryManagers().get(curMacAddress);
        if (deviceConnFactoryManager == null || !deviceConnFactoryManager.getConnState()) {
            result.error("not connect", "estado da conexão inválido", null);
        }

        if (args != null && args.containsKey("config") && args.containsKey("data")) {
            final Map<String, Object> config = (Map<String, Object>) args.get("config");
            final List<Map<String, Object>> list = (List<Map<String, Object>>) args.get("data");
            if (list == null) {
                return;
            }

            threadPool = ThreadPool.getInstantiation();
            threadPool.addSerialTask(new Runnable() {
                @Override
                public void run() {
                    assert deviceConnFactoryManager != null;
                    PrinterCommand printerCommand = deviceConnFactoryManager.getCurrentPrinterCommand();

                    // Converte e envia os dados de acordo com o tipo de impressora
                    if (printerCommand == PrinterCommand.ESC) {
                        deviceConnFactoryManager.sendDataImmediately(PrintContent.mapToReceipt(config, list));
                    } else if (printerCommand == PrinterCommand.TSC) {
                        deviceConnFactoryManager.sendDataImmediately(PrintContent.mapToLabel(config, list));
                    } else if (printerCommand == PrinterCommand.CPCL) {
                        deviceConnFactoryManager.sendDataImmediately(PrintContent.mapToCPCL(config, list));
                    }
                }
            });
        } else {
            result.error("invalid_arguments", "por favor adicione config ou data", null);
        }
    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        // Trata o resultado da solicitação de permissões
        if (requestCode == REQUEST_FINE_LOCATION_PERMISSIONS) {
            if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // Permissão concedida, continua com a varredura
                startScan(pendingCall, pendingResult);
            } else {
                // Permissão negada, retorna erro
                pendingResult.error("no_permissions", "este plugin requer permissões de localização para varredura",
                        null);
                pendingResult = null;
            }
            return true;
        }
        return false;
    }

    /**
     * StreamHandler para monitorar mudanças no estado Bluetooth
     */
    private final StreamHandler stateHandler = new StreamHandler() {
        private EventSink sink;

        // Receiver para monitorar mudanças no estado Bluetooth
        private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                final String action = intent.getAction();
                Log.d(TAG, "stateStreamHandler, ação atual: " + action);

                if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action)) {
                    threadPool = null;
                    sink.success(intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1));
                } else if (BluetoothDevice.ACTION_ACL_CONNECTED.equals(action)) {
                    sink.success(1); // Dispositivo
                                     // conectado
                } else if (BluetoothDevice.ACTION_ACL_DISCONNECTED.equals(action)) {
                    threadPool = null;
                    sink.success(0); // Dispositivo
                                     // desconectado
                }
            }
        };

        @Override
        public void onListen(Object o, EventSink eventSink) {
            sink = eventSink;
            // Filtro para as ações Bluetooth relevantes
            IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
            filter.addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED);
            filter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
            filter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
            context.registerReceiver(mReceiver, filter);
        }

        @Override
        public void onCancel(Object o) {
            sink = null;
            context.unregisterReceiver(mReceiver);
        }
    };
}