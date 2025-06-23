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
 * Classe responsável por gerenciar a conexão com dispositivos de impressão via
 * Bluetooth.
 * Fornece métodos para abrir/fechar conexões, enviar comandos e verificar o
 * status da impressora.
 * 
 * @author thon
 */
public class DeviceConnFactoryManager {
    private static final String TAG = DeviceConnFactoryManager.class.getSimpleName();

    // Gerenciador de portas de comunicação
    public PortManager mPort;

    // Método de conexão utilizado (Bluetooth, USB, WiFi, etc)
    public CONN_METHOD connMethod;

    // Endereço MAC do dispositivo Bluetooth
    private final String macAddress;

    // Contexto da aplicação
    private final Context mContext;

    // Mapa para armazenar múltiplas instâncias de gerenciadores de conexão
    private static Map<String, DeviceConnFactoryManager> deviceConnFactoryManagers = new HashMap<>();

    // Flag que indica se a porta está aberta
    private boolean isOpenPort;

    /**
     * Comando ESC para consultar o status em tempo real da impressora
     */
    private final byte[] esc = { 0x10, 0x04, 0x02 };

    /**
     * Status de erro de papel (ESC)
     */
    private static final int ESC_STATE_PAPER_ERR = 0x20;

    /**
     * Status de tampa aberta (ESC)
     */
    private static final int ESC_STATE_COVER_OPEN = 0x04;

    /**
     * Status de erro na impressora (ESC)
     */
    private static final int ESC_STATE_ERR_OCCURS = 0x40;

    /**
     * Comando TSC para consultar o status da impressora
     */
    private final byte[] tsc = { 0x1b, '!', '?' };

    /**
     * Status de erro de papel (TSC)
     */
    private static final int TSC_STATE_PAPER_ERR = 0x04;

    /**
     * Status de tampa aberta (TSC)
     */
    private static final int TSC_STATE_COVER_OPEN = 0x01;

    /**
     * Status de erro na impressora (TSC)
     */
    private static final int TSC_STATE_ERR_OCCURS = 0x80;

    /**
     * Comando CPCL para consultar o status da impressora
     */
    private final byte[] cpcl = { 0x1b, 0x68 };

    /**
     * Status de erro de papel (CPCL)
     */
    private static final int CPCL_STATE_PAPER_ERR = 0x01;

    /**
     * Status de tampa aberta (CPCL)
     */
    private static final int CPCL_STATE_COVER_OPEN = 0x02;

    // Comando que será enviado para a impressora
    private byte[] sendCommand;

    /**
     * Comando atual da impressora (ESC, TSC, CPCL)
     */
    private PrinterCommand currentPrinterCommand;

    // Constantes diversas
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

    // Thread para leitura de dados da impressora
    public PrinterReader reader;

    // Flag para controle do comando de consulta
    private int queryPrinterCommandFlag;

    // Constantes para tipos de comandos
    private final int ESC = 1;
    private final int TSC = 3;
    private final int CPCL = 2;

    /**
     * Enumeração dos métodos de conexão disponíveis
     */
    public enum CONN_METHOD {
        // Conexão Bluetooth
        BLUETOOTH("BLUETOOTH"),
        // Conexão USB
        USB("USB"),
        // Conexão WiFi
        WIFI("WIFI"),
        // Conexão por porta serial
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

    /**
     * Retorna o mapa de gerenciadores de conexão
     * 
     * @return Mapa com os gerenciadores de conexão
     */
    public static Map<String, DeviceConnFactoryManager> getDeviceConnFactoryManagers() {
        return deviceConnFactoryManagers;
    }

    /**
     * Abre a porta de comunicação com a impressora
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

        // Se a porta foi aberta com sucesso, verifica o comando da impressora
        if (isOpenPort) {
            queryCommand();
        } else {
            if (this.mPort != null) {
                this.mPort = null;
            }
        }
    }

    /**
     * Consulta o comando atual utilizado pela impressora (ESC, TSC, CPCL)
     */
    private void queryCommand() {
        // Inicia a thread de leitura dos dados de retorno
        reader = new PrinterReader();
        reader.start();
        // Consulta o comando da impressora
        queryPrinterCommand();
    }

    /**
     * Retorna o método de conexão utilizado
     * 
     * @return Método de conexão (BLUETOOTH, USB, etc)
     */
    public CONN_METHOD getConnMethod() {
        return connMethod;
    }

    /**
     * Verifica o estado da conexão
     * 
     * @return true se a porta está aberta, false caso contrário
     */
    public boolean getConnState() {
        return isOpenPort;
    }

    /**
     * Retorna o endereço MAC do dispositivo Bluetooth
     * 
     * @return Endereço MAC
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

            Log.e(TAG, "******************* Porta fechada - MAC: " + macAddress);
        }
    }

    /**
     * Fecha todas as portas de comunicação abertas
     */
    public static void closeAllPort() {
        for (DeviceConnFactoryManager deviceConnFactoryManager : deviceConnFactoryManagers.values()) {
            if (deviceConnFactoryManager != null) {
                Log.e(TAG,
                        "******************* Fechando todas as portas - MAC: " + deviceConnFactoryManager.macAddress);

                deviceConnFactoryManager.closePort();
                deviceConnFactoryManagers.put(deviceConnFactoryManager.macAddress, null);
            }
        }
    }

    /**
     * Construtor privado (padrão Builder)
     */
    private DeviceConnFactoryManager(Build build) {
        this.connMethod = build.connMethod;
        this.macAddress = build.macAddress;
        this.mContext = build.context;
        deviceConnFactoryManagers.put(build.macAddress, this);
    }

    /**
     * Retorna o comando atual da impressora
     * 
     * @return Comando da impressora (ESC, TSC, CPCL)
     */
    public PrinterCommand getCurrentPrinterCommand() {
        return Objects.requireNonNull(deviceConnFactoryManagers.get(macAddress)).currentPrinterCommand;
    }

    /**
     * Classe Builder para construção do DeviceConnFactoryManager
     */
    public static final class Build {
        private String macAddress;
        private CONN_METHOD connMethod;
        private Context context;

        /**
         * Define o endereço MAC do dispositivo
         * 
         * @param macAddress Endereço MAC
         * @return Instância do Builder
         */
        public DeviceConnFactoryManager.Build setMacAddress(String macAddress) {
            this.macAddress = macAddress;
            return this;
        }

        /**
         * Define o método de conexão
         * 
         * @param connMethod Método de conexão
         * @return Instância do Builder
         */
        public DeviceConnFactoryManager.Build setConnMethod(CONN_METHOD connMethod) {
            this.connMethod = connMethod;
            return this;
        }

        /**
         * Define o contexto da aplicação
         * 
         * @param context Contexto
         * @return Instância do Builder
         */
        public DeviceConnFactoryManager.Build setContext(Context context) {
            this.context = context;
            return this;
        }

        /**
         * Constrói a instância do DeviceConnFactoryManager
         * 
         * @return Instância configurada
         */
        public DeviceConnFactoryManager build() {
            return new DeviceConnFactoryManager(this);
        }
    }

    /**
     * Envia dados imediatamente para a impressora
     * 
     * @param data Dados a serem enviados (vetor de bytes)
     */
    public void sendDataImmediately(final Vector<Byte> data) {
        if (this.mPort == null) {
            return;
        }
        try {
            this.mPort.writeDataImmediately(data, 0, data.size());
        } catch (Exception e) {
            // Notifica desconexão anormal
            mHandler.obtainMessage(Constant.abnormal_Disconnection).sendToTarget();
        }
    }

    /**
     * Envia um array de bytes imediatamente para a impressora
     * 
     * @param data Array de bytes a ser enviado
     */
    public void sendByteDataImmediately(final byte[] data) {
        if (this.mPort != null) {
            Vector<Byte> datas = new Vector<Byte>();
            for (byte datum : data) {
                datas.add(Byte.valueOf(datum));
            }
            try {
                this.mPort.writeDataImmediately(datas, 0, datas.size());
            } catch (IOException e) {
                // Notifica desconexão anormal
                mHandler.obtainMessage(Constant.abnormal_Disconnection).sendToTarget();
            }
        }
    }

    /**
     * Lê dados imediatamente da impressora
     * 
     * @param buffer Buffer para armazenar os dados lidos
     * @return Número de bytes lidos
     */
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
     * Consulta o comando atual da impressora (ESC, CPCL, TSC)
     */
    private void queryPrinterCommand() {
        queryPrinterCommandFlag = ESC;
        ThreadPool.getInstantiation().addSerialTask(new Runnable() {
            @Override
            public void run() {
                // Agenda uma tarefa periódica para enviar comandos de consulta
                final ThreadFactoryBuilder threadFactoryBuilder = new ThreadFactoryBuilder("Timer");
                final ScheduledExecutorService scheduledExecutorService = new ScheduledThreadPoolExecutor(1,
                        threadFactoryBuilder);
                scheduledExecutorService.scheduleAtFixedRate(threadFactoryBuilder.newThread(new Runnable() {
                    @Override
                    public void run() {
                        if (currentPrinterCommand == null && queryPrinterCommandFlag > TSC) {
                            if (reader != null) {
                                // Se não houve resposta após tentar todos os comandos, fecha a conexão
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
                                sendCommand = esc;
                                break;
                            case TSC:
                                sendCommand = tsc;
                                break;
                            case CPCL:
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

    /**
     * Thread para leitura contínua de dados da impressora
     */
    class PrinterReader extends Thread {
        private boolean isRun = false;
        private final byte[] buffer = new byte[100];

        /**
         * Construtor - inicia a thread em modo executável
         */
        public PrinterReader() {
            isRun = true;
        }

        @Override
        public void run() {
            try {
                while (isRun && mPort != null) {
                    // Lê dados da impressora (bloqueante)
                    Log.e(TAG, "******************* Aguardando leitura ");
                    int len = readDataImmediately(buffer);
                    Log.e(TAG, "******************* Dados lidos: " + len);
                    if (len > 0) {
                        // Envia mensagem com os dados lidos para o handler
                        Message message = Message.obtain();
                        message.what = READ_DATA;
                        Bundle bundle = new Bundle();
                        bundle.putInt(READ_DATA_CNT, len);
                        bundle.putByteArray(READ_BUFFER_ARRAY, buffer);
                        message.setData(bundle);
                        mHandler.sendMessage(message);
                    }
                }
            } catch (Exception e) {
                // Em caso de erro, fecha a conexão
                if (deviceConnFactoryManagers.get(macAddress) != null) {
                    closePort();
                    mHandler.obtainMessage(Constant.abnormal_Disconnection).sendToTarget();
                }
            }
        }

        /**
         * Cancela a execução da thread
         */
        public void cancel() {
            isRun = false;
        }
    }

    /**
     * Handler para processar mensagens e eventos da impressora
     */
    @SuppressLint("HandlerLeak")
    private final Handler mHandler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case Constant.abnormal_Disconnection:
                    Log.d(TAG, "******************* Desconexão anormal");
                    sendStateBroadcast(Constant.abnormal_Disconnection);
                    break;
                case DEFAUIT_COMMAND:
                    // Modo padrão (não implementado)
                    break;
                case READ_DATA:
                    int cnt = msg.getData().getInt(READ_DATA_CNT);
                    byte[] buffer = msg.getData().getByteArray(READ_BUFFER_ARRAY);
                    if (buffer == null) {
                        return;
                    }
                    int result = judgeResponseType(buffer[0]);
                    String status = "";
                    if (sendCommand == esc) {
                        if (currentPrinterCommand == null) {
                            currentPrinterCommand = PrinterCommand.ESC;
                            sendStateBroadcast(CONN_STATE_CONNECTED);
                        } else {
                            if (result == 0) {
                                // Broadcast com status da impressora
                                Intent intent = new Intent(ACTION_QUERY_PRINTER_STATE);
                                intent.putExtra(DEVICE_ID, macAddress);
                                if (mContext != null) {
                                    mContext.sendBroadcast(intent);
                                }
                            } else if (result == 1) {
                                // Interpreta os status da impressora
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
                        if (currentPrinterCommand == null) {
                            currentPrinterCommand = PrinterCommand.TSC;
                            sendStateBroadcast(CONN_STATE_CONNECTED);
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
                                if ((buffer[0] == CPCL_STATE_PAPER_ERR)) {
                                    status += "******************* Impressora sem papel";
                                }
                                if ((buffer[0] == CPCL_STATE_COVER_OPEN)) {
                                    status += "******************* Tampa da impressora aberta";
                                }
                                Log.d(TAG, status);
                            } else {
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
     * Envia um broadcast com o estado da conexão
     * 
     * @param state Estado da conexão
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
     * Determina se a resposta é um status em tempo real ou uma consulta
     * 
     * @param r Byte de resposta
     * @return 0 para consulta, 1 para status em tempo real
     */
    private int judgeResponseType(byte r) {
        return (byte) ((r & FLAG) >> 4);
    }
}