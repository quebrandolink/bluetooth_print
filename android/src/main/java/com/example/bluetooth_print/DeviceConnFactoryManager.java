package com.example.bluetooth_print;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.os.Looper;
import android.util.Log;
import com.gprinter.io.*;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Vector;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.Iterator;
import java.lang.ref.WeakReference;

/**
 * @author thon
 */
public class DeviceConnFactoryManager {
    private static final String TAG = DeviceConnFactoryManager.class.getSimpleName();

    public PortManager mPort;

    public CONN_METHOD connMethod;

    private final String macAddress;

    private final Context mContext;

    private static Map<String, DeviceConnFactoryManager> deviceConnFactoryManagers = new HashMap<>();

    private boolean isOpenPort;
    /**
     * Comando ESC para consultar status em tempo real da impressora
     */
    private final byte[] esc = { 0x10, 0x04, 0x02 };

    /**
     * Status de falta de papel no comando ESC
     */
    private static final int ESC_STATE_PAPER_ERR = 0x20;

    /**
     * Status de tampa aberta no comando ESC
     */
    private static final int ESC_STATE_COVER_OPEN = 0x04;

    /**
     * Status de erro no comando ESC
     */
    private static final int ESC_STATE_ERR_OCCURS = 0x40;

    /**
     * Comando TSC para consultar status da impressora
     */
    private final byte[] tsc = { 0x1b, '!', '?' };

    /**
     * Status de falta de papel no comando TSC
     */
    private static final int TSC_STATE_PAPER_ERR = 0x04;

    /**
     * Status de tampa aberta no comando TSC
     */
    private static final int TSC_STATE_COVER_OPEN = 0x01;

    /**
     * Status de erro no comando TSC
     */
    private static final int TSC_STATE_ERR_OCCURS = 0x80;

    private final byte[] cpcl = { 0x1b, 0x68 };

    /**
     * Status de falta de papel no comando CPCL
     */
    private static final int CPCL_STATE_PAPER_ERR = 0x01;
    /**
     * Status de tampa aberta no comando CPCL
     */
    private static final int CPCL_STATE_COVER_OPEN = 0x02;

    private byte[] sendCommand;

    /**
     * Determina se o comando usado pela impressora é ESC
     */
    private PrinterCommand currentPrinterCommand;
    public static final byte FLAG = 0x10;
    private static final int READ_DATA = 10000;
    private static final int DEFAUIT_COMMAND = 20000;
    private static final String READ_DATA_CNT = "read_data_cnt";
    private static final String READ_BUFFER_ARRAY = "read_buffer_array";
    public static final String ACTION_CONN_STATE = "action_connect_state";
    public static final String ACTION_QUERY_PRINTER_STATE = "action_query_printer_state";
    public static final String STATE = "state";
    public static final String DEVICE_ID = "id";
    public static final int CONN_STATE_DISCONNECT = 0x90;
    public static final int CONN_STATE_CONNECTED = CONN_STATE_DISCONNECT << 3;
    public PrinterReader reader;
    private int queryPrinterCommandFlag;
    private final int ESC = 1;
    private final int TSC = 3;
    private final int CPCL = 2;

    public enum CONN_METHOD {
        // Conexão Bluetooth
        BLUETOOTH("BLUETOOTH"),
        // Conexão USB
        USB("USB"),
        // Conexão WiFi
        WIFI("WIFI"),
        // Conexão serial
        SERIAL_PORT("SERIAL_PORT");

        private final String name;

        private CONN_METHOD(String name) {
            this.name = name;
        }

        @Override
        public String toString() {
            return this.name;
        }
    }

    public static Map<String, DeviceConnFactoryManager> getDeviceConnFactoryManagers() {
        return deviceConnFactoryManagers;
    }

    /**
     * Abre a porta de comunicação
     */
    public void openPort() {
        DeviceConnFactoryManager deviceConnFactoryManager = deviceConnFactoryManagers.get(macAddress);
        if (deviceConnFactoryManager == null) {
            return;
        }

        // Fecha qualquer conexão existente antes de abrir nova
        if (this.mPort != null) {
            this.closePort();
        }

        deviceConnFactoryManager.isOpenPort = false;
        if (deviceConnFactoryManager.connMethod == CONN_METHOD.BLUETOOTH) {
            mPort = new BluetoothPort(macAddress);
            isOpenPort = deviceConnFactoryManager.mPort.openPort();
            // Adicionado verificação extra de conexão real
            if (isOpenPort) {
                // Aguarda um pouco para a conexão se estabilizar
                try {
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                // Verifica novamente o estado da conexão
                isOpenPort = testPrinterConnection();

                if (!isOpenPort) {
                    isOpenPort = false;
                    if (this.mPort != null) {
                        this.mPort.closePort();
                        this.mPort = null;
                    }
                    return;
                }
                // Inicia a thread de leitura
                queryCommand();
            } else {
                Log.e(TAG, "Falha ao abrir porta Bluetooth");
                if (this.mPort != null) {
                    this.mPort.closePort();
                    this.mPort = null;
                }
            }
        }

    }

    /**
     * Novo método para testar a comunicação com a impressora
     */
    private boolean testPrinterConnection() {
        try {
            // Comando simples de inicialização
            byte[] initCommand = { 0x1B, 0x40 }; // ESC @ - Initialize printer
            Vector<Byte> data = new Vector<>();
            for (byte b : initCommand) {
                data.add(b);
            }

            // Tenta enviar e receber resposta
            this.mPort.writeDataImmediately(data, 0, data.size());

            // Buffer para resposta
            byte[] response = new byte[10];
            int totalWaitTime = 3000; // 3 segundos no total
            int interval = 200; // Verifica a cada 200ms
            int attempts = totalWaitTime / interval;

            for (int i = 0; i < attempts; i++) {
                int len = this.mPort.readData(response);
                if (len > 0) {
                    return true; // Resposta recebida
                }
                Thread.sleep(interval);
            }
            return false; // Timeout
        } catch (Exception e) {
            Log.e(TAG, "Erro ao testar conexão com impressora", e);
            return false;
        }
    }

    /**
     * Consulta o comando usado pela impressora conectada (ESC, TSC)
     */
    private void queryCommand() {
        // Inicia thread para ler dados de retorno da impressora
        reader = new PrinterReader();
        reader.start(); // Thread de leitura de dados
        // Envia broadcast indicando que está tentando conectar (não conectado ainda)
        sendStateBroadcast(CONN_STATE_DISCONNECT);
        // Consulta o comando usado pela impressora
        queryPrinterCommand(); // Se a impressora de recibos não conectar, comente esta linha e use o comando
                               // ESC
    }

    /**
     * Obtém o método de conexão
     */
    public CONN_METHOD getConnMethod() {
        return connMethod;
    }

    /**
     * Obtém o status da porta (true = aberta, false = fechada)
     */
    public boolean getConnState() {
        return isOpenPort;
    }

    /**
     * Obtém o endereço MAC Bluetooth
     */
    public String getMacAddress() {
        return macAddress;
    }

    /**
     * Fecha a porta de comunicação
     */
    public void closePort() {
        Log.d(TAG, "Iniciando fechamento de porta para " + macAddress);
        try {
            // 1. Cancela a thread de leitura
            if (this.reader != null) {
                Log.d(TAG, "Interrompendo thread Reader para " + macAddress);
                this.reader.cancel();
                try {
                    this.reader.join(1000); // Espera até 1000ms
                    Log.d(TAG, "Thread Reader interrompida com sucesso para " + macAddress);
                } catch (InterruptedException e) {
                    Log.e(TAG, "Erro ao aguardar thread Reader para " + macAddress, e);
                    Thread.currentThread().interrupt();
                }
                this.reader = null;
            }

            // 2. Fecha a porta de comunicação
            if (this.mPort != null) {
                Log.d(TAG, "Fechando porta física para " + macAddress);
                // Envia comando de reset se ainda estiver conectado
                try {
                    byte[] resetCmd = { 0x1B, 0x40 }; // Comando ESC/@
                    Vector<Byte> data = new Vector<>();
                    for (byte b : resetCmd) {
                        data.add(b);
                    }
                    this.mPort.writeDataImmediately(data, 0, data.size());
                    Thread.sleep(300); // Pequena pausa para o comando ser processado
                } catch (Exception e) {
                    Log.w(TAG, "Erro ao enviar comando de reset para " + macAddress, e);
                }

                // Fecha a porta
                this.mPort.closePort();
                this.mPort = null;
                Log.d(TAG, "Porta física fechada para " + macAddress);
            }

            // 3. Atualiza estados
            isOpenPort = false;
            currentPrinterCommand = null;

            // 4. Notifica desconexão
            sendStateBroadcast(CONN_STATE_DISCONNECT);

            Log.i(TAG, "Porta completamente fechada: " + macAddress);
        } catch (Exception e) {
            Log.e(TAG, "Erro ao fechar porta para " + macAddress, e);
        }
    }

    public static void closeAllPort() {
        // Usar um iterador para remover de forma segura enquanto itera
        Iterator<Map.Entry<String, DeviceConnFactoryManager>> iterator = deviceConnFactoryManagers.entrySet()
                .iterator();
        while (iterator.hasNext()) {
            Map.Entry<String, DeviceConnFactoryManager> entry = iterator.next();
            DeviceConnFactoryManager manager = entry.getValue();
            if (manager != null) {
                Log.e(TAG, "******************* Fechando porta MAC -> " + manager.macAddress);
                manager.closePort();
            }
            iterator.remove(); // Remove a entrada do mapa
        }
    }

    /**
     * Verifica o estado da thread PrinterReader
     */
    public boolean isReaderThreadActive() {
        return reader != null && reader.isAliveAndRunning();
    }

    /**
     * Loga o estado atual da conexão e threads
     */
    public void logConnectionState() {
        Log.d(TAG, "Estado da conexão para " + macAddress +
                "\nPorta aberta: " + isOpenPort +
                "\nThread Reader ativa: " + (reader != null ? reader.isAliveAndRunning() : "null") +
                "\nComando atual: " + currentPrinterCommand);
    }

    private DeviceConnFactoryManager(Build build) {
        this.connMethod = build.connMethod;
        this.macAddress = build.macAddress;
        this.mContext = build.context;
        deviceConnFactoryManagers.put(build.macAddress, this);
    }

    /**
     * Obtém o comando atual da impressora
     *
     * @return PrinterCommand
     */
    public PrinterCommand getCurrentPrinterCommand() {
        return Objects.requireNonNull(deviceConnFactoryManagers.get(macAddress)).currentPrinterCommand;
    }

    public static final class Build {
        private String macAddress;
        private CONN_METHOD connMethod;
        private Context context;

        public DeviceConnFactoryManager.Build setMacAddress(String macAddress) {
            this.macAddress = macAddress;
            return this;
        }

        public DeviceConnFactoryManager.Build setConnMethod(CONN_METHOD connMethod) {
            this.connMethod = connMethod;
            return this;
        }

        public DeviceConnFactoryManager.Build setContext(Context context) {
            this.context = context;
            return this;
        }

        public DeviceConnFactoryManager build() {
            return new DeviceConnFactoryManager(this);
        }
    }

    public void sendDataImmediately(final Vector<Byte> data) {
        if (this.mPort == null) {
            return;
        }
        try {
            this.mPort.writeDataImmediately(data, 0, data.size());
        } catch (Exception e) { // Erro no envio
            mHandler.obtainMessage(Constant.abnormal_Disconnection).sendToTarget();
        }
    }

    public void sendByteDataImmediately(final byte[] data) {
        if (this.mPort != null) {
            Vector<Byte> datas = new Vector<Byte>();
            for (byte datum : data) {
                datas.add(Byte.valueOf(datum));
            }
            try {
                this.mPort.writeDataImmediately(datas, 0, datas.size());
            } catch (IOException e) { // Erro na comunicação
                mHandler.obtainMessage(Constant.abnormal_Disconnection).sendToTarget();
            }
        }
    }

    public int readDataImmediately(byte[] buffer) {
        int r = 0;
        if (this.mPort == null) {
            return r;
        }

        try {
            r = this.mPort.readData(buffer);
        } catch (IOException e) {
            closePort();
        }

        return r;
    }

    /**
     * Consulta o comando usado pela impressora (ESC, CPCL, TSC)
     */
    private void queryPrinterCommand() {
        queryPrinterCommandFlag = ESC;
        ThreadPool.getInstantiation().addSerialTask(new Runnable() {
            @Override
            public void run() {
                // Inicia timer para enviar comando de consulta se não houver resposta
                final ThreadFactoryBuilder threadFactoryBuilder = new ThreadFactoryBuilder("Timer");
                final ScheduledExecutorService scheduledExecutorService = new ScheduledThreadPoolExecutor(1,
                        threadFactoryBuilder);

                // Adicionado contador de tentativas
                final int[] attempts = { 0 };
                final int maxAttempts = 3; // Número máximo de tentativas por protocolo

                scheduledExecutorService.scheduleAtFixedRate(threadFactoryBuilder.newThread(new Runnable() {
                    @Override
                    public void run() {
                        // Se já identificou o protocolo, encerra

                        if (currentPrinterCommand != null) {
                            if (!scheduledExecutorService.isShutdown()) {
                                scheduledExecutorService.shutdown();
                            }
                            return;
                        }
                        // Se excedeu todas as tentativas sem resposta
                        if (queryPrinterCommandFlag > TSC && attempts[0] >= maxAttempts) {
                            Log.w(TAG, "Não foi possível detectar o protocolo - Usando ESC como padrão");
                            currentPrinterCommand = PrinterCommand.ESC; // Fallback para ESC
                            sendStateBroadcast(CONN_STATE_CONNECTED);
                            scheduledExecutorService.shutdown();
                            return;
                        }
                        // Reinicia contador quando muda de protocolo
                        if (queryPrinterCommandFlag <= TSC && attempts[0] >= maxAttempts) {
                            queryPrinterCommandFlag++;
                            attempts[0] = 0;
                        }

                        if (currentPrinterCommand == null && queryPrinterCommandFlag > TSC) {
                            if (reader != null) { // Se nenhum comando retornou resposta
                                reader.cancel();
                                mPort.closePort();
                                isOpenPort = false;

                                scheduledExecutorService.shutdown();
                            }
                        }
                        switch (queryPrinterCommandFlag) {
                            case ESC:
                                // Envia comando ESC de consulta de status
                                sendCommand = esc;
                                break;
                            case TSC:
                                // Envia comando TSC de consulta de status
                                sendCommand = tsc;
                                break;
                            case CPCL:
                                // Envia comando CPCL de consulta de status
                                sendCommand = cpcl;
                                break;
                            default:
                                break;
                        }
                        Vector<Byte> data = new Vector<>(sendCommand.length);
                        for (byte b : sendCommand) {
                            data.add(b);
                        }
                        sendDataImmediately(data);
                        queryPrinterCommandFlag++;
                    }
                }), 0, 1500, TimeUnit.MILLISECONDS);
            }
        });
    }

    class PrinterReader extends Thread {
        private volatile boolean isRunning = true;
        private final byte[] buffer = new byte[100];
        private long lastDataReceivedTime = 0;
        private static final long CONNECTION_TIMEOUT = 5000; // 5 segundos

        // Adicionando logs para monitoramento
        public PrinterReader() {
            super("PrinterReader-" + macAddress);
            Log.d(TAG, "Criando PrinterReader para " + macAddress);
        }

        @Override
        public void run() {
            Log.d(TAG, "PrinterReader iniciada para " + macAddress);
            try {
                lastDataReceivedTime = System.currentTimeMillis();
                while (isRunning && mPort != null) {
                    // Verifica timeout de conexão
                    if (System.currentTimeMillis() - lastDataReceivedTime > CONNECTION_TIMEOUT) {
                        Log.e(TAG, "Timeout de comunicação com a impressora " + macAddress);
                        mHandler.obtainMessage(Constant.abnormal_Disconnection).sendToTarget();
                        break;
                    }
                    // Lê dados de retorno da impressora
                    int len = readDataImmediately(buffer);
                    if (len > 0) {
                        lastDataReceivedTime = System.currentTimeMillis();
                        Message message = Message.obtain();
                        message.what = READ_DATA;
                        Bundle bundle = new Bundle();
                        bundle.putInt(READ_DATA_CNT, len); // Tamanho dos dados
                        bundle.putByteArray(READ_BUFFER_ARRAY, buffer); // Dados
                        message.setData(bundle);
                        mHandler.sendMessage(message);
                        Log.v(TAG, "Dados recebidos da impressora " + macAddress + ": " + len + " bytes");
                    }
                    // Pequena pausa para evitar busy-waiting
                    Thread.sleep(50);
                }
            } catch (Exception e) { // Desconexão anormal
                Log.e(TAG, "Erro na PrinterReader para " + macAddress, e);
                if (deviceConnFactoryManagers.get(macAddress) != null) {
                    closePort();
                    mHandler.obtainMessage(Constant.abnormal_Disconnection).sendToTarget();
                }
            } finally {
                Log.d(TAG, "PrinterReader finalizada para " + macAddress);
            }
        }

        public void cancel() {
            Log.d(TAG, "Cancelando PrinterReader para " + macAddress);
            isRunning = false;
            interrupt(); // Garante que a thread saia do sleep
        }

        // Método para verificar se a thread está ativa
        public boolean isAliveAndRunning() {
            return isRunning && isAlive();
        }
    }

    // Substitua o Handler existente por esta implementação corrigida
    private final Handler mHandler = new Handler(Looper.getMainLooper()) {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case Constant.abnormal_Disconnection:
                    Log.d(TAG, "******************* Desconexão anormal");
                    // Usar a instância atual para chamar sendStateBroadcast
                    DeviceConnFactoryManager.this.sendStateBroadcast(Constant.abnormal_Disconnection);
                    break;

                case DEFAUIT_COMMAND:
                    break;

                case READ_DATA:
                    int cnt = msg.getData().getInt(READ_DATA_CNT);
                    byte[] buffer = msg.getData().getByteArray(READ_BUFFER_ARRAY);

                    if (buffer == null) {
                        return;
                    }

                    // Usar a instância atual para chamar judgeResponseType
                    int result = DeviceConnFactoryManager.this.judgeResponseType(buffer[0]);
                    String status = "";

                    // Verificar usando a instância atual
                    if (DeviceConnFactoryManager.this.sendCommand == DeviceConnFactoryManager.this.esc) {
                        if (DeviceConnFactoryManager.this.currentPrinterCommand == null) {
                            DeviceConnFactoryManager.this.currentPrinterCommand = PrinterCommand.ESC;
                            DeviceConnFactoryManager.this.sendStateBroadcast(CONN_STATE_CONNECTED);
                        } else {
                            if (result == 0) {
                                Intent intent = new Intent(ACTION_QUERY_PRINTER_STATE);
                                intent.putExtra(DEVICE_ID, DeviceConnFactoryManager.this.macAddress);
                                if (DeviceConnFactoryManager.this.mContext != null) {
                                    DeviceConnFactoryManager.this.mContext.sendBroadcast(intent);
                                }
                            } else if (result == 1) {
                                if ((buffer[0] & ESC_STATE_PAPER_ERR) > 0) {
                                    status += "******************* Impressora sem papel";
                                }
                                if ((buffer[0] & ESC_STATE_COVER_OPEN) > 0) {
                                    status += "******************* Tampa da impressora aberta";
                                }
                                if ((buffer[0] & ESC_STATE_ERR_OCCURS) > 0) {
                                    status += "******************* Erro na impressora";
                                }
                                Log.d(TAG, status);
                            }
                        }
                    } else if (DeviceConnFactoryManager.this.sendCommand == DeviceConnFactoryManager.this.tsc) {
                        if (DeviceConnFactoryManager.this.currentPrinterCommand == null) {
                            DeviceConnFactoryManager.this.currentPrinterCommand = PrinterCommand.TSC;
                            DeviceConnFactoryManager.this.sendStateBroadcast(CONN_STATE_CONNECTED);
                        } else {
                            if (cnt == 1) {
                                if ((buffer[0] & TSC_STATE_PAPER_ERR) > 0) {
                                    status += "******************* Impressora sem papel";
                                }
                                if ((buffer[0] & TSC_STATE_COVER_OPEN) > 0) {
                                    status += "******************* Tampa da impressora aberta";
                                }
                                if ((buffer[0] & TSC_STATE_ERR_OCCURS) > 0) {
                                    status += "******************* Erro na impressora";
                                }
                                Log.d(TAG, status);
                            } else {
                                Intent intent = new Intent(ACTION_QUERY_PRINTER_STATE);
                                intent.putExtra(DEVICE_ID, DeviceConnFactoryManager.this.macAddress);
                                if (DeviceConnFactoryManager.this.mContext != null) {
                                    DeviceConnFactoryManager.this.mContext.sendBroadcast(intent);
                                }
                            }
                        }
                    } else if (DeviceConnFactoryManager.this.sendCommand == DeviceConnFactoryManager.this.cpcl) {
                        if (DeviceConnFactoryManager.this.currentPrinterCommand == null) {
                            DeviceConnFactoryManager.this.currentPrinterCommand = PrinterCommand.CPCL;
                            DeviceConnFactoryManager.this.sendStateBroadcast(CONN_STATE_CONNECTED);
                        } else {
                            if (cnt == 1) {
                                if ((buffer[0] == CPCL_STATE_PAPER_ERR)) {
                                    status += "******************* Impressora sem papel";
                                }
                                if ((buffer[0] == CPCL_STATE_COVER_OPEN)) {
                                    status += "******************* Tampa da impressora aberta";
                                }
                                Log.d(TAG, status);
                            } else {
                                Intent intent = new Intent(ACTION_QUERY_PRINTER_STATE);
                                intent.putExtra(DEVICE_ID, DeviceConnFactoryManager.this.macAddress);
                                if (DeviceConnFactoryManager.this.mContext != null) {
                                    DeviceConnFactoryManager.this.mContext.sendBroadcast(intent);
                                }
                            }
                        }
                    }
                    break;
            }
        }
    };

    /**
     * Envia broadcast com o status
     */
    private void sendStateBroadcast(int state) {
        Intent intent = new Intent(ACTION_CONN_STATE);
        intent.putExtra(STATE, state);
        intent.putExtra(DEVICE_ID, macAddress);
        if (mContext != null) {
            mContext.sendBroadcast(intent);
        }
    }

    /**
     * Determina se a resposta é status em tempo real ou consulta geral
     */
    private int judgeResponseType(byte r) {
        return (byte) ((r & FLAG) >> 4);
    }
}
