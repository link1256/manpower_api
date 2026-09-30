<%@ WebHandler Language="C#" Class="AjaxDataUtil" %>
using Newtonsoft.Json;
using System;
using System.Data;
using System.Web;
using System.Data.SqlClient;
using System.Reflection;
using System.Collections.Generic;
using System.Configuration;
using Supergeo.ComputeMod;
using System.IO;

public class AjaxDataUtil : IHttpHandler, System.Web.SessionState.IRequiresSessionState
{
    String sqlConnstr = System.Configuration.ConfigurationManager.ConnectionStrings["CensusGISADONet"].ConnectionString;
    ComputeMod ComputeMod = new ComputeMod();
    public void ProcessRequest(HttpContext context)
    {
        try
        {
            String result = "";
            Type t = GetType();
            MethodInfo m = t.GetMethod(context.Request["op"] as String);
            if (m != null)
                result = m.Invoke(this, new object[] { context }) as string;

            context.Response.Write(result);
        }
        catch (Exception e)
        {
            string ex = e.ToString();
            // context.Response.Write(ex);
        }
    }

    public class MNYear
    {
        public int maxyear { get; set; }
        public int minyear { get; set; }
    }

    public class listitem
    {
        public double FPS { get; set; }
        public double PEP { get; set; }
        public double PUP { get; set; }
        public double LAF { get; set; }
        public double NLF { get; set; }
        public double UPR { get; set; }
        public double LFP { get; set; }
        public double SFU { get; set; }
        public double TRU { get; set; }
        public double PLF { get; set; }
        public double LU1 { get; set; }
        public double LU2 { get; set; }
        public double LU3 { get; set; }
        public double LU4 { get; set; }
        public string date { get; set; }
        public string date_eng { get; set; }
    }

    public String GetIndexData(HttpContext context)
    {
        string jData = "";
        string startyear = context.Request["startyear"] as string;
        string endyear = context.Request["endyear"] as string;

        MNYear target = GetYears();
        int sy = 0, ey = 0;
        if (startyear == null && endyear == null)
        {
            int lastyear = target.maxyear;

            ey = Convert.ToInt32(lastyear);
            sy = ey - 10;

            if (sy < 1978) sy = 1978;
        }
        else
        {
            sy = Convert.ToInt32(startyear);
            ey = Convert.ToInt32(endyear);
        }

        string code = "";
        string table = "STATDATA_NEW182A";

        code = "PEP04T0000X0000000000000";
        DataTable pep = GetTargetTable(code, table, startyear, endyear);
        code = "PUP04T0000X0000000000000";
        DataTable pup = GetTargetTable(code, table, startyear, endyear);
        code = "NLF04T0000X0000000000000";
        DataTable nlf = GetTargetTable(code, table, startyear, endyear);

        code = "SFU09T0000X0000000000000";
        DataTable sfu = GetTargetTable(code, table, startyear, endyear);
        code = "TRU09T0000X0000000000000";
        DataTable tru = GetTargetTable(code, table, startyear, endyear);
        code = "PLF09T0000X0000000000000";
        DataTable plf = GetTargetTable(code, table, startyear, endyear);

        List<listitem> data = new List<listitem>();
        int cugmonth = 0;

        DataRow[] frow = pep.Select("YEAR = '" + ey + "'");
        cugmonth = frow.Length;

        for (int i = sy; i <= ey; i++)
        {
            DataRow[] peprow = pep.Select("YEAR = '" + i + "'");
            DataRow[] puprow = pup.Select("YEAR = '" + i + "'");
            DataRow[] nlfrow = nlf.Select("YEAR = '" + i + "'");

            DataRow[] sfurow = sfu.Select("YEAR = '" + i + "'");
            DataRow[] trurow = tru.Select("YEAR = '" + i + "'");
            DataRow[] plfrow = plf.Select("YEAR = '" + i + "'");

            double pepsum = 0, pupsum = 0, nlfsum = 0, sfusum = 0, trusum = 0, plfsum = 0;
            double cpepsum = 0, cpupsum = 0, cnlfsum = 0, csfusum = 0, ctrusum = 0, cplfsum = 0;

            for (int j = 0; j < peprow.Length; j++)
            {
                pepsum += Convert.ToDouble(peprow[j]["STAT_VAL"].ToString());
                pupsum += Convert.ToDouble(puprow[j]["STAT_VAL"].ToString());
                nlfsum += Convert.ToDouble(nlfrow[j]["STAT_VAL"].ToString());

                if (cugmonth == 0 || j < cugmonth)
                {
                    cpepsum += Convert.ToDouble(peprow[j]["STAT_VAL"].ToString());
                    cpupsum += Convert.ToDouble(puprow[j]["STAT_VAL"].ToString());
                    cnlfsum += Convert.ToDouble(nlfrow[j]["STAT_VAL"].ToString());
                }
            }

            for (int j = 0; j < sfurow.Length; j++)
            {
                sfusum += Convert.ToDouble(sfurow[j]["STAT_VAL"].ToString());
                trusum += Convert.ToDouble(trurow[j]["STAT_VAL"].ToString());
                plfsum += Convert.ToDouble(plfrow[j]["STAT_VAL"].ToString());

                if (cugmonth == 0 || j < cugmonth)
                {
                    csfusum += Convert.ToDouble(sfurow[j]["STAT_VAL"].ToString());
                    ctrusum += Convert.ToDouble(trurow[j]["STAT_VAL"].ToString());
                    cplfsum += Convert.ToDouble(plfrow[j]["STAT_VAL"].ToString());
                }
            }

            //年平均
            if (peprow.Length == 12)
            {
                if (i == 2023 || i == 2024)
                {
                    listitem item = new listitem()
                    {
                        FPS = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(pepsum + pupsum + nlfsum), 1000),
                        PEP = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(pepsum), 1000),
                        PUP = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(pupsum), 1000),
                        LAF = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(pepsum + pupsum), 1000),
                        NLF = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(nlfsum), 1000),
                        UPR = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(pupsum), Convert.ToDecimal(pepsum + pupsum), 2),
                        LFP = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(pepsum + pupsum), Convert.ToDecimal(pepsum + pupsum + nlfsum), 2),

                        SFU = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(sfusum), 1000),
                        TRU = Double.NaN,
                        PLF = Double.NaN,

                        LU1 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfusum), Convert.ToDecimal(pepsum + sfusum), 2),
                        LU2 = Double.NaN,
                        LU3 = Double.NaN,
                        LU4 = Double.NaN,
                        date = (i - 1911) + " 年平均",
                        date_eng = "Average " + i
                    };
                    data.Add(item);
                }
                else
                {
                    listitem item = new listitem()
                    {
                        FPS = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(pepsum + pupsum + nlfsum), 1000),
                        PEP = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(pepsum), 1000),
                        PUP = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(pupsum), 1000),
                        LAF = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(pepsum + pupsum), 1000),
                        NLF = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(nlfsum), 1000),
                        UPR = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(pupsum), Convert.ToDecimal(pepsum + pupsum), 2),
                        LFP = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(pepsum + pupsum), Convert.ToDecimal(pepsum + pupsum + nlfsum), 2),
                        SFU = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(sfusum), 1000),
                        TRU = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(trusum), 1000),
                        PLF = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(plfsum), 1000),
                        LU1 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfusum), Convert.ToDecimal(pepsum + sfusum), 2),
                        LU2 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfusum + trusum), Convert.ToDecimal(pepsum + sfusum), 2),
                        LU3 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfusum + plfsum), Convert.ToDecimal(pepsum + sfusum + plfsum), 2),
                        LU4 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfusum + trusum + plfsum), Convert.ToDecimal(pepsum + sfusum + plfsum), 2),
                        date = (i - 1911) + " 年平均",
                        date_eng = "Average " + i
                    };
                    data.Add(item);
                }
            }
            else
            {
                listitem item = new listitem()
                {
                    FPS = Double.NaN,
                    PEP = Double.NaN,
                    PUP = Double.NaN,
                    LAF = Double.NaN,
                    NLF = Double.NaN,
                    UPR = Double.NaN,
                    LFP = Double.NaN,
                    SFU = Double.NaN,
                    TRU = Double.NaN,
                    PLF = Double.NaN,
                    LU1 = Double.NaN,
                    LU2 = Double.NaN,
                    LU3 = Double.NaN,
                    LU4 = Double.NaN,
                    date = (i - 1911) + " 年平均",
                    date_eng = "Average " + i
                };
                data.Add(item);
            }

            //累計平均
            if (cugmonth > 0)
            {
                int months = cugmonth;

                if (i == 2023 || i == 2024)
                {
                    listitem item = new listitem()
                    {
                        FPS = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cpepsum + cpupsum + cnlfsum), 1000),
                        PEP = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cpepsum), 1000),
                        PUP = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cpupsum), 1000),
                        LAF = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cpepsum + cpupsum), 1000),
                        NLF = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cnlfsum), 1000),
                        UPR = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(cpupsum), Convert.ToDecimal(cpepsum + cpupsum), 2),
                        LFP = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(cpepsum + cpupsum), Convert.ToDecimal(cpepsum + cpupsum + cnlfsum), 2),

                        SFU = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(csfusum), 1000),
                        TRU = Double.NaN,
                        PLF = Double.NaN,

                        LU1 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(csfusum), Convert.ToDecimal(cpepsum + csfusum), 2),
                        LU2 = Double.NaN,
                        LU3 = Double.NaN,
                        LU4 = Double.NaN,
                        date = (i - 1911) + "年 1-" + months + "月",
                        date_eng = "Jan to " + DictionaryMonth_Eng(months.ToString()) + " " + i
                    };
                    data.Add(item);
                }
                else
                {
                    listitem item = new listitem()
                    {
                        FPS = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cpepsum + cpupsum + cnlfsum), 1000),
                        PEP = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cpepsum), 1000),
                        PUP = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cpupsum), 1000),
                        LAF = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cpepsum + cpupsum), 1000),
                        NLF = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cnlfsum), 1000),
                        UPR = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(cpupsum), Convert.ToDecimal(cpepsum + cpupsum), 2),
                        LFP = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(cpepsum + cpupsum), Convert.ToDecimal(cpepsum + cpupsum + cnlfsum), 2),
                        SFU = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(csfusum), 1000),
                        TRU = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(ctrusum), 1000),
                        PLF = (double)ComputeMod.ComputeAvgPepole(months, Convert.ToDecimal(cplfsum), 1000),
                        LU1 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(csfusum), Convert.ToDecimal(cpepsum + csfusum), 2),
                        LU2 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(csfusum + ctrusum), Convert.ToDecimal(cpepsum + csfusum), 2),
                        LU3 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(csfusum + cplfsum), Convert.ToDecimal(cpepsum + csfusum + cplfsum), 2),
                        LU4 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(csfusum + ctrusum + cplfsum), Convert.ToDecimal(cpepsum + csfusum + cplfsum), 2),
                        date = (i - 1911) + "年 1-" + months + "月",
                        date_eng = "Jan to " + DictionaryMonth_Eng(months.ToString()) + " " + i
                    };
                    data.Add(item);
                }
            }

            for (int j = 0; j < peprow.Length; j++)
            {
                string m = peprow[j]["MONTH"].ToString();
                double pepv = Convert.ToDouble(peprow[j]["STAT_VAL"].ToString());
                double pupv = Convert.ToDouble(puprow[j]["STAT_VAL"].ToString());
                double nlfv = Convert.ToDouble(nlfrow[j]["STAT_VAL"].ToString());

                double sfuv = 0;
                double truv = 0;
                double plfv = 0;

                if (j < sfurow.Length)
                {
                    sfuv = Convert.ToDouble(sfurow[j]["STAT_VAL"].ToString());
                    truv = Convert.ToDouble(trurow[j]["STAT_VAL"].ToString());
                    plfv = Convert.ToDouble(plfrow[j]["STAT_VAL"].ToString());
                }

                bool check = CheckIsSpecialMonth(i, Convert.ToInt32(m));
                if (check == true)
                {
                    listitem item = new listitem()
                    {
                        FPS = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(pepv + pupv + nlfv), 1000),
                        PEP = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(pepv), 1000),
                        PUP = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(pupv), 1000),
                        LAF = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(pepv + pupv), 1000),
                        NLF = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(nlfv), 1000),
                        UPR = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(pupv), Convert.ToDecimal(pepv + pupv), 2),
                        LFP = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(pepv + pupv), Convert.ToDecimal(pepv + pupv + nlfv), 2),

                        SFU = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(sfuv), 1000),
                        TRU = Double.NaN,
                        PLF = Double.NaN,

                        LU1 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfuv), Convert.ToDecimal(pepv + sfuv), 2),
                        LU2 = Double.NaN,
                        LU3 = Double.NaN,
                        LU4 = Double.NaN,

                        date = (i - 1911) + "年 " + m + "月",
                        date_eng = DictionaryMonth_Eng(m) + " " + i
                    };
                    data.Add(item);
                }
                else
                {
                    listitem item = new listitem()
                    {
                        FPS = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(pepv + pupv + nlfv), 1000),
                        PEP = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(pepv), 1000),
                        PUP = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(pupv), 1000),
                        LAF = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(pepv + pupv), 1000),
                        NLF = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(nlfv), 1000),
                        UPR = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(pupv), Convert.ToDecimal(pepv + pupv), 2),
                        LFP = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(pepv + pupv), Convert.ToDecimal(pepv + pupv + nlfv), 2),

                        SFU = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(sfuv), 1000),
                        TRU = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(truv), 1000),
                        PLF = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(plfv), 1000),

                        LU1 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfuv), Convert.ToDecimal(pepv + sfuv), 2),
                        LU2 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfuv + truv), Convert.ToDecimal(pepv + sfuv), 2),
                        LU3 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfuv + plfv), Convert.ToDecimal(pepv + sfuv + plfv), 2),
                        LU4 = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(sfuv + truv + plfv), Convert.ToDecimal(pepv + sfuv + plfv), 2),

                        date = (i - 1911) + "年 " + m + "月",
                        date_eng = DictionaryMonth_Eng(m) + " " + i
                    };
                    data.Add(item);
                }
            }
        }
        SetBrowserCount("ALL");
        jData = JsonConvert.SerializeObject(new { data = data, MNYear = target, lastmonth = cugmonth });
        return jData;
    }

    public bool CheckIsSpecialMonth(int year, int month)
    {
        bool isSpecial = false;

        if (year == 2023)
        {
            isSpecial = true;
        }
        else if (year == 2024 && month >= 1 && month <= 5)
        {
            isSpecial = true;
        }

        return isSpecial;
    }

    public string GetSeasonIndexData(HttpContext context)
    {
        string jData = "";
        string startyear = context.Request["startyear"] as string;
        string endyear = context.Request["endyear"] as string;

        MNYear target = GetSeasonYears();
        int sy = 0, ey = 0;

        WriteLog(startyear + "/" + endyear);
        if (startyear == null && endyear == null)
        {
            int lastyear = target.maxyear;

            WriteLog(lastyear.ToString());

            ey = Convert.ToInt32(lastyear);
            sy = ey - 10;

            if (sy < 1978) sy = 1978;
        }
        else
        {
            sy = Convert.ToInt32(startyear);
            ey = Convert.ToInt32(endyear);
        }

        WriteLog(sy + "/" + ey);

        string cy = ConfigurationManager.AppSettings["SeasonYear"];
        string cm = ConfigurationManager.AppSettings["SeasonMonth"];

        int scy = Convert.ToInt32(cy) + 1911;
        int scm = Convert.ToInt32(cm);

        if (sy > scy)
        {
            sy = scy;
        }
        if (ey > scy)
        {
            ey = scy;
        }

        if (scy != ey)
        {
            scm = 12;
        }

        WriteLog(sy + "/" + ey);

        target.maxyear = ey;
        target.minyear = sy;

        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
			    SELECT *
                FROM [Unemployedrate_Adjust]
                WHERE (([YEAR] < @endyear AND [YEAR] >= @startyear) OR ([YEAR] = @endyear AND ([MONTH] + 0) <= @endmonth)) 
			    ORDER BY [YEAR] ASC, ([MONTH] + 0) ASC ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@startyear", sy.ToString()),
                    new SqlParameter("@endyear", ey.ToString()),
                    new SqlParameter("@endmonth", scm.ToString())
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                dt = ds.Tables[0];

                List<listitem> data = new List<listitem>();

                foreach (DataRow r in dt.Rows)
                {
                    listitem item = new listitem();

                    item.PEP = Convert.ToDouble(r["Employed"].ToString());
                    item.PUP = Convert.ToDouble(r["Unemployed"].ToString());
                    item.LAF = Convert.ToDouble(r["Labor_Force"].ToString());
                    item.NLF = Convert.ToDouble(r["Not_In_Labor_Force"].ToString());
                    item.UPR = Convert.ToDouble(r["Unemployment_Rate"].ToString());
                    item.LFP = Convert.ToDouble(r["Labor_Force_Participation_Rate"].ToString());

                    item.date = (Convert.ToInt32(r["Year"].ToString()) - 1911) + "年 " + r["Month"].ToString() + "月";
                    item.date_eng = DictionaryMonth_Eng(r["Month"].ToString()) + " " + r["Year"].ToString();

                    data.Add(item);
                }

                jData = JsonConvert.SerializeObject(new { data = data, MNYear = target, lastmonth = scm });
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        }

        return jData;
    }

    public string DictionaryMonth_Eng(string m)
    {
        switch (m)
        {
            case "1":
                return "Jan";
            case "2":
                return "Feb";
            case "3":
                return "Mar";
            case "4":
                return "Apr";
            case "5":
                return "May";
            case "6":
                return "June";
            case "7":
                return "July";
            case "8":
                return "Aug";
            case "9":
                return "Sept";
            case "10":
                return "Oct";
            case "11":
                return "Nov";
            case "12":
                return "Dec";
            default:
                return "";
        }
    }

    public DataTable GetTargetTable(string code, string table, string startyear, string endyear)
    {
        int? sy = null, ey = null;

        int showmaxy = Convert.ToInt32(getShowYear()) + 1911;
        int showmaxm = Convert.ToInt32(getShowMonth());

        if (startyear == null && endyear == null)
        {
            ey = showmaxy;
            sy = ey - 10;

            if (sy < 1978) sy = 1978;
        }
        else
        {
            sy = Convert.ToInt32(startyear);
            ey = Convert.ToInt32(endyear);

            if (ey < showmaxy)
            {
                showmaxm = 12;
            }
        }

        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
			    SELECT DISTINCT 
					    [YEAR] 
					    ,([MONTH] + 0) as [MONTH] 
					    ,[STAT_VAL] 
			    FROM " + table +
                @" WHERE STATID = @code AND (([YEAR] < @endyear AND [YEAR] >= @startyear) OR ([YEAR] = @endyear AND ([MONTH] + 0) <= @endmonth)) 
			    ORDER BY [YEAR] ASC, ([MONTH] + 0) ASC ";
            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@code", code),
                    new SqlParameter("@startyear", sy.ToString()),
                    new SqlParameter("@endyear", ey.ToString()),
                    new SqlParameter("@endmonth", showmaxm.ToString())
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                dt = ds.Tables[0];
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        }
        return dt;
    }

    public MNYear GetPlayDataYears()
    {
        MNYear d = new MNYear();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
                SELECT MAX(Year) as maxyear, MIN(Year) as minyear
                FROM PlayData 
                WHERE LAF <> 0 AND LFP <> 0
            ";
            command.CommandText = sqlStr;

            try
            {
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                int maxyear = -9999;
                int minyear = 9999;

                for (int i = 0; i < ds.Tables.Count; i++)
                {
                    int tmax = Convert.ToInt16(ds.Tables[i].Rows[0]["maxyear"].ToString());
                    int tmin = Convert.ToInt16(ds.Tables[i].Rows[0]["minyear"].ToString());

                    if (maxyear <= tmax)
                        maxyear = tmax;
                    if (minyear >= tmin)
                        minyear = tmin;
                }

                d.maxyear = maxyear;
                d.minyear = minyear;
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        }

        return d;
    }

    public String GetPlayData(HttpContext context)
    {
        string jData = "";

        DataTable Male = GetPlayDataTable("男");
        DataTable Female = GetPlayDataTable("女");
        MNYear target = GetPlayDataYears();

        jData = JsonConvert.SerializeObject(new { Male = Male, Female = Female, mnyear = target });

        return (jData);
    }

    public DataTable GetPlayDataTable(String sex)
    {
        DataTable dt = new DataTable();

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT [Sno], [Year], [Age], [Sex], [LAF], [LFP] 
                            FROM PlayData
                            WHERE Sex = @Sex AND LAF <> 0 AND LFP <> 0 
                            ORDER BY YEAR, AGE ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Sex", sex)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                dt = ds.Tables[0];
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        };

        return dt;
    }

    public String GetData(HttpContext context)
    {
        string jData = "";
        string type = context.Request["type"] as string;

        string startyear = context.Request["startyear"] as string;
        string endyear = context.Request["endyear"] as string;

        MNYear target = GetYears();

        string code = "";
        string table = "STATDATA_NEW172A";

        switch(type)
        {
            case "PEP":
                code = "PEP04T0000X0000000000000";
                string v1 = GetTableData(code, table, startyear, endyear);
                var vv1 = JsonConvert.DeserializeObject(v1);
                var a = JsonConvert.DeserializeObject(GetIndexData(context));
                jData = JsonConvert.SerializeObject(new { PEP = vv1, MNYear = target, avg = a });
                break;
            case "PUP":
                code = "PUP04T0000X0000000000000";
                string v2 = GetTableData(code, table, startyear, endyear);
                var vv2 = JsonConvert.DeserializeObject(v2);
                var b = JsonConvert.DeserializeObject(GetIndexData(context));
                jData = JsonConvert.SerializeObject(new { PUP = vv2, MNYear = target, avg = b });
                break;
            case "NLF":
                code = "NLF04T0000X0000000000000";
                string v3 = GetTableData(code, table, startyear, endyear);
                var vv3 = JsonConvert.DeserializeObject(v3);
                var c = JsonConvert.DeserializeObject(GetIndexData(context));
                jData = JsonConvert.SerializeObject(new { NLF = vv3, MNYear = target, avg = c });
                break;
            case "LAF":
                code = "PEP04T0000X0000000000000";
                string laf1 = GetTableData(code, table, startyear, endyear);
                code = "PUP04T0000X0000000000000";
                string laf2 = GetTableData(code, table, startyear, endyear);
                var lafm1 = JsonConvert.DeserializeObject(laf1);
                var lafm2 = JsonConvert.DeserializeObject(laf2);
                var d = (GetIndexData(context));
                jData = JsonConvert.SerializeObject(new { PEP = lafm1, PUP = lafm2, MNYear = target, avg = d });
                break;
            case "FPS":
                code = "PEP04T0000X0000000000000";
                string fps1 = GetTableData(code, table, startyear, endyear);
                code = "PUP04T0000X0000000000000";
                string fps2 = GetTableData(code, table, startyear, endyear);
                code = "NLF04T0000X0000000000000";
                string fps3 = GetTableData(code, table, startyear, endyear);

                var fpsm1 = JsonConvert.DeserializeObject(fps1);
                var fpsm2 = JsonConvert.DeserializeObject(fps2);
                var fpsm3 = JsonConvert.DeserializeObject(fps3);
                var f = JsonConvert.DeserializeObject(GetIndexData(context));
                jData = JsonConvert.SerializeObject(new { PEP = fpsm1, PUP = fpsm2, NLF = fpsm3, MNYear = target, avg = f });
                break;
            case "LFP":
                code = "PEP04T0000X0000000000000";
                string lfp1 = GetTableData(code, table, startyear, endyear);
                code = "PUP04T0000X0000000000000";
                string lfp2 = GetTableData(code, table, startyear, endyear);
                code = "NLF04T0000X0000000000000";
                string lfp3 = GetTableData(code, table, startyear, endyear);
                var lfpm1 = JsonConvert.DeserializeObject(lfp1);
                var lfpm2 = JsonConvert.DeserializeObject(lfp2);
                var lfpm3 = JsonConvert.DeserializeObject(lfp3);

                var g = JsonConvert.DeserializeObject(GetIndexData(context));
                jData = JsonConvert.SerializeObject(new { PEP = lfpm1, PUP = lfpm2, NLF = lfpm3, MNYear = target, avg = g });

                break;
            case "UPR":
                code = "PEP04T0000X0000000000000";
                string upr1 = GetTableData(code, table, startyear, endyear);
                code = "PUP04T0000X0000000000000";
                string upr2 = GetTableData(code, table, startyear, endyear);
                var uprm1 = JsonConvert.DeserializeObject(upr1);
                var uprm2 = JsonConvert.DeserializeObject(upr2);

                var h = JsonConvert.DeserializeObject(GetIndexData(context));
                jData = JsonConvert.SerializeObject(new { PEP = uprm1, PUP = uprm2, MNYear = target, avg = h });

                break;
        }

        SetBrowserCount(type);

        return (jData);
    }

    public void SetBrowserCount(string type)
    {
        string roctype = getROCType(type);
        DataRow recode = CheckAlreadyHasRecord(roctype);
        DateTime ndate = DateTime.Now;
        DateTime odate = ndate.Date;

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            if (recode != null)
            {
                sqlStr = @"UPDATE Count_List 
                           SET BrowseCount=@BrowseCount 
                           WHERE Sno=@Sno ";
            }
            else
            {
                sqlStr = @"INSERT INTO Count_List (Time, FunctionName, StatisticItem, BrowseCount, DownloadTable, DownloadChart) 
                           VALUES (@Time, '常用資料查詢', @StatisticItem, 1, 0, 0)";
            }
            command.CommandText = sqlStr;
            try
            {
                if (recode != null)
                {
                    SqlParameter[] p = {
                        new SqlParameter("@BrowseCount", Convert.ToInt32(recode["BrowseCount"].ToString()) + 1),
                        new SqlParameter("@Sno", recode["Sno"].ToString())
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);
                }
                else
                {
                    SqlParameter[] p = {
                        new SqlParameter("@Time", odate),
                        new SqlParameter("@StatisticItem", roctype)
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);
                }
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        };
    }

    public void SetTableCount(HttpContext context)
    {
        string type = context.Request["type"] as string;
        string roctype = getROCType(type);
        DataRow recode = CheckAlreadyHasRecord(roctype);
        DateTime ndate = DateTime.Now;
        DateTime odate = ndate.Date;

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            if (recode != null)
            {
                sqlStr = @"UPDATE Count_List 
                           SET DownloadTable=@DownloadTable 
                           WHERE Sno=@Sno ";
            }
            else
            {
                sqlStr = @"INSERT INTO Count_List (Time, FunctionName, StatisticItem, BrowseCount, DownloadTable, DownloadChart) 
                           VALUES (@Time, '常用資料查詢', @StatisticItem, 0, 1, 0)";
            }
            command.CommandText = sqlStr;
            try
            {
                if (recode != null)
                {
                    SqlParameter[] p = {
                        new SqlParameter("@DownloadTable", Convert.ToInt32(recode["DownloadTable"].ToString()) + 1),
                        new SqlParameter("@Sno", recode["Sno"].ToString())
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);
                }
                else
                {
                    SqlParameter[] p = {
                        new SqlParameter("@Time", odate),
                        new SqlParameter("@StatisticItem", roctype)
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);
                }
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        };
    }

    public void SetChartCount(HttpContext context)
    {
        string type = context.Request["type"] as string;
        string roctype = getROCType(type);
        DataRow recode = CheckAlreadyHasRecord(roctype);
        DateTime ndate = DateTime.Now;
        DateTime odate = ndate.Date;

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            if (recode != null)
            {
                sqlStr = @"UPDATE Count_List 
                           SET DownloadChart=@DownloadChart 
                           WHERE Sno=@Sno ";
            }
            else
            {
                sqlStr = @"INSERT INTO Count_List (Time, FunctionName, StatisticItem, BrowseCount, DownloadTable, DownloadChart) 
                           VALUES (@Time, '常用資料查詢', @StatisticItem, 0, 0, 1)";
            }
            command.CommandText = sqlStr;
            try
            {
                if (recode != null)
                {
                    SqlParameter[] p = {
                        new SqlParameter("@DownloadChart", Convert.ToInt32(recode["DownloadChart"].ToString()) + 1),
                        new SqlParameter("@Sno", recode["Sno"].ToString())
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);
                }
                else
                {
                    SqlParameter[] p = {
                        new SqlParameter("@Time", odate),
                        new SqlParameter("@StatisticItem", roctype)
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);
                }
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        };
    }

    public DataRow CheckAlreadyHasRecord(string roctype)
    {
        DateTime ndate = DateTime.Now;
        DateTime odate = ndate.Date;

        DataRow row = null;
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM Count_List WHERE Time=@Time AND FunctionName=@FunctionName AND StatisticItem=@StatisticItem ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Time", odate),
                    new SqlParameter("@FunctionName", "常用資料查詢"),
                    new SqlParameter("@StatisticItem", roctype)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);
                DataTable dt = ds.Tables[0];
                if (dt.Rows.Count > 0)
                    row = dt.Rows[0];
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        };
        return row;
    }

    public string getROCType(string type)
    {
        string roctype = "";
        switch(type)
        {
            case "PEP":
                roctype = "就業者";
                break;
            case "PUP":
                roctype = "失業者";
                break;
            case "NLF":
                roctype = "非勞動力";
                break;
            case "LAF":
                roctype = "勞動力";
                break;
            case "FPS":
                roctype = "15歲以上民間人口";
                break;
            case "LFP":
                roctype = "勞動力參與率";
                break;
            case "UPR":
                roctype = "失業率";
                break;
            case "ALL":
                roctype = "所有指標";
                break;
        }
        return roctype;
    }

    public String GetTableData(string code, string table, string startyear, string endyear)
    {
        int? sy = null, ey = null;
        int showmaxy = Convert.ToInt32(getShowYear()) + 1911;
        int showmaxm = Convert.ToInt32(getShowMonth());

        if (startyear == null && endyear == null)
        {
            ey = showmaxy;
            sy = ey - 10;

            if (sy < 1978) sy = 1978;
        }
        else
        {
            sy = Convert.ToInt32(startyear);
            ey = Convert.ToInt32(endyear);

            if (ey < showmaxy)
            {
                showmaxm = 12;
            }
        }

        String jData = "";
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
			    SELECT DISTINCT 
					    [YEAR] 
					    ,([MONTH] + 0) as [MONTH] 
					    ,[STAT_VAL] 
			    FROM " + table +
                @" WHERE STATID = @code AND (([YEAR] < @endyear AND [YEAR] >= @startyear) OR ([YEAR] = @endyear  AND ([MONTH] + 0) <= @endmonth)) 
			    ORDER BY [YEAR] ASC, ([MONTH] + 0) ASC ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@code", code),
                    new SqlParameter("@startyear", sy.ToString()),
                    new SqlParameter("@endyear", ey.ToString()),
                    new SqlParameter("@endmonth", showmaxm.ToString()),
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                jData = JsonConvert.SerializeObject(ds.Tables[0]);
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        }
        return (jData);
    }

    public String GetLastestYear(string code, string table)
    {
        String jData = "";
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT MAX([YEAR]) as value 
						FROM " + table +
                      " WHERE STATID = @code ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@code", code)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                DataTable t = ds.Tables[0];

                int y = Convert.ToInt32(t.Rows[0]["value"].ToString());
                int my = Convert.ToInt32(getShowYear()) + 1911;

                if (y >= my)
                    jData = my.ToString();
                else
                    jData = y.ToString();
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        }
        return (jData);
    }

    //取得顯示到的年份跟月份
    public String getShowYear()
    {
        string daystring = ConfigurationManager.AppSettings["TaiwanDataYear"];
        return daystring;
    }

    public String getShowMonth()
    {
        string daystring = ConfigurationManager.AppSettings["TaiwanDataMonth"];
        return daystring;
    }

    public MNYear GetYears()
    {
        MNYear d = new MNYear();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM STATDATA_NEW182A 
            ";
            command.CommandText = sqlStr;

            try
            {
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                int maxyear = -9999;
                int minyear = 9999;
                for (int i = 0; i < ds.Tables.Count; i++)
                {
                    int tmax = Convert.ToInt16(ds.Tables[i].Rows[0]["maxyear"].ToString());
                    int tmin = Convert.ToInt16(ds.Tables[i].Rows[0]["minyear"].ToString());

                    if (maxyear <= tmax)
                        maxyear = tmax;
                    if (minyear >= tmin)
                        minyear = tmin;
                }

                int showyear = Convert.ToInt32(getShowYear()) + 1911;
                if (maxyear >= showyear)
                    maxyear = showyear;

                d.maxyear = maxyear;
                d.minyear = minyear;
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        }

        return d;
    }

    public MNYear GetSeasonYears()
    {
        MNYear d = new MNYear();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM [Unemployedrate_Adjust] 
            ";
            command.CommandText = sqlStr;

            try
            {
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                int maxyear = -9999;
                int minyear = 9999;
                for (int i = 0; i < ds.Tables.Count; i++)
                {
                    int tmax = Convert.ToInt16(ds.Tables[i].Rows[0]["maxyear"].ToString());
                    int tmin = Convert.ToInt16(ds.Tables[i].Rows[0]["minyear"].ToString());

                    if (maxyear <= tmax)
                        maxyear = tmax;
                    if (minyear >= tmin)
                        minyear = tmin;
                }

                d.maxyear = maxyear;
                d.minyear = minyear;
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        }

        return d;
    }

    public void WriteLog(String logMsg)
    {
        string ppath = System.AppDomain.CurrentDomain.BaseDirectory;
        string logPath = ppath + "/Log/Jerry/";
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

    public bool IsReusable {
        get {
            return false;
        }
    }
}