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

/**
 * @author thon
 */
public class PrintContent {
      private static final String TAG = PrintContent.class.getSimpleName();

      /**
       * Ticket print object conversion
       */
      public static Vector<Byte> mapToReceipt(Map<String,Object> config, List<Map<String,Object>> list) {
            EscCommand esc = new EscCommand();
            //Initialize printer
            esc.addInitializePrinter();
            //Print paper for a number of units
            esc.addPrintAndFeedLines((byte) 1);

            // {type:'text|barcode|qrcode|image', content:'', size:4, align: 0|1|2, weight: 0|1, width:0|1, height:0|1, underline:0|1, linefeed: 0|1}
            for (Map<String,Object> m: list) {
                  String type = (String)m.get("type");
                  String content = (String)m.get("content");
                  int align = (int)(m.get("align")==null?0:m.get("align"));
                  int size = (int)(m.get("size")==null?3:m.get("size"));
                  int weight = (int)(m.get("weight")==null?0:m.get("weight"));
                  int width = (int)(m.get("width")==null?0:m.get("width"));
                  int height = (int)(m.get("height")==null?0:m.get("height"));
                  int underline = (int)(m.get("underline")==null?0:m.get("underline"));
                  int linefeed = (int)(m.get("linefeed")==null?0:m.get("linefeed"));

                  EscCommand.ENABLE emphasized = weight==0?EscCommand.ENABLE.OFF:EscCommand.ENABLE.ON;
                  EscCommand.ENABLE doublewidth = width==0?EscCommand.ENABLE.OFF:EscCommand.ENABLE.ON;
                  EscCommand.ENABLE doubleheight = height==0?EscCommand.ENABLE.OFF:EscCommand.ENABLE.ON;
                  EscCommand.ENABLE isUnderline = underline==0?EscCommand.ENABLE.OFF:EscCommand.ENABLE.ON;

                  // Set print position
                  esc.addSelectJustification(align==0?EscCommand.JUSTIFICATION.LEFT:(align==1?EscCommand.JUSTIFICATION.CENTER:EscCommand.JUSTIFICATION.RIGHT));

                  if("text".equals(type)){
                        int absolutePos = (int)(m.get("absolutePos")==null?0:m.get("absolutePos"));
                        int relativePos = (int)(m.get("relativePos")==null?0:m.get("relativePos"));
                        int fontZoom = (int)(m.get("fontZoom")==null?1:m.get("fontZoom"));
                        short aPos = (short)absolutePos;
                        short rPos = (short)relativePos;
                        Log.e(TAG,"******************* absolutePos: " + aPos +", relativePos: " + rPos +", fontZoom: " + fontZoom);

                        // Set absolute print position, set the current print position to n* hor_motion_unit points from the beginning of the line
                        esc.addSetAbsolutePrintPosition(aPos);
                        // Set relative print position, set the print position to n points from the current position
                        esc.addSetRelativePrintPositon(rPos);
                        // Set to double height and width
                        esc.addSelectPrintModes(EscCommand.FONT.FONTA, emphasized, doubleheight, doublewidth, isUnderline);
                        if(fontZoom>1){
                              esc.addSetKanjiFontMode(EscCommand.ENABLE.ON, EscCommand.ENABLE.ON, EscCommand.ENABLE.OFF);
                        }else{
                              esc.addSetKanjiFontMode(EscCommand.ENABLE.OFF, EscCommand.ENABLE.OFF, EscCommand.ENABLE.OFF);
                        }
                        esc.addText(content);
                        // Cancel double height and width
                        esc.addSelectPrintModes(EscCommand.FONT.FONTA, EscCommand.ENABLE.OFF, EscCommand.ENABLE.OFF, EscCommand.ENABLE.OFF, EscCommand.ENABLE.OFF);
                  }else if("barcode".equals(type)){
                        esc.addSelectPrintingPositionForHRICharacters(EscCommand.HRI_POSITION.BELOW);
                        // Set the readable character position of the barcode to below the barcode
                        // Set the barcode height to 60 points
                        esc.addSetBarcodeHeight((byte) 60);
                        // Set the barcode width to 2
                        esc.addSetBarcodeWidth((byte) 2);
                        // Print Code128 barcode
                        esc.addCODE128(esc.genCodeB(content));
                  }else if("qrcode".equals(type)){
                        // Set the error correction level
                        esc.addSelectErrorCorrectionLevelForQRCode((byte) 0x31);
                        // Set the qrcode module size
                        esc.addSelectSizeOfModuleForQRCode((byte) size);
                        // Set the qrcode content
                        esc.addStoreQRCodeData(content);
                        // Print QRCode
                        esc.addPrintQRCode();
                  }else if("image".equals(type)){
                        byte[] bytes = Base64.decode(content, Base64.DEFAULT);
                        Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);

                        if(bitmap.getHeight() > bitmap.getWidth()){
                              // Crop the image to maintain the aspect ratio and fit within the maximum height
                              int startY = (bitmap.getHeight() - bitmap.getWidth()) / 2;
                              bitmap = Bitmap.createBitmap(bitmap, 0, startY, bitmap.getWidth(), bitmap.getWidth());
                        }
                        
                        esc.addRastBitImage(bitmap, width, 0);
                  }

                  if(linefeed == 1){
                        //Print and feed
                        esc.addPrintAndLineFeed();
                  }

            }

            //Print and feed n units
            esc.addPrintAndFeedLines((byte) 1);

            // Open cash drawer
            // esc.addGeneratePlus(LabelCommand.FOOT.F2, (byte) 255, (byte) 255);
            //Cut paper
            esc.addCutPaper();
            //Add buffer print completion query
            byte [] bytes={0x1D,0x72,0x01};
            //Add user command
            esc.addUserCommand(bytes);

            return esc.getCommand();
      }

      /**
       * Label print object conversion
       */
      public static Vector<Byte> mapToLabel(Map<String,Object> config, List<Map<String,Object>> list) {
            LabelCommand tsc = new LabelCommand();

            int width = (int)(config.get("width")==null?60:config.get("width")); // Unit: mm
            int height = (int)(config.get("height")==null?75:config.get("height")); // Unit: mm
            int gap = (int)(config.get("gap")==null?0:config.get("gap")); // Unit: mm

            // Set the label size width and height, set according to the actual size Unit: mm
            tsc.addSize(width, height);
            // Set the label gap, set according to the actual size, if it is a gapless paper, set it to 0 Unit: mm
            tsc.addGap(gap);
            // Set the print direction
            tsc.addDirection(LabelCommand.DIRECTION.FORWARD, LabelCommand.MIRROR.NORMAL);
            // Enable printing with Response, used for continuous printing
            tsc.addQueryPrinterStatus(LabelCommand.RESPONSE_MODE.ON);
            // Set the origin coordinates
            tsc.addReference(0, 0);
            // Set the density
            tsc.addDensity(LabelCommand.DENSITY.DNESITY4);
            //Tear mode enabled
            tsc.addTear(EscCommand.ENABLE.ON);
            //Clear print buffer
            tsc.addCls();

            // {type:'text|barcode|qrcode|image', content:'', x:0,y:0}
            for (Map<String,Object> m: list) {
                  String type = (String)m.get("type");
                  String content = (String)m.get("content");
                  int x = (int)(m.get("x")==null?0:m.get("x")); //dpi: 1mm约为8个点
                  int y = (int)(m.get("y")==null?0:m.get("y"));

                  if("text".equals(type)){
                        // Draw Simplified Chinese
                        tsc.addText(x, y, LabelCommand.FONTTYPE.SIMPLIFIED_CHINESE, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1, content);
                        //Print Traditional Chinese
                        //tsc.addUnicodeText(10,32, LabelCommand.FONTTYPE.TRADITIONAL_CHINESE, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1,"BIG5碼繁體中文字元","BIG5");
                        //Print Korean
                        //tsc.addUnicodeText(10,60, LabelCommand.FONTTYPE.KOREAN, LabelCommand.ROTATION.ROTATION_0, LabelCommand.FONTMUL.MUL_1, LabelCommand.FONTMUL.MUL_1,"Korean 지아보 하성","EUC_KR");
                  }else if("barcode".equals(type)){
                        tsc.add1DBarcode(x, y, LabelCommand.BARCODETYPE.CODE128, 100, LabelCommand.READABEL.EANBEL, LabelCommand.ROTATION.ROTATION_0, content);
                  }else if("qrcode".equals(type)){
                        tsc.addQRCode(x,y, LabelCommand.EEC.LEVEL_L, 5, LabelCommand.ROTATION.ROTATION_0, content);
                  }else if("image".equals(type)){
                        byte[] bytes = Base64.decode(content, Base64.DEFAULT);
                        Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                        tsc.addBitmap(x, y, LabelCommand.BITMAP_MODE.OVERWRITE, 300, bitmap);
                  }
            }

            // Print label
            tsc.addPrint(1, 1);
            // Print label after the buzzer sounds
            tsc.addSound(2, 100);
            //Open cash drawer
            tsc.addCashdrwer(LabelCommand.FOOT.F5, 255, 255);
            // Send data
            return  tsc.getCommand();
      }

      /**
       * Waybill print object conversion
       */
      public static Vector<Byte> mapToCPCL(Map<String,Object> config, List<Map<String,Object>> list) {
            CpclCommand cpcl = new CpclCommand();


            Vector<Byte> datas = cpcl.getCommand();
            return datas;
      }

}
