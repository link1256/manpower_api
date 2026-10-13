using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Text;
using System.Web;

namespace Supergeo.StatUtils
{
    public class ManPowerProcess
    {
        public delegate void MessageEventHandler(String data);
        public event MessageEventHandler Message = null;
        public delegate void ProgressEventHandler(ProgressItem item);
        public event ProgressEventHandler Progress = null;
        public delegate void FinishedEventHandler(FinishItem item);
        public event FinishedEventHandler Finished = null;

        private String _UniqueID = null;
        private String _ConnectionString = null;
        private String _MetadataTable = null;
        private String _MetadataSource = null;
        private String _DataValueTable = null;
        private String _DataValueSeparator = null;
        private Layout _Layout = null;
        private Metadata _Metadata = null;
        private DateTime? _DateRangeStart = null;
        private DateTime? _DateRangeEnd = null;
        private List<Int32> _CountyFilter = null;
        private Int32 _BatchLimit = 1000;
        private String[] _DataRows = null;
        private SqlConnection _ImportConnection = null;
        private SqlTransaction _ImportTransaction = null;
        private FinishItem _ImportResult = null;

        private Boolean _UserBreaking = false;

        private Boolean _DisplayIgnoreMessage = false;
        private String _IgnoreYear = null;
        private String _IgnoreMonth = null;
        private String _IgnoreCounty = null;

        public Boolean DisplayIgnoreMessage
        {
            get { return _DisplayIgnoreMessage; }
            set { _DisplayIgnoreMessage = value; }
        }

        public ManPowerProcess()
        {
            _CountyFilter = new List<Int32>();
        }

        public ManPowerProcess(String strDB)
            :this()
        {
            _ConnectionString = strDB;
        }

        ~ManPowerProcess()
        {
            Clear();
        }

        private void Clear()
        {
            _ConnectionString = null;
            _MetadataTable = null;
            _DataValueTable = null;
            _Layout = null;
        }

        public void SetUniqueID(String strID)
        {
            _UniqueID = strID;
        }

        public String GetUniqueID()
        {
            return _UniqueID;
        }

        public void BreakProcess()
        {
            _UserBreaking = true;
        }

        public Boolean SetMetadataTable(String strTableMetadata, String strTableSource)
        {
            if (_ConnectionString == null)
                return false;
            Boolean bRc = false;
            try
            {
                Int32 metadataCount = 0;
                _Metadata = new Metadata();
                using (SqlConnection conn = new SqlConnection(_ConnectionString))
                {
                    String strSQL = String.Format("SELECT * FROM {0} WHERE [SOURCE_TB] = '{1}';", strTableMetadata, strTableSource);
                    if (conn.State != ConnectionState.Open)
                    {
                        conn.Open();
                    }
                    using (SqlCommand command = new SqlCommand(strSQL, conn))
                    {
                        command.CommandTimeout = 300;
                        using (SqlDataReader dr = command.ExecuteReader())
                        {
                            Int32 nCardNum = dr.GetOrdinal("CARD_NUM");
                            Int32 nColNum = dr.GetOrdinal("COL_NUM");
                            Int32 nStatID = dr.GetOrdinal("STATID");
                            Int32 nSourceTB = dr.GetOrdinal("SOURCE_TB");
                            Int32 nDescFull = dr.GetOrdinal("DES_FULL");
                            while ((dr.Read()))
                            {
                                metadataCount++;
                                String strCardNum = (dr[nCardNum] as String).Trim();
                                String strColNum = (dr[nColNum] as String).Trim();
                                String strStatID = (dr[nStatID] as String).Trim();
                                String strSourceTB = (dr[nSourceTB] as String).Trim();
                                String strDescFull = (dr[nDescFull] as String).Trim();
                                _Metadata.Add(new Dictionary<String, String>()
                                {
                                    { "CardNum", strCardNum },
                                    { "ColNum", strColNum},
                                    { "StatID", strStatID},
                                    { "SourceTB", strSourceTB},
                                    { "DescFull", strDescFull}
                                });
                            }
                        }
                    }
                    conn.Close();
                    if (metadataCount == 0)
                        throw new InvalidOperationException("No import mappings were found.");
                    _MetadataTable = strTableMetadata;
                    _MetadataSource = strTableSource;
                    if (Message != null)
                        Message(String.Format("Metadata : {0} 已載入.", _MetadataTable));
                    bRc = true;
                }
            }
            catch (Exception ex)
            {
            }
            return bRc;
        }

        public Int32 SetCountyFilter(String strFilter)
        {
            _CountyFilter.Clear();
            if (strFilter != null)
            {
                String[] saParts = strFilter.Split(new Char[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries);
                if (saParts.Length > 0)
                {
                    foreach (String str in saParts)
                    {
                        Int32 nV;
                        if (Int32.TryParse(str.Trim(), out nV))
                        {
                            if (nV > 0)
                            {
                                _CountyFilter.Add(nV);
                            }
                        }
                    }
                }
            }
            return _CountyFilter.Count;
        }

        public DateTime? SetStartYearMonth(String strYearMonth)
        {
            _DateRangeStart = null;
            if (strYearMonth != null && strYearMonth.Length > 0)
            {
                String[] saParts = strYearMonth.Split(new Char[] { '/' }, StringSplitOptions.None);
                if (saParts.Length == 2)
                {
                    Int32 nYear;
                    Int32 nMonth = 0;
                    if (Int32.TryParse(saParts[0], out nYear))
                    {
                        if (nYear > 0)
                        {
                            Int32 nV;
                            if (Int32.TryParse(saParts[1], out nV))
                            {
                                nMonth = nV;
                            }
                            if (nMonth > 0 && nMonth <= 12)
                            {
                                _DateRangeStart = new DateTime(nYear, nMonth, 1);
                            }
                            else
                            {
                                _DateRangeStart = new DateTime(nYear, 1, 1);
                            }
                        }
                    }
                }
            }
            return _DateRangeStart;
        }

        public DateTime? SetEndYearMonth(String strYearMonth)
        {
            _DateRangeEnd = null;
            if (strYearMonth != null && strYearMonth.Length > 0)
            {
                String[] saParts = strYearMonth.Split(new Char[] { '/' }, StringSplitOptions.None);
                if (saParts.Length == 2)
                {
                    Int32 nYear;
                    Int32 nMonth = 0;
                    if (Int32.TryParse(saParts[0], out nYear))
                    {
                        if (nYear > 0)
                        {
                            Int32 nV;
                            if (Int32.TryParse(saParts[1], out nV))
                            {
                                nMonth = nV;
                            }
                            if (nMonth > 0 && nMonth <= 12)
                            {
                                _DateRangeEnd = new DateTime(nYear, nMonth, 1).AddMonths(1).AddDays(-1);
                            }
                            else
                            {
                                _DateRangeEnd = new DateTime(nYear, 12, 31);
                            }
                        }
                    }
                }
            }
            return _DateRangeEnd;
        }

        public Int32 SetBatchLimit(int nBatchLimit)
        {
            if (nBatchLimit > 0)
                _BatchLimit = nBatchLimit;
            if (Message != null)
                Message(String.Format("批次寫入數量 = {0} ", _BatchLimit));
            return _BatchLimit;
        }

        public Boolean SetDataValueTable(string strTableDataValue)
        {
            if (_ConnectionString == null)
                return false;
            Boolean bRc = false;
            try
            {
                using (SqlConnection conn = new SqlConnection(_ConnectionString))
                {
                    String strSQL = String.Format("SELECT * FROM {0} WHERE 1=2;", strTableDataValue);
                    if (conn.State != ConnectionState.Open)
                    {
                        conn.Open();
                    }
                    using (SqlCommand command = new SqlCommand(strSQL, conn))
                    {
                        using (SqlDataAdapter adapter = new SqlDataAdapter(command))
                        {
                        }
                    }
                    conn.Close();
                    _DataValueTable = strTableDataValue;
                    bRc = true;
                }
            }
            catch (Exception ex)
            {
            }
            return bRc;
        }

        public Boolean LoadLayout(String strFile, LayoutTypeEnum layoutType)
        {
            Boolean bRc = false;
            if (_ConnectionString != null && _MetadataTable != null 
                && _DataValueTable != null)
            {
                if (File.Exists(strFile))
                {
                    String[] saRows = null;
                    if (layoutType == LayoutTypeEnum.Layout)
                    {
                        saRows = Utils.GetRows(strFile);
                    }
                    else if (layoutType == LayoutTypeEnum.Header)
                    {
                        String strRow = Utils.GetFirstRow(strFile);
                        saRows = strRow.Split(new Char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                        if (saRows.Length > 1)
                        {
                            _DataValueSeparator = ",";
                        }
                        else
                        {
                            saRows = strRow.Split(new Char[] { '\t' }, StringSplitOptions.RemoveEmptyEntries);
                            if (saRows.Length > 1)
                            {
                                _DataValueSeparator = "\t";
                            }
                        }
                    }
                    if (saRows != null && saRows.Length > 0)
                    {
                        _Layout = new Layout();
                        if (_Layout != null)
                        {
                            bRc = _Layout.Load(saRows, layoutType);
                        }
                    }
                    saRows = null;
                }
            }
            if (bRc)
            {
                if (Message != null)
                    Message.Invoke(String.Format("Layout : {0} 已載入.", Path.GetFileName(strFile)));
            }
            else
            {
                if (Message != null)
                    Message(String.Format("Layout : {0} 載入內容出問題.", Path.GetFileName(strFile)));
            }
            return bRc;
        }

        public List<String> LoadDataFile(String strDataFile, String strFormat = "yyyy/MM")
        {
            List<String> lstRc = new List<String>();

            if (_Layout != null)
            {
                if (_DataRows != null)
                {
                    _DataRows = null;
                }
                if (File.Exists(strDataFile))
                {
                    _DataRows = Utils.GetRows(strDataFile);
                    if (_DataRows.Length > 0)
                    {
                        String strRow = null;
                        LayoutTypeEnum layoutType = _Layout.LayoutType;
                        List<LayoutItem> layoutStats = _Layout.GetStats();
                        Boolean bBreak = true;
                        Int32 nTotalLines = _DataRows.Length;
                        for (Int32 i = 0; i < _DataRows.Length; i++)
                        {
                            try
                            {
                                strRow = _DataRows[i].Trim();
                            }
                            catch (Exception ex)
                            {
                            }
                            if (bBreak)
                            {
                                if (layoutType == LayoutTypeEnum.Header)
                                {
                                    // 由 Header 讀欄位
                                    String[] saValues = strRow.Split(new String[] { _DataValueSeparator }, StringSplitOptions.RemoveEmptyEntries);
                                    if (Utils.IsNumber(saValues[0]))
                                    {
                                        bBreak = false;
                                    }
                                }
                                else
                                {
                                    bBreak = false;
                                }
                                if (bBreak)
                                    continue;
                            }
                            StatData data = new StatData(_DataValueTable);
                            if (strRow != null && strRow.Length > 0)
                            {
                                String[] saValues = null;
                                if (layoutType == LayoutTypeEnum.Header)
                                {
                                    saValues = strRow.Split(new String[] { _DataValueSeparator }, StringSplitOptions.RemoveEmptyEntries);
                                }
                                String strVal = "";
                                for (Int32 s = 0; s < layoutStats.Count; s++)
                                {
                                    LayoutItem item = layoutStats[s];
                                    strVal = "";
                                    if (layoutType == LayoutTypeEnum.Layout)
                                    {
                                        strVal = HttpUtility.HtmlEncode(strRow.Substring(item.Start, item.Length).Trim());
                                    }
                                    else if (layoutType == LayoutTypeEnum.Header)
                                    {
                                        strVal = HttpUtility.HtmlEncode(saValues[item.Index]);
                                    }
                                    if (item.Tag == LayoutItemEnum.Year)
                                        data.Year = HttpUtility.HtmlEncode(strVal);
                                    else if (item.Tag == LayoutItemEnum.Month)
                                        data.Month = HttpUtility.HtmlEncode(strVal);
                                    else if (item.Tag == LayoutItemEnum.County)
                                        data.County = HttpUtility.HtmlEncode(strVal);
                                }
                                String strYM = ParseYearMonth(data);
                                if (strYM != null)
                                {
                                    if (!lstRc.Contains(strYM))
                                    {
                                        lstRc.Add(strYM);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if (lstRc.Count <= 0)
            {
                lstRc.Clear();
                lstRc = null;
            }
            else
            {
                lstRc.Sort();
            }
            return lstRc;
        }

        public Int32 ImportData(String strDataFile)
        {
            LoadDataFile(strDataFile);
            return ImportData();
        }

        public Int32 ImportData()
        {
            return ImportData(null, null);
        }

        public Int32 ImportData(DateTime? replaceStart, DateTime? replaceEnd)
        {
            if (_DataRows == null || _DataRows.Length == 0 || _MetadataTable == null
                || _DataValueTable == null || _Layout == null)
                throw new InvalidOperationException("Import data and mappings must be loaded first.");
            if (replaceStart.HasValue != replaceEnd.HasValue
                || (replaceStart.HasValue && replaceStart.Value > replaceEnd.Value))
                throw new ArgumentException("Invalid replacement period.");

            _ImportResult = null;
            Int32 imported = 0;
            try
            {
                using (SqlConnection connection = new SqlConnection(_ConnectionString))
                {
                    connection.Open();
                    using (SqlTransaction transaction = connection.BeginTransaction())
                    {
                        _ImportConnection = connection;
                        _ImportTransaction = transaction;
                        try
                        {
                            if (replaceStart.HasValue)
                            {
                                using (SqlCommand command = connection.CreateCommand())
                                {
                                    command.Transaction = transaction;
                                    command.CommandTimeout = 300;
                                    command.CommandText = "DELETE FROM [" + _DataValueTable.Replace("]", "]]")
                                        + "] WHERE (CAST(YEAR AS int) * 100 + CAST(MONTH AS int)) BETWEEN @Start AND @End";
                                    command.Parameters.AddWithValue("@Start", replaceStart.Value.Year * 100 + replaceStart.Value.Month);
                                    command.Parameters.AddWithValue("@End", replaceEnd.Value.Year * 100 + replaceEnd.Value.Month);
                                    command.ExecuteNonQuery();
                                }
                            }
                            imported = ImportDataCore();
                            if (_UserBreaking || imported <= 0)
                                throw new InvalidOperationException("Import was interrupted or produced no records.");
                            transaction.Commit();
                        }
                        finally
                        {
                            _ImportConnection = null;
                            _ImportTransaction = null;
                        }
                    }
                }
            }
            catch
            {
                if (Finished != null)
                    Finished.Invoke(new FinishItem() { UniqueID = _UniqueID, UserBreak = 1 });
                throw;
            }
            if (_ImportResult != null && Finished != null)
                Finished.Invoke(_ImportResult);
            return imported;
        }

        private Int32 ImportDataCore()
        {
            Int32 nRc = 0;
            if (_DataRows != null && _DataRows.Length > 0)
            {
                _UserBreaking = false;
                Int32 nTotalLines = 0;
                DateTime dtStart = new DateTime(2100, 1, 1);
                DateTime dtEnd = new DateTime(1900, 1, 1);

                if (_ConnectionString != null && _MetadataTable != null
                    && _DataValueTable != null && _Layout != null)
                {
                    _IgnoreYear = "";
                    _IgnoreMonth = "";
                    _IgnoreCounty = "";

                    String strRow = null;
                    LayoutTypeEnum layoutType = _Layout.LayoutType;
                    List<LayoutItem> layoutStats = _Layout.GetStats();
                    LayoutItem cardItem = _Layout.GetCard();
                    List<LayoutItem> layoutItems = _Layout.GetItems();
                    List<Object> lstSQL = new List<Object>();
                    Int32 nBatchCount = 0;
                    Boolean bBreak = true;
                    nTotalLines = _DataRows.Length;
                    for (Int32 i = 0; i < _DataRows.Length; i++)
                    {
                        try
                        {
                            strRow = _DataRows[i].Trim();
                        }
                        catch (Exception ex)
                        {
                            _UserBreaking = true;
                            WriteLog("匯入時出現錯誤:" + ex.ToString());
                        }
                        if (bBreak)
                        {
                            if (layoutType == LayoutTypeEnum.Header)
                            {
                                // 由 Header 讀欄位
                                String[] saValues = strRow.Split(new String[] { _DataValueSeparator }, StringSplitOptions.RemoveEmptyEntries);
                                if (Utils.IsNumber(saValues[0]))
                                {
                                    bBreak = false;
                                }
                            }
                            else
                            {
                                bBreak = false;
                            }
                            if (bBreak)
                                continue;
                        }

                          StatData data = new StatData(_DataValueTable);
                        if (strRow != null && strRow.Length > 0)
                        {
                            String[] saValues = null;
                            if (layoutType == LayoutTypeEnum.Header)
                            {
                                saValues = strRow.Split(new String[] { _DataValueSeparator }, StringSplitOptions.RemoveEmptyEntries);
                            }
                            String strVal = "";
                            for (Int32 s = 0; s < layoutStats.Count; s++)
                            {
                                LayoutItem item = layoutStats[s];
                                strVal = "";
                                if (layoutType == LayoutTypeEnum.Layout)
                                {
                                    strVal = HttpUtility.HtmlEncode(strRow.Substring(item.Start, item.Length).Trim());
                                }
                                else if (layoutType == LayoutTypeEnum.Header)
                                {
                                    strVal = HttpUtility.HtmlEncode(saValues[item.Index]);
                                }

                                if (item.Tag == LayoutItemEnum.Year)
                                    data.Year = HttpUtility.HtmlEncode(strVal);
                                else if (item.Tag == LayoutItemEnum.Month)
                                    data.Month = HttpUtility.HtmlEncode(strVal);
                                else if (item.Tag == LayoutItemEnum.County)
                                    data.County = HttpUtility.HtmlEncode(strVal);
                            }
                            DateTime? dtCurrent;
                            if (InsideRange(data, out dtCurrent))
                            {
                                if (dtCurrent != null && dtCurrent.HasValue)
                                {
                                    if (dtCurrent.Value < dtStart) dtStart = dtCurrent.Value;
                                    if (dtCurrent.Value > dtEnd) dtEnd = dtCurrent.Value;
                                }
                                for (Int32 s = 0; s < layoutItems.Count; s++)
                                {
                                    String strCard = "";
                                    LayoutItem item = layoutItems[s];
                                    strVal = "";
                                    if (layoutType == LayoutTypeEnum.Layout)
                                    {
                                        strCard = HttpUtility.HtmlEncode(strRow.Substring(cardItem.Start, cardItem.Length).Trim());
                                        strVal = HttpUtility.HtmlEncode(strRow.Substring(item.Start, item.Length).Trim());
                                    }
                                    else if (layoutType == LayoutTypeEnum.Header)
                                    {
                                        strCard = HttpUtility.HtmlEncode(saValues[cardItem.Index]);
                                        strVal = HttpUtility.HtmlEncode(saValues[item.Index]);
                                    }

                                    if (item.Tag == LayoutItemEnum.Item)
                                    {
                                        Boolean bW;
                                        Int32 nCard = Utils.ToNumber(strCard, out bW);
                                        String strStatID = _Metadata.GetStatID(nCard.ToString(), item.Value.ToString());
                                        if (strStatID.Length > 0)
                                        {
                                            data.StatID = strStatID;
                                            Int32 nV;
                                            if (Int32.TryParse(strVal, out nV))
                                            {
                                                lstSQL.Add(data.GetInsertSQL(nV));
                                                nBatchCount++;
                                            }
                                            else
                                                throw new FormatException("Invalid value at line " + (i + 1)
                                                    + ", card " + strCard + ", column " + item.Value + ".");
                                        }
                                    }
                                }
                            }
                            else
                            {
                                if (_DisplayIgnoreMessage &&
                                    _IgnoreYear != data.Year || _IgnoreMonth != data.Month ||
                                    (_CountyFilter.Count > 0 && _IgnoreCounty != data.County))
                                {
                                    _IgnoreYear = data.Year;
                                    _IgnoreMonth = data.Month;
                                    _IgnoreCounty = data.County;
                                    if (Message != null)
                                        Message.Invoke(String.Format("略過 {0}/{1} (縣市 {2}).", _IgnoreYear, _IgnoreMonth, _IgnoreCounty));
                                }
                            }
                        }

                        if (nBatchCount >= _BatchLimit)
                        {
                            nRc += InsertStatData(_DataValueTable, lstSQL);
                            lstSQL.Clear();
                            nBatchCount = 0;
                            if (Progress != null)
                                Progress.Invoke(new ProgressItem(_UniqueID, i + 1, _DataRows.Length, nRc));
                        }

                        if (i % 999 == 0 || i + 1 == _DataRows.Length)
                        {
                            WriteLog(String.Format("處理 {0} 筆", i + 1));
                        }

                        if (_UserBreaking)
                        {
                            if (Message != null)
                            {
                                WriteLog("發生錯誤中斷匯入.");
                            }
                            // Message.Invoke(String.Format("使用者中斷作業!"));
                            break;
                        }
                    }
                    if (nBatchCount > 0)
                    {
                        nRc += InsertStatData(_DataValueTable, lstSQL);
                        lstSQL.Clear();
                        nBatchCount = 0;
                        if (Progress != null)
                            Progress.Invoke(new ProgressItem(_UniqueID, _DataRows.Length, _DataRows.Length, nRc));
                    }
                }
                _ImportResult = new FinishItem(_UniqueID, _UserBreaking ? 1 : 0, _MetadataSource, nTotalLines, nRc, dtStart.Year, dtStart.Month, dtEnd.Year, dtEnd.Month);
            }
            return nRc;
        }

        private String ParseYearMonth(StatData data, String strFormat = "yyyyMM")
        {
            String strYearMonth = null;
            Int32 nYear = 0;
            if (data.Year != null && data.Year.Length > 0)
                nYear = Convert.ToInt32(data.Year);

            Int32 nMonth = 0;
            if (data.Month != null && data.Month.Length > 0)
                nMonth = Convert.ToInt32(data.Month);

            if (nYear != 0 && nMonth != 0)
            {
                DateTime dtData = new DateTime(nYear, nMonth, 15);
                strYearMonth = dtData.ToString(strFormat);
            }

            return strYearMonth;
        }

        private Boolean InsideRange(StatData data, out DateTime? dtCurrent)
        {
            Boolean bRc = true;

            Int32 nYear = 0;
            if (data.Year != null && data.Year.Length > 0)
                nYear = Convert.ToInt32(data.Year);
            Int32 nMonth = 0;
            if (data.Month != null && data.Month.Length > 0)
                nMonth = Convert.ToInt32(data.Month);
            DateTime dtData = new DateTime(nYear, nMonth, 15);
            dtCurrent = dtData;
            if (_DateRangeStart != null && _DateRangeEnd != null)
            {
                // 同時設定起始與結束的年月.
                if (nYear > 0 && nMonth > 0)
                {
                    // 同時有年月
                    if (dtData < _DateRangeStart.Value || dtData > _DateRangeEnd.Value)
                    {
                        bRc = false;
                    }
                }
            }
            else if (_DateRangeStart != null)
            {
                // 只設定起始的年月.
                if (nYear > 0 && nMonth > 0)
                {
                    // 同時有年月
                    if (dtData < _DateRangeStart.Value)
                    {
                        bRc = false;
                    }
                }
            }
            else if (_DateRangeEnd != null)
            {
                // 只設定結束的年月.
                if (nYear > 0 && nMonth > 0)
                {
                    // 同時有年月
                    if (dtData > _DateRangeEnd.Value)
                    {
                        bRc = false;
                    }
                }
            }

            if (_CountyFilter.Count > 0)
            {
                Int32 nCounty = 0;
                if (data.County != null && data.County.Length > 0)
                    nCounty = Convert.ToInt32(data.County);

                if (nCounty > 0 && !_CountyFilter.Contains(nCounty))
                {
                    bRc = false;
                }
            }
            return bRc;
        }

        private Int32 InsertStatData(String strTable, List<Object> lstSQL)
        {
            Int32 nRc = 0;
            if (_ImportConnection == null || _ImportTransaction == null)
                throw new InvalidOperationException("An import transaction is required.");
            using (SqlCommand cmd = _ImportConnection.CreateCommand())
            {
                cmd.CommandTimeout = 300;
                cmd.CommandType = CommandType.Text;
                cmd.Transaction = _ImportTransaction;
                foreach (Object obj in lstSQL)
                {
                    cmd.Parameters.Clear();
                    Dictionary<String, Object> param = obj as Dictionary<String, Object>;
                    if (param != null)
                    {
                        List<String> lstColumns = new List<String>();
                        List<String> lstParams = new List<String>();
                        foreach (String key in param.Keys)
                        {
                            lstColumns.Add(key);
                            lstParams.Add("@" + key);
                            cmd.Parameters.Add(new SqlParameter("@" + key, param[key]));
                        }
                        cmd.CommandText = "INSERT INTO [" + strTable.Replace("]", "]]") + "] ("
                            + String.Join(",", lstColumns) + ") VALUES (" + String.Join(",", lstParams) + ");";
                        nRc += cmd.ExecuteNonQuery();
                    }
                }
            }
            return nRc;
        }
        public void WriteLog(String logMsg)
        {
            string ppath = System.AppDomain.CurrentDomain.BaseDirectory;
            string logPath = ppath + "/Log/Jerry/Export/";
            String logFileName = DateTime.Now.Year.ToString() + int.Parse(DateTime.Now.Month.ToString()).ToString("00") + int.Parse(DateTime.Now.Day.ToString()).ToString("00") + ".txt";
            String nowTime = int.Parse(DateTime.Now.Hour.ToString()).ToString("00") + ":" + int.Parse(DateTime.Now.Minute.ToString()).ToString("00") + ":" + int.Parse(DateTime.Now.Second.ToString()).ToString("00");

            if (!Directory.Exists(logPath))
            {
                //建立資料夾
                Directory.CreateDirectory(logPath);
            }

            if (!File.Exists(logPath + "\\" + logFileName))
            {
                //建立檔案
                File.Create(logPath + "\\" + logFileName).Close();
            }

            using (StreamWriter sw = File.AppendText(logPath + "\\" + logFileName))
            {
                sw.WriteLine("--執行時間 " + nowTime + "--");
                sw.WriteLine(logMsg);
                sw.WriteLine();
                sw.WriteLine("-------------------------------");
                sw.WriteLine();
            }
        }
    }
}
