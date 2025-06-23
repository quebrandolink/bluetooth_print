package com.example.bluetooth_print;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Base64;
import android.util.Log;
import com.gprinter.command.CpclCommand;
import com.gprinter.command.EscCommand;
import com.gprinter.command.LabelCommand;

import java.util.List;
import java.util.Map;
import java.util.Vector;
import java.io.UnsupportedEncodingException;

/**
 * Classe responsável por converter dados em comandos de impressão para
 * diferentes tipos de impressoras
 * (térmica, etiquetas e CPCL). Transforma estruturas de dados em comandos
 * específicos para cada protocolo.
 * 
 * @author thon
 */
public class PrintContent {
      private static final String TAG = PrintContent.class.getSimpleName();

      /**
       * Converte um mapa de dados em comandos ESC/POS para impressão de recibos
       * 
       * @param config Configurações gerais da impressão
       * @param list   Lista de elementos a serem impressos (texto, códigos de barras,
       *               etc)
       * @return Vetor de bytes com os comandos para a impressora
       */
      public static Vector<Byte> mapToReceipt(Map<String, Object> config, List<Map<String, Object>> list) {
            EscCommand esc = new EscCommand();
            // Configura codificação para Português (PC860)
            Vector<Byte> encodingCommand = new Vector<>();
            encodingCommand.add((byte) 0x1B); // ESC
            encodingCommand.add((byte) 0x74); // t
            encodingCommand.add((byte) 0x10); // 10 = PC860 Portuguese
            esc.getCommand().addAll(encodingCommand);

            // Inicializa a impressora
            esc.addInitializePrinter();
            // Avança o papel
            esc.addPrintAndFeedLines((byte) 1);

            // Estrutura dos elementos:
            // {type:'text|barcode|qrcode|image', content:'', size:4, align: 0|1|2, weight:
            // 0|1, width:0|1, height:0|1, underline:0|1, linefeed: 0|1}
            for (Map<String, Object> m : list) {
                  String type = (String) m.get("type");
                  String content = (String) m.get("content");
                  int align = (int) (m.get("align") == null ? 0 : m.get("align"));
                  int size = (int) (m.get("size") == null ? 3 : m.get("size"));
                  int weight = (int) (m.get("weight") == null ? 0 : m.get("weight"));
                  int width = (int) (m.get("width") == null ? 0 : m.get("width"));
                  int height = (int) (m.get("height") == null ? 0 : m.get("height"));
                  int underline = (int) (m.get("underline") == null ? 0 : m.get("underline"));
                  int linefeed = (int) (m.get("linefeed") == null ? 0 : m.get("linefeed"));

                  // Configurações de formatação
                  EscCommand.ENABLE emphasized = weight == 0 ? EscCommand.ENABLE.OFF : EscCommand.ENABLE.ON;
                  EscCommand.ENABLE doublewidth = width == 0 ? EscCommand.ENABLE.OFF : EscCommand.ENABLE.ON;
                  EscCommand.ENABLE doubleheight = height == 0 ? EscCommand.ENABLE.OFF : EscCommand.ENABLE.ON;
                  EscCommand.ENABLE isUnderline = underline == 0 ? EscCommand.ENABLE.OFF : EscCommand.ENABLE.ON;

                  // Alinhamento do texto
                  esc.addSelectJustification(align == 0 ? EscCommand.JUSTIFICATION.LEFT
                              : (align == 1 ? EscCommand.JUSTIFICATION.CENTER : EscCommand.JUSTIFICATION.RIGHT));

                  if ("text".equals(type)) {
                        try {
                              // Converte para ISO-8859-1 para suportar caracteres portugueses
                              byte[] textBytes = content.getBytes("ISO-8859-1");
                              String encodedContent = new String(textBytes, "ISO-8859-1");

                              // Posicionamento absoluto/relativo
                              int absolutePos = (int) (m.get("absolutePos") == null ? 0 : m.get("absolutePos"));
                              int relativePos = (int) (m.get("relativePos") == null ? 0 : m.get("relativePos"));
                              int fontZoom = (int) (m.get("fontZoom") == null ? 1 : m.get("fontZoom"));
                              short aPos = (short) absolutePos;
                              short rPos = (short) relativePos;
                              Log.e(TAG, "Posicionamento absoluto: " + aPos + ", relativo: " + rPos + ", zoom: "
                                          + fontZoom);

                              // Define posições e formatação
                              esc.addSetAbsolutePrintPosition(aPos);
                              esc.addSetRelativePrintPositon(rPos);
                              esc.addSelectPrintModes(EscCommand.FONT.FONTA, emphasized, doubleheight, doublewidth,
                                          isUnderline);

                              // Aplica zoom se necessário
                              if (fontZoom > 1) {
                                    esc.addSetKanjiFontMode(EscCommand.ENABLE.ON, EscCommand.ENABLE.ON,
                                                EscCommand.ENABLE.OFF);
                              } else {
                                    esc.addSetKanjiFontMode(EscCommand.ENABLE.OFF, EscCommand.ENABLE.OFF,
                                                EscCommand.ENABLE.OFF);
                              }

                              esc.addText(content);
                              // Restaura formatação padrão
                              esc.addSelectPrintModes(EscCommand.FONT.FONTA, EscCommand.ENABLE.OFF,
                                          EscCommand.ENABLE.OFF, EscCommand.ENABLE.OFF, EscCommand.ENABLE.OFF);

                        } catch (UnsupportedEncodingException e) {
                              Log.e(TAG, "Erro na codificação: " + e.getMessage());
                              esc.addText(content); // Fallback para codificação padrão
                        }

                  } else if ("barcode".equals(type)) {
                        // Configura e imprime código de barras
                        esc.addSelectPrintingPositionForHRICharacters(EscCommand.HRI_POSITION.BELOW);
                        esc.addSetBarcodeHeight((byte) 60);
                        esc.addSetBarcodeWidth((byte) 2);
                        esc.addCODE128(esc.genCodeB(content));
                  } else if ("qrcode".equals(type)) {
                        // Configura e imprime QR Code
                        esc.addSelectErrorCorrectionLevelForQRCode((byte) 0x31);
                        esc.addSelectSizeOfModuleForQRCode((byte) size);
                        esc.addStoreQRCodeData(content);
                        esc.addPrintQRCode();
                  } else if ("image".equals(type)) {
                        // Decodifica e imprime imagem em base64
                        byte[] bytes = Base64.decode(content, Base64.DEFAULT);
                        Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);

                        // Ajusta proporções para formato retrato
                        if (bitmap.getHeight() > bitmap.getWidth()) {
                              int startY = (bitmap.getHeight() - bitmap.getWidth()) / 2;
                              bitmap = Bitmap.createBitmap(bitmap, 0, startY, bitmap.getWidth(), bitmap.getWidth());
                        }

                        esc.addRastBitImage(bitmap, width, 0);
                  }

                  // Avança linha se configurado
                  if (linefeed == 1) {
                        esc.addPrintAndLineFeed();
                  }
            }

            // Finaliza o recibo
            esc.addPrintAndFeedLines((byte) 1);
            // Comando para cortar o papel
            esc.addCutPaper();
            // Adiciona comando de consulta de status
            byte[] bytes = { 0x1D, 0x72, 0x01 };
            esc.addUserCommand(bytes);

            return esc.getCommand();
      }

      /**
       * Converte um mapa de dados em comandos TSPL para impressão de etiquetas
       * 
       * @param config Configurações gerais da etiqueta
       * @param list   Lista de elementos a serem impressos
       * @return Vetor de bytes com os comandos para a impressora de etiquetas
       */
      public static Vector<Byte> mapToLabel(Map<String, Object> config, List<Map<String, Object>> list) {
            LabelCommand tsc = new LabelCommand();

            // Configurações básicas da etiqueta (em mm)
            int width = (int) (config.get("width") == null ? 60 : config.get("width"));
            int height = (int) (config.get("height") == null ? 75 : config.get("height"));
            int gap = (int) (config.get("gap") == null ? 0 : config.get("gap"));

            // Define parâmetros da etiqueta
            tsc.addSize(width, height);
            tsc.addGap(gap);
            tsc.addDirection(LabelCommand.DIRECTION.FORWARD, LabelCommand.MIRROR.NORMAL);
            tsc.addQueryPrinterStatus(LabelCommand.RESPONSE_MODE.ON);
            tsc.addReference(0, 0);
            tsc.addDensity(LabelCommand.DENSITY.DNESITY4);
            tsc.addTear(EscCommand.ENABLE.ON);
            tsc.addCls(); // Limpa buffer

            // Processa cada elemento {type:'text|barcode|qrcode|image', content:'',
            // x:0,y:0}
            for (Map<String, Object> m : list) {
                  String type = (String) m.get("type");
                  String content = (String) m.get("content");
                  int x = (int) (m.get("x") == null ? 0 : m.get("x")); // 1mm ≈ 8 pontos
                  int y = (int) (m.get("y") == null ? 0 : m.get("y"));

                  if ("text".equals(type)) {
                        try {
                              content = new String(content.getBytes("UTF-8"), "ISO-8859-1");
                        } catch (UnsupportedEncodingException e) {
                              Log.e(TAG, "Erro na conversão de codificação: " + e.getMessage());
                        }
                        // Adiciona texto simplificado chinês (pode ser adaptado para outros idiomas)
                        tsc.addText(x, y, LabelCommand.FONTTYPE.SIMPLIFIED_CHINESE, LabelCommand.ROTATION.ROTATION_0,
                                    LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, content);
                  } else if ("barcode".equals(type)) {
                        // Adiciona código de barras CODE128
                        tsc.add1DBarcode(x, y, LabelCommand.BARCODETYPE.CODE128, 100, LabelCommand.READABEL.EANBEL,
                                    LabelCommand.ROTATION.ROTATION_0, content);
                  } else if ("qrcode".equals(type)) {
                        // Adiciona QR Code
                        tsc.addQRCode(x, y, LabelCommand.EEC.LEVEL_L, 5, LabelCommand.ROTATION.ROTATION_0, content);
                  } else if ("image".equals(type)) {
                        // Decodifica e adiciona imagem
                        byte[] bytes = Base64.decode(content, Base64.DEFAULT);
                        Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                        tsc.addBitmap(x, y, LabelCommand.BITMAP_MODE.OVERWRITE, 300, bitmap);
                  }
            }

            // Comandos finais
            tsc.addPrint(1, 1); // Imprime 1 cópia
            tsc.addSound(2, 100); // Bip ao terminar
            tsc.addCashdrwer(LabelCommand.FOOT.F5, 255, 255); // Abre gaveta
            return tsc.getCommand();
      }

      /**
       * Converte um mapa de dados em comandos CPCL (para etiquetas específicas)
       * 
       * @param config Configurações gerais
       * @param list   Lista de elementos a serem impressos
       * @return Vetor de bytes com os comandos CPCL
       */
      public static Vector<Byte> mapToCPCL(Map<String, Object> config, List<Map<String, Object>> list) {
            CpclCommand cpcl = new CpclCommand();
            // Implementação básica - pode ser expandida conforme necessidade
            Vector<Byte> datas = cpcl.getCommand();
            return datas;
      }
}