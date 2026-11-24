<%@ WebHandler Language="C#" Class="DynamicCharts" %>
using System.Web;

public class DynamicCharts : IHttpHandler
{
    public bool IsReusable { get { return true; } }

    public void ProcessRequest(HttpContext context)
    {
        DynamicChartData.WriteResponse(context);
    }
}

