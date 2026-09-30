<%@ WebHandler Language="C#" Class="ExportOds" %>

using System;
using System.Web;
using System.IO;
using System.Text;

public class ExportOds : IHttpHandler {

    public void ProcessRequest (HttpContext context) {
        context.Response.ContentType = "text/plain";
        string example_css = "<style>";
        example_css += "tr td,tr th { border:1px; font-size:1em; }";
        example_css += " .valueColumn { width:200px; text-align:right; }";
        example_css += " tr th { text-align:center; }";
        example_css += " .titleColumn { width:200px; text-align:center; }";
        example_css += " .pvtTable { min-height: 100%; min-width: 100%; }";
        example_css += " .pvtAxisLabel, .pvtTotalLabel { display: none; }";
        example_css += " table.pvtTable thead tr th, table.pvtTable tbody tr th { min-width: 150px; min-height: 45px; background-color: #ffffff; border: 1px solid #505050; font-size: 16px !important; }";
        example_css += " table.pvtTable thead tr:nth-child(1) th:nth-child(n + 3) { background: #85b2b5; }";
        example_css += " table.pvtTable tbody tr td { text-align: center; vertical-align: middle; border: 1px solid #505050; font-size: 14px !important; }";
        example_css += " table.pvtTable tbody tr:nth-child(odd) td { background-color: #d0e0ea; } ";
        example_css += " .slevel3 { background: #fcd76e !important; color: #000000 !important; } ";
        example_css += " .slevel2 { background: #485b68 !important; color: #ffffff !important; } ";
        example_css += " .slevel1 { background: #72a2a5 !important; color: #ffffff !important; } ";
        example_css += " </style>";

        string sHtml = context.Request.Form["html"];
        sHtml = HttpUtility.HtmlDecode(sHtml);

        StringBuilder StrExport = new StringBuilder();
        StrExport.Append("<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:excel' xmlns='http://www.w3.org/TR/REC-html40'><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"/></head><title>Time</title>");
        StrExport.Append("<body lang=EN-US style='mso-element:header' id=h1><span style='mso--code:DATE'></span><div class=Section1>");
        StrExport.Append("<div  style='font-size:12px;'>");
        StrExport.Append(sHtml);
        StrExport.Append("</div></body></html>");

        string strFile = "file.ods";
        string strcontentType= "application/vnd.oasis.opendocument.spreadsheet";

        context.Response.ClearContent();
        context.Response.ClearHeaders();
        context.Response.BufferOutput = true;
        context.Response.Clear();
        context.Response.ContentType = strcontentType;
        context.Response.AddHeader("Content-Disposition", "attachment; filename=" + strFile);
        context.Response.Buffer = true;

        String succeedStr = StrExport.ToString();
        context.Response.Write(succeedStr);
        context.Response.Flush();
        context.Response.Close();

        context.Response.Write("[if gte mso 9]><xml>");
        context.Response.Write("<x:ExcelWorkbook>");
        context.Response.Write("<x:ExcelWorksheets>");
        context.Response.Write("<x:ExcelWorksheet>");
        context.Response.Write("<x:Name>Report Data</x:Name>");
        context.Response.Write("<x:WorksheetOptions>");
        context.Response.Write("<x:Print>");
        context.Response.Write("<x:ValidPrinterInfo/>");
        context.Response.Write("</x:Print>");
        context.Response.Write("</x:WorksheetOptions>");
        context.Response.Write("</x:ExcelWorksheet>");
        context.Response.Write("</x:ExcelWorksheets>");
        context.Response.Write("</x:ExcelWorkbook>");
        context.Response.Write("</xml>");
        context.Response.Write("<![endif] ");
    }

    public bool IsReusable {
        get {
            return false;
        }
    }

}