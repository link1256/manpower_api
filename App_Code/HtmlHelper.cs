using HtmlAgilityPack;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;

namespace Supergeo.Utilities
{
    public class HtmlHelper : IDisposable
    {
        private StatCondition _StatCondition = null;
        private DataTable _DataTable = null;
        
        public HtmlHelper()
        {
            Init();
        }

        public void Dispose()
        {
            if (_StatCondition != null)
            {
                _StatCondition = null;
            }
            if (_DataTable != null)
            {
                _DataTable = null;
            }
        }

        private void Init()
        {
            _StatCondition = null;
            _DataTable = null;
        }

        public void SetStatCondition(StatCondition stat)
        {
            _StatCondition = stat;
        }

        public List<int> SetDataTable(DataTable table)
        {
            _DataTable = table;
            List<int> Decimals = new List<int>();
            if (_DataTable != null && _DataTable.Rows.Count > 0)
            {
                Boolean bFloat = false;
                Int32 nColumns = _DataTable.Columns.Count;
                DataRow row = _DataTable.Rows[0];
                
                for (Int32 i = 6; i < nColumns; i++)
                {
                    Object obj = row[i];
                    if (obj is String)
                    {
                        String strVal = obj as String;
                        if (strVal != null && strVal.Length > 0 && strVal.IndexOf(".") > 0)
                        {
                            Decimals.Add(2);
                            _StatCondition.Decimals = 2;
                        }
                        else
                        {
                            Decimals.Add(0);
                        }
                    }
                }
                if (bFloat)
                {
                    _StatCondition.Decimals = 2;
                }
                else
                {
                    _StatCondition.Decimals = 0;
                }
            }
            return Decimals;
        }

        private void ProcessRow(HtmlDocument htmlDoc)
        {
            var titleNode = htmlDoc.DocumentNode.SelectSingleNode("//table[contains(@class, 'tableTitle')]");
            if (titleNode != null)
            {
                var titleText = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleText')]");
                if (titleText != null)
                {
                    ReplaceTitleText(titleText);
                }
                var titleRange = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleRange')]");
                if (titleRange != null)
                {
                    ReplaceTitleRange(titleRange);
                }
                var titleUnit = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleUnit')]");
                if (titleUnit != null)
                {
                    ReplaceTitleUnit(titleUnit);
                }
            }
            var dataNode = htmlDoc.DocumentNode.SelectSingleNode("//table[contains(@class, 'tableData')]");
            if (dataNode != null)
            {
                HtmlNodeCollection repeatHead = new HtmlNodeCollection(htmlDoc.DocumentNode);
                // 找出 Table 之中的 thead
                var dataHead = dataNode.SelectSingleNode("thead");
                if (dataHead != null)
                {
                    // TODO : 套用新的 css
                    dataHead.SetAttributeValue("class", "newCssThead");

                    // 找出 thead 之中的 headerMain (只有一格)
                    var headerMain = dataHead.SelectSingleNode("tr/td[contains(@class, 'headerMain')]");
                    if (headerMain != null)
                    {
                        // TODO : 套用新的 css
                        //headerMain.SetAttributeValue("class", "newCssHeaderMain");
                    }
                    var heads = dataHead.SelectNodes("tr");
                    for (Int32 h = 0; h < heads.Count; h++)
                    {
                        heads[h].SetAttributeValue("class", "newCssThead");
                        repeatHead.Add(heads[h].Clone());
                    }
                }
                // 找出資料列
                var dataBody = dataNode.SelectSingleNode("tbody");
                if (dataBody != null)
                {
                    var dataRows = dataBody.SelectNodes("tr");
                    // 一筆 Row : 循序填寫 [年 / 年月 / 年月+平均] 資料
                    var templateRow = dataRows[0].Clone();
                    dataBody.RemoveAll();
                    Int32 nRows = 0;
                    for (Int32 r = 0; r < _DataTable.Rows.Count; r++)
                    {
                        DataRow row = _DataTable.Rows[r];

                        var newRow = templateRow.Clone();
                        var newCols = newRow.SelectNodes("td");
                        for (Int32 c = 0; c < newCols.Count; c++)
                        {
                            String strText = newCols[c].InnerHtml;
                            // TODO : 替換對應的文字
                            if (String.Compare("YEAR", strText, true) == 0)
                            {
                                Int32 nYear = (Int32)row["欄位1"] - 1911;
                                strText = nYear.ToString() + "年"; ;
                            }
                            else if (String.Compare("MONTH", strText, true) == 0)
                            {
                                Int32 nMonth = (Int32)row["欄位2"];
                                if (nMonth == 0)
                                {
                                    strText = "平均";
                                }
                                else
                                {
                                    strText = nMonth.ToString() + "月";
                                }
                            }
                            else if (strText.StartsWith("欄位"))
                            {
                                if (row != null)
                                {
                                    string svalue = row[strText].ToString();
                                    decimal value;
                                    if (Decimal.TryParse(svalue, out value))
                                    {
                                        if (svalue.Split('.').Length > 1)
                                            strText = value.ToString();
                                        else if (value == 0)
                                            strText = value.ToString();
                                        else
                                            strText = value.ToString("###,###");
                                    }
                                    else
                                    {
                                        strText = "-";
                                    }
                                }
                                else
                                {
                                    strText = "-";
                                }
                            }
                            else
                            {
                                strText = "";
                            }
                            newCols[c].InnerHtml = strText;
                        }
                        dataBody.AppendChild(newRow);
                        nRows++;
                    }
                }
            }
        }

        private void ProcessRow2(HtmlDocument htmlDoc)
        {
            var titleNode = htmlDoc.DocumentNode.SelectSingleNode("//table[contains(@class, 'tableTitle')]");
            if (titleNode != null)
            {
                var titleText = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleText')]");
                if (titleText != null)
                {
                    ReplaceTitleText(titleText);
                }
                var titleRange = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleRange')]");
                if (titleRange != null)
                {
                    ReplaceTitleRange(titleRange);
                }
                var titleUnit = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleUnit')]");
                if (titleUnit != null)
                {
                    ReplaceTitleUnit(titleUnit);
                }
            }
            var dataNode = htmlDoc.DocumentNode.SelectSingleNode("//table[contains(@class, 'tableData')]");
            if (dataNode != null)
            {
                HtmlNodeCollection repeatHead = new HtmlNodeCollection(htmlDoc.DocumentNode);
                // 找出 Table 之中的 thead
                var dataHead = dataNode.SelectSingleNode("thead");
                if (dataHead != null)
                {
                    // TODO : 套用新的 css
                    dataHead.SetAttributeValue("class", "newCssThead");

                    // 找出 thead 之中的 headerMain (只有一格)
                    var headerMain = dataHead.SelectSingleNode("tr/td[contains(@class, 'headerMain')]");
                    if (headerMain != null)
                    {
                        // TODO : 套用新的 css
                        //headerMain.SetAttributeValue("class", "newCssHeaderMain");
                    }
                    var heads = dataHead.SelectNodes("tr");
                    for (Int32 h = 0; h < heads.Count; h++)
                    {
                        heads[h].SetAttributeValue("class", "newCssThead");
                        repeatHead.Add(heads[h].Clone());
                    }
                }
                // 找出資料列
                var dataBody = dataNode.SelectSingleNode("tbody");
                if (dataBody != null)
                {
                    var dataRows = dataBody.SelectNodes("tr");
                    // 一筆 Row : 循序填寫 [年 / 年月 / 年月+平均] 資料
                    var oriRow = dataRows[0].Clone();
                    var oriCols = oriRow.SelectNodes("td");
                    
                    dataBody.RemoveAll();
                    Int32 nRows = 0;
                    for (Int32 r = 0; r < _DataTable.Rows.Count; r++)
                    {
                        var templateRow = dataRows[r % dataRows.Count].Clone();
                        DataRow row = _DataTable.Rows[r];

                        var newRow = templateRow.Clone();
                        var newCols = newRow.SelectNodes("td");
                        for (Int32 c = 0; c < newCols.Count; c++)
                        {
                            String strText = "";
                            if (c < oriCols.Count - newCols.Count)
                            {
                                strText = newCols[c].InnerHtml;
                            }
                            else
                            {
                                strText = oriCols[c + (oriCols.Count - newCols.Count)].InnerHtml;
                            }
                            // TODO : 替換對應的文字
                            if (strText.StartsWith("欄位"))
                            {
                                if (row != null)
                                {
                                    string svalue = row[strText].ToString();
                                    decimal value;
                                    if (Decimal.TryParse(svalue, out value))
                                    {
                                        if (svalue.Split('.').Length > 1)
                                            strText = value.ToString();
                                        else if (value == 0)
                                            strText = value.ToString();
                                        else
                                            strText = value.ToString("###,###");
                                    }
                                    else
                                    {
                                        strText = "-";
                                    }
                                }
                                else
                                {
                                    strText = "-";
                                }
                            }
                            else if (strText.StartsWith("CLASS_YEAR"))
                            {
                                if (nRows < _DataTable.Rows.Count)
                                {
                                    Int32 nYear = Convert.ToInt32(_DataTable.Rows[nRows]["欄位1"]);
                                    strText = (nYear - 1911).ToString() + "年";
                                }
                            }
                            newCols[c].InnerHtml = strText;
                        }
                        dataBody.AppendChild(newRow);
                        nRows++;
                    }
                }
            }
        }

        private void ProcessTable(HtmlDocument htmlDoc)
        {
            Int32 nRows = 0;
            var bodyNode = htmlDoc.DocumentNode.SelectSingleNode("//body");
            var tableOuterDivNode = htmlDoc.DocumentNode.SelectSingleNode("//div");
            // 樣版內容
            var templateTitleNode = bodyNode.SelectSingleNode("table[contains(@class, 'tableTitle')]").Clone();
            var templateDataNode = tableOuterDivNode.SelectSingleNode("table[contains(@class, 'tableData')]").Clone();
            // 由輸出檔移除
            bodyNode.RemoveChild(bodyNode.SelectSingleNode("table[contains(@class, 'tableTitle')]"));
            tableOuterDivNode.RemoveChild(tableOuterDivNode.SelectSingleNode("table[contains(@class, 'tableData')]"));
            // 依照所有的資料列填值.
            while (nRows < _DataTable.Rows.Count)
            {
                var titleNode = templateTitleNode.Clone();
                if (titleNode != null && nRows == 0)
                {
                    if (nRows > 0 && _StatCondition.NextPartNode != null)
                    {
                        try
                        {
                            HtmlNode node = HtmlNode.CreateNode(_StatCondition.NextPartNode);
                            if (node != null)
                            {
                                bodyNode.AppendChild(node);
                            }
                        }
                        catch (Exception)
                        {
                        }
                    }
                    var titleText = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleText')]");
                    if (titleText != null)
                    {
                        ReplaceTitleText(titleNode);
                    }
                    var titleRange = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleRange')]");
                    if (titleRange != null)
                    {
                        Int32 nYear = Convert.ToInt32(_DataTable.Rows[nRows]["欄位1"]);
                        ReplaceTitleRange(titleRange, nYear - 1911);
                    }
                    var titleUnit = titleNode.SelectSingleNode("tbody/tr/td[contains(@class, 'titleUnit')]");
                    if (titleUnit != null)
                    {
                        ReplaceTitleUnit(titleUnit);
                    }
                    bodyNode.AppendChild(titleNode);
                }
                var dataNode = templateDataNode.Clone();
                if (dataNode != null)
                {
                    HtmlNodeCollection repeatHead = new HtmlNodeCollection(htmlDoc.DocumentNode);
                    // 找出 Table 之中的 thead
                    var dataHead = dataNode.SelectSingleNode("thead");
                    if (dataHead != null)
                    {
                        // TODO : 套用新的 css
                        dataHead.SetAttributeValue("class", "newCssThead");

                        // 找出 thead 之中的 headerMain (只有一格)
                        var headerMain = dataHead.SelectSingleNode("tr/td[contains(@class, 'headerMain')]");
                        if (headerMain != null)
                        {
                            // TODO : 套用新的 css
                            //headerMain.SetAttributeValue("class", "newCssHeaderMain");
                        }
                        var heads = dataHead.SelectNodes("tr");
                        for (Int32 h = 0; h < heads.Count; h++)
                        {
                            repeatHead.Add(heads[h].Clone());
                        }
                    }
                    // 找出資料列
                    var dataBody = dataNode.SelectSingleNode("tbody");
                    if (dataBody != null)
                    {
                        var dataRows = dataBody.SelectNodes("tr");
                        // 多筆 Row : 固定統計類別項目
                        var oriRow = dataRows[0].Clone();
                        var oriCols = oriRow.SelectNodes("td");
                        for (Int32 r = 0; r < dataRows.Count; r++)
                        {
                            var templateRow = dataRows[r].Clone();
                            DataRow row = null;
                            if (nRows < _DataTable.Rows.Count)
                            {
                                row = _DataTable.Rows[nRows++];
                            }
                            var currentRow = dataRows[r];
                            var currentCols = currentRow.SelectNodes("td");

                            if (currentCols != null)
                            {
                                var newRow = templateRow.Clone();
                                var newCols = newRow.SelectNodes("td");
                                for (Int32 c = 0; c < currentCols.Count; c++)
                                {
                                    String strText = "";
                                    if (c < oriCols.Count - newCols.Count)
                                    {
                                        strText = newCols[c].InnerHtml;
                                    }
                                    else
                                    {
                                        strText = oriCols[c + (oriCols.Count - newCols.Count)].InnerHtml;
                                    }
                                    // TODO : 替換對應的文字
                                    if (strText.StartsWith("欄位"))
                                    {
                                        if (row != null)
                                        {
                                            strText = row[strText].ToString();
                                        }
                                        else
                                        {
                                            strText = "-";
                                        }
                                    }
                                    else if (strText.StartsWith("CLASS_YEAR"))
                                    {
                                        if (nRows < _DataTable.Rows.Count)
                                        {
                                            Int32 nYear = Convert.ToInt32(_DataTable.Rows[nRows]["欄位1"]);
                                            strText = (nYear - 1911).ToString() + "年";
                                        }
                                    }
                                    else
                                    {
                                        strText = currentCols[c].InnerHtml;
                                        // 把原來的 style 帶到新的 Column
                                        String strStyle = currentCols[c].GetAttributeValue("style", "");
                                        if (strStyle.Length > 0)
                                        {
                                            newCols[c].SetAttributeValue("style", strStyle);
                                        }
                                    }
                                    newCols[c].InnerHtml = strText;
                                }
                                dataBody.RemoveChild(currentRow);
                                dataBody.AppendChild(newRow);
                            }
                        }
                    }
                    tableOuterDivNode.AppendChild(dataNode);
                }
            }
        }

        private String ColumnInteger(Object obj)
        {
            String strText = "-";
            try
            {
                Int32 nVal = Convert.ToInt32(obj);
                if (nVal == 99999999)
                {
                    strText = "-";
                }
                else
                {
                    strText = nVal.ToString();
                }
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            return strText;
        }

        private String ColumnDecimal(Object obj, Int32 nDecimals)
        {
            String strText = "-";
            try
            {
                Decimal dVal = Convert.ToDecimal(obj);
                if (dVal == 99999999)
                {
                    strText = "-";
                }
                else
                {
                    String strDecimalFormat = "{0:0.";
                    for (Int32 d = 0; d < nDecimals; d++)
                    {
                        strDecimalFormat += "0";
                    }
                    strDecimalFormat += "}";
                    strText = String.Format(strDecimalFormat, Math.Round(dVal, nDecimals, MidpointRounding.AwayFromZero));
                }
            }
            catch (Exception)
            {
            }
            return strText;
        }

        private void ReplaceTitleText(HtmlNode titleText)
        {
            // TODO : 套用新的 css
            //titleText.SetAttributeValue("class", "newCssTitleText");

            String strText = titleText.InnerHtml;
            // TODO : 替換對應的文字
            strText = strText.Replace("$$TABLE$$", _StatCondition.TableText);
            strText = strText.Replace("$$TITLE$$", _StatCondition.TitleText);
            strText = strText.Replace("$$NEXT_STAT$$", _StatCondition.NextStatText);
            titleText.InnerHtml = strText;
        }

        private void ReplaceTitleRange(HtmlNode titleRange, Int32 nYear = -1)
        {
            // TODO : 套用新的 css
            //titleRange.SetAttributeValue("class", "newCssTitleRange");

            String strText = titleRange.InnerHtml;
            // TODO : 替換對應的文字
            if (nYear >= 0)
            {
                strText = strText.Replace("$$YEAR$$", nYear.ToString());
            }
            strText = strText.Replace("$$START_YEAR$$", _StatCondition.StartYear.ToString());
            strText = strText.Replace("$$END_YEAR$$", _StatCondition.EndYear.ToString());
            strText = strText.Replace("$$STAT_ITEM$$", _StatCondition.ItemText);
            titleRange.InnerHtml = strText;
        }

        private void ReplaceTitleUnit(HtmlNode titleUnit)
        {
            // TODO : 套用新的 css
            //titleUnit.SetAttributeValue("class", "newCssTitleUnit");

            String strText = titleUnit.InnerHtml;
            // TODO : 替換對應的文字
            strText = strText.Replace("$$STAT_UNIT$$", _StatCondition.UnitText);
            titleUnit.InnerHtml = strText;
        }

        public String TemplateApply(String strHtml)
        {
            String strRc = null;
            if (_StatCondition == null || _StatCondition.StatClass == StatClassItem.Notset || _DataTable == null)
                return strRc;

        
            // 試著用套件解析 html 內容.
            var htmlDoc = new HtmlAgilityPack.HtmlDocument();
            if (htmlDoc != null)
            {
                htmlDoc.LoadHtml(strHtml);
                var dataNodes = htmlDoc.DocumentNode.SelectNodes("//table[contains(@class, 'tableData')]/tbody/tr");
                if (dataNodes != null && dataNodes.Count > 0)
                {
                    if (dataNodes.Count == 1)
                    {
                        // TODO : 一筆 Row : 循序填寫 [年 / 年月 / 年月+平均] 資料
                        ProcessRow(htmlDoc);
                    }
                    else
                    {
                        // TODO : 多筆 Row : 固定統計類別項目
                        ProcessRow2(htmlDoc);
                        //ProcessTable(htmlDoc);
                    }
                }
                //var styleNode = htmlDoc.DocumentNode.SelectSingleNode("//style");
                //if (styleNode != null)
                //{
                //    // 清掉原先轉出的 <tyle></style>
                //    styleNode.InnerHtml = "";
                //}
                using (var stringWriter = new StringWriter())
                {
                    htmlDoc.Save(stringWriter);
                    strRc = stringWriter.GetStringBuilder().ToString();
                }
            }
            return strRc;
        }

        public static String JoinBody(List<String> lstHtml, String strSeparator = null)
        {
            String strOutHtml = "";
            var htmlDoc = new HtmlDocument();
            if (htmlDoc != null)
            {
                htmlDoc.LoadHtml(lstHtml[0]);
                var bodyNode = htmlDoc.DocumentNode.SelectSingleNode("//body");
                if (bodyNode != null)
                {
                    var htmlTemp = new HtmlDocument();
                    if (htmlTemp != null)
                    {
                        for (Int32 i = 1; i < lstHtml.Count; i++)
                        {
                            htmlTemp.LoadHtml(lstHtml[i]);
                            var tempBody = htmlTemp.DocumentNode.SelectSingleNode("//body");
                            if (tempBody != null)
                            {
                                if (strSeparator != null && strSeparator.Length > 0)
                                {
                                    try
                                    {
                                        HtmlNode node = HtmlNode.CreateNode(strSeparator);
                                        if (node != null)
                                        {
                                            bodyNode.AppendChild(node);
                                        }
                                    }
                                    catch (Exception)
                                    {
                                    }
                                }
                                else
                                {
                                    try
                                    {
                                        HtmlNode brNode = htmlTemp.CreateElement("br");
                                        if (brNode != null)
                                        {
                                            bodyNode.AppendChild(brNode);
                                        }
                                    }
                                    catch (Exception)
                                    {
                                    }
                                }
                                bodyNode.AppendChildren(tempBody.ChildNodes);
                            }
                        }
                        htmlTemp = null;
                    }
                }
                using (var stringWriter = new StringWriter())
                {
                    htmlDoc.Save(stringWriter);
                    strOutHtml = stringWriter.GetStringBuilder().ToString();
                }
                htmlDoc = null;
            }
            return strOutHtml;
        }

        public static String AppendNodeToHead(String strHtml, List<String> lstNodeContent)
        {
            String strOutHtml = strHtml;
            
            var htmlDoc = new HtmlDocument();
            if (htmlDoc != null)
            {
                htmlDoc.LoadHtml(strHtml);
                var headNode = htmlDoc.DocumentNode.SelectSingleNode("//head");
                if (headNode != null)
                {
                    foreach (String strContent in lstNodeContent)
                    {
                        try
                        {
                            HtmlNode node = HtmlNode.CreateNode(strContent);
                            if (node != null)
                            {
                                headNode.AppendChild(node);
                            }
                        }
                        catch (Exception)
                        {
                        }
                    }
                    using (var stringWriter = new StringWriter())
                    {
                        htmlDoc.Save(stringWriter);
                        strOutHtml = stringWriter.GetStringBuilder().ToString();
                    }
                }
                htmlDoc = null;
            }
            return strOutHtml;
        }

        public static String ReplaceStyleWithText(String strHtml, String strStyle)
        {
            String strOutHtml = strHtml;
            var htmlDoc = new HtmlDocument();
            if (htmlDoc != null)
            {
                htmlDoc.LoadHtml(strHtml);
                var styleNode = htmlDoc.DocumentNode.SelectSingleNode("//style");
                if (styleNode != null)
                {
                    // 換掉原先的 <tyle></style>
                    styleNode.InnerHtml = strStyle;
                    using (var stringWriter = new StringWriter())
                    {
                        htmlDoc.Save(stringWriter);
                        strOutHtml = stringWriter.GetStringBuilder().ToString();
                    }
                }
                htmlDoc = null;
            }
            return strOutHtml;
        }
    }
}
