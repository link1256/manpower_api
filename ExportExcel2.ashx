<%@ WebHandler Language="C#" Class="ExportOds" %>

using Newtonsoft.Json;
using System;
using System.IO;
using System.Diagnostics;
using System.Globalization;
using System.Web;
using System.Collections.Generic;
using NPOI.XSSF.UserModel;
using NPOI.SS.UserModel;

public class ExportOds : IHttpHandler {

    public void ProcessRequest (HttpContext context) {

        if (context.Request.Form["html"] == null) return;

        string sHtml = context.Request.Form["html"];
        string title = context.Request.Form["title"];
        string type = context.Request.Form["type"];
        string unit = context.Request.Form["unit"];
        string countycol = context.Request.Form["countycol"];
        tableElm vv1 = JsonConvert.DeserializeObject<tableElm>(sHtml);

        MemoryStream ExcelFiles = new MemoryStream();
        XSSFWorkbook workbook  = new XSSFWorkbook();

        ISheet ExcelSheet = null;
        if (title == "Seasonally Adjusted Unemployment Rate")
            ExcelSheet = workbook.CreateSheet("Unemployment Rate, s.a.");
        else
            ExcelSheet = workbook.CreateSheet("Sheet");

        ICellStyle styleRight = workbook.CreateCellStyle();
        styleRight.BorderLeft = BorderStyle.Thin;
        styleRight.BorderBottom = BorderStyle.Thin;
        styleRight.BorderRight = BorderStyle.Thin;
        styleRight.BorderTop = BorderStyle.Thin;
        styleRight.Alignment = HorizontalAlignment.Right;
        styleRight.FillBackgroundColor = 0;
        styleRight.FillForegroundColor = 0;

        ICellStyle styleRight2 = workbook.CreateCellStyle();
        styleRight2.BorderLeft = BorderStyle.Thin;
        styleRight2.BorderBottom = BorderStyle.Thin;
        styleRight2.BorderRight = BorderStyle.Thin;
        styleRight2.BorderTop = BorderStyle.Thin;
        styleRight2.Alignment = HorizontalAlignment.Right;
        styleRight2.FillBackgroundColor = 0;
        styleRight2.FillForegroundColor = 0;

        ICellStyle styleRight3 = workbook.CreateCellStyle();
        styleRight3.BorderLeft = BorderStyle.Thin;
        styleRight3.BorderBottom = BorderStyle.Thin;
        styleRight3.BorderRight = BorderStyle.Thin;
        styleRight3.BorderTop = BorderStyle.Thin;
        styleRight3.Alignment = HorizontalAlignment.Left;
        styleRight3.VerticalAlignment = VerticalAlignment.Center;

        ICellStyle styleHead = workbook.CreateCellStyle();
        styleHead.BorderLeft = BorderStyle.Thin;
        styleHead.BorderBottom = BorderStyle.Thin;
        styleHead.BorderRight = BorderStyle.Thin;
        styleHead.BorderTop = BorderStyle.Thin;
        styleHead.Alignment = HorizontalAlignment.Center;
        styleHead.VerticalAlignment = VerticalAlignment.Center;
        styleHead.FillBackgroundColor = 0;

        try
        {
            //title
            ExcelSheet.CreateRow(0);

            if (countycol!= null && countycol != "")
                ExcelSheet.GetRow(0).CreateCell(0).SetCellValue(countycol);
            else
                ExcelSheet.GetRow(0).CreateCell(0).SetCellValue(title);

            ExcelSheet.GetRow(0).CreateCell(3);
            ExcelSheet.AddMergedRegion(new NPOI.SS.Util.CellRangeAddress(0, 0, 0, 3));

            //單位位置
            if (unit != "")
            {
                if (vv1.thead.Count == 1)
                {
                    int column = vv1.thead[0].ths.Count;
                    ExcelSheet.GetRow(0).CreateCell(column - 1).SetCellValue(unit);
                }
                else
                    ExcelSheet.GetRow(0).CreateCell(4).SetCellValue(unit);
            }

            //thead
            int tscol = 0;
            int tsrow = 0;

            // CreateTotalRow
            if (vv1.thead.Count > 0)
            {
                List<thElm> cols = vv1.thead[0].ths;
                if (cols.Count > 0)
                {
                    int rowspan = Convert.ToInt32(cols[0].rowspan);
                    for (int i = 1; i <= 1 + rowspan; i++)
                        ExcelSheet.CreateRow(i);
                }
            }

            for (int r = 0; r < vv1.thead.Count; r++)
            {
                int Nrow = r + 1;
                // ExcelSheet.CreateRow(Nrow);

                int Ncol = 0;
                if (r != 0)
                    Ncol = tscol;

                List<thElm> cols = vv1.thead[r].ths;
                for (int c = 0; c < cols.Count; c++)
                {
                    int rowspan = Convert.ToInt32(cols[c].rowspan);
                    int colspan = Convert.ToInt32(cols[c].colspan);

                    if (r == 0 && c == 0)
                    {
                        tscol = Ncol + colspan;
                        tsrow = Nrow + rowspan;
                    }

                    string value = HttpUtility.HtmlDecode(cols[c].value);

                    ExcelSheet.GetRow(Nrow).CreateCell(Ncol).SetCellValue(value);

                    int collen = Ncol + colspan - 1;
                    int rowlen = Nrow + rowspan - 1;

                    if (Nrow < rowlen || Ncol < collen)
                    {
                        NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(Nrow, rowlen, Ncol, collen);
                        ExcelSheet.AddMergedRegion(range);

                        NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range, ExcelSheet); //Bottom border  
                        NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range, ExcelSheet); //Left border  
                        NPOI.SS.Util.RegionUtil.SetBorderRight(1, range, ExcelSheet); //Right border  
                        NPOI.SS.Util.RegionUtil.SetBorderTop(1, range, ExcelSheet); //Top border  

                        ExcelSheet.GetRow(Nrow).GetCell(Ncol).CellStyle = styleHead;
                    }
                    else
                    {
                        ExcelSheet.GetRow(Nrow).GetCell(Ncol).CellStyle = styleHead;
                    }

                    Ncol = collen + 1;
                }
            }
            //tbody
            int bodyrow = tsrow;
            int tcol = 0;

            // CreateTotalRow
            int createRow = 1;
            if (vv1.tbody.Count > 0)
            {
                List<thElm> cols = vv1.tbody[0].ths;
                if (cols.Count > 0)
                {
                    createRow = Convert.ToInt32(cols[0].rowspan);
                }
            }

            for (int r = 0; r < vv1.tbody.Count; r++)
            {
                int Nrow = r + bodyrow;

                if (r == 109)
                {
                    int y = 0;
                }

                if (r % createRow == 0)
                {
                    for (int i = Nrow; i <= Nrow + createRow; i++)
                        ExcelSheet.CreateRow(i);
                }

                List<thElm> cols = vv1.tbody[r].ths;
                int Ncol = Math.Abs(cols.Count - tcol);
                if (r == 0)
                {
                    Ncol = 0;
                    tcol = cols.Count;
                }

                for (int c = 0; c < cols.Count; c++)
                {
                    int rowspan = Convert.ToInt32(cols[c].rowspan);
                    int colspan = Convert.ToInt32(cols[c].colspan);
                    decimal number;
                    string value = cols[c].value;
                    bool isnumber = Decimal.TryParse(value, NumberStyles.Number, null, out number);

                    int collen = Ncol + colspan - 1;
                    ExcelSheet.GetRow(Nrow).CreateCell(Ncol).SetCellValue(value);

                    if (value == "臺灣地區")
                    {
                        ExcelSheet.GetRow(Nrow).CreateCell(Ncol).SetCellValue(value);
                    }
                    else if (value == "北部區域" || value == "中部區域" || value == "東部區域" || value == "南部區域")
                    {
                        ExcelSheet.GetRow(Nrow).CreateCell(Ncol).SetCellValue("   " + value);
                    }
                    else if (value == "新北市" || value == "臺北市" || value == "桃園市" || value == "基隆市" || value == "新竹市" || value == "宜蘭縣" ||
                                value == "新竹縣" || value == "臺中市" || value == "苗栗縣" || value == "彰化縣" || value == "南投縣" || value == "雲林縣" ||
                                value == "臺南市" || value == "高雄市" || value == "嘉義市" || value == "嘉義縣" || value == "屏東縣" || value == "澎湖縣" ||
                                value == "臺東縣" || value == "花蓮縣" || value == "臺北縣" || value == "桃園縣" || value == "臺中縣" || value == "臺南縣" ||
                                value == "高雄縣" )
                    {
                        ExcelSheet.GetRow(Nrow).CreateCell(Ncol).SetCellValue("      " + value);
                    }

                    if (!isnumber && (c + 1 < cols.Count))
                    {
                        ExcelSheet.GetRow(Nrow).GetCell(Ncol).CellStyle = styleRight3;
                    }

                    if (cols[c].isth != true && c != 0)
                    {
                        if ((isnumber && (r % 2) == 0) || (value == "-" && (r % 2) == 0))
                            ExcelSheet.GetRow(Nrow).GetCell(Ncol).CellStyle = styleRight2;
                        else if (isnumber || value == "-") //判斷是否為數字 是的話往右邊對齊
                            ExcelSheet.GetRow(Nrow).GetCell(Ncol).CellStyle = styleRight;
                    }

                    int rowlen = Nrow + rowspan - 1;
                    if (Nrow < rowlen || Ncol < collen)
                    {
                        ExcelSheet.GetRow(Nrow).GetCell(Ncol).CellStyle = styleRight3;

                        NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(Nrow, rowlen, Ncol, collen);
                        ExcelSheet.AddMergedRegion(range);

                        NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range, ExcelSheet); //Bottom border  
                        NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range, ExcelSheet); //Left border  
                        NPOI.SS.Util.RegionUtil.SetBorderRight(1, range, ExcelSheet); //Right border  
                        NPOI.SS.Util.RegionUtil.SetBorderTop(1, range, ExcelSheet);
                    }

                    Ncol = collen + 1;
                }
            }

            if (context.Request.Form["totalviews"] != null)
            {
                int endrow = bodyrow + vv1.tbody.Count + 1;

                ExcelSheet.CreateRow(endrow + 1);
                ExcelSheet.GetRow(endrow + 1).CreateCell(0).SetCellValue("總瀏覽次數");
                ExcelSheet.GetRow(endrow + 1).CreateCell(1).SetCellValue(context.Request.Form["totalviews"].ToString());

                ExcelSheet.CreateRow(endrow + 2);
                ExcelSheet.GetRow(endrow + 2).CreateCell(0).SetCellValue("下載次數(表)");
                ExcelSheet.GetRow(endrow + 2).CreateCell(1).SetCellValue(context.Request.Form["downloadtable"].ToString());

                ExcelSheet.CreateRow(endrow + 3);
                ExcelSheet.GetRow(endrow + 3).CreateCell(0).SetCellValue("下載次數(圖)");
                ExcelSheet.GetRow(endrow + 3).CreateCell(1).SetCellValue(context.Request.Form["downloadviews"].ToString());
            }

            if (title.Contains("失業原因"))
            {
                int endrow = bodyrow + vv1.tbody.Count + 1;

                ExcelSheet.CreateRow(endrow);

                NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                ExcelSheet.AddMergedRegion(range);

                ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("註：112年1月起「女性結婚或生育」修改為「結婚或生育」。");
            }
            if (title.Contains("未參與勞動原因"))
            {
                int endrow = bodyrow + vv1.tbody.Count + 1;

                ExcelSheet.CreateRow(endrow);

                NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                ExcelSheet.AddMergedRegion(range);

                ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("註：自114年起，非勞動力未參與勞動原因「想工作而未找工作且隨時可以開始工作」者，依實際狀況分別歸入「求學及準備升學」、「料理家務」、「高齡、身心障礙」及「其他」4類，不再單獨列示。");
            }
            if (title.Contains("人力資源調查重要指標"))
            {
                int endrow = bodyrow + vv1.tbody.Count + 1;

                ExcelSheet.CreateRow(endrow);

                NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                ExcelSheet.AddMergedRegion(range);

                ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("註1：自112年1月起，發布4週失業者及LU1。");

                endrow = endrow + 1;
                ExcelSheet.CreateRow(endrow);

                NPOI.SS.Util.CellRangeAddress range2 = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                ExcelSheet.AddMergedRegion(range2);

                ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("註2：自113年6月起，發布工時不足就業者、潛在勞動力及LU2~LU4。");
            }
            if (title.Contains("Important Indicators of Manpower Survey"))
            {
                int endrow = bodyrow + vv1.tbody.Count + 1;

                ExcelSheet.CreateRow(endrow);

                NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                ExcelSheet.AddMergedRegion(range);

                ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("Note 1: 4 weeks unemployed and LU1 have been released since January 2023.");

                endrow = endrow + 1;
                ExcelSheet.CreateRow(endrow);

                NPOI.SS.Util.CellRangeAddress range2 = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                ExcelSheet.AddMergedRegion(range2);

                ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("Note 2: Time-related underemployed, Potential labor force and LU2~LU4 have been released since June 2024.");
            }
            if (title.Contains("Reason for Unemployment"))
            {
                int endrow = bodyrow + vv1.tbody.Count + 1;

                ExcelSheet.CreateRow(endrow);

                NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                ExcelSheet.AddMergedRegion(range);

                ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("Note: Until 2022, “Marriage or childbirth” referred only to women.");
            }
            if (title.Contains("Not in Labor Force-Reason for Not in Labor Force"))
            {
                int endrow = bodyrow + vv1.tbody.Count + 1;

                ExcelSheet.CreateRow(endrow);

                NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                ExcelSheet.AddMergedRegion(range);

                ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("Note: Starting from January 2025, those who are not in the labor force for the reason “Intend & be available to work but not seeking” are classified into four categories: \"Attend school or rebrush to take entrance exams\", \"Housekeeping\", \"Old age or disable\", and \"Others\" according to their actual conditions, and are no longer listed separately.");
            }

            workbook.Write(ExcelFiles);

            DateTime Now = DateTime.Now;
            title = title.Replace(" ", "_");
            string filename = title + "_" + Now.ToString("yyyyMMddHHmms");
            string fname = string.Format(@"{0}", filename) + ".xlsx";
            string ServerPath = HttpContext.Current.Server.MapPath("~/");
            string strFullDirectoryPath = Path.Combine(ServerPath, "ExportExcel\\");
            if (!Directory.Exists(strFullDirectoryPath))
            {
                Directory.CreateDirectory(strFullDirectoryPath);
            }

            string strExcelFilePath = Path.Combine(strFullDirectoryPath, fname);
            System.IO.File.WriteAllBytes(strExcelFilePath, ExcelFiles.ToArray());

            if (type == "ods")
            {
                using (Process exeProcess = Process.Start(GetConvertInfo(System.Configuration.ConfigurationManager.AppSettings["SofficePath"], strFullDirectoryPath, strExcelFilePath, 2)))
                {
                    exeProcess.WaitForExit();
                }
                GC.Collect();
                fname = fname.Replace(".xlsx", ".ods");
            }
            workbook.Close();
            workbook = null;
            context.Response.Write(fname);
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }
    }

    /// <summary>
    /// 執行Libreoffice轉成開放格式
    /// </summary>
    /// <param name="_ExeFullPath">soffice執行檔完整路徑</param>
    /// <param name="_strFullDirectoryPath">為資料夾路徑（不用包含檔案名稱）</param>
    /// <param name="_strFilePath">轉換檔案的完整路徑</param>
    /// <param name="_intConvertType">1是ODT 2是ODS</param>
    /// <returns></returns>
    private ProcessStartInfo GetConvertInfo(string _ExeFullPath, string _strFullDirectoryPath, string _strFilePath, int _intConvertType)
    {
        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.RedirectStandardOutput = true;
        startInfo.CreateNoWindow = false;
        startInfo.UseShellExecute = false;
        startInfo.FileName = _ExeFullPath;
        startInfo.WindowStyle = ProcessWindowStyle.Hidden;
        startInfo.Arguments = string.Format(@"soffice -env:UserInstallation=file:///C:/LibreOfficeTemp/Temp -headless -nofirststartwizard --convert-to {0} --outdir {1} --nologo {2}", GetConvertFormat(_intConvertType), _strFullDirectoryPath, _strFilePath);

        return startInfo;
    }

    public string GetConvertFormat(int _intConvertType)
    {
        switch (_intConvertType)
        {
            case 1:
                return "odt";
            case 2:
                return "ods";
        }
        return string.Empty;
    }

    public class tableElm
    {
        public List<trElm> thead { get; set; }
        public List<trElm> tbody { get; set; }
    }

    public class trElm
    {
        public List<thElm> ths { get; set; }
    }

    public class thElm
    {
        public bool isth { get; set; }
        public string colspan { get; set; }
        public string rowspan { get; set; }
        public string className { get; set; }
        public string value { get; set; }
    }

    public bool IsReusable {
        get {
            return false;
        }
    }

}