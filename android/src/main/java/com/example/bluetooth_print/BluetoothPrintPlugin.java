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
import android.annotation.SuppressLint;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import com.gprinter.command.FactoryCommand;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener;
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
import java.util.Vector;
import java.io.UnsupportedEncodingException;

/**
 * Plugin para comunicação com impressoras Bluetooth
 * Funcionalidades: conexão, impressão, escaneamento de dispositivos
 * 
 * @author thon
 */
public class BluetoothPrintPlugin implements FlutterPlugin, ActivityAware, MethodCallHandler,
        RequestPermissionsResultListener {

    // Tag para logs
    private static final String TAG = "BluetoothPrintPlugin";

    private static final int CONNECTED = 1;
    private static final int DISCONNECTED = 0;

    // Objeto para sincronização
    private Object initializationLock = new Object();

    // Contexto da aplicação
    private Context context;

    // Pool de threads para operações assíncronas
    private ThreadPool threadPool;

    // Endereço MAC do dispositivo conectado
    private String curMacAddress;

    // Namespace para os canais de comunicação
    private static final String NAMESPACE = "bluetooth_print";

    // Canais de comunicação com o Flutter
    private MethodChannel channel;
    private EventChannel stateChannel;

    // Gerenciador e adaptador Bluetooth
    private BluetoothManager mBluetoothManager;
    private BluetoothAdapter mBluetoothAdapter;

    // Bindings para integração com Flutter
    private FlutterPluginBinding pluginBinding;
    private ActivityPluginBinding activityBinding;

    // Contexto da aplicação e atividade
    private Application application;
    private Activity activity;

    // Chamadas pendentes
    private MethodCall pendingCall;
    private Result pendingResult;

    // Códigos de requisição
    private static final int REQUEST_FINE_LOCATION_PERMISSIONS = 1452;
    private static final int REQUEST_ENABLE_BT = 1;

    // Permissões necessárias
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

    // Métodos do FlutterPlugin
    // ========================

    /**
     * Chamado quando o plugin é anexado ao motor Flutter
     * 
     * @param flutterPluginBinding Binding do plugin Flutter
     */
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        this.pluginBinding = flutterPluginBinding;
        context = flutterPluginBinding.getApplicationContext();

        // Configura o canal de métodos
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "bluetooth_print");
        channel.setMethodCallHandler(this);
    }

    /**
     * Chamado quando o plugin é desanexado do motor Flutter
     * 
     * @param binding Binding do plugin Flutter
     */
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        pluginBinding = null;
        channel.setMethodCallHandler(null);
        channel = null;
    }

    // Métodos do ActivityAware
    // =======================

    /**
     * Chamado quando o plugin é anexado a uma atividade
     * 
     * @param binding Binding da atividade
     */
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;

        activityBinding.addActivityResultListener(new ActivityResultListener() {
            @Override
            public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
                return BluetoothPrintPlugin.this.onActivityResult(requestCode, resultCode, data);
            }
        });

        if (pluginBinding != null) {
            setup(
                    pluginBinding.getBinaryMessenger(),
                    (Application) pluginBinding.getApplicationContext(),
                    activityBinding.getActivity(),
                    activityBinding);
        }
    }

    /**
     * Chamado quando o plugin é desanexado da atividade
     */
    @Override
    public void onDetachedFromActivity() {
        tearDown();
    }

    /**
     * Chamado quando a atividade é destruída para mudanças de configuração
     */
    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    /**
     * Chamado quando o plugin é reanexado a uma nova atividade após mudanças de
     * configuração
     * 
     * @param binding Binding da nova atividade
     */
    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    // Métodos de configuração
    // ======================

    /**
     * Configura os componentes do plugin
     * 
     * @param messenger       Mensageiro binário
     * @param application     Aplicação
     * @param activity        Atividade
     * @param activityBinding Binding da atividade
     */
    private void setup(
            final BinaryMessenger messenger,
            final Application application,
            final Activity activity,
            final ActivityPluginBinding activityBinding) {
        synchronized (initializationLock) {
            Log.i(TAG, "Configurando plugin Bluetooth");
            this.activity = activity;
            this.application = application;
            this.context = application;

            // Configura canais de comunicação
            channel = new MethodChannel(messenger, NAMESPACE + "/methods");
            channel.setMethodCallHandler(this);

            stateChannel = new EventChannel(messenger, NAMESPACE + "/state");
            stateChannel.setStreamHandler(stateHandler);

            // Obtém o gerenciador Bluetooth
            mBluetoothManager = (BluetoothManager) application.getSystemService(Context.BLUETOOTH_SERVICE);
            mBluetoothAdapter = mBluetoothManager.getAdapter();

            // Configura listeners
            if (activityBinding != null) {
                activityBinding.addRequestPermissionsResultListener(this);
            }
        }
    }

    /**
     * Limpa os recursos do plugin
     */
    private void tearDown() {
        Log.i(TAG, "Finalizando plugin Bluetooth");
        context = null;

        if (activityBinding != null) {
            activityBinding.removeRequestPermissionsResultListener(this);
            activityBinding = null;
        }

        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }

        if (stateChannel != null) {
            stateChannel.setStreamHandler(null);
            stateChannel = null;
        }

        mBluetoothAdapter = null;
        mBluetoothManager = null;
        application = null;
    }

    // Métodos de resultado de atividade
    // ================================

    /**
     * Trata resultados de atividades (como ativação do Bluetooth)
     * 
     * @param requestCode Código da requisição
     * @param resultCode  Código do resultado
     * @param data        Dados retornados
     * @return Verdadeiro se o resultado foi tratado
     */

    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_ENABLE_BT) {
            if (resultCode == Activity.RESULT_OK) {
                // Bluetooth foi ativado, pode escanear agora
                if (pendingCall != null && pendingResult != null) {
                    startScan(pendingCall, pendingResult);
                }
            } else {
                // Usuário recusou ativar o Bluetooth
                if (pendingResult != null) {
                    pendingResult.error("bluetooth_disabled", "Usuário negou ativação do Bluetooth", null);
                }
            }
            return true;
        }
        return false;
    }

    // Métodos principais
    // =================

    /**
     * Trata chamadas de método do Flutter
     * 
     * @param call   Chamada recebida
     * @param result Objeto para retornar resultados
     */
    @Override
    public void onMethodCall(MethodCall call, Result result) {
        // Verifica se o Bluetooth está disponível
        if (mBluetoothAdapter == null && !"isAvailable".equals(call.method)) {
            result.error("bluetooth_unavailable", "O dispositivo não possui Bluetooth", null);
            return;
        }

        // Processa os diferentes comandos
        switch (call.method) {
            case "state":
                getBluetoothState(result);
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
            case "startScan":
                handleStartScan(call, result);
                break;
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
            case "openCashDrawer":
                openCashDrawer(result);
                break;
            case "getCurrentDevice":
                getCurrentDevice(call, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    // Métodos auxiliares
    // =================

    /**
     * Obtém os dispositivos Bluetooth pareados
     * 
     * @param result Objeto para retornar os dispositivos
     */
    private void getDevices(Result result) {
        List<Map<String, Object>> devices = new ArrayList<>();

        for (BluetoothDevice device : mBluetoothAdapter.getBondedDevices()) {
            Map<String, Object> deviceInfo = new HashMap<>();
            deviceInfo.put("address", device.getAddress());
            deviceInfo.put("name", device.getName());
            deviceInfo.put("type", device.getType());
            devices.add(deviceInfo);
        }

        result.success(devices);
    }

    /**
     * Obtém o estado atual do Bluetooth
     * 
     * @param result Objeto para retornar o estado
     */
    private void getBluetoothState(Result result) {
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
            result.error("invalid_argument", "Argumento 'address' não encontrado", null);
        }
    }

    /**
     * Trata a inicialização do escaneamento Bluetooth
     * 
     * @param call   Chamada recebida
     * @param result Objeto para retornar resultados
     */
    private void handleStartScan(MethodCall call, Result result) {
        if (!mBluetoothAdapter.isEnabled()) {
            // Solicita ativação do Bluetooth
            Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            activity.startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT);
            pendingCall = call;
            pendingResult = result;
            return;
        }

        if (ContextCompat.checkSelfPermission(context,
                Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
            // Solicita permissões necessárias
            ActivityCompat.requestPermissions(activity, PERMISSIONS_LOCATION,
                    REQUEST_FINE_LOCATION_PERMISSIONS);
            pendingCall = call;
            pendingResult = result;
            return;
        }

        // Inicia o escaneamento
        startScan(call, result);
    }

    /**
     * Inicia o escaneamento Bluetooth
     * 
     * @param call   Chamada recebida
     * @param result Objeto para retornar resultados
     */
    private void startScan(MethodCall call, Result result) {
        Log.d(TAG, "Iniciando escaneamento Bluetooth");

        try {
            startScan();
            result.success(null);
        } catch (Exception e) {
            result.error("startScan", e.getMessage(), e);
        }
    }

    /**
     * Invoca um método na thread UI
     * 
     * @param name   Nome do método
     * @param device Dispositivo Bluetooth
     */
    private void invokeMethodUIThread(final String name, final BluetoothDevice device) {
        final Map<String, Object> deviceInfo = new HashMap<>();
        deviceInfo.put("address", device.getAddress());
        deviceInfo.put("name", device.getName());
        deviceInfo.put("type", device.getType());

        activity.runOnUiThread(() -> channel.invokeMethod(name, deviceInfo));
    }

    // Callback para escaneamento Bluetooth
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
     * Inicia o escaneamento Bluetooth
     * 
     * @throws IllegalStateException Se o Bluetooth não estiver disponível
     */
    private void startScan() throws IllegalStateException {
        if (mBluetoothAdapter == null || !mBluetoothAdapter.isEnabled()) {
            throw new IllegalStateException("Adaptador Bluetooth não disponível ou desativado");
        }

        BluetoothLeScanner scanner = mBluetoothAdapter.getBluetoothLeScanner();
        if (scanner == null) {
            throw new IllegalStateException("Falha ao obter scanner Bluetooth");
        }

        // Configurações de escaneamento (baixa latência)
        ScanSettings settings = new ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build();

        scanner.startScan(null, settings, mScanCallback);
    }

    /**
     * Para o escaneamento Bluetooth
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
     * @param call   Chamada recebida
     * @param result Objeto para retornar resultados
     */
    private void connect(MethodCall call, Result result) {
        Map<String, Object> args = call.arguments();

        if (args != null && args.containsKey("address")) {
            final String address = (String) args.get("address");
            this.curMacAddress = address;

            // Desconecta qualquer conexão existente
            disconnect();

            try {
                // Cria e configura a conexão
                new DeviceConnFactoryManager.Build()
                        .setConnMethod(DeviceConnFactoryManager.CONN_METHOD.BLUETOOTH)
                        .setMacAddress(address)
                        .setContext(context)
                        .build();

                // Abre a porta em uma thread separada
                threadPool = ThreadPool.getInstantiation();
                threadPool.addSerialTask(() -> {
                    DeviceConnFactoryManager manager = DeviceConnFactoryManager.getDeviceConnFactoryManagers()
                            .get(address);
                    if (manager != null) {
                        manager.openPort();
                        // Verify connection
                        if (manager.getConnState()) {
                            activity.runOnUiThread(() -> result.success(true));
                            // Explicitly send connected state
                            channel.invokeMethod("connectionState", CONNECTED);
                        } else {
                            activity.runOnUiThread(
                                    () -> result.error("connection_failed", "Failed to establish connection", null));
                            channel.invokeMethod("connectionState", DISCONNECTED);
                        }
                    } else {
                        activity.runOnUiThread(
                                () -> result.error("connection_error", "Connection manager not created", null));
                        channel.invokeMethod("connectionState", DISCONNECTED);
                    }
                });
            } catch (Exception e) {
                result.error("connection_error", "Connection manager not created", null);
                channel.invokeMethod("connectionState", DISCONNECTED);
            }
        } else {
            result.error("invalid_argument", "Argumento 'address' não encontrado", null);
            channel.invokeMethod("connectionState", DISCONNECTED);
        }
    }

    @SuppressLint("MissingPermission")
    private void getCurrentDevice(MethodCall call, Result result) {
        if (curMacAddress == null) {
            result.success(null);
            return;
        }

        try {
            BluetoothDevice device = mBluetoothAdapter.getRemoteDevice(curMacAddress);
            if (device != null) {
                Map<String, Object> deviceInfo = new HashMap<>();
                deviceInfo.put("name", device.getName());
                deviceInfo.put("address", device.getAddress());
                deviceInfo.put("type", device.getType());
                deviceInfo.put("connected", true); // Assumindo que está conectado se chegou aqui
                result.success(deviceInfo);
            } else {
                result.success(null);
            }
        } catch (Exception e) {
            Log.e(TAG, "Erro ao obter dispositivo atual", e);
            result.success(null);
        }
    }

    /**
     * Desconecta da impressora atual
     * 
     * @return Verdadeiro se desconectado com sucesso
     */
    private boolean disconnect() {
        try {
            if (curMacAddress == null) {
                Log.w(TAG, "Nenhum dispositivo conectado para desconectar");
                return true;
            }

            // 1. Obter o gerenciador de conexão
            DeviceConnFactoryManager deviceConnFactoryManager = DeviceConnFactoryManager.getDeviceConnFactoryManagers()
                    .get(curMacAddress);

            // 2. Desconectar se existir
            if (deviceConnFactoryManager != null) {
                // Forçar fechamento da porta
                deviceConnFactoryManager.closePort();

                // Remover do mapa de gerenciadores
                DeviceConnFactoryManager.getDeviceConnFactoryManagers().remove(curMacAddress);
            }

            // 3. Limpar referências
            curMacAddress = null;

            // 4. Parar o thread pool
            if (threadPool != null) {
                threadPool.stopThreadPool();
                threadPool = null;
            }

            return true;
        } catch (Exception e) {
            Log.e(TAG, "Erro ao desconectar: " + e.getMessage());
            return false;
        }
    }

    /**
     * Destrói todas as conexões e recursos
     * 
     * @return Verdadeiro se tudo foi destruído com sucesso
     */
    private boolean destroy() {
        DeviceConnFactoryManager.closeAllPort();

        if (threadPool != null) {
            threadPool.stopThreadPool();
        }

        return true;
    }

    /**
     * Imprime um teste na impressora conectada
     * 
     * @param result Objeto para retornar resultados
     */
    private void printTest(Result result) {
        final DeviceConnFactoryManager deviceConnFactoryManager = DeviceConnFactoryManager
                .getDeviceConnFactoryManagers().get(curMacAddress);

        if (deviceConnFactoryManager == null || !deviceConnFactoryManager.getConnState()) {
            result.error("not_connected", "Impressora não conectada", null);
            return;
        }

        threadPool = ThreadPool.getInstantiation();
        threadPool.addSerialTask(() -> {
            PrinterCommand printerCommand = deviceConnFactoryManager.getCurrentPrinterCommand();

            if (printerCommand == PrinterCommand.ESC) {
                deviceConnFactoryManager.sendByteDataImmediately(
                        FactoryCommand.printSelfTest(FactoryCommand.printerMode.ESC));
            } else if (printerCommand == PrinterCommand.TSC) {
                deviceConnFactoryManager.sendByteDataImmediately(
                        FactoryCommand.printSelfTest(FactoryCommand.printerMode.TSC));
            } else if (printerCommand == PrinterCommand.CPCL) {
                deviceConnFactoryManager.sendByteDataImmediately(
                        FactoryCommand.printSelfTest(FactoryCommand.printerMode.CPCL));
            }
        });
    }

    /**
     * Abre a gaveta de dinheiro da impressora
     * 
     * @param result Objeto para retornar resultados
     */
    private void openCashDrawer(Result result) {
        final DeviceConnFactoryManager deviceConnFactoryManager = DeviceConnFactoryManager
                .getDeviceConnFactoryManagers().get(curMacAddress);

        if (deviceConnFactoryManager == null || !deviceConnFactoryManager.getConnState()) {
            result.error("not_connected", "Impressora não conectada", null);
            return;
        }

        threadPool = ThreadPool.getInstantiation();
        threadPool.addSerialTask(() -> {
            try {
                // Comando ESC/POS para abrir gaveta
                byte[] openDrawerCommand = new byte[] { 0x1B, 0x70, 0x00, (byte) 0xFF, (byte) 0xFF };
                deviceConnFactoryManager.sendByteDataImmediately(openDrawerCommand);
                result.success(true);
            } catch (Exception e) {
                result.error("open_cash_drawer_error", e.getMessage(), null);
            }
        });
    }

    /**
     * Envia dados para impressão
     * 
     * @param call   Chamada recebida
     * @param result Objeto para retornar resultados
     */
    @SuppressWarnings("unchecked")
    private void print(MethodCall call, Result result) {
        Map<String, Object> args = call.arguments();

        final DeviceConnFactoryManager deviceConnFactoryManager = DeviceConnFactoryManager
                .getDeviceConnFactoryManagers().get(curMacAddress);

        if (deviceConnFactoryManager == null || !deviceConnFactoryManager.getConnState()) {
            result.error("not_connected", "Impressora não conectada", null);
            return;
        }

        if (args != null && args.containsKey("config") && args.containsKey("data")) {
            final Map<String, Object> config = (Map<String, Object>) args.get("config");
            final List<Map<String, Object>> list = (List<Map<String, Object>>) args.get("data");

            if (list == null) {
                result.error("invalid_data", "Dados de impressão inválidos", null);
                return;
            }

            threadPool = ThreadPool.getInstantiation();
            threadPool.addSerialTask(() -> {
                try {
                    PrinterCommand printerCommand = deviceConnFactoryManager.getCurrentPrinterCommand();
                    Vector<Byte> data;

                    // Configurar codificação ISO-8859-1 para caracteres acentuados
                    byte[] encodingCommand = new byte[] { 0x1B, 0x74, 0x10 };
                    deviceConnFactoryManager.sendByteDataImmediately(encodingCommand);

                    // Obter os dados no formato apropriado
                    if (printerCommand == PrinterCommand.ESC) {
                        data = PrintContent.mapToReceipt(config, list);
                    } else if (printerCommand == PrinterCommand.TSC) {
                        data = PrintContent.mapToLabel(config, list);
                    } else if (printerCommand == PrinterCommand.CPCL) {
                        data = PrintContent.mapToCPCL(config, list);
                    } else {
                        throw new Exception("Tipo de comando de impressora não suportado");
                    }

                    // Enviar os dados para impressão
                    deviceConnFactoryManager.sendDataImmediately(data);
                    activity.runOnUiThread(() -> result.success(true));

                } catch (Exception e) {
                    Log.e(TAG, "Erro na impressão: " + e.getMessage());
                    activity.runOnUiThread(() -> result.error("print_error", e.getMessage(), null));
                }
            });
        } else {
            result.error("invalid_arguments", "Forneça config e data para impressão", null);
        }
    }

    // Tratamento de permissões
    // =======================

    /**
     * Trata o resultado de solicitações de permissão
     * 
     * @param requestCode  Código da requisição
     * @param permissions  Permissões solicitadas
     * @param grantResults Resultados das permissões
     * @return Verdadeiro se o resultado foi tratado
     */
    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == REQUEST_FINE_LOCATION_PERMISSIONS) {
            if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startScan(pendingCall, pendingResult);
            } else {
                pendingResult.error("no_permissions",
                        "Este plugin requer permissões de localização para escanear", null);
                pendingResult = null;
            }
            return true;
        }
        return false;
    }

    // StreamHandler para estado do Bluetooth
    // =====================================

    private final StreamHandler stateHandler = new StreamHandler() {
        private EventSink sink;
        private BroadcastReceiver mReceiver;

        @Override
        public void onListen(Object o, EventSink eventSink) {
            sink = eventSink;

            mReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    final String action = intent.getAction();
                    Log.d(TAG, "stateStreamHandler, ação atual: " + action);

                    if (BluetoothAdapter.ACTION_STATE_CHANGED.equals(action)) {
                        threadPool = null;
                        int state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1);
                        // Mapeia para os valores que o Dart espera (10, 11, 12, 13)
                        switch (state) {
                            case BluetoothAdapter.STATE_OFF:
                                sink.success(10);
                                break;
                            case BluetoothAdapter.STATE_TURNING_ON:
                                sink.success(11);
                                break;
                            case BluetoothAdapter.STATE_ON:
                                sink.success(12);
                                break;
                            case BluetoothAdapter.STATE_TURNING_OFF:
                                sink.success(13);
                                break;
                            default:
                                sink.success(-1); // unknown
                        }
                    } else if (BluetoothDevice.ACTION_ACL_CONNECTED.equals(action)) {
                        sink.success(1); // CONNECTED
                    } else if (BluetoothDevice.ACTION_ACL_DISCONNECTED.equals(action)) {
                        threadPool = null;
                        sink.success(0); // DISCONNECTED
                    }
                }
            };

            IntentFilter filter = new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED);
            filter.addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED);
            filter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
            filter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
            context.registerReceiver(mReceiver, filter);
            // Envia o estado inicial
            if (mBluetoothAdapter != null) {
                switch (mBluetoothAdapter.getState()) {
                    case BluetoothAdapter.STATE_OFF:
                        sink.success(10);
                        break;
                    case BluetoothAdapter.STATE_TURNING_ON:
                        sink.success(11);
                        break;
                    case BluetoothAdapter.STATE_ON:
                        sink.success(12);
                        break;
                    case BluetoothAdapter.STATE_TURNING_OFF:
                        sink.success(13);
                        break;
                    default:
                        sink.success(-1);
                }
            }
        }

        @Override
        public void onCancel(Object o) {
            if (mReceiver != null) {
                context.unregisterReceiver(mReceiver);
                mReceiver = null;
            }
            sink = null;
        }
    };
}