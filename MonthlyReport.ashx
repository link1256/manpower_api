<%@ WebHandler Language="C#" Class="MonthlyReport" %>

using Newtonsoft.Json;
using System;
using System.Data;
using System.Web;
using System.Data.SqlClient;
using System.Reflection;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using Supergeo.ComputeMod;
using System.IO;
using System.Diagnostics;
using NPOI.XSSF.UserModel;
using NPOI.SS.UserModel;
using System.Web.SessionState;

public class MonthlyReport : IHttpHandler, IRequiresSessionState
{
    String sqlConnstr = System.Configuration.ConfigurationManager.ConnectionStrings["CensusGISADONet"].ConnectionString;
    ComputeMod ComputeMod = new ComputeMod();
    String tablestring = "SHIEN25A";
    String tablecode = "06";
    String[] citys = {
        "臺灣地區", "北部區域", "新北市", "臺北市", "桃園市", "基隆市", "新竹市", "宜蘭縣", "新竹縣", "中部區域",
        "臺中市", "苗栗縣", "彰化縣", "南投縣", "雲林縣", "南部區域", "臺南市", "高雄市", "嘉義市", "嘉義縣",
        "屏東縣", "澎湖縣", "東部區域", "臺東縣", "花蓮縣"
        };

    public void ProcessRequest(HttpContext context)
    {
        try
        {
            if (context.Session["logaccount"] != null && context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('6') > -1)
            {
                String result = "";
                Type t = GetType();
                MethodInfo m = t.GetMethod(context.Request["op"] as String);
                if (m != null)
                    result = m.Invoke(this, new object[] { context }) as string;

                context.Response.Write(result);
            }
            else
            {
                context.Response.Write("沒有權限");
            }
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

    public String GetBaseInfo(HttpContext context)
    {
        String jData = "";

        MNYear target = GetYears();

        jData = JsonConvert.SerializeObject(new { MNYear = target });

        return (jData);
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
                FROM STATDATA_SHIEN25A
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

    public class listitem
    {
        public string date { get; set; } //年月
        public string classes { get; set; } //統計項
        public string sex { get; set; } //性別
        public decimal value { get; set; } //值
        public string county { get; set; } //地區
        public string level { get; set; } //階層
    }

    public class rdata
    {
        public List<listitem> data { get; set; }
        public Dictionary<string, decimal> data2 { get; set; }
    }

    public String GetRequestTables(HttpContext context)
    {
        string state = context.Request["states"] as string;
        string jData = "";
        List<listitem> list = new List<listitem>();

        CompareMonthlyData(context, list, null);

        jData = JsonConvert.SerializeObject(list);
        return jData;
    }

    public rdata GetRequestTables2(HttpContext context)
    {
        string state = context.Request["states"] as string;
        List<listitem> list = new List<listitem>();
        Dictionary<string, decimal> data2 = new Dictionary<string, decimal>();

        CompareMonthlyData(context, list, data2);

        rdata r = new rdata();
        r.data = list;
        r.data2 = data2;

        return r;
    }

    public void CompareMonthlyData(HttpContext context, List<listitem> list, Dictionary<string, decimal> data2)
    {
        string cycle = context.Request["states"] as string;
        string sex = context.Request["sex"] as string;

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        int isy = Convert.ToInt32(sy) + 1911;
        int iey = Convert.ToInt32(ey) + 1911;

        // 年報為全台地區 取得新縣市全台的CODE
        DataTable zCode = GetZoneCode("臺灣地區", false);
        // 性別組合
        string[] allsex = sex.Split(',');
        // 計算組合編碼
        List<string> ctip = new List<string>{
            "PEP" + tablecode,
            "PUP" + tablecode,
            "NLF" + tablecode
        };

        List<DataTable> dts = new List<DataTable>();

        for (int i = 0; i < ctip.Count; i++)
        {
            List<string> codes = new List<string>();
            for (int j = 0; j < allsex.Length; j++)
            {
                string code = "";
                code += ctip[i] + allsex[j] + "0000X0000000000000";
                codes.Add(code);
            }

            DataTable dt = GetYearTable(context, isy, iey, zCode, codes, tablestring);
            dts.Add(dt);
        }

        // 取得縣市的編碼
        DataTable zonedt = GetZoneTable(false);

        if (cycle == "1")
        {
            CompareMonthsData(context, dts, list, zonedt, data2);
        }
        else if (cycle == "2")
        {
            CompareSeasonData(context, dts, list, zonedt, data2);
        }
        else if (cycle == "3" || cycle == "4")
        {
            CompareHalfYearData(context, dts, list, zonedt, data2);
        }
        else if (cycle == "5")
        {
            CompareYearData(context, dts, list, zonedt, data2);
        }
    }

    // 計算月份/單月月份
    public void CompareMonthsData(HttpContext context, List<DataTable> dts, List<listitem> list, DataTable zonedt, Dictionary<string, decimal> data2)
    {
        string smonth = context.Request["months"] as string;
        string[] months = smonth.Split(',');
        string sex = context.Request["sex"] as string;
        string output1 = context.Request["output1"] as string;
        string output2 = context.Request["output2"] as string;

        // 根據縣市編碼來進行資料建立
        foreach (DataRow r in zonedt.Rows)
        {
            string lvl = r["LVL"].ToString();
            string c = r["DES_ZH"].ToString();
            string l = "2";

            List<string> tarcode = new List<string>();

            if (lvl == "1")
            {
                tarcode.Add(r["CODE"].ToString());
            }
            else if (lvl == "2")
            {
                string[] codes = r["CAL_ITEM"].ToString().Split(',');
                for (int i = 0; i < codes.Length; i++)
                {
                    tarcode.Add(codes[i]);
                }
            }

            // 篩選TABLE裡面需要的縣市
            string selectStr = "";
            for (int i = 0; i < tarcode.Count; i++)
            {
                if (i != 0)
                    selectStr += " OR ";

                selectStr += "COUNTY='" + tarcode[i] + "'";
            }

            List<DataTable> tardts = CompareZoneSumTable(dts, selectStr);

            // 就業者
            DataTable pepTable = tardts[0];
            foreach (DataRow tr in pepTable.Rows)
            {
                if (Array.IndexOf(months, tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString() + "月",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "就業者";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 失業者
            DataTable pupTable = tardts[1];
            foreach (DataRow tr in pupTable.Rows)
            {
                if (Array.IndexOf(months, tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString() + "月",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "失業者";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 非勞動力
            DataTable nlfTable = tardts[2];
            foreach (DataRow tr in nlfTable.Rows)
            {
                if (Array.IndexOf(months, tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString() + "月",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "非勞動力";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 15歲以上民間人口
            DataTable Table15 = MerageTable("2", tardts);
            foreach (DataRow tr in Table15.Rows)
            {
                if (Array.IndexOf(months, tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString() + "月",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "15歲以上民間人口";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 勞動力
            DataTable TableP = MerageTable("3", tardts);
            foreach (DataRow tr in TableP.Rows)
            {
                if (Array.IndexOf(months, tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString() + "月",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "勞動力";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 勞動力參與率
            DataTable TableLP = MerageTable("7", tardts);
            foreach (DataRow tr in TableLP.Rows)
            {
                if (Array.IndexOf(months, tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString() + "月",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "勞動力參與率";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output2 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 2);
                }
                else if (output2 == "2")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 失業率
            DataTable TableNP = MerageTable("6", tardts);
            foreach (DataRow tr in TableNP.Rows)
            {
                if (Array.IndexOf(months, tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString() + "月",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "失業率";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output2 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 2);
                }
                else if (output2 == "2")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

        }
    }
    // 計算年
    public void CompareYearData(HttpContext context, List<DataTable> dts, List<listitem> list, DataTable zonedt, Dictionary<string, decimal> data2)
    {
        string sex = context.Request["sex"] as string;
        string output1 = context.Request["output1"] as string;
        string output2 = context.Request["output2"] as string;

        // 根據縣市編碼來進行資料建立
        foreach (DataRow r in zonedt.Rows)
        {
            string lvl = r["LVL"].ToString();
            string c = r["DES_ZH"].ToString();
            string l = "2";

            List<string> tarcode = new List<string>();

            if (lvl == "1")
            {
                tarcode.Add(r["CODE"].ToString());
            }
            else if (lvl == "2")
            {
                string[] codes = r["CAL_ITEM"].ToString().Split(',');
                for (int i = 0; i < codes.Length; i++)
                {
                    tarcode.Add(codes[i]);
                }
            }

            // 篩選TABLE裡面需要的縣市
            string selectStr = "";
            for (int i = 0; i < tarcode.Count; i++)
            {
                if (i != 0)
                    selectStr += " OR ";

                selectStr += "COUNTY='" + tarcode[i] + "'";
            }

            List<DataTable> tardts = CompareZoneSumTable(dts, selectStr);

            // 就業者
            DataTable pepTable = computeTableYear(tardts[0]);

            foreach (DataRow tr in pepTable.Rows)
            {
                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "就業者";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 失業者
            DataTable pupTable = computeTableYear(tardts[1]);
            foreach (DataRow tr in pupTable.Rows)
            {
                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "失業者";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 非勞動力
            DataTable nlfTable = computeTableYear(tardts[2]);
            foreach (DataRow tr in nlfTable.Rows)
            {
                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "非勞動力";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 15歲以上民間人口
            DataTable Table15 = computeTableYear(MerageTable("2", tardts));

            foreach (DataRow tr in Table15.Rows)
            {
                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "15歲以上民間人口";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 勞動力
            DataTable TableP = computeTableYear(MerageTable("3", tardts));
            foreach (DataRow tr in TableP.Rows)
            {
                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "勞動力";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 勞動力參與率
            DataTable TableLP = computeTableYear2(tardts, "7")[0];

            foreach (DataRow tr in TableLP.Rows)
            {
                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "勞動力參與率";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output2 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 2);
                }
                else if (output2 == "2")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 失業率
            DataTable TableNP = computeTableYear2(tardts, "6")[0];
            foreach (DataRow tr in TableNP.Rows)
            {
                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年",
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "失業率";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output2 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 2);
                }
                else if (output2 == "2")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }
        }
    }
    // 計算半年
    public void CompareHalfYearData(HttpContext context, List<DataTable> dts, List<listitem> list, DataTable zonedt, Dictionary<string, decimal> data2)
    {
        string cycle = context.Request["states"] as string;
        string sex = context.Request["sex"] as string;
        string output1 = context.Request["output1"] as string;
        string output2 = context.Request["output2"] as string;

        string mStr = cycle == "3" ? "上半年" : "下半年";

        // 根據縣市編碼來進行資料建立
        foreach (DataRow r in zonedt.Rows)
        {
            string lvl = r["LVL"].ToString();
            string c = r["DES_ZH"].ToString();
            string l = "2";

            List<string> tarcode = new List<string>();

            if (lvl == "1")
            {
                tarcode.Add(r["CODE"].ToString());
            }
            else if (lvl == "2")
            {
                string[] codes = r["CAL_ITEM"].ToString().Split(',');
                for (int i = 0; i < codes.Length; i++)
                {
                    tarcode.Add(codes[i]);
                }
            }

            // 篩選TABLE裡面需要的縣市
            string selectStr = "";
            for (int i = 0; i < tarcode.Count; i++)
            {
                if (i != 0)
                    selectStr += " OR ";

                selectStr += "COUNTY='" + tarcode[i] + "'";
            }

            List<DataTable> tardts = CompareZoneSumTable(dts, selectStr);

            // 就業者
            DataTable pepTable = computeTableHalfYear(tardts[0]);

            foreach (DataRow tr in pepTable.Rows)
            {
                if (tr["MONTH"].ToString() != mStr)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "就業者";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 失業者
            DataTable pupTable = computeTableHalfYear(tardts[1]);

            foreach (DataRow tr in pupTable.Rows)
            {
                if (tr["MONTH"].ToString() != mStr)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "失業者";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 非勞動力
            DataTable nlfTable = computeTableHalfYear(tardts[2]);

            foreach (DataRow tr in nlfTable.Rows)
            {
                if (tr["MONTH"].ToString() != mStr)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "非勞動力";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 15歲以上民間人口
            DataTable Table15 = computeTableHalfYear(MerageTable("2", tardts));

            foreach (DataRow tr in Table15.Rows)
            {
                if (tr["MONTH"].ToString() != mStr)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "15歲以上民間人口";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 勞動力
            DataTable TableP = computeTableHalfYear(MerageTable("3", tardts));

            foreach (DataRow tr in TableP.Rows)
            {
                if (tr["MONTH"].ToString() != mStr)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "勞動力";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 勞動力參與率
            DataTable TableLP = computeTableHalfYear2(tardts, "7")[0];

            foreach (DataRow tr in TableLP.Rows)
            {
                if (tr["MONTH"].ToString() != mStr)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "勞動力參與率";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output2 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 2);
                }
                else if (output2 == "2")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 失業率
            DataTable TableNP = computeTableHalfYear2(tardts, "6")[0];

            foreach (DataRow tr in TableNP.Rows)
            {
                if (tr["MONTH"].ToString() != mStr)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "失業率";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output2 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 2);
                }
                else if (output2 == "2")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }
        }
    }
    // 計算季節
    public void CompareSeasonData(HttpContext context, List<DataTable> dts, List<listitem> list, DataTable zonedt, Dictionary<string, decimal> data2)
    {
        string sex = context.Request["sex"] as string;
        string output1 = context.Request["output1"] as string;
        string output2 = context.Request["output2"] as string;

        string seasons = context.Request["seasons"] as string;
        string[] ar = seasons.Split(',');

        List<string> seasonlist = new List<string>();
        foreach (string r in ar)
        {
            seasonlist.Add("第" + r + "季");
        }

        // 根據縣市編碼來進行資料建立
        foreach (DataRow r in zonedt.Rows)
        {
            string lvl = r["LVL"].ToString();
            string c = r["DES_ZH"].ToString();
            string l = "2";

            List<string> tarcode = new List<string>();

            if (lvl == "1")
            {
                tarcode.Add(r["CODE"].ToString());
            }
            else if (lvl == "2")
            {
                string[] codes = r["CAL_ITEM"].ToString().Split(',');
                for (int i = 0; i < codes.Length; i++)
                {
                    tarcode.Add(codes[i]);
                }
            }

            // 篩選TABLE裡面需要的縣市
            string selectStr = "";
            for (int i = 0; i < tarcode.Count; i++)
            {
                if (i != 0)
                    selectStr += " OR ";

                selectStr += "COUNTY='" + tarcode[i] + "'";
            }

            List<DataTable> tardts = CompareZoneSumTable(dts, selectStr);

            // 就業者
            DataTable pepTable = computeTableSeason(tardts[0]);

            foreach (DataRow tr in pepTable.Rows)
            {
                if (seasonlist.IndexOf(tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "就業者";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 失業者
            DataTable pupTable = computeTableSeason(tardts[1]);

            foreach (DataRow tr in pupTable.Rows)
            {
                if (seasonlist.IndexOf(tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "失業者";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 非勞動力
            DataTable nlfTable = computeTableSeason(tardts[2]);

            foreach (DataRow tr in nlfTable.Rows)
            {
                if (seasonlist.IndexOf(tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "非勞動力";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 15歲以上民間人口
            DataTable Table15 = computeTableSeason(MerageTable("2", tardts));

            foreach (DataRow tr in Table15.Rows)
            {
                if (seasonlist.IndexOf(tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "15歲以上民間人口";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 勞動力
            DataTable TableP = computeTableSeason(MerageTable("3", tardts));

            foreach (DataRow tr in TableP.Rows)
            {
                if (seasonlist.IndexOf(tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "勞動力";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output1 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1000);
                }
                else
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeAvgPepole(1, item.value, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 勞動力參與率
            DataTable TableLP = computeTableSeason2(tardts, "7")[0];

            foreach (DataRow tr in TableLP.Rows)
            {
                if (seasonlist.IndexOf(tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "勞動力參與率";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output2 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 2);
                }
                else if (output2 == "2")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }

            // 失業率
            DataTable TableNP = computeTableSeason2(tardts, "6")[0];

            foreach (DataRow tr in TableNP.Rows)
            {
                if (seasonlist.IndexOf(tr["MONTH"].ToString()) == -1)
                    continue;

                string sid = tr["STATID"].ToString();
                string tsex = sid.IndexOf('T', 4) != -1 ? "總計" : sid.IndexOf('M', 4) != -1 ? "男" : "女";

                listitem item = new listitem()
                {
                    date = tr["YEAR"].ToString() + "年" + tr["MONTH"].ToString(),
                    county = c,
                    level = l,
                    sex = tsex
                };
                item.classes = "失業率";
                item.value = Convert.ToDecimal(tr["value"].ToString());

                if (output2 == "1")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 2);
                }
                else if (output2 == "2")
                {
                    if (item.value != -999999)
                        item.value = ComputeMod.ComputeWeekPercent(item.value, 1, 1);
                }

                list.Add(item);

                if (data2 != null)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}", item.classes, item.date, item.sex, item.county);
                    data2.Add(key, (decimal)item.value);
                }
            }
        }
    }

    public DataTable GetYearTable(HttpContext context, int syear, int eyear, DataTable code, List<string> codes, string table)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT DISTINCT (CAST(YEAR AS decimal) - 1911) as YEAR, CAST(MONTH AS decimal) as MONTH, CAST(STAT_VAL AS decimal) as value, STATID, COUNTY FROM STATDATA_" + table
                        + @" WHERE (YEAR >= @startyear AND YEAR <= @endyear) ";

            sqlStr += " AND ( ";
            for (int i = 0; i < codes.Count; i++)
            {
                if (i != 0)
                    sqlStr += " OR ";

                sqlStr += " STATID = @STATID_" + i;
            }
            sqlStr += ") ";

            string lvl = code.Rows[0]["LVL"].ToString();
            string cal = code.Rows[0]["CAL_ITEM"].ToString();
            string[] cals = cal.Split(',');

            if (lvl == "1")
                sqlStr += "AND (COUNTY = @COUNTY) ";
            else
            {
                sqlStr += "AND ( ";
                for (int i = 0; i < cals.Length; i++)
                {
                    if (i != 0)
                        sqlStr += " OR ";

                    sqlStr += " COUNTY = @COUNTY_" + i;
                }
                sqlStr += ") ";
            }

            sqlStr += @" ORDER BY STATID, YEAR, MONTH ";
            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@startyear", syear),
                    new SqlParameter("@endyear", eyear)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                for (int i = 0; i < codes.Count; i++)
                {
                    command.Parameters.Add(new SqlParameter("@STATID_" + i, codes[i]));
                }

                if (lvl == "1")
                    command.Parameters.Add(new SqlParameter("@COUNTY", code.Rows[0]["CODE"].ToString()));
                else
                {
                    for (int i = 0; i < cals.Length; i++)
                    {
                        command.Parameters.Add(new SqlParameter("@COUNTY_" + i, cals[i]));
                    }
                }

                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                DataTable tb = ds.Tables[0];

                dt = tb;
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
    // 計算地區總合回傳TABLE
    public List<DataTable> CompareZoneSumTable(List<DataTable> dts, String selectStr)
    {
        List<DataTable> result = new List<DataTable>();

        foreach (DataTable t in dts)
        {
            DataRow[] tb = t.Select(selectStr);
            DataTable tbb = tb.CopyToDataTable();
            tbb.DefaultView.Sort = "STATID, YEAR, MONTH";
            tbb = tbb.DefaultView.ToTable();

            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(Int32));
            data.Columns.Add("MONTH", typeof(Int32));
            data.Columns.Add("value", typeof(Double));
            data.Columns.Add("STATID", typeof(String));

            int sum = 0;
            for (int i = 0; i < tbb.Rows.Count; i++)
            {
                int month = Convert.ToInt32(tbb.Rows[i]["MONTH"].ToString());
                string statid = tbb.Rows[i]["STATID"].ToString();
                int lmonth = -1;
                string lstatid = "";
                if (i + 1 != tbb.Rows.Count)
                {
                    lmonth = Convert.ToInt32(tbb.Rows[i + 1]["MONTH"].ToString());
                    lstatid = tbb.Rows[i + 1]["STATID"].ToString();
                }

                if (month != lmonth || statid != lstatid)
                {
                    sum += Convert.ToInt32(tbb.Rows[i]["value"].ToString());
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = tbb.Rows[i]["YEAR"].ToString();
                    workRow["MONTH"] = tbb.Rows[i]["MONTH"].ToString();
                    workRow["value"] = sum.ToString();
                    workRow["STATID"] = tbb.Rows[i]["STATID"].ToString();

                    data.Rows.Add(workRow);
                    sum = 0;
                }
                else
                {
                    sum += Convert.ToInt32(tbb.Rows[i]["value"].ToString());
                }
            }

            result.Add(data);
        }

        return result;
    }

    public DataTable MerageTable(string type, List<DataTable> table)
    {
        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("value", typeof(Double));

        if (table.Count == 1)
        {
            DataTable d1 = table[0];
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                DataRow workRow = data.NewRow();
                workRow["YEAR"] = d1.Rows[i]["YEAR"].ToString();
                workRow["MONTH"] = d1.Rows[i]["MONTH"].ToString();
                workRow["STATID"] = d1.Rows[i]["STATID"].ToString();

                decimal dv1 = Convert.ToDecimal(d1.Rows[i]["value"].ToString());
                decimal va = dv1;

                workRow["value"] = va;
                data.Rows.Add(workRow);
            }
        }
        else
        {
            if (type == "3") //勞動力
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"].ToString();
                    workRow["MONTH"] = d1.Rows[i]["MONTH"].ToString();
                    workRow["STATID"] = d1.Rows[i]["STATID"].ToString();

                    decimal dv1 = Convert.ToDecimal(d1.Rows[i]["value"].ToString());
                    decimal dv2 = Convert.ToDecimal(d2.Rows[i]["value"].ToString());
                    decimal va = dv1 + dv2;

                    workRow["value"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "2") //15歲以上民間人口
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];
                DataTable d3 = table[2];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = d1.Rows[i]["MONTH"];
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    decimal dv1 = Convert.ToDecimal(d1.Rows[i]["value"].ToString());
                    decimal dv2 = Convert.ToDecimal(d2.Rows[i]["value"].ToString());
                    decimal dv3 = Convert.ToDecimal(d3.Rows[i]["value"].ToString());
                    decimal va = dv1 + dv2 + dv3;

                    workRow["value"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "7") //勞動力參與率
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];
                DataTable d3 = table[2];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = d1.Rows[i]["MONTH"];
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    decimal dv1 = Convert.ToDecimal(d1.Rows[i]["value"].ToString());
                    decimal dv2 = Convert.ToDecimal(d2.Rows[i]["value"].ToString());
                    decimal dv3 = Convert.ToDecimal(d3.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((dv1 + dv2), (dv1 + dv2 + dv3), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);
                }
            }
            else if (type == "6") //失業率
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = d1.Rows[i]["MONTH"];
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    decimal dv1 = Convert.ToDecimal(d1.Rows[i]["value"].ToString());
                    decimal dv2 = Convert.ToDecimal(d2.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((dv2), (dv1 + dv2), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);
                }
            }
        }

        return data;
    }

    public DataTable GetZoneTable(bool isold)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM CODE WHERE CAT=@CAT AND INTERNAL = 1 AND CODE <> '00' ";

            string CAT = "";

            if (isold)
            {
                CAT = "縣市(舊)";
            }
            else
            {
                CAT = "縣市(新)";
            }

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@CAT", CAT)
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

    public DataTable GetZoneCode(string zone, bool isold)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM CODE WHERE CAT=@CAT AND INTERNAL = 1 ";

            string CAT = "";
            List<string> cs = new List<string>();
            if (isold)
            {
                CAT = "縣市(舊)";
                cs.Add(zone);
            }
            else
            {
                CAT = "縣市(新)";
                cs.Add(zone);
            }

            string addstring = "AND (";
            for (int i = 0; i < cs.Count; i++)
            {
                if (i == 0)
                    addstring += " DES_ZH=@DES_ZH_" + i;
                else
                    addstring += " OR DES_ZH=@DES_ZH_" + i;
            }
            addstring += ")";
            sqlStr += addstring;
            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@CAT", CAT)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                for (int i = 0; i < cs.Count; i++)
                {
                    command.Parameters.Add(new SqlParameter("@DES_ZH_" + i, cs[i]));
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
        };

        return dt;
    }

    //計算年
    public DataTable computeTableYear(DataTable dt)
    {
        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("value", typeof(String));

        decimal sum = 0;
        for (int j = 0; j < dt.Rows.Count; j++)
        {
            DataRow workRow = data.NewRow();
            int month = Convert.ToInt32(dt.Rows[j]["MONTH"].ToString());
            int lmonth = -1;
            if (j + 1 != dt.Rows.Count)
                lmonth = Convert.ToInt32(dt.Rows[j + 1]["MONTH"].ToString());

            if (month == 1)
            {
                sum = 0;
            }
            if (month == 12)
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());

                decimal avg = sum;
                avg = ComputeMod.ComputeAvgPepole(12, avg, 1);

                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "-";
                workRow["value"] = avg.ToString();

                data.Rows.Add(workRow);

                sum = 0;
            }
            else if ((month != 12 && lmonth == 1) || (month != 12 && lmonth == -1))
            {
                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "-";
                workRow["value"] = 0;

                data.Rows.Add(workRow);
                sum = 0;
            }
            else
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
            }
        }
        return data;
    }

    //計算年-率
    public List<DataTable> computeTableYear2(List<DataTable> table, string iclasses)
    {
        List<DataTable> ldt = new List<DataTable>();

        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("value", typeof(decimal));

        if (table.Count == 1)
        {
            for (int t = 0; t < table.Count; t++)
            {
                DataTable d = table[t];
                decimal sum = 0;

                for (int i = 0; i < d.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d.Rows.Count)
                        lmonth = Convert.ToInt32(d.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1)
                    {
                        sum = 0;
                    }
                    if (month == 12)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "-";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());

                        decimal va = sum;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else if ((month != 12 && lmonth == 1) || (month != 12 && lmonth == -1))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "-";
                        workRow["STATID"] = d.Rows[i]["STATID"];
                        workRow["value"] = 0;

                        data.Rows.Add(workRow);
                        sum = 0;
                    }
                    else
                    {
                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                    }
                }
            }
        }
        else if (iclasses == "7") //勞動力參與率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];
            DataTable d3 = table[2];

            decimal sum1 = 0, sum2 = 0, sum3 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                int lmonth = -1;
                if (i + 1 != d1.Rows.Count)
                    lmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                if (month == 1)
                {
                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }

                if (month == 12)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if ((month != 12 && lmonth == 1) || (month != 12 && lmonth == -1))
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = d1.Rows[i]["STATID"];
                    workRow["value"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                }
            }
        }
        else if (iclasses == "6") //失業率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];

            decimal sum1 = 0, sum2 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                int lmonth = -1;
                if (i + 1 != d1.Rows.Count)
                    lmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                if (month == 1)
                {
                    sum1 = 0;
                    sum2 = 0;
                }
                if (month == 12)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if ((month != 12 && lmonth == 1) || (month != 12 && lmonth == -1))
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = d1.Rows[i]["STATID"];
                    workRow["value"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                }
            }
        }

        ldt.Add(data);

        return ldt;
    }

    //計算半年
    public DataTable computeTableHalfYear(DataTable dt)
    {
        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("value", typeof(String));

        decimal sum = 0;
        for (int j = 0; j < dt.Rows.Count; j++)
        {
            DataRow workRow = data.NewRow();
            int month = Convert.ToInt32(dt.Rows[j]["MONTH"].ToString());
            int lmonth = -1;
            if (j + 1 != dt.Rows.Count)
                lmonth = Convert.ToInt32(dt.Rows[j + 1]["MONTH"].ToString());

            if (month == 1 || month == 7)
            {
                sum = 0;
            }
            if (month == 12)
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
                decimal avg = sum;
                avg = ComputeMod.ComputeAvgPepole(6, avg, 1);

                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "下半年";
                workRow["value"] = avg.ToString();

                data.Rows.Add(workRow);

                sum = 0;
            }
            else if (month == 6)
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
                decimal avg = sum;
                avg = ComputeMod.ComputeAvgPepole(6, avg, 1);

                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "上半年";
                workRow["value"] = avg.ToString();

                data.Rows.Add(workRow);

                sum = 0;
            }
            else if ((month != 6 && month != 12 && lmonth == 1) || (month != 6 && month != 12 && lmonth == -1))
            {
                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "上半年";
                if (month > 6)
                    workRow["MONTH"] = "下半年";

                workRow["value"] = 0;

                data.Rows.Add(workRow);

                sum = 0;
            }
            else
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
            }
        }


        return data;
    }

    //計算半年-率
    public List<DataTable> computeTableHalfYear2(List<DataTable> table, string iclasses)
    {
        List<DataTable> ldt = new List<DataTable>();

        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("value", typeof(String));

        if (table.Count == 1)
        {
            for (int t = 0; t < table.Count; t++)
            {
                DataTable d = table[t];
                decimal sum = 0;

                for (int i = 0; i < d.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d.Rows.Count)
                        lmonth = Convert.ToInt32(d.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1 || month == 7)
                    {
                        sum = 0;
                    }
                    if (month == 6)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "上半年";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());

                        decimal va = sum;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else if (month == 12)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "下半年";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());

                        decimal va = sum;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else if ((month != 6 && month != 12 && lmonth == 1) || (month != 6 && month != 12 && lmonth == -1))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "上半年";
                        if (month > 6)
                            workRow["MONTH"] = "下半年";

                        workRow["STATID"] = d.Rows[i]["STATID"];
                        workRow["value"] = 0;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else
                    {
                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                    }
                }
            }

        }
        else if (iclasses == "7") //勞動力參與率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];
            DataTable d3 = table[2];

            decimal sum1 = 0, sum2 = 0, sum3 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                int lmonth = -1;
                if (i + 1 != d1.Rows.Count)
                    lmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                if (month == 1 || month == 7)
                {
                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                if (month == 6)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "上半年";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if (month == 12)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "下半年";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if ((month != 6 && month != 12 && lmonth == 1) || (month != 6 && month != 12 && lmonth == -1))
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "上半年";
                    if (month > 6)
                        workRow["MONTH"] = "下半年";

                    workRow["STATID"] = d1.Rows[i]["STATID"];
                    workRow["value"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                }
            }
        }
        else if (iclasses == "6") //失業率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];

            decimal sum1 = 0, sum2 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                int lmonth = -1;
                if (i + 1 != d1.Rows.Count)
                    lmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                if (month == 1 || month == 7)
                {
                    sum1 = 0;
                    sum2 = 0;
                }
                if (month == 6)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "上半年";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if (month == 12)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "下半年";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if ((month != 6 && month != 12 && lmonth == 1) || (month != 6 && month != 12 && lmonth == -1))
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "上半年";
                    if (month > 6)
                        workRow["MONTH"] = "下半年";

                    workRow["STATID"] = d1.Rows[i]["STATID"];
                    workRow["value"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                }
            }
        }

        ldt.Add(data);

        return ldt;
    }

    //計算季
    public DataTable computeTableSeason(DataTable dt)
    {
        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("value", typeof(String));

        decimal sum = 0;
        for (int j = 0; j < dt.Rows.Count; j++)
        {
            DataRow workRow = data.NewRow();
            int month = Convert.ToInt32(dt.Rows[j]["MONTH"].ToString());
            int lmonth = -1;
            if (j + 1 != dt.Rows.Count)
                lmonth = Convert.ToInt32(dt.Rows[j + 1]["MONTH"].ToString());

            if (month == 1 || month == 4 || month == 7 || month == 10)
            {
                sum = 0;
            }
            if (month == 12)
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
                decimal avg = sum;

                avg = ComputeMod.ComputeAvgPepole(3, avg, 1);

                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "第4季";
                workRow["value"] = avg.ToString();

                data.Rows.Add(workRow);

                sum = 0;
            }
            else if (month == 9)
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
                decimal avg = sum;
                avg = ComputeMod.ComputeAvgPepole(3, avg, 1);

                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "第3季";
                workRow["value"] = avg.ToString();

                data.Rows.Add(workRow);

                sum = 0;
            }
            else if (month == 6)
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
                decimal avg = sum;
                avg = ComputeMod.ComputeAvgPepole(3, avg, 1);

                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "第2季";
                workRow["value"] = avg.ToString();

                data.Rows.Add(workRow);

                sum = 0;
            }
            else if (month == 3)
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
                decimal avg = sum;
                avg = ComputeMod.ComputeAvgPepole(3, avg, 1);

                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "第1季";
                workRow["value"] = avg.ToString();

                data.Rows.Add(workRow);

                sum = 0;
            }
            else if ((month != 3 && month != 6 && month != 9 && month != 12 && lmonth == 1) || (month != 3 && month != 6 && month != 9 && month != 12 && lmonth == -1))
            {
                workRow["YEAR"] = dt.Rows[j]["YEAR"].ToString();
                workRow["STATID"] = dt.Rows[j]["STATID"].ToString();
                workRow["MONTH"] = "第1季";
                if (month > 9)
                    workRow["MONTH"] = "第4季";
                else if (month > 6)
                    workRow["MONTH"] = "第3季";
                else if (month > 3)
                    workRow["MONTH"] = "第2季";

                workRow["value"] = 0;

                data.Rows.Add(workRow);

                sum = 0;
            }
            else
            {
                sum += Convert.ToDecimal(dt.Rows[j]["value"].ToString());
            }
        }

        return data;
    }

    //計算季-率
    public List<DataTable> computeTableSeason2(List<DataTable> table, string iclasses)
    {
        List<DataTable> ldt = new List<DataTable>();

        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("value", typeof(String));

        if (table.Count == 1)
        {
            for (int t = 0; t < table.Count; t++)
            {
                DataTable d = table[t];
                decimal sum = 0;

                for (int i = 0; i < d.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d.Rows.Count)
                        lmonth = Convert.ToInt32(d.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1 || month == 4 || month == 7 || month == 10)
                    {
                        sum = 0;
                    }
                    if (month == 3)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第1季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());

                        decimal va = sum;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else if (month == 6)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第2季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());

                        decimal va = sum;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else if (month == 9)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第3季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());

                        decimal va = sum;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else if (month == 12)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第4季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());

                        decimal va = sum;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else if ((month != 3 && month != 6 && month != 9 && month != 12 && lmonth == 1) || (month != 3 && month != 6 && month != 9 && month != 12 && lmonth == -1))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["STATID"] = d.Rows[i]["STATID"];
                        workRow["MONTH"] = "第1季";
                        if (month > 9)
                            workRow["MONTH"] = "第4季";
                        else if (month > 6)
                            workRow["MONTH"] = "第3季";
                        else if (month > 3)
                            workRow["MONTH"] = "第2季";

                        workRow["value"] = 0;

                        data.Rows.Add(workRow);

                        sum = 0;
                    }
                    else
                    {
                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                    }
                }
            }
        }
        else if (iclasses == "7") //勞動力參與率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];
            DataTable d3 = table[2];

            decimal sum1 = 0, sum2 = 0, sum3 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                int lmonth = -1;
                if (i + 1 != d1.Rows.Count)
                    lmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                if (month == 1 || month == 4 || month == 7 || month == 10)
                {
                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                if (month == 3)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "第1季";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if (month == 6)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "第2季";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if (month == 9)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "第3季";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if (month == 12)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "第4季";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if ((month != 3 && month != 6 && month != 9 && month != 12 && lmonth == 1) || (month != 3 && month != 6 && month != 9 && month != 12 && lmonth == -1))
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["STATID"] = d1.Rows[i]["STATID"];
                    workRow["MONTH"] = "第1季";
                    if (month > 9)
                        workRow["MONTH"] = "第4季";
                    else if (month > 6)
                        workRow["MONTH"] = "第3季";
                    else if (month > 3)
                        workRow["MONTH"] = "第2季";

                    workRow["value"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                }
            }
        }
        else if (iclasses == "6") //失業率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];

            decimal sum1 = 0, sum2 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                int lmonth = -1;
                if (i + 1 != d1.Rows.Count)
                    lmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                if (month == 1 || month == 4 || month == 7 || month == 10)
                {
                    sum1 = 0;
                    sum2 = 0;
                }
                if (month == 3)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "第1季";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if (month == 6)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "第2季";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if (month == 9)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "第3季";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if (month == 12)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "第4季";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if ((month != 3 && month != 6 && month != 9 && month != 12 && lmonth == 1) || (month != 3 && month != 6 && month != 9 && month != 12 && lmonth == -1))
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["STATID"] = d1.Rows[i]["STATID"];
                    workRow["MONTH"] = "第1季";
                    if (month > 9)
                        workRow["MONTH"] = "第4季";
                    else if (month > 6)
                        workRow["MONTH"] = "第3季";
                    else if (month > 3)
                        workRow["MONTH"] = "第2季";

                    workRow["value"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                }
            }
        }

        ldt.Add(data);

        return ldt;
    }

    public string GetExcelForMonthlyIntranet(HttpContext context)
    {
        string filename = "";

        MemoryStream ExcelFiles = new MemoryStream();
        XSSFWorkbook workbook  = new XSSFWorkbook();

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

        ICellStyle styleLeft = workbook.CreateCellStyle();
        styleLeft.BorderLeft = BorderStyle.Thin;
        styleLeft.BorderBottom = BorderStyle.Thin;
        styleLeft.BorderRight = BorderStyle.Thin;
        styleLeft.BorderTop = BorderStyle.Thin;
        styleLeft.Alignment = HorizontalAlignment.Left;
        styleLeft.VerticalAlignment = VerticalAlignment.Center;

        ICellStyle styleHead = workbook.CreateCellStyle();
        styleHead.BorderLeft = BorderStyle.Thin;
        styleHead.BorderBottom = BorderStyle.Thin;
        styleHead.BorderRight = BorderStyle.Thin;
        styleHead.BorderTop = BorderStyle.Thin;
        styleHead.Alignment = HorizontalAlignment.Center;
        styleHead.VerticalAlignment = VerticalAlignment.Center;
        styleHead.FillBackgroundColor = 0;

        string[] ssex = (context.Request["sex"] as string).Replace("T", "總計").Replace("M", "男").Replace("F", "女").Split(',');
        string[] classes = { "15歲以上民間人口", "勞動力", "就業者", "失業者", "非勞動力", "勞動力參與率", "失業率" };
        string exporttype = context.Request["exporttype"] as string;
        
        try
        {
            Supergeo.Tools.HiResTimer timer = new Supergeo.Tools.HiResTimer();
            Int64 StartTime = timer.Value;

            string title = "臺灣地區人力資源調查-依縣市區分";
            ISheet ExcelSheet = null;
            ExcelSheet = workbook.CreateSheet("sheet");

            Int64 oneFromAddr = timer.Value;

            rdata dat = new rdata();

            dat = GetRequestTables2(context);

            WriteLog("取資料耗費時間:" + timer.End(oneFromAddr).ToString("F6") + "秒");

            WriteLog("資料筆數:" + dat.data.Count);

            //title
            ExcelSheet.CreateRow(0);
            ExcelSheet.GetRow(0).CreateCell(0).SetCellValue(title);
            ExcelSheet.GetRow(0).CreateCell(3);
            ExcelSheet.AddMergedRegion(new NPOI.SS.Util.CellRangeAddress(0, 0, 0, 3));

            // 計算Layout所需要用到的長度
            int totalCol = classes.Length * ssex.Length;

            // 建立Head
            Int64 tt2 = timer.Value;

            int scol = 3;
            // 建立Head空欄位

            for (int i = 1; i <= 2; i++)
            {
                ExcelSheet.CreateRow(i);

                ExcelSheet.GetRow(i).CreateCell(0);
                ExcelSheet.GetRow(i).CreateCell(1);
                ExcelSheet.GetRow(i).CreateCell(2);

                for (int j = scol; j <= (scol + totalCol); j++)
                {
                    ExcelSheet.GetRow(i).CreateCell(j);
                }
            }

            // 左方空白
            NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(1, 2, 0, 2);
            ExcelSheet.AddMergedRegion(range);

            NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range, ExcelSheet); //Bottom border  
            NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range, ExcelSheet); //Left border  
            NPOI.SS.Util.RegionUtil.SetBorderRight(1, range, ExcelSheet); //Right border  
            NPOI.SS.Util.RegionUtil.SetBorderTop(1, range, ExcelSheet); //Top border

            int rcol1 = scol;
            int rcol2 = scol;

            // 根據Class填入格子
            foreach (string r in classes)
            {
                // Row 1-類別
                int ccol = ssex.Length;
                ExcelSheet.GetRow(1).CreateCell(rcol1).SetCellValue(r);
                ExcelSheet.GetRow(1).GetCell(rcol1).CellStyle = styleHead;

                if (ccol > 1)
                {
                    NPOI.SS.Util.CellRangeAddress range2 = new NPOI.SS.Util.CellRangeAddress(1, 1, rcol1, rcol1 + ccol - 1);
                    ExcelSheet.AddMergedRegion(range2);

                    NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range2, ExcelSheet); //Bottom border  
                    NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range2, ExcelSheet); //Left border  
                    NPOI.SS.Util.RegionUtil.SetBorderRight(1, range2, ExcelSheet); //Right border  
                    NPOI.SS.Util.RegionUtil.SetBorderTop(1, range2, ExcelSheet); //Top border
                }

                rcol1 = rcol1 + ccol;

                // Row 2-Sex
                foreach (string r2 in ssex)
                {
                    ExcelSheet.GetRow(2).CreateCell(rcol2).SetCellValue(r2);
                    ExcelSheet.GetRow(2).GetCell(rcol2).CellStyle = styleHead;

                    rcol2++;
                }
            }

            WriteLog("建Head耗費時間:" + timer.End(tt2).ToString("F6") + "秒");

            // 計算年份縣市長度
            Int64 tt3 = timer.Value;

            Dictionary<string, string> clock = new Dictionary<string, string>();
            foreach (listitem d in dat.data)
            {
                string value = string.Empty;
                bool f = clock.TryGetValue(d.date, out value);
                if (f == false)
                    clock.Add(d.date, d.date);
            }

            WriteLog("計算年分長度耗費時間:" + timer.End(tt3).ToString("F6") + "秒");

            Int64 tt4 = timer.Value;
            int srow = 3;
            int rrow1 = srow;

            foreach (KeyValuePair<string, string> item in clock)
            {
                string c = item.Value;
                foreach (string ci in citys)
                {
                    ExcelSheet.CreateRow(rrow1);
                    if (rrow1 == srow)
                    {
                        // 週期
                        ExcelSheet.GetRow(rrow1).CreateCell(0).SetCellValue(c);
                        ExcelSheet.GetRow(rrow1).GetCell(0).CellStyle = styleLeft;
                    }

                    // 縣市
                    if (ci == "臺灣地區")
                    {
                        ExcelSheet.GetRow(rrow1).CreateCell(1).SetCellValue(ci);
                    }
                    else if (ci == "北部區域" || ci == "中部區域" || ci == "東部區域" || ci == "南部區域")
                    {
                        ExcelSheet.GetRow(rrow1).CreateCell(1).SetCellValue("   " + ci);
                    }
                    else if (ci == "新北市" || ci == "臺北市" || ci == "桃園市" || ci == "基隆市" || ci == "新竹市" || ci == "宜蘭縣" ||
                            ci == "新竹縣" || ci == "臺中市" || ci == "苗栗縣" || ci == "彰化縣" || ci == "南投縣" || ci == "雲林縣" ||
                            ci == "臺南市" || ci == "高雄市" || ci == "嘉義市" || ci == "嘉義縣" || ci == "屏東縣" || ci == "澎湖縣" ||
                            ci == "臺東縣" || ci == "花蓮縣" || ci == "臺北縣" || ci == "桃園縣" || ci == "臺中縣" || ci == "臺南縣" ||
                            ci == "高雄縣" )
                    {
                        ExcelSheet.GetRow(rrow1).CreateCell(1).SetCellValue("      " + ci);
                    }
                    ExcelSheet.GetRow(rrow1).GetCell(1).CellStyle = styleLeft;

                    NPOI.SS.Util.CellRangeAddress range5 = new NPOI.SS.Util.CellRangeAddress(rrow1, rrow1, 1, 2);
                    ExcelSheet.AddMergedRegion(range5);

                    NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range5, ExcelSheet); //Bottom border  
                    NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range5, ExcelSheet); //Left border  
                    NPOI.SS.Util.RegionUtil.SetBorderRight(1, range5, ExcelSheet); //Right border  
                    NPOI.SS.Util.RegionUtil.SetBorderTop(1, range5, ExcelSheet); //Top border

                    // 填值部分
                    int rcol = 3;
                    foreach (string r in classes)
                    {
                        foreach (string r2 in ssex)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}", r, c, r2, ci);
                            decimal value = 0;
                            bool f = dat.data2.TryGetValue(key, out value);

                            if (f == false) value = -999999;

                            string vstr = "";

                            if (value == -999999) vstr = "-";
                            else if (r != "勞動力參與率" && r != "失業率")
                                vstr = value.ToString("N0");
                            else vstr = value.ToString();

                            ExcelSheet.GetRow(rrow1).CreateCell(rcol).SetCellValue(vstr);
                            ExcelSheet.GetRow(rrow1).GetCell(rcol).CellStyle = styleRight;
                            rcol++;
                        }
                    }
                    rrow1++;
                }
                if (citys.Length > 1)
                { 
                    NPOI.SS.Util.CellRangeAddress range6 = new NPOI.SS.Util.CellRangeAddress(srow, rrow1 - 1, 0, 0);
                    ExcelSheet.AddMergedRegion(range6);

                    NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range6, ExcelSheet); //Bottom border  
                    NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range6, ExcelSheet); //Left border  
                    NPOI.SS.Util.RegionUtil.SetBorderRight(1, range6, ExcelSheet); //Right border  
                    NPOI.SS.Util.RegionUtil.SetBorderTop(1, range6, ExcelSheet); //Top border
                }

                srow = rrow1;
            }

            WriteLog("填值進框的位置耗費時間:" + timer.End(tt4).ToString("F6") + "秒");

            Int64 tt5 = timer.Value;

            workbook.Write(ExcelFiles);

            DateTime Now = DateTime.Now;
            title = title.Replace(" ", "_");
            filename = title + "_" + Now.ToString("yyyyMMddHHmms");
            string fname = string.Format(@"{0}", filename) + ".xlsx";
            string ServerPath = HttpContext.Current.Server.MapPath("~/");
            string strFullDirectoryPath = Path.Combine(ServerPath, "ExportExcel\\");
            if (!Directory.Exists(strFullDirectoryPath))
            {
                Directory.CreateDirectory(strFullDirectoryPath);
            }

            string strExcelFilePath = Path.Combine(strFullDirectoryPath, fname);
            System.IO.File.WriteAllBytes(strExcelFilePath, ExcelFiles.ToArray());

            WriteLog("寫檔案耗費時間:" + timer.End(tt5).ToString("F6") + "秒");

            if (exporttype == "3")
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

            filename = fname;
        }
        catch (Exception ex)
        {
            WriteLog(ex.ToString());
        }

        return filename;
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

    public bool IsReusable {
        get {
            return false;
        }
    }
}
