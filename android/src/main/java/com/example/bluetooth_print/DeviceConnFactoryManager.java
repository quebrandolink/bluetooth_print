package com.example.bluetooth_print;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
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
    private final byte[] esc = {0x10, 0x04, 0x02};

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
    private final byte[] tsc = {0x1b, '!', '?'};

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

    private final byte[] cpcl = {0x1b, 0x68};

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

        deviceConnFactoryManager.isOpenPort = false;
        if (deviceConnFactoryManager.connMethod == CONN_METHOD.BLUETOOTH) {
            mPort = new BluetoothPort(macAddress);
            isOpenPort = deviceConnFactoryManager.mPort.openPort();
        }

        // Se a porta foi aberta com sucesso, verifica o comando usado pela impressora (ESC, TSC)
        if (isOpenPort) {
            queryCommand();
        } else {
            if (this.mPort != null) {
                this.mPort = null;
            }
        }
    }

    /**
     * Consulta o comando usado pela impressora conectada (ESC, TSC)
     */
    private void queryCommand() {
        // Inicia thread para ler dados de retorno da impressora
        reader = new PrinterReader();
        reader.start(); // Thread de leitura de dados
        // Consulta o comando usado pela impressora
        queryPrinterCommand(); // Se a impressora de recibos não conectar, comente esta linha e use o comando ESC
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
        if (this.mPort != null) {
            if (reader != null) {
                reader.cancel();
                reader = null;
            }
            boolean b = this.mPort.closePort();
            if (b) {
                this.mPort = null;
                isOpenPort = false;
                currentPrinterCommand = null;
            }

            Log.e(TAG, "******************* Porta fechada MAC -> " + macAddress);
        }
    }

    public static void closeAllPort() {
        for (DeviceConnFactoryManager deviceConnFactoryManager : deviceConnFactoryManagers.values()) {
            if (deviceConnFactoryManager != null) {
                Log.e(TAG, "******************* Fechando todas as portas MAC -> " + deviceConnFactoryManager.macAddress);

                deviceConnFactoryManager.closePort();
                deviceConnFactoryManagers.put(deviceConnFactoryManager.macAddress, null);
            }
        }
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
                final ScheduledExecutorService scheduledExecutorService = new ScheduledThreadPoolExecutor(1, threadFactoryBuilder);
                scheduledExecutorService.scheduleAtFixedRate(threadFactoryBuilder.newThread(new Runnable() {
                    @Override
                    public void run() {
                        if (currentPrinterCommand == null && queryPrinterCommandFlag > TSC) {
                            if (reader != null) { // Se nenhum comando retornou resposta
                                reader.cancel();
                                mPort.closePort();
                                isOpenPort = false;

                                scheduledExecutorService.shutdown();
                            }
                        }
                        if (currentPrinterCommand != null) {
                            if (!scheduledExecutorService.isShutdown()) {
                                scheduledExecutorService.shutdown();
                            }
                            return;
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
                }), 1500, 1500, TimeUnit.MILLISECONDS);
            }
        });
    }

    class PrinterReader extends Thread {
        private boolean isRun = false;
        private final byte[] buffer = new byte[100];

        public PrinterReader() {
            isRun = true;
        }

        @Override
        public void run() {
            try {
                while (isRun && mPort != null) {
                    // Lê dados de retorno da impressora
                    Log.e(TAG, "******************* Aguardando leitura ");
                    int len = readDataImmediately(buffer);
                    Log.e(TAG, "******************* Lidos " + len + " bytes");
                    if (len > 0) {
                        Message message = Message.obtain();
                        message.what = READ_DATA;
                        Bundle bundle = new Bundle();
                        bundle.putInt(READ_DATA_CNT, len); // Tamanho dos dados
                        bundle.putByteArray(READ_BUFFER_ARRAY, buffer); // Dados
                        message.setData(bundle);
                        mHandler.sendMessage(message);
                    }
                }
            } catch (Exception e) { // Desconexão anormal
                if (deviceConnFactoryManagers.get(macAddress) != null) {
                    closePort();
                    mHandler.obtainMessage(Constant.abnormal_Disconnection).sendToTarget();
                }
            }
        }

        public void cancel() {
            isRun = false;
        }
    }

    @SuppressLint("HandlerLeak")
    private final Handler mHandler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case Constant.abnormal_Disconnection: // Desconexão anormal
                    Log.d(TAG, "******************* Desconexão anormal");
                    sendStateBroadcast(Constant.abnormal_Disconnection);
                    break;
                case DEFAUIT_COMMAND: // Modo padrão
                    break;
                case READ_DATA:
                    int cnt = msg.getData().getInt(READ_DATA_CNT); // Tamanho dos dados > 0
                    byte[] buffer = msg.getData().getByteArray(READ_BUFFER_ARRAY); // Dados
                    // Processa apenas respostas de consulta de status
                    if (buffer == null) {
                        return;
                    }
                    int result = judgeResponseType(buffer[0]); // Desloca os bits
                    String status = "";
                    if (sendCommand == esc) {
                        // Configura modo ESC
                        if (currentPrinterCommand == null) {
                            currentPrinterCommand = PrinterCommand.ESC;
                            sendStateBroadcast(CONN_STATE_CONNECTED);
                        } else { // Consulta status
                            if (result == 0) { // Consulta geral
                                Intent intent = new Intent(ACTION_QUERY_PRINTER_STATE);
                                intent.putExtra(DEVICE_ID, macAddress);
                                if (mContext != null) {
                                    mContext.sendBroadcast(intent);
                                }
                            } else if (result == 1) { // Status em tempo real
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
                    } else if (sendCommand == tsc) {
                        // Configura modo TSC
                        if (currentPrinterCommand == null) {
                            currentPrinterCommand = PrinterCommand.TSC;
                            sendStateBroadcast(CONN_STATE_CONNECTED);
                        } else {
                            if (cnt == 1) { // Status em tempo real
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
                            } else { // Consulta geral
                                Intent intent = new Intent(ACTION_QUERY_PRINTER_STATE);
                                intent.putExtra(DEVICE_ID, macAddress);
                                if (mContext != null) {
                                    mContext.sendBroadcast(intent);
                                }
                            }
                        }
                    } else if (sendCommand == cpcl) {
                        if (currentPrinterCommand == null) {
                            currentPrinterCommand = PrinterCommand.CPCL;
                            sendStateBroadcast(CONN_STATE_CONNECTED);
                        } else {
                            if (cnt == 1) {
                                if ((buffer[0] == CPCL_STATE_PAPER_ERR)) { // Sem papel
                                    status += "******************* Impressora sem papel";
                                }
                                if ((buffer[0] == CPCL_STATE_COVER_OPEN)) { // Tampa aberta
                                    status += "******************* Tampa da impressora aberta";
                                }
                                Log.d(TAG, status);
                            } else { // Consulta geral
                                Intent intent = new Intent(ACTION_QUERY_PRINTER_STATE);
                                intent.putExtra(DEVICE_ID, macAddress);
                                if (mContext != null) {
                                    mContext.sendBroadcast(intent);
                                }
                            }
                        }
                    }
                    break;
                default:
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
