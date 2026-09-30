using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Security.AntiXss;

namespace Supergeo.StatUtils
{
    public class Utils
    {
        public static Encoding GetEncoding(String filename)
        {
            // Read the BOM
            var bom = new byte[4];
            using (var file = new FileStream(filename, FileMode.Open)) file.Read(bom, 0, 4);

            // Analyze the BOM
            if (bom[0] == 0x2b && bom[1] == 0x2f && bom[2] == 0x76) return Encoding.UTF7;
            if (bom[0] == 0xef && bom[1] == 0xbb && bom[2] == 0xbf) return Encoding.UTF8;
            if (bom[0] == 0xff && bom[1] == 0xfe) return Encoding.Unicode; //UTF-16LE
            if (bom[0] == 0xfe && bom[1] == 0xff) return Encoding.BigEndianUnicode; //UTF-16BE
            if (bom[0] == 0 && bom[1] == 0 && bom[2] == 0xfe && bom[3] == 0xff) return Encoding.UTF32;
            return Encoding.ASCII;
        }

        public static String[] GetRows(String strFilename)
        {
            string file = AntiXssEncoder.HtmlEncode(strFilename, true);
            String[] saRows = null;
            Encoding enc = Utils.GetEncoding(file);
            String text = null;
            if (enc != Encoding.ASCII)
            {
                text = File.ReadAllText(file, enc);
            }
            else
            {
                text = File.ReadAllText(file, Encoding.Default);
            }

            //過濾敏感字詞
            text = AntiXssEncoder.HtmlEncode(text, true);

            if (text != null)
            {
                if (text.IndexOf("&#13;&#10;") > 0)
                    saRows = text.Split(new String[] { Environment.NewLine, "&#13;&#10;" }, StringSplitOptions.None);
                else
                    saRows = text.Split(new String[] { Environment.NewLine, "&#10;" }, StringSplitOptions.None);

                text = null;
            }

            for (int i = 0; i < saRows.Length; i++)
            {
                saRows[i] = AntiXssEncoder.HtmlEncode(saRows[i], true);
            }
            return saRows;
        }

        public static String GetFirstRow(String strFilename)
        {
            String strRow = null;
            String[] saRows = GetRows(strFilename);
            if (saRows.Length > 0)
            {
                strRow = saRows[0];
            }
            saRows = null;
            return strRow;
        }

        public static Int32 ToNumber(String strSrc, out Boolean wordIn)
        {
            wordIn = false;
            Int32 nRc = 0;

            Int32 srclen = strSrc.Length;
            String word;
            String seg = "";

            int i = 0;	// 搜尋到第 i 個 char
            while (i < srclen)
            {
                word = strSrc[i++].ToString();
                if (!IsNumber(word)) wordIn = true;
                // 將全形大寫及阿拉伯數字轉為半形阿拉伯數字,
                // 另需注意 "十" 的轉換 (10, 12 ... 等)
                if (String.Compare(word, "一") == 0 || String.Compare(word, "１") == 0)
                {
                    seg = seg + "1";
                }
                else if (String.Compare(word, "二") == 0 || String.Compare(word, "２") == 0)
                {
                    seg = seg + "2";
                }
                else if (String.Compare(word, "三") == 0 || String.Compare(word, "３") == 0)
                {
                    seg = seg + "3";
                }
                else if (String.Compare(word, "四") == 0 || String.Compare(word, "４") == 0)
                {
                    seg = seg + "4";
                }
                else if (String.Compare(word, "五") == 0 || String.Compare(word, "５") == 0)
                {
                    seg = seg + "5";
                }
                else if (String.Compare(word, "六") == 0 || String.Compare(word, "６") == 0)
                {
                    seg = seg + "6";
                }
                else if (String.Compare(word, "七") == 0 || String.Compare(word, "７") == 0)
                {
                    seg = seg + "7";
                }
                else if (String.Compare(word, "八") == 0 || String.Compare(word, "８") == 0)
                {
                    seg = seg + "8";
                }
                else if (String.Compare(word, "九") == 0 || String.Compare(word, "９") == 0)
                {
                    seg = seg + "9";
                }
                else if (String.Compare(word, "十") == 0)
                {
                    if (seg.Length <= 0)
                    {
                        seg = seg + "1";
                    }
                    if (i >= srclen)
                    {
                        seg = seg + "0";
                    }
                }
                else if (String.Compare(word, "０") == 0)
                {
                    seg = seg + "0";
                }
                else if (String.Compare(word, "1") == 0
                     || String.Compare(word, "2") == 0
                     || String.Compare(word, "3") == 0
                     || String.Compare(word, "4") == 0
                     || String.Compare(word, "5") == 0
                     || String.Compare(word, "6") == 0
                     || String.Compare(word, "7") == 0
                     || String.Compare(word, "8") == 0
                     || String.Compare(word, "9") == 0
                     || String.Compare(word, "0") == 0)
                {
                    seg = seg + word;
                }
            }

            if (seg.Length > 0)
            {
                Int32 nV;
                if (Int32.TryParse(seg, out nV))
                {
                    nRc = nV;
                }
            }

            return nRc;
        }

        public static Boolean IsNumber(String word)
        {
            Boolean bGotNumber = false; ;
            Int32 nV;
            Double dV;
            if (Int32.TryParse(word, out nV))
            {
                bGotNumber = true;
            }
            if (!bGotNumber)
            {
                if (Double.TryParse(word, out dV))
                {
                    bGotNumber = true;
                }
            }
            return bGotNumber;
        }

    }
}
