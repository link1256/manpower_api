using NPOI.SS.UserModel;
using NPOI.XSSF.UserModel;
using System;
using System.Collections.Generic;
using System.IO;
using System.Xml;

namespace Supergeo.Utilities
{
    public class TemplateHelper : IDisposable
    {
        private Boolean _Loaded = false;
        private String _LastError = "";
        private List<TemplateItem> _Items = null;
        
        public TemplateHelper(IWorkbook workbook)
        {
            if (workbook != null && workbook is XSSFWorkbook)
            {
                Parse(workbook);
                if (_Items != null && _Items.Count > 0)
                {
                    _Loaded = true;
                }
                else
                {
                    _LastError = "No Template Found.";
                }
            }
            else
            {
                _LastError = "Only support .xlsx";
            }
        }

        public void Dispose()
        {
            if (_Items != null)
            {
                _Items.Clear();
                _Items = null;
            }
        }

        public Boolean Loaded
        {
            get { return _Loaded; }
        }

        public String LastError
        {
            get { return _LastError; }
        }

        public TemplateItem Get(Int32 idx)
        {
            if (_Items != null)
            {
                if (idx >= 0 && idx < _Items.Count)
                {
                    return _Items[idx];
                }
            }
            return null;
        }

        public Int32 TemplateCount
        {
            get { return (_Items != null ? _Items.Count : 0); }
        }

        public TemplateItem Get(String name)
        {
            TemplateItem selected = null;
            if (_Items != null)
            {
                for (Int32 i = 0; i < _Items.Count; i++)
                {
                    if (String.Compare(name, _Items[i].Name, true) == 0)
                    {
                        selected = _Items[i];
                        break;
                    }
                }
            }
            return selected;
        }

        private void Parse(IWorkbook workbook)
        {
            for (Int32 i = 0; i < workbook.NumberOfSheets; i++)
            {
                ISheet originSheet = workbook.GetSheetAt(i);
                Dictionary<String, Object> def = null;
                Boolean bGotFieldDef = false;
                Boolean bGotTitleCell = false;
                TemplateItem item = new TemplateItem();
                for (Int32 r = originSheet.FirstRowNum; r <= originSheet.LastRowNum; r++)
                {
                    IRow currentRow = originSheet.GetRow(r);
                    if (currentRow != null)
                    {
                        Boolean bGotContent = false;
                        for (Int32 c = currentRow.FirstCellNum; c <= currentRow.LastCellNum; c++)
                        {
                            if (c >= 0)
                            {
                                ICell currentCell = currentRow.GetCell(c, MissingCellPolicy.RETURN_BLANK_AS_NULL);
                                if (currentCell != null)
                                {
                                    String strVal = GetCellValue(currentCell);
                                    if (strVal != null)
                                    {
                                        strVal = strVal.Trim();
                                        if (strVal.Length > 0)
                                        {
                                            Int32 nRowIndex = currentRow.RowNum - 1;
                                            if (!bGotFieldDef)
                                            {
                                                def = LoadFieldDef(currentRow);
                                                if (def != null)
                                                {
                                                    List<Int32> lstIndex = def["FIELDS_INDEX"] as List<Int32>;
                                                    if (lstIndex != null && lstIndex.Count > 0)
                                                    {
                                                        item.ColumnEnd = lstIndex[lstIndex.Count - 1];
                                                    }
                                                    bGotFieldDef = true;
                                                }
                                            }
                                            else
                                            {
                                                if (String.Compare("$$HEADER$$", strVal, true) == 0)
                                                {
                                                    if (nRowIndex < item.HeaderStart) item.HeaderStart = nRowIndex;
                                                    if (nRowIndex > item.HeaderEnd) item.HeaderEnd = nRowIndex;
                                                }
                                                else if (String.Compare("$$ROW$$", strVal, true) == 0)
                                                {
                                                    // DataRow (Only One Row)
                                                    if (item.DataRow < 0)
                                                    {
                                                        item.DataRow = nRowIndex;
                                                    }
                                                }
                                                else if (String.Compare("$$START$$", strVal, true) == 0)
                                                {
                                                    // Table Start
                                                    if (item.TableStart < 0)
                                                    {
                                                        item.TableStart = nRowIndex;
                                                    }
                                                }
                                                else if (String.Compare("$$END$$", strVal, true) == 0)
                                                {
                                                    // Table End
                                                    if (item.TableEnd < 0)
                                                    {
                                                        item.TableEnd = nRowIndex;
                                                    }
                                                }
                                                else
                                                {
                                                    if (!item.HasHeader && !item.HasTable)
                                                    {
                                                        // Title
                                                        if (nRowIndex < item.TitleStart) item.TitleStart = nRowIndex;
                                                        if (nRowIndex > item.TitleEnd) item.TitleEnd = nRowIndex;
                                                        Int32 nTitle = strVal.IndexOf("$$NEXT");
                                                        if (nTitle >= 0 || !bGotTitleCell)
                                                        {
                                                            bGotTitleCell = true;
                                                            currentCell.SetCellValue("$$TABLE$$　$$TITLE$$　$$NEXT_STAT$$");
                                                        }
                                                    }
                                                }
                                            }
                                            if (nRowIndex >= item.RowEnd)
                                            {
                                                item.RowEnd = nRowIndex;
                                            }
                                            bGotContent = true;
                                        }
                                    }
                                }
                            }
                            if (bGotContent)
                            {
                                break;
                            }
                        }
                    }
                }
                if (def != null)
                {
                    item.SetName(originSheet.SheetName);
                    item.SetFields(def);
                    item.LoadTemplate(originSheet);
                    if (_Items == null)
                    {
                        _Items = new List<TemplateItem>();
                    }
                    _Items.Add(item);
                }
            }
        }

        private String GetCellValue(ICell iCell)
        {
            String strVal = null;
            if (iCell != null)
            {
                switch (iCell.CellType)
                {
                    case CellType.Blank:
                        break;
                    case CellType.Boolean:
                        strVal = Convert.ToString(iCell.BooleanCellValue);
                        break;
                    case CellType.Error:
                        strVal = Convert.ToString(iCell.ErrorCellValue);
                        break;
                    case CellType.Formula:
                        strVal = Convert.ToString(iCell.CellFormula);
                        break;
                    case CellType.Numeric:
                        strVal = Convert.ToString(iCell.NumericCellValue);
                        break;
                    case CellType.String:
                        strVal = Convert.ToString(iCell.StringCellValue);
                        break;
                    default:
                        break;
                }
            }
            return strVal;
        }

        private Dictionary<String, Object> LoadFieldDef(IRow row)
        {
            Dictionary<String, Object> dicDef = new Dictionary<String, Object>();
            List<String> lstFileds = new List<String>();
            List<Int32> lstIndex = new List<Int32>();
            for (Int32 c = row.FirstCellNum; c <= row.LastCellNum; c++)
            {
                ICell currentCell = row.GetCell(c, MissingCellPolicy.RETURN_BLANK_AS_NULL);
                String strVal = GetCellValue(currentCell);
                if (strVal != null && strVal.Trim().Length > 0)
                {
                    if (String.Compare("YEAR", strVal, true) == 0 ||
                        String.Compare("MONTH", strVal, true) == 0 ||
                        String.Compare("$$STAT_CLASS$$", strVal, true) == 0 ||
                        String.Compare("CLASS_YEAR", strVal, true) == 0)
                    {
                        dicDef.Add(strVal, currentCell.ColumnIndex - 1);
                        if (!strVal.StartsWith("$$"))
                        {
                            lstFileds.Add(strVal);
                            lstIndex.Add(currentCell.ColumnIndex - 1);
                        }
                    }
                    else
                    {
                        lstFileds.Add(strVal);
                        lstIndex.Add(currentCell.ColumnIndex - 1);
                    }
                }
            }
            if (dicDef.Count > 0)
            {
                dicDef.Add("FIELDS_NAME", lstFileds);
                dicDef.Add("FIELDS_INDEX", lstIndex);
            }
            else
            {
                dicDef = null;
            }
            return dicDef;
        }
    }
}
