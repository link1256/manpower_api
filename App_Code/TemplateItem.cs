using System;
using System.Collections.Generic;
using NPOI.SS.UserModel;
using NPOI.XSSF.UserModel;
using System.IO;
using System.Data;
using System.Web;
using System.Diagnostics;

namespace Supergeo.Utilities
{
    public class TemplateItem : IDisposable
    {
        private String _Name = "";
        private Int32 _Year = -1;
        private Int32 _Month = -1;
        private Int32 _StatClass = -1;
        private List<String> _FieldsName = null;
        private List<Int32> _FieldsIndex = null;
        private Int32 _RowEnd = -1;
        private Int32 _ColumnEnd = -1;
        private Int32 _TitleStart = Int32.MaxValue;
        private Int32 _TitleEnd = Int32.MinValue;
        private Int32 _HeaderStart = Int32.MaxValue;
        private Int32 _HeaderEnd = Int32.MinValue;
        private Int32 _DataRow = -1;
        private Int32 _TableStart = -1;
        private Int32 _TableEnd = -1;

        private ISheet _Sheet = null;
        private String _Html = null;

        public void Dispose()
        {
            if (_FieldsName != null)
            {
                _FieldsName.Clear();
                _FieldsName = null;
            }
            if (_FieldsIndex != null)
            {
                _FieldsIndex.Clear();
                _FieldsIndex = null;
            }
            if (_Sheet != null)
            {
                _Sheet = null;
            }
        }

        public void LoadTemplate(ISheet sheet)
        {
            NPOIUtils utils = new NPOIUtils();
            if (utils != null)
            {
                XSSFWorkbook workbook = new XSSFWorkbook();
                if (workbook != null)
                {
                    workbook.SetForceFormulaRecalculation((sheet.Workbook as XSSFWorkbook).GetForceFormulaRecalculation());
                    workbook.MissingCellPolicy = (sheet.Workbook as XSSFWorkbook).MissingCellPolicy;
                    _Sheet = workbook.CreateSheet(sheet.SheetName);

                    utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                        1, _RowEnd + 1, 1, _ColumnEnd + 1,
                        0, 0);

                    // FileStream file = new FileStream(@"D:\Project\dgbas_api\layoutupload\Part.xlsx", FileMode.Create);//產生檔案
                    // workbook.Write(file);
                    // file.Close();

                    ExcelToHtmlConverter eth = new ExcelToHtmlConverter();
                    if (eth != null)
                    {
                        // 設置輸出參數
                        eth.OutputColumnHeaders = false; //是否輸出ColumnHeader
                        eth.OutputHiddenColumns = false;//是否在表頭插入一行序列號
                        eth.OutputHiddenRows = false;//是否輸出HiddenRow
                        eth.OutputLeadingSpacesAsNonBreaking = true; //不清楚
                        eth.OutputRowNumbers = false;//是否在列頭插入一行序列號
                        eth.UseDivsToSpan = false; //不清楚

                        // 加載Excel文件
                        eth.ProcessWorkbook(workbook, this);

                        using (var stringWriter = new StringWriter())
                        {
                            eth.Document.Save(stringWriter);
                            String strHtml = stringWriter.GetStringBuilder().ToString();
                            strHtml = strHtml.Substring(strHtml.IndexOf("<html"));
                            strHtml = "<!DOCTYPE html>\r\n" + strHtml;

                            _Html = strHtml;
                        }

                        //string htmlFile = @"C:\Temp\Part.htm";
                        //eth.Document.Save(htmlFile);
                    }
                }
            }
        }

        public string SetTemplateWithData(HttpContext context, ISheet sheet, XSSFWorkbook workbook, List<DataSet> data, StatCondition stat, List<String> unittext)
        {
            string fileName = "";
            try
            {
                NPOIUtils utils = new NPOIUtils();
                ICellStyle styleRight = workbook.CreateCellStyle();
                
                styleRight.Alignment = HorizontalAlignment.Right;

                if (utils != null)
                {
                    if (workbook != null)
                    {
                        workbook.SetForceFormulaRecalculation((sheet.Workbook as XSSFWorkbook).GetForceFormulaRecalculation());
                        workbook.MissingCellPolicy = (sheet.Workbook as XSSFWorkbook).MissingCellPolicy;

                        int S_Year = stat.StartYear;
                        int E_Year = stat.EndYear;

                        if (stat.StatClass == StatClassItem.Month)
                        {
                            int rowstart = _DataRow;
                            _Sheet = workbook.CreateSheet("月");

                            for (int d = 0; d < data.Count; d++)
                            {
                                int y = S_Year;
                                int m = 1;
                                DataTable dt = data[d].Tables[0];
                                for (int i = 0; i < dt.Rows.Count; i++)
                                {
                                    if (d == 0 && i == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            0, 0);

                                        for (int ti = _TitleStart; ti <= _TitleEnd; ti++)
                                        {
                                            String uStr = Sheet.GetRow(ti).GetCell(0).StringCellValue;
                                            if (uStr.Contains("$$TITLE$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue(stat.TitleText);
                                            }
                                            else if (uStr.Contains("$$START_YEAR$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue("民國 " + stat.StartYear + " 年至民國 " + stat.EndYear + " 年 " + "按月");
                                            }
                                            else if (uStr.Contains("$$STAT_UNIT$$"))
                                            {
                                                uStr = uStr.Replace("$$STAT_UNIT$$", "");
                                                if (d < unittext.Count)
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + unittext[d]);
                                                else
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + stat.UnitText);
                                            }
                                        }
                                    }
                                    else if (d > 0 && i == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            rowstart, 0);

                                        for (int ti = rowstart + _TitleStart; ti <= rowstart + _TitleEnd; ti++)
                                        {
                                            String uStr = Sheet.GetRow(ti).GetCell(0).StringCellValue;
                                            if (uStr.Contains("$$TITLE$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue(stat.TitleText + " (續)");
                                            }
                                            else if (uStr.Contains("$$START_YEAR$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue("民國 " + stat.StartYear + " 年至民國 " + stat.EndYear + " 年 " + "按月");
                                            }
                                            else if (uStr.Contains("$$STAT_UNIT$$"))
                                            {
                                                uStr = uStr.Replace("$$STAT_UNIT$$", "");
                                                if (d < unittext.Count)
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + unittext[d]);
                                                else
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + stat.UnitText);
                                            }
                                        }

                                        rowstart = rowstart + _DataRow;
                                    }

                                    if (m > 12)
                                    {
                                        y = y + 1;
                                        m = 1;
                                    }

                                    IRow nowRow = Sheet.CreateRow(rowstart++);
                                    nowRow.CreateCell(0).SetCellValue(y + "年");
                                    nowRow.CreateCell(1).SetCellValue(m + "月");
                                    m++;
                                    int nowCol = 2;
                                    for (int j = 6; j < dt.Columns.Count; j++)
                                    {
                                        if (nowCol > _ColumnEnd)
                                            break;
                                        ICell nowCell = nowRow.CreateCell(nowCol);
                                        string svalue = dt.Rows[i]["欄位" + j].ToString();
                                        Decimal ivalue;
                                        if (Decimal.TryParse(svalue, out ivalue))
                                        {
                                            decimal value = Convert.ToDecimal(svalue);

                                            if (svalue.Split('.').Length > 1)
                                                nowCell.SetCellValue(value.ToString());
                                            else if (value == 0)
                                                nowCell.SetCellValue(value.ToString());
                                            else
                                                nowCell.SetCellValue(value.ToString("###,###"));

                                            nowCell.CellStyle = styleRight;
                                        }
                                        else
                                        {
                                            nowCell.SetCellValue("-");
                                            nowCell.CellStyle = styleRight;
                                        }

                                        nowCol++;
                                    }
                                }
                            }
                        }
                        else if (stat.StatClass == StatClassItem.YearAverageAndMonth)
                        {
                            int rowstart = _DataRow;
                            _Sheet = workbook.CreateSheet("年平均與月");

                            for (int d = 0; d < data.Count; d++)
                            {
                                DataTable dt = data[d].Tables[0];
                                for (int i = 0; i < dt.Rows.Count; i++)
                                {
                                    if (d == 0 && i == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            0, 0);

                                        for (int ti = _TitleStart; ti <= _TitleEnd; ti++)
                                        {
                                            String uStr = Sheet.GetRow(ti).GetCell(0).StringCellValue;
                                            if (uStr.Contains("$$TITLE$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue(stat.TitleText);
                                            }
                                            else if (uStr.Contains("$$START_YEAR$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue("民國 " + stat.StartYear + " 年至民國 " + stat.EndYear + " 年 " + "年平均與月");
                                            }
                                            else if (uStr.Contains("$$STAT_UNIT$$"))
                                            {
                                                uStr = uStr.Replace("$$STAT_UNIT$$", "");
                                                if (d < unittext.Count)
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + unittext[d]);
                                                else
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + stat.UnitText);
                                            }
                                        }
                                    }
                                    else if (d > 0 && i == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            rowstart, 0);

                                        for (int ti = rowstart + _TitleStart; ti <= rowstart + _TitleEnd; ti++)
                                        {
                                            String uStr = Sheet.GetRow(ti).GetCell(0).StringCellValue;
                                            if (uStr.Contains("$$TITLE$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue(stat.TitleText + " (續)");
                                            }
                                            else if (uStr.Contains("$$START_YEAR$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue("民國 " + stat.StartYear + " 年至民國 " + stat.EndYear + " 年 " + "年平均與月");
                                            }
                                            else if (uStr.Contains("$$STAT_UNIT$$"))
                                            {
                                                uStr = uStr.Replace("$$STAT_UNIT$$", "");
                                                if (d < unittext.Count)
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + unittext[d]);
                                                else
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + stat.UnitText);
                                            }
                                        }

                                        rowstart = rowstart + _DataRow;
                                    }

                                    string strYear = dt.Rows[i]["欄位1"].ToString();
                                    string strMonth = dt.Rows[i]["欄位2"].ToString();
                                    int y = Convert.ToInt32(strYear) - 1911;
                                    int m = Convert.ToInt32(strMonth);

                                    IRow nowRow = Sheet.CreateRow(rowstart++);
                                    nowRow.CreateCell(0).SetCellValue(y + "年");
                                    if (m != 0)
                                        nowRow.CreateCell(1).SetCellValue(m + "月");
                                    else
                                        nowRow.CreateCell(1).SetCellValue("平均");

                                    m++;
                                    int nowCol = 2;
                                    for (int j = 6; j < dt.Columns.Count; j++)
                                    {
                                        if (nowCol > _ColumnEnd)
                                            break;
                                        ICell nowCell = nowRow.CreateCell(nowCol);
                                        string svalue = dt.Rows[i]["欄位" + j].ToString();
                                        Decimal ivalue;
                                        if (Decimal.TryParse(svalue, out ivalue))
                                        {
                                            decimal value = Convert.ToDecimal(svalue);

                                            if (svalue.Split('.').Length > 1)
                                                nowCell.SetCellValue(value.ToString());
                                            else if (value == 0)
                                                nowCell.SetCellValue(value.ToString());
                                            else
                                                nowCell.SetCellValue(value.ToString("###,###"));

                                            nowCell.CellStyle = styleRight;
                                        }
                                        else
                                        {
                                            nowCell.SetCellValue("-");
                                            nowCell.CellStyle = styleRight;
                                        }

                                        nowCol++;
                                    }
                                }
                            }
                        }
                        else if (stat.StatClass == StatClassItem.YearAverage)
                        {
                            int rowstart = _DataRow;
                            _Sheet = workbook.CreateSheet("年平均");

                            for (int d = 0; d < data.Count; d++)
                            {
                                int y = S_Year;
                                DataTable dt = data[d].Tables[0];
                                for (int i = 0; i < dt.Rows.Count; i++)
                                {
                                    if (d == 0 && i == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            0, 0);

                                        for (int ti = _TitleStart; ti <= _TitleEnd; ti++)
                                        {
                                            String uStr = Sheet.GetRow(ti).GetCell(0).StringCellValue;
                                            if (uStr.Contains("$$TITLE$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue(stat.TitleText);
                                            }
                                            else if (uStr.Contains("$$START_YEAR$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue("民國 " + stat.StartYear + " 年至民國 " + stat.EndYear + " 年 " + "年平均");
                                            }
                                            else if (uStr.Contains("$$STAT_UNIT$$"))
                                            {
                                                uStr = uStr.Replace("$$STAT_UNIT$$", "");
                                                if (d < unittext.Count)
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + unittext[d]);
                                                else
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + stat.UnitText);
                                            }
                                        }
                                    }
                                    else if (d > 0 && i == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            rowstart, 0);

                                        for (int ti = rowstart + _TitleStart; ti <= rowstart + _TitleEnd; ti++)
                                        {
                                            String uStr = Sheet.GetRow(ti).GetCell(0).StringCellValue;
                                            if (uStr.Contains("$$TITLE$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue(stat.TitleText + " (續)");
                                            }
                                            else if (uStr.Contains("$$START_YEAR$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue("民國 " + stat.StartYear + " 年至民國 " + stat.EndYear + " 年 " + "年平均");
                                            }
                                            else if (uStr.Contains("$$STAT_UNIT$$"))
                                            {
                                                uStr = uStr.Replace("$$STAT_UNIT$$", "");
                                                if (d < unittext.Count)
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + unittext[d]);
                                                else
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + stat.UnitText);
                                            }
                                        }

                                        rowstart = rowstart + _DataRow;
                                    }

                                    IRow nowRow = Sheet.CreateRow(rowstart++);
                                    nowRow.CreateCell(0).SetCellValue(y + "年");
                                    y++;
                                    int nowCol = 1;
                                    for (int j = 6; j < dt.Columns.Count; j++)
                                    {
                                        if (nowCol > _ColumnEnd)
                                            break;
                                        ICell nowCell = nowRow.CreateCell(nowCol);
                                        string svalue = dt.Rows[i]["欄位" + j].ToString();
                                        Decimal ivalue;
                                        if (Decimal.TryParse(svalue, out ivalue))
                                        {
                                            decimal value = Convert.ToDecimal(svalue);

                                            if (svalue.Split('.').Length > 1)
                                                nowCell.SetCellValue(value.ToString());
                                            else if (value == 0)
                                                nowCell.SetCellValue(value.ToString());
                                            else
                                                nowCell.SetCellValue(value.ToString("###,###"));

                                            nowCell.CellStyle = styleRight;
                                        }
                                        else
                                        {
                                            nowCell.SetCellValue("-");
                                            nowCell.CellStyle = styleRight;
                                        }

                                        nowCol++;
                                    }
                                }
                            }
                        }
                        else if (stat.StatClass == StatClassItem.Items)
                        {
                            int rowstart = _TableStart;
                            _Sheet = workbook.CreateSheet("年分");
                            int group = _TableEnd - _TableStart + 1;

                            for (int d = 0; d < data.Count; d++)
                            {
                                DataTable dt = data[d].Tables[0];
                                int y = S_Year;
                                for (int i = 0; i < dt.Rows.Count; i++)
                                {
                                    if (d == 0 && i == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            0, 0);

                                        for (int ti = _TitleStart; ti <= _TitleEnd; ti++)
                                        {
                                            String uStr = Sheet.GetRow(ti).GetCell(0).StringCellValue;
                                            if (uStr.Contains("$$TITLE$$"))
                                            {
                                                ICellStyle tstyle = Sheet.GetRow(ti).GetCell(0).CellStyle;
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue(stat.TitleText);
                                            }
                                            else if (uStr.Contains("$$START_YEAR$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue("民國 " + stat.StartYear + " 年至民國 " + stat.EndYear + " 年 " + "按年");
                                            }
                                            else if (uStr.Contains("$$STAT_UNIT$$"))
                                            {
                                                uStr = uStr.Replace("$$STAT_UNIT$$", "");
                                                if (d < unittext.Count)
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + unittext[d]);
                                                else
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + stat.UnitText);
                                            }
                                        }

                                        Sheet.GetRow(rowstart).GetCell(0).SetCellValue(y + "年");
                                        y++;
                                    }
                                    else if (d > 0 && i == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            rowstart, 0);

                                        for (int ti = rowstart + _TitleStart; ti <= rowstart + _TitleEnd; ti++)
                                        {
                                            String uStr = Sheet.GetRow(ti).GetCell(0).StringCellValue;
                                            if (uStr.Contains("$$TITLE$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue(stat.TitleText + " (續)");
                                            }
                                            else if (uStr.Contains("$$START_YEAR$$"))
                                            {
                                                Sheet.GetRow(ti).GetCell(0).SetCellValue("民國 " + stat.StartYear + " 年至民國 " + stat.EndYear + " 年 " + "按年");
                                            }
                                            else if (uStr.Contains("$$STAT_UNIT$$"))
                                            {
                                                uStr = uStr.Replace("$$STAT_UNIT$$", "");
                                                if (d < unittext.Count)
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + unittext[d]);
                                                else
                                                    Sheet.GetRow(ti).GetCell(0).SetCellValue(uStr + stat.UnitText);
                                            }
                                        }

                                        rowstart = rowstart + _TableStart;

                                        Sheet.GetRow(rowstart).GetCell(0).SetCellValue(y + "年");
                                        y++;
                                    }

                                    if (i != 0 && i % group == 0)
                                    {
                                        utils.CopyRange(sheet as XSSFSheet, _Sheet as XSSFSheet,
                                                            _TableStart + 1, _RowEnd + 1, 1, _ColumnEnd + 1,
                                                            rowstart, 0);

                                        Sheet.GetRow(rowstart).GetCell(0).SetCellValue(y + "年");
                                        y++;
                                    }

                                    IRow nowRow = Sheet.GetRow(rowstart++);
                                    int nowCol = 2;
                                    for (int j = 6; j < dt.Columns.Count; j++)
                                    {
                                        if (nowCol > _ColumnEnd)
                                            break;

                                        ICell nowCell = nowRow.CreateCell(nowCol);
                                        string svalue = dt.Rows[i]["欄位" + j].ToString();
                                        Decimal ivalue;
                                        if (Decimal.TryParse(svalue, out ivalue))
                                        {
                                            decimal value = Convert.ToDecimal(svalue);

                                            if (svalue.Split('.').Length > 1)
                                                nowCell.SetCellValue(value.ToString());
                                            else if (value == 0)
                                                nowCell.SetCellValue(value.ToString());
                                            else
                                                nowCell.SetCellValue(value.ToString("###,###"));

                                            nowCell.CellStyle = styleRight;
                                        }
                                        else
                                        {
                                            nowCell.SetCellValue("-");
                                            nowCell.CellStyle = styleRight;
                                        }

                                        nowCol++;
                                    }
                                }
                            }
                        }

                        String GUID = Guid.NewGuid().ToString();
                        string strExcel = HttpContext.Current.Server.MapPath(".\\ExportYearReport\\" + GUID + ".xlsx");
                        fileName = GUID;
                        FileStream file = new FileStream(strExcel, FileMode.Create); //產生檔案
                        workbook.Write(file);
                        file.Close();
                        string strFullDirectoryPath = HttpContext.Current.Server.MapPath(".\\ExportYearReport\\");

                        using (Process exeProcess = Process.Start(GetConvertInfo(System.Configuration.ConfigurationManager.AppSettings["SofficePath"], strFullDirectoryPath, strExcel, 2)))
                        {
                            exeProcess.WaitForExit();
                        }
                        GC.Collect();
                    }
                }
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            return fileName;
        }

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

        public void SetFields(Dictionary<String, Object> def)
        {
            if (def != null)
            {
                if (def.ContainsKey("YEAR"))
                {
                    _Year = (Int32)def["YEAR"];
                }
                if (def.ContainsKey("MONTH"))
                {
                    _Month = (Int32)def["MONTH"];
                }
                if (def.ContainsKey("MONTH"))
                {
                    _Month = (Int32)def["MONTH"];
                }
                if (def.ContainsKey("$$STAT_CLASS$$"))
                {
                    _StatClass = (Int32)def["$$STAT_CLASS$$"];
                }
                if (def.ContainsKey("FIELDS_NAME"))
                {
                    _FieldsName = def["FIELDS_NAME"] as List<String>;
                }
                if (def.ContainsKey("FIELDS_INDEX"))
                {
                    _FieldsIndex = def["FIELDS_INDEX"] as List<Int32>;
                }
            }
        }

        public String Name
        {
            get { return _Name; }
        }

        public ISheet Sheet
        {
            get { return _Sheet; }
        }

        public String Html
        {
            get { return _Html; }
        }

        public List<String> FieldsName
        {
            get { return _FieldsName; }
        }

        public List<Int32> FieldsIndex
        {
            get { return _FieldsIndex; }
        }

        public Int32 Year
        {
            get { return _Year; }
        }

        public Int32 Month
        {
            get { return _Month; }
        }

        public Int32 StatClass
        {
            get { return _StatClass; }
        }

        public Int32 RowEnd
        {
            set { _RowEnd = value; }
            get { return _RowEnd; }
        }

        public Int32 ColumnEnd
        {
            set { _ColumnEnd = value; }
            get { return _ColumnEnd; }
        }

        public Boolean HasTitle
        {
            get { return (_TitleStart <= _TitleEnd); }
        }

        public Int32 TitleLength
        {
            get { return (HasTitle ? (TitleEnd - TitleStart + 1) : -1); }
        }

        public Int32 TitleStart
        {
            set { _TitleStart = value; }
            get { return _TitleStart; }
        }

        public Int32 TitleEnd
        {
            set { _TitleEnd = value; }
            get { return _TitleEnd; }
        }

        public Boolean HasHeader
        {
            get { return (_HeaderStart <= _HeaderEnd); }
        }

        public Int32 HeaderLength
        {
            get { return (HasHeader ? (HeaderEnd - HeaderStart + 1) : -1); }
        }

        public Int32 HeaderStart
        {
            set { _HeaderStart = value; }
            get { return _HeaderStart; }
        }

        public Int32 HeaderEnd
        {
            set { _HeaderEnd = value; }
            get { return _HeaderEnd; }
        }

        public Boolean HasDataRow
        {
            get { return (_DataRow >= 0); }
        }

        public Int32 DataRow
        {
            set { _DataRow = value; }
            get { return _DataRow; }
        }

        public Boolean HasTable
        {
            get { return (_TableStart >= 0 && _TableEnd >= 0); }
        }

        public Int32 TableLength
        {
            get { return (HasTable ? (TableEnd - TableStart + 1) : -1); }
        }

        public Int32 TableStart
        {
            set { _TableStart = value; }
            get { return _TableStart; }
        }

        public Int32 TableEnd
        {
            set { _TableEnd = value; }
            get { return _TableEnd; }
        }

        public void SetName(String name)
        {
            _Name = name;
        }

    }
}
