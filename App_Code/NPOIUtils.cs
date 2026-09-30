using NPOI.HSSF;
using NPOI.HSSF.UserModel;
using NPOI.HSSF.Util;
using NPOI.SS.UserModel;
using NPOI.SS.Util;
using NPOI.XSSF.UserModel;
using NPOI.XSSF.Model;
using System;
using System.Collections.Generic;

namespace Supergeo.Utilities
{
    public class NPOIUtils : IDisposable
    {
        private List<HSSFWorkbook> workbookHssf = null;
        private List<XSSFWorkbook> workbookXssf = null;
        private int lastColumn = 0;
        private Dictionary<Int32, XSSFCellStyle> xssfStyleMap = null;
        private Dictionary<Int32, HSSFCellStyle> hssfStyleMap = null;

        public NPOIUtils()
        {
        }

        public void Dispose()
        {
            if (xssfStyleMap != null)
            {
                xssfStyleMap.Clear();
                xssfStyleMap = null;
            }
            if (hssfStyleMap != null)
            {
                hssfStyleMap.Clear();
                hssfStyleMap = null;
            }
            if (workbookHssf != null)
            {
                workbookHssf.Clear();
                workbookHssf = null;
            }
            if (workbookXssf != null)
            {
                workbookXssf.Clear();
                workbookXssf = null;
            }
        }

        /// <summary>
        /// 將 Excel 的 Column 名稱轉成索引
        /// </summary>
        /// <param name="colAdress"></param>
        /// <returns></returns>
        public static Int32 ColumnNumber(String colAdress)
        {
            Int32[] digits = new int[colAdress.Length];
            for (Int32 i = 0; i < colAdress.Length; ++i)
            {
                digits[i] = Convert.ToInt32(colAdress[i]) - 64;
            }
            Int32 mul = 1;
            Int32 res = 0;
            for (Int32 pos = digits.Length - 1; pos >= 0; --pos)
            {
                res += digits[pos] * mul;
                mul *= 26;
            }
            return res;
        }

        /// <summary>
        /// 將 Excel 的 Column 索引轉成名稱
        /// </summary>
        /// <param name="columnNumber"></param>
        /// <returns></returns>
        public static String ColumnName(Int32 columnNumber)
        {
            Int32 dividend = columnNumber;
            string columnName = String.Empty;
            Int32 modulo;

            while (dividend > 0)
            {
                modulo = (dividend - 1) % 26;
                columnName = Convert.ToChar(65 + modulo).ToString() + columnName;
                dividend = (int)((dividend - modulo) / 26);
            }

            return columnName;
        }

        public static Dictionary<String, Int32> ParseA1Notation(String cellAddr)
        {
            Dictionary<String, Int32> row_col = new Dictionary<String, Int32>();
            Int32 ii = 0, jj, colVal = 0;
            while (cellAddr[ii++] >= 'A') { };
            ii--;

            for (jj = 0; jj < ii; jj++) colVal = 26 * colVal + cellAddr[jj] - 'A' + 1;
            row_col.Add("C", colVal);
            row_col.Add("R", Int32.Parse(cellAddr.Substring(ii)));
            return row_col;
        }

        public IWorkbook Transform(IWorkbook workbook)
        {
            if (workbookXssf == null)
            {
                workbookXssf = new List<XSSFWorkbook>();
            }
            if (workbookHssf == null)
            {
                workbookHssf = new List<HSSFWorkbook>();
            }
            IWorkbook newWorkbook = null;
            if (workbook is HSSFWorkbook)
            {
                newWorkbook = TransformWorkbook(workbook as HSSFWorkbook);
            }
            else if (workbook is XSSFWorkbook)
            {
                newWorkbook = TransformWorkbook(workbook as XSSFWorkbook);
            }
            return newWorkbook;
        }

        private XSSFWorkbook TransformWorkbook(HSSFWorkbook workbook)
        {
            workbookHssf.Add(workbook);
            workbookXssf.Add(new XSSFWorkbook());
            xssfStyleMap = new Dictionary<Int32, XSSFCellStyle>();
            TransformHssfToXssf();
            return workbookXssf[0];
        }

        private HSSFWorkbook TransformWorkbook(XSSFWorkbook workbook)
        {
            workbookXssf.Add(workbook);
            workbookHssf.Add(new HSSFWorkbook());
            hssfStyleMap = new Dictionary<Int32, HSSFCellStyle>();
            TransformXssfToHssf();
            return workbookHssf[0];
        }

        private void TransformHssfToXssf()
        {
            XSSFSheet sheetNew;
            HSSFSheet sheetOld;
            workbookXssf[0].SetForceFormulaRecalculation(workbookHssf[0].ForceFormulaRecalculation);
            // workbookNew.setHidden(workbookOld.isHidden()); //ST@03.05.2012 -
            // von Apache noch nicht implementiert
            workbookXssf[0].MissingCellPolicy = workbookHssf[0].MissingCellPolicy;

            for (Int32 i = 0; i < workbookHssf[0].NumberOfSheets; i++)
            {
                sheetOld = workbookHssf[0].GetSheetAt(i) as HSSFSheet;
                sheetNew = workbookXssf[0].GetSheet(sheetOld.SheetName) as XSSFSheet;
                if (sheetNew == null)
                {
                    sheetNew = workbookXssf[0].CreateSheet(sheetOld.SheetName) as XSSFSheet;
                }
                TransformSheet(sheetOld, sheetNew);
            }
        }

        private void TransformXssfToHssf()
        {
            HSSFSheet sheetNew;
            XSSFSheet sheetOld;
            workbookHssf[0].ForceFormulaRecalculation = workbookXssf[0].GetForceFormulaRecalculation();
            // workbookNew.setHidden(workbookOld.isHidden()); //ST@03.05.2012 -
            // von Apache noch nicht implementiert
            workbookHssf[0].MissingCellPolicy = workbookXssf[0].MissingCellPolicy;

            for (Int32 i = 0; i < workbookXssf[0].NumberOfSheets; i++)
            {
                sheetOld = workbookXssf[0].GetSheetAt(i) as XSSFSheet;
                sheetNew = workbookHssf[0].GetSheet(sheetOld.SheetName) as HSSFSheet;
                if (sheetNew == null)
                {
                    sheetNew = workbookHssf[0].CreateSheet(sheetOld.SheetName) as HSSFSheet;
                }
                TransformSheet(sheetOld, sheetNew);
            }
        }

        private void TransformSheet(HSSFSheet sheetOld, XSSFSheet sheetNew)
        {
            sheetNew.DisplayFormulas = sheetOld.DisplayFormulas;
            sheetNew.DisplayGridlines = sheetOld.DisplayGridlines;
            sheetNew.DisplayGuts = sheetOld.DisplayGuts;
            sheetNew.DisplayRowColHeadings = sheetOld.DisplayRowColHeadings;
            sheetNew.DisplayZeros = sheetOld.DisplayZeros;
            sheetNew.FitToPage = sheetOld.FitToPage;
            sheetNew.ForceFormulaRecalculation = sheetOld.ForceFormulaRecalculation;
            sheetNew.HorizontallyCenter = sheetOld.HorizontallyCenter;
            sheetNew.SetMargin(MarginType.BottomMargin, sheetOld.GetMargin(MarginType.BottomMargin));
            sheetNew.SetMargin(MarginType.FooterMargin, sheetOld.GetMargin(MarginType.FooterMargin));
            sheetNew.SetMargin(MarginType.HeaderMargin, sheetOld.GetMargin(MarginType.HeaderMargin));
            sheetNew.SetMargin(MarginType.LeftMargin, sheetOld.GetMargin(MarginType.LeftMargin));
            sheetNew.SetMargin(MarginType.RightMargin, sheetOld.GetMargin(MarginType.RightMargin));
            sheetNew.SetMargin(MarginType.TopMargin, sheetOld.GetMargin(MarginType.TopMargin));
            sheetNew.IsPrintGridlines = sheetOld.IsPrintGridlines;
            sheetNew.RightToLeft = sheetOld.IsRightToLeft;
            sheetNew.RowSumsBelow = sheetOld.RowSumsBelow;
            sheetNew.RowSumsRight = sheetOld.RowSumsRight;
            sheetNew.VerticallyCenter = sheetOld.VerticallyCenter;

            XSSFRow rowNew;
            for (Int32 i = sheetOld.FirstRowNum; i<=sheetOld.LastRowNum; i++)
            {
                IRow row = sheetOld.GetRow(i);
                if (row != null)
                {
                    rowNew = sheetNew.CreateRow(row.RowNum) as XSSFRow;
                    if (rowNew != null)
                    {
                        TransformRow(row as HSSFRow, rowNew);
                    }
                }
            }

            for (Int32 i = 0; i < lastColumn; i++)
            {
                sheetNew.SetColumnWidth(i, sheetOld.GetColumnWidth(i));
                sheetNew.SetColumnHidden(i, sheetOld.IsColumnHidden(i));
            }

            for (Int32 i = 0; i < sheetOld.NumMergedRegions; i++)
            {
                CellRangeAddress merged = sheetOld.GetMergedRegion(i);
                sheetNew.AddMergedRegion(merged);
            }
        }

        private void TransformSheet(XSSFSheet sheetOld, HSSFSheet sheetNew)
        {
            sheetNew.DisplayFormulas = sheetOld.DisplayFormulas;
            sheetNew.DisplayGridlines = sheetOld.DisplayGridlines;
            sheetNew.DisplayGuts = sheetOld.DisplayGuts;
            sheetNew.DisplayRowColHeadings = sheetOld.DisplayRowColHeadings;
            sheetNew.DisplayZeros = sheetOld.DisplayZeros;
            sheetNew.FitToPage = sheetOld.FitToPage;
            sheetNew.ForceFormulaRecalculation = sheetOld.ForceFormulaRecalculation;
            sheetNew.HorizontallyCenter = sheetOld.HorizontallyCenter;
            sheetNew.SetMargin(MarginType.BottomMargin, sheetOld.GetMargin(MarginType.BottomMargin));
            sheetNew.SetMargin(MarginType.FooterMargin, sheetOld.GetMargin(MarginType.FooterMargin));
            sheetNew.SetMargin(MarginType.HeaderMargin, sheetOld.GetMargin(MarginType.HeaderMargin));
            sheetNew.SetMargin(MarginType.LeftMargin, sheetOld.GetMargin(MarginType.LeftMargin));
            sheetNew.SetMargin(MarginType.RightMargin, sheetOld.GetMargin(MarginType.RightMargin));
            sheetNew.SetMargin(MarginType.TopMargin, sheetOld.GetMargin(MarginType.TopMargin));
            sheetNew.IsPrintGridlines = sheetOld.IsPrintGridlines;
            sheetNew.IsRightToLeft = sheetOld.RightToLeft;
            sheetNew.RowSumsBelow = sheetOld.RowSumsBelow;
            sheetNew.RowSumsRight = sheetOld.RowSumsRight;
            sheetNew.VerticallyCenter = sheetOld.VerticallyCenter;

            HSSFRow rowNew;
            for (Int32 i = sheetOld.FirstRowNum; i <= sheetOld.LastRowNum; i++)
            {
                IRow row = sheetOld.GetRow(i);
                if (row != null)
                {
                    rowNew = sheetNew.CreateRow(row.RowNum) as HSSFRow;
                    if (rowNew != null)
                    {
                        TransformRow(row as XSSFRow, rowNew);
                    }
                }
            }

            for (Int32 i = 0; i < lastColumn; i++)
            {
                sheetNew.SetColumnWidth(i, sheetOld.GetColumnWidth(i));
                sheetNew.SetColumnHidden(i, sheetOld.IsColumnHidden(i));
            }

            for (Int32 i = 0; i < sheetOld.NumMergedRegions; i++)
            {
                CellRangeAddress merged = sheetOld.GetMergedRegion(i);
                sheetNew.AddMergedRegion(merged);
            }
        }

        public void CopyRange(XSSFSheet sheetOld, XSSFSheet sheetNew, 
            Int32 OldStartRow, Int32 OldEndRow, Int32 OldStartCol, Int32 OldEndCol,
            Int32 NewStartRow, Int32 NewStartCol)
        {
            if (workbookXssf == null)
            {
                workbookXssf = new List<XSSFWorkbook>();
            }
            workbookXssf.Add(sheetOld.GetWorkbook());
            workbookXssf.Add(sheetNew.GetWorkbook());
            if (xssfStyleMap == null)
            {
                xssfStyleMap = new Dictionary<Int32, XSSFCellStyle>();
            }

            sheetNew.DisplayFormulas = sheetOld.DisplayFormulas;
            sheetNew.DisplayGridlines = sheetOld.DisplayGridlines;
            sheetNew.DisplayGuts = sheetOld.DisplayGuts;
            sheetNew.DisplayRowColHeadings = sheetOld.DisplayRowColHeadings;
            sheetNew.DisplayZeros = sheetOld.DisplayZeros;
            sheetNew.FitToPage = sheetOld.FitToPage;
            sheetNew.ForceFormulaRecalculation = sheetOld.ForceFormulaRecalculation;
            sheetNew.HorizontallyCenter = sheetOld.HorizontallyCenter;
            sheetNew.SetMargin(MarginType.BottomMargin, sheetOld.GetMargin(MarginType.BottomMargin));
            sheetNew.SetMargin(MarginType.FooterMargin, sheetOld.GetMargin(MarginType.FooterMargin));
            sheetNew.SetMargin(MarginType.HeaderMargin, sheetOld.GetMargin(MarginType.HeaderMargin));
            sheetNew.SetMargin(MarginType.LeftMargin, sheetOld.GetMargin(MarginType.LeftMargin));
            sheetNew.SetMargin(MarginType.RightMargin, sheetOld.GetMargin(MarginType.RightMargin));
            sheetNew.SetMargin(MarginType.TopMargin, sheetOld.GetMargin(MarginType.TopMargin));
            sheetNew.IsPrintGridlines = sheetOld.IsPrintGridlines;
            sheetNew.RightToLeft = sheetOld.IsRightToLeft;
            sheetNew.RowSumsBelow = sheetOld.RowSumsBelow;
            sheetNew.RowSumsRight = sheetOld.RowSumsRight;
            sheetNew.VerticallyCenter = sheetOld.VerticallyCenter;

            XSSFRow rowNew;
            Int32 nCurrentRow = NewStartRow;
            for (Int32 i = OldStartRow; i <= OldEndRow; i++)
            {
                rowNew = sheetNew.CreateRow(nCurrentRow) as XSSFRow;
                IRow row = sheetOld.GetRow(i);
                if (row != null)
                {
                    CopyRow(row as XSSFRow, rowNew, OldStartCol, OldEndCol, NewStartCol);
                }
                nCurrentRow++;
            }

            for (Int32 i = 0; i < lastColumn; i++)
            {
                sheetNew.SetColumnWidth(i, sheetOld.GetColumnWidth(i));
                sheetNew.SetColumnHidden(i, sheetOld.IsColumnHidden(i));
            }
        }

        private void TransformRow(HSSFRow rowOld, XSSFRow rowNew)
        {
            XSSFCell cellNew;
            rowNew.Height = rowOld.Height;
            if (rowOld.RowStyle != null)
            {
                Int32 hash = rowOld.RowStyle.Index;
                if (!xssfStyleMap.ContainsKey(hash))
                {
                    TransformStyle(hash, rowOld.RowStyle as HSSFCellStyle, workbookXssf[0].CreateCellStyle() as XSSFCellStyle);
                }
                rowNew.RowStyle = xssfStyleMap[hash];
            }
            for (Int32 i = rowOld.FirstCellNum; i <= rowOld.LastCellNum; i++)
            {
                ICell cell = rowOld.GetCell(i);
                if (cell != null)
                {
                    cellNew = rowNew.CreateCell(cell.ColumnIndex, cell.CellType) as XSSFCell;
                    if (cellNew != null)
                    {
                        TransformCell(cell as HSSFCell, cellNew);
                    }
                }
            }
            lastColumn = Math.Max(lastColumn, rowNew.LastCellNum);
        }

        private void TransformRow(XSSFRow rowOld, HSSFRow rowNew)
        {
            HSSFCell cellNew;
            rowNew.Height = rowOld.Height;
            if (rowOld.RowStyle != null)
            {
                Int32 hash = rowOld.RowStyle.Index;
                if (!xssfStyleMap.ContainsKey(hash))
                {
                    TransformStyle(hash, rowOld.RowStyle as XSSFCellStyle, workbookXssf[0].CreateCellStyle() as HSSFCellStyle);
                }
                rowNew.RowStyle = xssfStyleMap[hash];
            }
            for (Int32 i = rowOld.FirstCellNum; i <= rowOld.LastCellNum; i++)
            {
                ICell cell = rowOld.GetCell(i);
                if (cell != null)
                {
                    cellNew = rowNew.CreateCell(cell.ColumnIndex, cell.CellType) as HSSFCell;
                    if (cellNew != null)
                    {
                        TransformCell(cell as XSSFCell, cellNew);
                    }
                }
            }
            lastColumn = Math.Max(lastColumn, rowOld.LastCellNum);
        }

        private void CopyRow(XSSFRow rowOld, XSSFRow rowNew,
            Int32 OldStartCol, Int32 OldEndCol, 
            Int32 NewStartCol)
        {
            XSSFCell cellNew;
            rowNew.Height = rowOld.Height;
            if (rowOld.RowStyle != null)
            {
                Int32 hash = rowOld.RowStyle.Index;
                if (!xssfStyleMap.ContainsKey(hash))
                {
                    TransformStyle(hash, rowOld.RowStyle as XSSFCellStyle, workbookXssf[1].CreateCellStyle() as XSSFCellStyle);
                }
                rowNew.RowStyle = xssfStyleMap[hash];
            }
            Int32 nCurrentCol = NewStartCol;
            for (Int32 i = OldStartCol; i <= OldEndCol; i++)
            {
                ICell cell = rowOld.GetCell(i);

                if (cell != null)
                {
                    cellNew = rowNew.CreateCell(nCurrentCol, cell.CellType) as XSSFCell;
                    if (cellNew != null)
                    {
                        TransformCell(cell as XSSFCell, cellNew);
                        CellRangeAddress cellRangeAddress = null, newCellRangeAddress = null;
                        for (Int32 r = 0; r < rowOld.Sheet.NumMergedRegions; r++)
                        {
                            cellRangeAddress = rowOld.Sheet.GetMergedRegion(r);
                            if (cellRangeAddress.FirstRow == cell.RowIndex &&
                                cellRangeAddress.FirstColumn == cell.ColumnIndex)
                            {
                                newCellRangeAddress = new CellRangeAddress(
                                    cellNew.RowIndex,
                                    (cellNew.RowIndex + (cellRangeAddress.LastRow - cellRangeAddress.FirstRow)),
                                    cellNew.ColumnIndex,
                                    (cellNew.ColumnIndex + (cellRangeAddress.LastColumn - cellRangeAddress.FirstColumn))
                                );
                                rowNew.Sheet.AddMergedRegion(newCellRangeAddress);
                            }
                        }
                    }
                }
                else
                {
                    cellNew = rowNew.CreateCell(nCurrentCol, CellType.String) as XSSFCell;
                    cellNew.SetCellValue(" ");
                }
                nCurrentCol++;
            }
            lastColumn = Math.Max(lastColumn, rowNew.LastCellNum);
        }

        private void TransformCell(HSSFCell cellOld, XSSFCell cellNew)
        {
            cellNew.CellComment = cellOld.CellComment;
            cellNew.Hyperlink = cellOld.Hyperlink;
            //cellNew.CellFormula = cellOld.CellFormula;
            
            Int32 hash = cellOld.CellStyle.Index;
            if (!xssfStyleMap.ContainsKey(hash))
            {
                TransformStyle(hash, cellOld.CellStyle as HSSFCellStyle, workbookXssf[0].CreateCellStyle() as XSSFCellStyle);
            }
            cellNew.CellStyle = xssfStyleMap[hash];

            switch (cellOld.CellType)
            {
                case CellType.Blank:
                    break;
                case CellType.Boolean:
                    cellNew.SetCellValue(cellOld.BooleanCellValue);
                    break;
                case CellType.Error:
                    cellNew.SetCellValue(cellOld.ErrorCellValue);
                    break;
                case CellType.Formula:
                    cellNew.SetCellValue(cellOld.CellFormula);
                    break;
                case CellType.Numeric:
                    cellNew.SetCellValue(cellOld.NumericCellValue);
                    break;
                case CellType.String:
                    cellNew.SetCellValue(cellOld.StringCellValue);
                    break;
                default:
                    cellNew.SetCellValue(cellOld.StringCellValue);
                    break;
            }
        }

        private void TransformCell(XSSFCell cellOld, HSSFCell cellNew)
        {
            cellNew.CellComment = cellOld.CellComment;
            cellNew.Hyperlink = cellOld.Hyperlink;
            //cellNew.CellFormula = cellOld.CellFormula;

            Int32 hash = cellOld.CellStyle.Index;
            if (!hssfStyleMap.ContainsKey(hash))
            {
                TransformStyle(hash, cellOld.CellStyle as XSSFCellStyle, workbookHssf[0].CreateCellStyle() as HSSFCellStyle);
            }
            cellNew.CellStyle = hssfStyleMap[hash];

            switch (cellOld.CellType)
            {
                case CellType.Blank:
                    break;
                case CellType.Boolean:
                    cellNew.SetCellValue(cellOld.BooleanCellValue);
                    break;
                case CellType.Error:
                    cellNew.SetCellValue(cellOld.ErrorCellValue);
                    break;
                case CellType.Formula:
                    cellNew.SetCellValue(cellOld.CellFormula);
                    break;
                case CellType.Numeric:
                    cellNew.SetCellValue(cellOld.NumericCellValue);
                    break;
                case CellType.String:
                    cellNew.SetCellValue(cellOld.StringCellValue);
                    break;
                default:
                    cellNew.SetCellValue(cellOld.StringCellValue);
                    break;
            }
        }

        private void TransformCell(XSSFCell cellOld, XSSFCell cellNew)
        {
            cellNew.CellComment = cellOld.CellComment;
            cellNew.Hyperlink = cellOld.Hyperlink;
            //cellNew.CellFormula = cellOld.CellFormula;

            if (cellOld.CellStyle != null)
            {
                Int32 hash = cellOld.CellStyle.Index;
                if (!xssfStyleMap.ContainsKey(hash))
                {
                    TransformStyle(hash, cellOld.CellStyle as XSSFCellStyle, workbookXssf[1].CreateCellStyle() as XSSFCellStyle);
                }
                cellNew.CellStyle = xssfStyleMap[hash];
            }

            switch (cellOld.CellType)
            {
                case CellType.Blank:
                    break;
                case CellType.Boolean:
                    cellNew.SetCellValue(cellOld.BooleanCellValue);
                    break;
                case CellType.Error:
                    cellNew.SetCellValue(cellOld.ErrorCellValue);
                    break;
                case CellType.Formula:
                    cellNew.SetCellValue(cellOld.CellFormula);
                    break;
                case CellType.Numeric:
                    cellNew.SetCellValue(cellOld.NumericCellValue);
                    break;
                case CellType.String:
                    cellNew.SetCellValue(cellOld.StringCellValue);
                    break;
                default:
                    cellNew.SetCellValue(cellOld.StringCellValue);
                    break;
            }
        }

        private void TransformStyle(Int32 hash, HSSFCellStyle styleOld, XSSFCellStyle styleNew)
        {
            styleNew.Alignment = styleOld.Alignment;
            styleNew.BorderDiagonal = styleOld.BorderDiagonal;
            styleNew.BorderDiagonalColor = styleOld.BorderDiagonalColor;
            styleNew.BorderDiagonalLineStyle = styleOld.BorderDiagonalLineStyle;
            styleNew.BorderBottom = styleOld.BorderBottom;
            styleNew.BorderLeft = styleOld.BorderLeft;
            styleNew.BorderRight = styleOld.BorderRight;
            styleNew.BorderTop = styleOld.BorderTop;
            styleNew.LeftBorderColor = styleOld.LeftBorderColor;
            styleNew.TopBorderColor = styleOld.TopBorderColor;
            styleNew.RightBorderColor = styleOld.RightBorderColor;
            styleNew.BottomBorderColor = styleOld.BottomBorderColor;
            styleNew.SetDataFormat(TransformDataFormat(styleOld.DataFormat, false));
            styleNew.FillBackgroundColor = styleOld.FillBackgroundColor;
            styleNew.FillForegroundColor = styleOld.FillForegroundColor;
            styleNew.FillPattern = styleOld.FillPattern;
            styleNew.SetFont(TransformFont(styleOld.GetFont(workbookHssf[0]) as HSSFFont));
            styleNew.IsHidden = styleOld.IsHidden;
            styleNew.Indention = styleOld.Indention;
            styleNew.IsLocked = styleOld.IsLocked;
            styleNew.VerticalAlignment = styleOld.VerticalAlignment;
            styleNew.ShrinkToFit = styleOld.ShrinkToFit;
            styleNew.WrapText = styleOld.WrapText;

            xssfStyleMap.Add(hash, styleNew);
        }

        private void TransformStyle(Int32 hash, XSSFCellStyle styleOld, HSSFCellStyle styleNew)
        {
            styleNew.Alignment = styleOld.Alignment;
            styleNew.BorderDiagonal = styleOld.BorderDiagonal;
            styleNew.BorderDiagonalColor = GetSimilarColorIndex(styleOld.DiagonalBorderXSSFColor);
            styleNew.BorderDiagonalLineStyle = styleOld.BorderDiagonalLineStyle;
            styleNew.BorderBottom = styleOld.BorderBottom;
            styleNew.BorderLeft = styleOld.BorderLeft;
            styleNew.BorderRight = styleOld.BorderRight;
            styleNew.BorderTop = styleOld.BorderTop;
            styleNew.LeftBorderColor = GetSimilarColorIndex(styleOld.LeftBorderXSSFColor);
            styleNew.TopBorderColor = GetSimilarColorIndex(styleOld.TopBorderXSSFColor);
            styleNew.RightBorderColor = GetSimilarColorIndex(styleOld.RightBorderXSSFColor);
            styleNew.BottomBorderColor = GetSimilarColorIndex(styleOld.BottomBorderXSSFColor);
            styleNew.DataFormat = TransformDataFormat(styleOld.DataFormat, true);
            styleNew.FillBackgroundColor = GetSimilarColorIndex(styleOld.FillBackgroundXSSFColor);
            styleNew.FillForegroundColor = GetSimilarColorIndex(styleOld.FillForegroundXSSFColor);
            styleNew.FillPattern = styleOld.FillPattern;
            styleNew.SetFont(TransformFont(styleOld.GetFont(workbookXssf[0]) as XSSFFont));
            styleNew.IsHidden = styleOld.IsHidden;
            styleNew.Indention = styleOld.Indention;
            styleNew.IsLocked = styleOld.IsLocked;
            styleNew.VerticalAlignment = styleOld.VerticalAlignment;
            styleNew.ShrinkToFit = styleOld.ShrinkToFit;
            styleNew.WrapText = styleOld.WrapText;

            hssfStyleMap.Add(hash, styleNew);
        }

        private void TransformStyle(Int32 hash, XSSFCellStyle styleOld, XSSFCellStyle styleNew)
        {
            styleNew.Alignment = styleOld.Alignment;
            styleNew.BorderDiagonal = styleOld.BorderDiagonal;
            styleNew.BorderDiagonalColor = styleOld.BorderDiagonalColor;
            styleNew.BorderDiagonalLineStyle = styleOld.BorderDiagonalLineStyle;
            styleNew.BorderBottom = styleOld.BorderBottom;
            styleNew.BorderLeft = styleOld.BorderLeft;
            styleNew.BorderRight = styleOld.BorderRight;
            styleNew.BorderTop = styleOld.BorderTop;
            styleNew.LeftBorderColor = styleOld.LeftBorderColor;
            styleNew.TopBorderColor = styleOld.TopBorderColor;
            styleNew.RightBorderColor = styleOld.RightBorderColor;
            styleNew.BottomBorderColor = styleOld.BottomBorderColor;
            styleNew.SetDataFormat(TransformDataFormatXssf(styleOld.DataFormat));
            if (styleOld.FillBackgroundColorColor != null)
            {
                styleNew.FillBackgroundColorColor = styleOld.FillBackgroundColorColor;
            }
            else
            {
                styleNew.FillBackgroundColor = styleOld.FillBackgroundColor;
            }
            if (styleOld.FillForegroundColorColor != null)
            {
                styleNew.FillForegroundColorColor = styleOld.FillForegroundColorColor;
            }
            else
            {
                styleNew.FillForegroundColor = styleOld.FillForegroundColor;
            }
            styleNew.FillPattern = styleOld.FillPattern;
            styleNew.SetFont(TransformFontXssf(styleOld.GetFont(workbookXssf[0]) as XSSFFont, workbookXssf[0]));
            styleNew.IsHidden = styleOld.IsHidden;
            styleNew.Indention = styleOld.Indention;
            styleNew.IsLocked = styleOld.IsLocked;
            styleNew.VerticalAlignment = styleOld.VerticalAlignment;
            styleNew.ShrinkToFit = styleOld.ShrinkToFit;
            styleNew.WrapText = styleOld.WrapText;

            xssfStyleMap.Add(hash, styleNew);
        }

        private short TransformDataFormat(short index, Boolean x_to_h)
        {
            if (x_to_h)
            {
                IDataFormat formatOld = this.workbookXssf[0].CreateDataFormat();
                IDataFormat formatNew = this.workbookHssf[0].CreateDataFormat();

                return formatNew.GetFormat(formatOld.GetFormat(index));
            }
            else
            {
                IDataFormat formatOld = this.workbookHssf[0].CreateDataFormat();
                IDataFormat formatNew = this.workbookXssf[0].CreateDataFormat();

                return formatNew.GetFormat(formatOld.GetFormat(index));
            }
        }

        private short TransformDataFormatXssf(short index)
        {
            IDataFormat formatOld = this.workbookXssf[0].CreateDataFormat();
            IDataFormat formatNew = this.workbookXssf[1].CreateDataFormat();

            return formatNew.GetFormat(formatOld.GetFormat(index));
        }

        private XSSFFont TransformFont(HSSFFont fontOld)
        {
            XSSFFont fontNew = workbookXssf[0].CreateFont() as XSSFFont;
            fontNew.FontName = fontOld.FontName;
            fontNew.IsBold = fontOld.IsBold;
            fontNew.IsItalic = fontOld.IsItalic;
            fontNew.IsStrikeout = fontOld.IsStrikeout;
            fontNew.Charset = fontOld.Charset;
            fontNew.Color = fontOld.Color;
            HSSFColor iColor = fontOld.GetHSSFColor(workbookHssf[0]);
            if (iColor != null)
            {
                fontNew.SetColor(TransformColor(iColor));
            }
            fontNew.FontName = fontOld.FontName;
            fontNew.FontHeight = fontOld.FontHeight;
            fontNew.FontHeightInPoints = fontOld.FontHeightInPoints;
            fontNew.TypeOffset = fontOld.TypeOffset;
            fontNew.Underline = fontOld.Underline;

            return fontNew;
        }

        private HSSFFont TransformFont(XSSFFont fontOld)
        {
            HSSFFont fontNew = workbookHssf[0].CreateFont() as HSSFFont;

            fontNew.FontName = fontOld.FontName;
            fontNew.IsBold = fontOld.IsBold;
            fontNew.IsItalic = fontOld.IsItalic;
            fontNew.IsStrikeout = fontOld.IsStrikeout;
            fontNew.Charset = fontOld.Charset;
            fontNew.Color = GetSimilarColorIndex(fontOld.GetXSSFColor());
            fontNew.FontName = fontOld.FontName;
            fontNew.FontHeight = fontOld.FontHeight;
            fontNew.FontHeightInPoints = fontOld.FontHeightInPoints;
            fontNew.TypeOffset = fontOld.TypeOffset;
            fontNew.Underline = fontOld.Underline;

            return fontNew;
        }

        private XSSFFont TransformFontXssf(XSSFFont fontOld, XSSFWorkbook workbook)
        {
            XSSFFont fontNew = workbookXssf[1].CreateFont() as XSSFFont;
            
            fontNew.FontName = fontOld.FontName;
            fontNew.IsBold = fontOld.IsBold;
            fontNew.IsItalic = fontOld.IsItalic;
            fontNew.IsStrikeout = fontOld.IsStrikeout;
            fontNew.Charset = fontOld.Charset;
            fontNew.Color = fontOld.Color;
            fontNew.SetThemesTable(workbook.GetTheme());

            XSSFColor iColor = fontOld.GetXSSFColor();
            if (iColor != null)
            {
                fontNew.SetColor(iColor);
                if (iColor.IsThemed)
                {
                    var ctFont = fontNew.GetCTFont();
                    if (ctFont != null && ctFont.sizeOfColorArray() > 0)
                    {
                        var c = ctFont.GetColorArray(0);
                        if (iColor.HasTint)
                            c.tint = iColor.Tint;
                        if (iColor.IsIndexed)
                            c.indexed = (uint)iColor.Indexed;
                    }
                }
            }

            fontNew.FontName = fontOld.FontName;
            fontNew.FontHeight = fontOld.FontHeight;
            fontNew.FontHeightInPoints = fontOld.FontHeightInPoints;
            fontNew.TypeOffset = fontOld.TypeOffset;
            fontNew.Underline = fontOld.Underline;

            return fontNew;
        }

        private short GetSimilarColorIndex(XSSFColor iColor)
        {
            short rcColor = 0;
            if (iColor != null)
            {
                if (iColor != null)
                {
                    byte[] rgb = iColor.RGB;
                    if (rgb != null && rgb.Length >= 3)
                    {
                        HSSFPalette palette = workbookHssf[0].GetCustomPalette();
                        HSSFColor myColor = palette.FindSimilarColor(rgb[rgb.Length - 3], rgb[rgb.Length - 2], rgb[rgb.Length - 1]);
                        rcColor = myColor.Indexed;
                    }
                }
            }
            return rcColor;
        }

        private XSSFColor TransformColor(HSSFColor iColor)
        {
            XSSFColor colorNew = new XSSFColor();
            colorNew.SetRgb(iColor.RGB);
            return colorNew;
        }

    }
}
