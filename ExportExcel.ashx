<%@ WebHandler Language="C#" Class="Handler" %>
using Newtonsoft.Json;
using System;
using System.Data;
using System.Web;
using System.IO;
using ClosedXML.Excel;

public class Handler : IHttpHandler {

    public void ProcessRequest (HttpContext context) {

        context.Response.ContentType = "text/plain";
        try
        {
            string json = new StreamReader(context.Request.InputStream).ReadToEnd();

            MemoryStream ms = ExportExcel(json);
            context.Response.Clear();
            context.Response.Buffer = true;
            context.Response.AddHeader("content-disposition", "attachment; filename=export.xls");
            context.Response.ContentType = "application/vnd.ms-excel";
            context.Response.BinaryWrite(ms.ToArray());
        }
        catch (Exception e)
        {
            string ex = e.ToString();
            // context.Response.Write(ex);
        }
    }

    public MemoryStream ExportExcel(string json)
    {
        DataTable dt = (DataTable)JsonConvert.DeserializeObject(json, (typeof(DataTable)));
        XLWorkbook wb = new XLWorkbook();
        wb.Worksheets.Add(dt,"WorksheetName");
        MemoryStream fs = new MemoryStream();
        wb.SaveAs(fs);
        fs.Position = 0;
        
        return fs;
    }

    public bool IsReusable {
        get {
            return false;
        }
    }

}