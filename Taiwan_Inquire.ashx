<%@ WebHandler Language="C#" Class="Taiwan_Inquire" %>

using Newtonsoft.Json;
using System;
using System.Data;
using System.Web;
using System.Data.SqlClient;
using System.Reflection;
using System.Collections.Generic;
using System.Linq;
using Supergeo.ComputeMod;
using System.IO;
using System.Diagnostics;
using NPOI.XSSF.UserModel;
using NPOI.SS.UserModel;
using System.Web.SessionState;
using System.Text.RegularExpressions;

public class Taiwan_Inquire : IHttpHandler, IRequiresSessionState {
    String sqlConnstr = System.Configuration.ConfigurationManager.ConnectionStrings["CensusGISADONet"].ConnectionString;
    string ind6code = "IND01";
    string ind7code = "IND02";
    string ind8code = "IND04";
    string occ5code = "OCC03";
    string occ6code = "OCC04";
    string cowcode = "COW04";
    string roncode = "RON04";
    string roucode = "ROU04";

    ComputeMod ComputeMod = new ComputeMod();

    public void ProcessRequest(HttpContext context) {
        try
        {
            /*if (context.Session["logaccount"] != null && context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('6') > -1)
            {*/
                String result = "";
                Type t = GetType();
                MethodInfo m = t.GetMethod(context.Request["op"] as String);
                if (m != null)
                    result = m.Invoke(this, new object[] { context }) as string;

                context.Response.Write(result);
            /* }
            else
            {
                context.Response.Write("沒有權限");
            } */
        }
        catch (Exception e)
        {
            string ex = e.ToString();
            // context.Response.Write(ex);
        }
    }

    public string GetBaseInfo(HttpContext context) {
        String jData = "";

        MNYear target = GetYears();

        jData = JsonConvert.SerializeObject(new {
            cow = GetSortItems("從業身分", "0"),
            rou = GetSortItems("失業原因", "0"),
            ron = GetSortItems("非勞動原因", "0"),
            ind6 = GetSortItems("行業", "6"),
            ind7 = GetSortItems("行業", "7"),
            ind8 = GetSortItems("行業", "8-10"),
            ind12 = GetSortItems("行業", "12"),
            occ5 = GetSortItems("職業", "5"),
            occ6 = GetSortItems("職業", "6"),
            MNYear = target
        });

        return (jData);
    }

    public DataSet GetINDOCCLayOutTable() {
        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" 
                SELECT * FROM LAYOUT WHERE CAT='行業'; 
                SELECT * FROM LAYOUT WHERE CAT='職業'; 
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

        return ds;
    }

    public class MNYear
    {
        public int maxyear { get; set; }
        public int minyear { get; set; }
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
                FROM STATDATA_NEW69;

                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM STATDATA_NEW103;

                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM STATDATA_NEW84;

                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM STATDATA_NEW182A;
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
        public string m { get; set; } //上層
        public string d { get; set; } //年月
        public string c { get; set; } //統計項
        public string s { get; set; } //性別
        public string st { get; set; } //資料屬性
        public string l { get; set; }
        public double v { get; set; } //值
    }

    public class sortitem
    {
        public string code { get; set; } //編碼
        public string name { get; set; } //名稱
        public string level { get; set; } //階層
        public string classes { get; set; }
    }

    public class rdata
    {
        public List<listitem> data { get; set; }
        public List<sortitem> sort { get; set; }
        public List<string> subclasses { get; set; }
        public Dictionary<string, decimal> data2 { get; set; }
    }

    public string GetRequestTables(HttpContext context)
    {
        string jData = "";
        int type = CheckDataType(context);

        rdata rData = new rdata();
        List<listitem> data = new List<listitem>();
        rData.data = data;
        List<sortitem> sort = new List<sortitem>();
        rData.sort = sort;

        if (type == 1)
        {
            sortitem si = new sortitem();
            si.classes = "1";
            si.name = "人口";
            si.level = "3";
            rData.sort.Add(si);
            SetAllTaiwanData(context, data, null);
        }
        else if (type == 2)
        {
            SetBaseTypeData(context, data, rData, null);
        }
        else if (type == 3)
        {
            SetWeekTypeData(context, data, rData, null);
        }
        else if (type == 4)
        {
            rData.subclasses = new List<string>();
            SetSecondTypeData(context, data, rData, null);
        }
        else if (type == 5)
        {
            SetNLFData(context, data, rData, null);
        }

        jData = JsonConvert.SerializeObject(rData);
        return jData;
    }

    public rdata GetRequestTables2(HttpContext context) // EXCEL-查詢
    {
        int type = CheckDataType(context);

        rdata rData = new rdata();
        List<listitem> data = new List<listitem>();
        rData.data = data;
        List<sortitem> sort = new List<sortitem>();
        rData.sort = sort;
        Dictionary<string, decimal> data2 = new Dictionary<string, decimal>();
        rData.data2 = data2;

        if (type == 1)
        {
            sortitem si = new sortitem();
            si.classes = "1";
            si.name = "人口";
            si.level = "3";
            rData.sort.Add(si);
            SetAllTaiwanData(context, data, data2);
        }
        else if (type == 2)
        {
            SetBaseTypeData(context, data, rData, data2);
        }
        else if (type == 3)
        {
            SetWeekTypeData(context, data, rData, data2);
        }
        else if (type == 4)
        {
            rData.subclasses = new List<string>();
            SetSecondTypeData(context, data, rData, data2);
        }
        else if (type == 5)
        {
            SetNLFData(context, data, rData, data2);
        }

        return rData;
    }

    public void SetAllTaiwanData(HttpContext context, List<listitem> litems, Dictionary<string,decimal> data2)
    {
        int syear = Convert.ToInt32(context.Request["startyear"] as string) + 1911;
        int eyear = Convert.ToInt32(context.Request["endyear"] as string) + 1911;
        string[] sexes = (context.Request["sex"] as string).Split(',');
        string[] codes = { "POP04T0000X0000000000000", "POP04M0000X0000000000000", "POP04F0000X0000000000000" };
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string[] output = (context.Request["output"] as string).Split(',');
        string smonth = context.Request["smonth"] as string;

        List<DataTable> dts = new List<DataTable>();

        for (int i = 0; i < codes.Length; i++)
        {
            DataTable dt = GetAllTaiwanData(syear, eyear, codes[i]);
            dts.Add(dt);
        }

        List<DataTable> cdts =  new List<DataTable>();
        if (cycle == 1)
            cdts = computeTableYear(syear, eyear, dts);
        else if (cycle == 2)
            cdts = computeTableHalfYear(syear, eyear, dts);
        else if (cycle == 3)
            cdts = computeTableSeason(syear, eyear, dts);
        else if (cycle == 5)
        {
            cdts = dts;
            for (int i = 0; i < cdts.Count; i++)
            {
                cdts[i] = cdts[i].Select("MONTH='" + smonth + "'").CopyToDataTable();
            }
        }
        else if (cycle == 6)
        {
            int iavgmonth = Convert.ToInt32(smonth);
            cdts = computeTableSumAvg(syear, eyear, dts, iavgmonth);
        }
        else
            cdts = dts;

        SetListData(context, litems, cdts, data2);
    }

    public void SetListData(HttpContext context, List<listitem> litems, List<DataTable> cdts, Dictionary<string,decimal> data2)
    {
        int syear = Convert.ToInt32(context.Request["startyear"] as string) + 1911;
        int eyear = Convert.ToInt32(context.Request["endyear"] as string) + 1911;
        string[] sexes = (context.Request["sex"] as string).Split(',');
        string[] codes = { "POP04T0000X0000000000000", "POP04M0000X0000000000000", "POP04F0000X0000000000000" };
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string[] output = (context.Request["output"] as string).Split(',');
        string smonth = context.Request["smonth"] as string;

        for (int k = 0; k < output.Length; k++)
        {
            if (output[k] == "S")
            {
                for (int i = 0; i < sexes.Length; i++)
                {
                    if (sexes[i] == "T")
                    {
                        DataTable d = cdts[0];

                        for (int j = 0; j < d.Rows.Count; j++)
                        {
                            listitem item = new listitem();
                            item.m = "總計";
                            item.s = "總計";
                            item.c = "人口";
                            item.st = "結構比 (%)";

                            string year = d.Rows[j]["YEAR"].ToString();
                            string month = d.Rows[j]["MONTH"].ToString();

                            if (month == "-")
                                item.d = year + "年";
                            else
                                item.d = year + "年" + month;

                            if (cycle == 4 || cycle == 5)
                                item.d += "月";

                            double value = Convert.ToDouble(d.Rows[j]["value"].ToString());
                            item.v = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(value), Convert.ToDecimal(value), 2);
                            item.v = CheckHideValue("人口", item.v, year);
                            item.v = CheckDashValue(item.v);

                            litems.Add(item);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", item.m, item.d, item.c, item.s, item.st);
                                data2.Add(key, (decimal)item.v);
                            }
                        }
                    }
                    else if (sexes[i] == "M")
                    {
                        DataTable t = cdts[0];
                        DataTable d = cdts[1];

                        for (int j = 0; j < d.Rows.Count; j++)
                        {
                            listitem item = new listitem();
                            item.m = "總計";
                            item.s = "男";
                            item.c = "人口";
                            item.st = "結構比 (%)";

                            string year = d.Rows[j]["YEAR"].ToString();
                            string month = d.Rows[j]["MONTH"].ToString();

                            if (month == "-")
                                item.d = year + "年";
                            else
                                item.d = year + "年" + month;

                            if (cycle == 4 || cycle == 5)
                                item.d += "月";

                            double value = Convert.ToDouble(d.Rows[j]["value"].ToString());
                            double tvalue = Convert.ToDouble(t.Rows[j]["value"].ToString());

                            item.v = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(value), Convert.ToDecimal(tvalue), 2);
                            item.v = CheckHideValue("人口", item.v, year);
                            item.v = CheckDashValue(item.v);
                            litems.Add(item);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", item.m, item.d, item.c, item.s, item.st);
                                data2.Add(key, (decimal)item.v);
                            }
                        }
                    }
                    else if (sexes[i] == "F")
                    {
                        DataTable t = cdts[0];
                        DataTable d = cdts[2];

                        for (int j = 0; j < d.Rows.Count; j++)
                        {
                            listitem item = new listitem();
                            item.m = "總計";
                            item.s = "女";
                            item.c = "人口";
                            item.st = "結構比 (%)";

                            string year = d.Rows[j]["YEAR"].ToString();
                            string month = d.Rows[j]["MONTH"].ToString();

                            if (month == "-")
                                item.d = year + "年";
                            else
                                item.d = year + "年" + month;

                            if (cycle == 4 || cycle == 5)
                                item.d += "月";

                            double value = Convert.ToDouble(d.Rows[j]["value"].ToString());
                            double tvalue = Convert.ToDouble(t.Rows[j]["value"].ToString());
                            item.v = (double)ComputeMod.ComputeAvgPercent(Convert.ToDecimal(value), Convert.ToDecimal(tvalue), 2);

                            item.v = CheckHideValue("人口", item.v, year);
                            item.v = CheckDashValue(item.v);

                            litems.Add(item);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", item.m, item.d, item.c, item.s, item.st);
                                data2.Add(key, (decimal)item.v);
                            }
                        }
                    }
                }
            }
            else
            {
                for (int i = 0; i < sexes.Length; i++)
                {
                    if (sexes[i] == "T")
                    {
                        DataTable d = cdts[0];

                        for (int j = 0; j < d.Rows.Count; j++)
                        {
                            listitem item = new listitem();
                            item.m = "總計";
                            item.s = "總計";
                            item.c = "人口";

                            string year = d.Rows[j]["YEAR"].ToString();
                            string month = d.Rows[j]["MONTH"].ToString();

                            if (month == "-")
                                item.d = year + "年";
                            else
                                item.d = year + "年" + month;

                            if (cycle == 4 || cycle == 5)
                                item.d += "月";

                            double value = Convert.ToDouble(d.Rows[j]["value"].ToString());
                            item.st = "統計值 (人)";
                            item.v = value;

                            if (output[k] == "T")
                            {
                                item.v = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(item.v), 1000);
                                item.st = "統計值 (千人)";
                            }
                            else
                            {
                                item.v = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(item.v), 1);
                            }
                            item.v = CheckHideValue("人口", item.v, year);
                            item.v = CheckDashValue(item.v);

                            litems.Add(item);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", item.m, item.d, item.c, item.s, item.st);
                                data2.Add(key, (decimal)item.v);
                            }
                        }
                    }
                    else if (sexes[i] == "M")
                    {
                        DataTable d = cdts[1];

                        for (int j = 0; j < d.Rows.Count; j++)
                        {
                            listitem item = new listitem();
                            item.m = "總計";
                            item.s = "男";
                            item.c = "人口";

                            string year = d.Rows[j]["YEAR"].ToString();
                            string month = d.Rows[j]["MONTH"].ToString();

                            if (month == "-")
                                item.d = year + "年";
                            else
                                item.d = year + "年" + month;

                            if (cycle == 4 || cycle == 5)
                                item.d += "月";

                            double value = Convert.ToDouble(d.Rows[j]["value"].ToString());
                            item.st = "統計值 (人)";
                            item.v = value;

                            if (output[k] == "T")
                            {
                                item.v = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(item.v), 1000);
                                item.st = "統計值 (千人)";
                            }
                            else
                            {
                                item.v = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(item.v), 1);
                            }

                            item.v = CheckHideValue("人口", item.v, year);
                            item.v = CheckDashValue(item.v);

                            litems.Add(item);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", item.m, item.d, item.c, item.s, item.st);
                                data2.Add(key, (decimal)item.v);
                            }
                        }
                    }
                    else if (sexes[i] == "F")
                    {
                        DataTable d = cdts[2];

                        for (int j = 0; j < d.Rows.Count; j++)
                        {
                            listitem item = new listitem();
                            item.m = "總計";
                            item.s = "女";
                            item.c = "人口";

                            string year = d.Rows[j]["YEAR"].ToString();
                            string month = d.Rows[j]["MONTH"].ToString();

                            if (month == "-")
                                item.d = year + "年";
                            else
                                item.d = year + "年" + month;

                            if (cycle == 4 || cycle == 5)
                                item.d += "月";

                            double value = Convert.ToDouble(d.Rows[j]["value"].ToString());
                            item.st = "統計值 (人)";
                            item.v = value;

                            if (output[k] == "T")
                            {
                                item.v = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(item.v), 1000);
                                item.st = "統計值 (千人)";
                            }
                            else
                            {
                                item.v = (double)ComputeMod.ComputeAvgPepole(1, Convert.ToDecimal(item.v), 1);
                            }

                            item.v = CheckHideValue("人口", item.v, year);
                            item.v = CheckDashValue(item.v);

                            litems.Add(item);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", item.m, item.d, item.c, item.s, item.st);
                                data2.Add(key, (decimal)item.v);
                            }
                        }
                    }
                }
            }
        }
    }

    public void SetNLFData(HttpContext context, List<listitem> litems, rdata rdata, Dictionary<string, decimal> data2)
    {
        int syear = Convert.ToInt32(context.Request["startyear"] as string) + 1911;
        int eyear = Convert.ToInt32(context.Request["endyear"] as string) + 1911;
        string[] sexes = (context.Request["sex"] as string).Split(',');
        string[] tsexes = { "T", "M", "F" };
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string output = context.Request["output"] as string;
        string smonth = context.Request["smonth"] as string;
        string classes = context.Request["classes"] as string;
        string subtype = context.Request["subtype"] as string; //下拉選單
        string rcs = cDictionary(classes);

        string[] css = (context.Request["classes1"] as string).Split(',');

        for (int q = 0; q < css.Length; q++)
        {
            string cs = css[q];
            string dcs = ClassesDictionary(cs);

            bool hasLayOut = false;
            if (cs != "1")
                hasLayOut = true;

            if (!hasLayOut) //總計部分
            {
                List<string> ctip = Dictionary(context);
                string des = cDictionary(classes);
                sortitem si = new sortitem();
                si.classes = "1";
                si.name = des;
                si.level = "3";
                rdata.sort.Add(si);

                List<DataTable> dts = new List<DataTable>();
                for (int i = 0; i < ctip.Count; i++)
                {
                    List<string> codes = new List<string>();
                    for (int j = 0; j < tsexes.Length; j++)
                    {
                        string code = "";
                        code += ctip[i] + tsexes[j] + "0000X0000000000000";
                        codes.Add(code);
                    }
                    DataTable dt5 = getTabelByCodes(context, codes, "NEW182A");
                    dts.Add(dt5);
                }

                if (subtype == "1" || subtype == "2" || subtype == "3")
                {
                    List<DataTable> cdts = new List<DataTable>();
                    DataTable dt = MerageTable(context, dts);

                    List<DataTable> fdts = new List<DataTable>();
                    fdts.Add(dt);

                    if (cycle == 1)
                        cdts = computeTableYear(syear, eyear, fdts);
                    else if (cycle == 2)
                        cdts = computeTableHalfYear(syear, eyear, fdts);
                    else if (cycle == 3)
                        cdts = computeTableSeason(syear, eyear, fdts);
                    else if (cycle == 5)
                    {
                        DataTable tmp = dt.Select("MONTH='" + smonth + "'").CopyToDataTable();
                        cdts.Add(tmp);
                    }
                    else if (cycle == 6)
                    {
                        int iavgmonth = Convert.ToInt32(smonth);
                        cdts = computeTableSumAvg(syear, eyear, fdts, iavgmonth);
                    }
                    else
                        cdts = fdts;

                    SetBaseStatistics1(context, cdts[0], classes, litems, output, data2);
                    if (output.IndexOf("S") != -1)
                        SetBaseStatistics2(context, dt, classes, litems, data2);
                }
                else //基底-率 額外處理
                {
                    List<DataTable> cdts = new List<DataTable>();
                    DataTable dt = MerageTable(context, dts);

                    List<DataTable> fdts = new List<DataTable>();
                    fdts.Add(dt);

                    if (cycle == 1)
                        cdts = computeTableYear2(context, dts, classes, false);
                    else if (cycle == 2)
                        cdts = computeTableHalfYear2(context, dts, classes, false);
                    else if (cycle == 3)
                        cdts = computeTableSeason2(context, dts, classes, false);
                    else if (cycle == 5)
                    {
                        DataTable tmp = dt.Select("MONTH='" + smonth + "'").CopyToDataTable();
                        cdts.Add(tmp);
                    }
                    else if (cycle == 6)
                    {
                        int iavgmonth = Convert.ToInt32(smonth);
                        cdts = computeTableSumAvg2(context, dts, classes, false, iavgmonth);
                    }
                    else
                        cdts = fdts;

                    SetBaseStatistics1(context, cdts[0], classes, litems, output, data2);
                }
            }
            else //含有LayOut階層部分
            {
                List<DataTable> dts = null;
                string ver = "0";
                //判斷取LayOut
                if (cs == "2") //教育程度
                {
                    dts = GetEdtionTables(context, "教育程度");
                    rdata.sort.AddRange(GetSortItems("教育程度", ver));
                }
                else if (cs == "3") //年齡
                {
                    dts = GetAgeTables(context, "年齡");
                    rdata.sort.AddRange(GetSortItems("年齡", ver));
                }

                if (subtype == "1" || subtype == "2" || subtype == "3")
                {
                    //取得Layout
                    string layoutstring = GetLayouts(dcs, ver);
                    string[] layouts = layoutstring.Split(',');
                    //取得CodeTable
                    DataTable code = GetCodeTable(dcs, ver);
                    List<DataTable> cdts = new List<DataTable>();
                    DataTable dt = MerageTable(context, dts);

                    List<DataTable> fdts = new List<DataTable>();
                    fdts.Add(dt);

                    dts = fdts;

                    if (cycle == 1)
                        cdts = computeTableYear2(context, dts, classes, false);
                    else if (cycle == 2)
                        cdts = computeTableHalfYear2(context, dts, classes, false);
                    else if (cycle == 3)
                        cdts = computeTableSeason2(context, dts, classes, false);
                    else if (cycle == 5)
                    {
                        DataTable tmp = dt.Select("MONTH='" + smonth + "'").CopyToDataTable();
                        cdts.Add(tmp);
                    }
                    else if (cycle == 6)
                    {
                        int iavgmonth = Convert.ToInt32(smonth);
                        cdts = computeTableSumAvg2(context, dts, classes, false, iavgmonth);
                    }
                    else
                        cdts = fdts;

                    SetLayOutStatistics1(context, cdts[0], classes, litems, layouts, code, output, dcs, data2);
                }
                else //基底-率 額外處理
                {
                    //取得Layout
                    string layoutstring = GetLayouts(dcs, ver);
                    string[] layouts = layoutstring.Split(',');
                    //取得CodeTable
                    DataTable code = GetCodeTable(dcs, ver);
                    List<DataTable> cdts = new List<DataTable>();
                    DataTable dt = MerageTable(context, dts);

                    List<DataTable> fdts = new List<DataTable>();
                    fdts.Add(dt);

                    for (int i = 0; i < dts.Count; i++)
                    {
                        List<DataTable> tmp = new List<DataTable>();
                        tmp.Add(dts[i]);

                        if (cycle == 1)
                        {
                            DataTable t = computeTableYear2(context, tmp, classes, true)[0];
                            cdts.Add(t);
                        }
                        else if (cycle == 2)
                        {
                            DataTable t = computeTableHalfYear2(context, tmp, classes, true)[0];
                            cdts.Add(t);
                        }
                        else if (cycle == 3)
                        {
                            DataTable t = computeTableSeason2(context, tmp, classes, true)[0];
                            cdts.Add(t);
                        }
                        else if (cycle == 5)
                        {
                            DataTable t = dts[i].Select("MONTH='" + smonth + "'").CopyToDataTable();
                            cdts.Add(t);
                        }
                        else if (cycle == 6)
                        {
                            int iavgmonth = Convert.ToInt32(smonth);
                            DataTable t = computeTableSumAvg2(context, tmp, classes, false, iavgmonth)[0];
                            cdts.Add(t);
                        }
                        else
                        {
                            cdts.Add(dts[i]);
                        }
                    }

                    // cdts = dts;
                    SetLayOutUTypeStatistics1(context, cdts, classes, litems, layouts, code, output, dcs, data2);
                }
            }
        }
    }

    //計算年
    public List<DataTable> computeTableYear(int syear, int eyear, List<DataTable> dt)
    {
        List<DataTable> ldt = new List<DataTable>();

        for (int i = 0; i < dt.Count; i++)
        {
            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(String));
            data.Columns.Add("MONTH", typeof(String));
            data.Columns.Add("STATID", typeof(String));
            data.Columns.Add("value", typeof(String));

            int count = 0;
            double sum = 0;
            for (int j = 0; j < dt[i].Rows.Count; j++)
            {
                DataRow workRow = data.NewRow();
                int month = Convert.ToInt32(dt[i].Rows[j]["MONTH"].ToString());
                int lmonth = -1;
                if (j + 1 != dt[i].Rows.Count)
                    lmonth = Convert.ToInt32(dt[i].Rows[j + 1]["MONTH"].ToString());

                if (month == 1)
                {
                    sum = 0;
                    count = 0;
                }
                if (month == 12)
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;

                    double avg = sum;
                    avg = (double)ComputeMod.ComputeAvgPepole(12, Convert.ToDecimal(avg), 1);
                    if (count != 12) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "-";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if ((month != 12 && lmonth == 1) || (month != 12 && lmonth == -1))
                {
                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "-";
                    workRow["value"] = 0;

                    data.Rows.Add(workRow);
                    sum = 0;
                    count = 0;
                }
                else
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                }
            }

            ldt.Add(data);
        }

        return ldt;
    }

    //計算年-率
    public List<DataTable> computeTableYear2(HttpContext context, List<DataTable> table, string iclasses, bool layout)
    {
        List<DataTable> ldt = new List<DataTable>();

        if (table.Count == 1 || layout == true)
        {
            for (int t = 0; t < table.Count; t++)
            {
                DataTable d = table[t];
                double sum = 0;
                int count = 0;
                DataTable tmp = new DataTable();
                tmp.Columns.Add("YEAR", typeof(String));
                tmp.Columns.Add("MONTH", typeof(String));
                tmp.Columns.Add("STATID", typeof(String));
                tmp.Columns.Add("value", typeof(String));
                ldt.Add(tmp);
                for (int i = 0; i < d.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d.Rows.Count)
                        lmonth = Convert.ToInt32(d.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1)
                    {
                        sum = 0;
                        count = 0;
                    }
                    if (month == 12)
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "-";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        double va = sum;
                        if (count != 12) va = 0;

                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if ((month != 12 && lmonth == 1) || (month != 12 && lmonth == -1))
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "-";
                        workRow["STATID"] = d.Rows[i]["STATID"];
                        workRow["value"] = 0;

                        tmp.Rows.Add(workRow);
                        sum = 0;
                        count = 0;
                    }
                    else
                    {
                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;
                    }
                }
            }
        }
        else
        {
            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(String));
            data.Columns.Add("MONTH", typeof(String));
            data.Columns.Add("STATID", typeof(String));
            data.Columns.Add("value", typeof(String));

            ldt.Add(data);

            if (iclasses == "6") //勞動力參與率
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
            else if (iclasses == "5") //失業率
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
            else if (iclasses == "4") //失業週數
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

                        decimal va = ComputeMod.ComputeWeekPercent((sum2), (sum1), -1);
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
            else if (iclasses == "2") //勞動力
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

                        decimal va = sum1 + sum2;
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
            else if (iclasses == "3") //15歲以上民間人口
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];
                DataTable d3 = table[2];

                double sum1 = 0, sum2 = 0, sum3 = 0;
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

                        double va = sum1 + sum2 + sum3;
                        if (Double.IsNaN(va))
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
            else if (iclasses == "11") // 勞動力低度運用指標
            {
                string subtype = context.Request["subtype"] as string;

                DataTable d1 = table[0]; // PEP
                DataTable d2 = table[1]; // SFU
                DataTable d3 = table[2]; // TRU
                DataTable d4 = table[3]; // PLF

                d1 = d1.AsEnumerable()
                    .Where(r =>
                        Convert.ToInt32(r["YEAR"]) > Convert.ToInt32(d2.Rows[0]["YEAR"].ToString())
                        || (
                            Convert.ToInt32(r["YEAR"]) == Convert.ToInt32(d2.Rows[0]["YEAR"].ToString()) &&
                            Convert.ToInt32(r["MONTH"]) >= Convert.ToInt32(d2.Rows[0]["MONTH"].ToString())
                        )
                    ).CopyToDataTable();

                int count = 0;
                double sum1 = 0, sum2 = 0, sum3 = 0, sum4 = 0;
                for (int i = 0; i < d2.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d2.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d2.Rows.Count)
                        lmonth = Convert.ToInt32(d2.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    if (month == 12)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "-";
                        workRow["STATID"] = d2.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;

                        double va = 0;
                        if (subtype == "4")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "5")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "6")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        else if (subtype == "7")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }

                        if (count != 12) va = 0;

                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else if ((month != 12 && lmonth == 1) || (month != 12 && lmonth == -1))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "-";
                        workRow["STATID"] = d2.Rows[i]["STATID"];
                        workRow["value"] = 0;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else
                    {
                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;
                    }
                }
            }
        }
        return ldt;
    }

    //計算半年
    public List<DataTable> computeTableHalfYear(int syear, int eyear, List<DataTable> dt)
    {
        List<DataTable> ldt = new List<DataTable>();

        for (int i = 0; i < dt.Count; i++)
        {
            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(String));
            data.Columns.Add("MONTH", typeof(String));
            data.Columns.Add("STATID", typeof(String));
            data.Columns.Add("value", typeof(String));

            int count = 0;
            double sum = 0;
            for (int j = 0; j < dt[i].Rows.Count; j++)
            {
                DataRow workRow = data.NewRow();
                int month = Convert.ToInt32(dt[i].Rows[j]["MONTH"].ToString());
                int lmonth = -1;
                if (j + 1 != dt[i].Rows.Count)
                    lmonth = Convert.ToInt32(dt[i].Rows[j + 1]["MONTH"].ToString());

                if (month == 1 || month == 7)
                {
                    sum = 0;
                    count = 0;
                }
                if (month == 12)
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;

                    double avg = sum;
                    avg = (double)ComputeMod.ComputeAvgPepole(6, Convert.ToDecimal(avg), 1);
                    if (count != 6) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "下半年";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if (month == 6)
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;

                    double avg = sum;
                    avg = (double)ComputeMod.ComputeAvgPepole(6, Convert.ToDecimal(avg), 1);
                    if (count != 6) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "上半年";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if ((month != 6 && month != 12 && lmonth == 1) || (month != 6 && month != 12 && lmonth == -1))
                {
                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "上半年";
                    if (month > 6)
                        workRow["MONTH"] = "下半年";

                    workRow["value"] = 0;

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                }
            }
            ldt.Add(data);
        }

        return ldt;
    }

    //計算半年-率
    public List<DataTable> computeTableHalfYear2(HttpContext context, List<DataTable> table, string iclasses, bool layout)
    {
        List<DataTable> ldt = new List<DataTable>();

        if (table.Count == 1 || layout == true)
        {
            for (int t = 0; t < table.Count; t++)
            {
                DataTable d = table[t];
                double sum = 0;
                int count = 0;
                DataTable tmp = new DataTable();
                tmp.Columns.Add("YEAR", typeof(String));
                tmp.Columns.Add("MONTH", typeof(String));
                tmp.Columns.Add("STATID", typeof(String));
                tmp.Columns.Add("value", typeof(String));
                ldt.Add(tmp);
                for (int i = 0; i < d.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d.Rows.Count)
                        lmonth = Convert.ToInt32(d.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1 || month == 7)
                    {
                        sum = 0;
                        count = 0;
                    }
                    if (month == 6)
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "上半年";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        double va = sum;
                        if (count != 6) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if (month == 12)
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "下半年";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        double va = sum;
                        if (count != 6) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if ((month != 6 && month != 12 && lmonth == 1) || (month != 6 && month != 12 && lmonth == -1))
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "上半年";
                        if (month > 6)
                            workRow["MONTH"] = "下半年";

                        workRow["STATID"] = d.Rows[i]["STATID"];
                        workRow["value"] = 0;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else
                    {
                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;
                    }
                }
            }
        }
        else
        {
            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(String));
            data.Columns.Add("MONTH", typeof(String));
            data.Columns.Add("STATID", typeof(String));
            data.Columns.Add("value", typeof(String));

            if (iclasses == "6") //勞動力參與率
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
            else if (iclasses == "5") //失業率
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
            else if (iclasses == "4") //失業週數
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

                        decimal va = ComputeMod.ComputeWeekPercent((sum2), (sum1), -1);
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

                        decimal va = ComputeMod.ComputeWeekPercent((sum2), (sum1), -1);
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
            else if (iclasses == "2") //勞動力
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                double sum1 = 0, sum2 = 0;
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

                        double va = sum1 + sum2;
                        if (Double.IsNaN(va))
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

                        double va = sum1 + sum2;
                        if (Double.IsNaN(va))
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
            else if (iclasses == "3") //15歲以上民間人口
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];
                DataTable d3 = table[2];

                double sum1 = 0, sum2 = 0, sum3 = 0;
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

                        double va = sum1 + sum2 + sum3;
                        if (Double.IsNaN(va))
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

                        double va = sum1 + sum2 + sum3;
                        if (Double.IsNaN(va))
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
            else if (iclasses == "11") // 勞動力低度運用指標
            {
                string subtype = context.Request["subtype"] as string;

                DataTable d1 = table[0]; // PEP
                DataTable d2 = table[1]; // SFU
                DataTable d3 = table[2]; // TRU
                DataTable d4 = table[3]; // PLF

                d1 = d1.AsEnumerable()
                    .Where(r =>
                        Convert.ToInt32(r["YEAR"]) > Convert.ToInt32(d2.Rows[0]["YEAR"].ToString())
                        || (
                            Convert.ToInt32(r["YEAR"]) == Convert.ToInt32(d2.Rows[0]["YEAR"].ToString()) &&
                            Convert.ToInt32(r["MONTH"]) >= Convert.ToInt32(d2.Rows[0]["MONTH"].ToString())
                        )
                    ).CopyToDataTable();

                int count = 0;
                double sum1 = 0, sum2 = 0, sum3 = 0, sum4 = 0;
                for (int i = 0; i < d2.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d2.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d2.Rows.Count)
                        lmonth = Convert.ToInt32(d2.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1 || month == 7)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    if (month == 6)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "上半年";
                        workRow["STATID"] = d2.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;

                        double va = 0;
                        if (subtype == "4")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "5")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "6")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        else if (subtype == "7")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        if (count != 6) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else if (month == 12)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "下半年";
                        workRow["STATID"] = d2.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;

                        double va = 0;
                        if (subtype == "4")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "5")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "6")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        else if (subtype == "7")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        if (count != 6) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else if ((month != 6 && month != 12 && lmonth == 1) || (month != 6 && month != 12 && lmonth == -1))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "上半年";
                        if (month > 6)
                            workRow["MONTH"] = "下半年";

                        workRow["STATID"] = d2.Rows[i]["STATID"];
                        workRow["value"] = 0;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else
                    {
                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;
                    }
                }
            }
            ldt.Add(data);
        }

        return ldt;
    }

    //計算季
    public List<DataTable> computeTableSeason(int syear, int eyear, List<DataTable> dt)
    {
        List<DataTable> ldt = new List<DataTable>();

        for (int i = 0; i < dt.Count; i++)
        {
            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(String));
            data.Columns.Add("MONTH", typeof(String));
            data.Columns.Add("STATID", typeof(String));
            data.Columns.Add("value", typeof(String));

            double sum = 0;
            int count = 0;
            for (int j = 0; j < dt[i].Rows.Count; j++)
            {
                DataRow workRow = data.NewRow();
                int month = Convert.ToInt32(dt[i].Rows[j]["MONTH"].ToString());
                int lmonth = -1;
                if (j + 1 != dt[i].Rows.Count)
                    lmonth = Convert.ToInt32(dt[i].Rows[j + 1]["MONTH"].ToString());

                if (month == 1 || month == 4 || month == 7 || month == 10)
                {
                    sum = 0;
                    count = 0;
                }
                if (month == 12)
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                    double avg = sum;
                    avg = (double)ComputeMod.ComputeAvgPepole(3, Convert.ToDecimal(avg), 1);
                    if (count != 3) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "第4季";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if (month == 9)
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                    double avg = sum;
                    avg = (double)ComputeMod.ComputeAvgPepole(3, Convert.ToDecimal(avg), 1);
                    if (count != 3) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "第3季";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if (month == 6)
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                    double avg = sum;
                    avg = (double)ComputeMod.ComputeAvgPepole(3, Convert.ToDecimal(avg), 1);
                    if (count != 3) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "第2季";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if (month == 3)
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                    double avg = sum;
                    avg = (double)ComputeMod.ComputeAvgPepole(3, Convert.ToDecimal(avg), 1);
                    if (count != 3) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "第1季";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if ((month != 3 && month != 6 && month != 9 && month != 12 && lmonth == 1) || (month != 3 && month != 6 && month != 9 && month != 12 && lmonth == -1))
                {
                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
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
                    count = 0;
                }
                else
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                }
            }

            ldt.Add(data);
        }

        return ldt;
    }

    //計算季-率
    public List<DataTable> computeTableSeason2(HttpContext context, List<DataTable> table, string iclasses, bool layout)
    {
        List<DataTable> ldt = new List<DataTable>();

        if (table.Count == 1 || layout == true)
        {
            for (int t = 0; t < table.Count; t++)
            {
                DataTable d = table[t];
                double sum = 0;
                int count = 0;
                DataTable tmp = new DataTable();
                tmp.Columns.Add("YEAR", typeof(String));
                tmp.Columns.Add("MONTH", typeof(String));
                tmp.Columns.Add("STATID", typeof(String));
                tmp.Columns.Add("value", typeof(String));

                ldt.Add(tmp);
                for (int i = 0; i < d.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d.Rows.Count)
                        lmonth = Convert.ToInt32(d.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1 || month == 4 || month == 7 || month == 10)
                    {
                        sum = 0;
                        count = 0;
                    }
                    if (month == 3)
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第1季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        double va = sum;
                        if (count != 3) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if (month == 6)
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第2季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        double va = sum;
                        if (count != 3) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if (month == 9)
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第3季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        double va = sum;
                        if (count != 3) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if (month == 12)
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第4季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        double va = sum;
                        if (count != 3) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if ((month != 3 && month != 6 && month != 9 && month != 12 && lmonth == 1) || (month != 3 && month != 6 && month != 9 && month != 12 && lmonth == -1))
                    {
                        DataRow workRow = tmp.NewRow();
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

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else
                    {
                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;
                    }
                }
            }
        }
        else
        {
            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(String));
            data.Columns.Add("MONTH", typeof(String));
            data.Columns.Add("STATID", typeof(String));
            data.Columns.Add("value", typeof(String));

            if (iclasses == "6") //勞動力參與率
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
            else if (iclasses == "5") //失業率
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
            else if (iclasses == "4") //失業週數
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

                        decimal va = ComputeMod.ComputeWeekPercent((sum2), (sum1), -1);
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

                        decimal va = ComputeMod.ComputeWeekPercent((sum2), (sum1), -1);
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

                        decimal va = ComputeMod.ComputeWeekPercent((sum2), (sum1), -1);
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

                        decimal va = ComputeMod.ComputeWeekPercent((sum2), (sum1), -1);
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
            else if (iclasses == "2") //勞動力
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                double sum1 = 0, sum2 = 0;
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

                        double va = sum1 + sum2;
                        if (Double.IsNaN(va))
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

                        double va = sum1 + sum2;
                        if (Double.IsNaN(va))
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

                        double va = sum1 + sum2;
                        if (Double.IsNaN(va))
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

                        double va = sum1 + sum2;
                        if (Double.IsNaN(va))
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
            else if (iclasses == "3") //15歲以上民間人口
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];
                DataTable d3 = table[2];

                double sum1 = 0, sum2 = 0, sum3 = 0;
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

                        double va = sum1 + sum2 + sum3;
                        if (Double.IsNaN(va))
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

                        double va = sum1 + sum2 + sum3;
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

                        double va = sum1 + sum2 + sum3;
                        if (Double.IsNaN(va))
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

                        double va = sum1 + sum2 + sum3;
                        if (Double.IsNaN(va))
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
            else if (iclasses == "11") // 勞動力低度運用指標
            {
                string subtype = context.Request["subtype"] as string;

                DataTable d1 = table[0]; // PEP
                DataTable d2 = table[1]; // SFU
                DataTable d3 = table[2]; // TRU
                DataTable d4 = table[3]; // PLF

                d1 = d1.AsEnumerable()
                    .Where(r =>
                        Convert.ToInt32(r["YEAR"]) > Convert.ToInt32(d2.Rows[0]["YEAR"].ToString())
                        || (
                            Convert.ToInt32(r["YEAR"]) == Convert.ToInt32(d2.Rows[0]["YEAR"].ToString()) &&
                            Convert.ToInt32(r["MONTH"]) >= Convert.ToInt32(d2.Rows[0]["MONTH"].ToString())
                        )
                    ).CopyToDataTable();

                int count = 0;
                double sum1 = 0, sum2 = 0, sum3 = 0, sum4 = 0;
                for (int i = 0; i < d2.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d2.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d2.Rows.Count)
                        lmonth = Convert.ToInt32(d2.Rows[i + 1]["MONTH"].ToString());

                    if (month == 1 || month == 4 || month == 7 || month == 10)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    if (month == 3)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第1季";
                        workRow["STATID"] = d2.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;

                        double va = 0;
                        if (subtype == "4")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "5")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "6")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        else if (subtype == "7")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        if (count != 3) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else if (month == 6)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第2季";
                        workRow["STATID"] = d2.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;

                        double va = 0;
                        if (subtype == "4")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "5")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "6")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        else if (subtype == "7")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        if (count != 3) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;
                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else if (month == 9)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第3季";
                        workRow["STATID"] = d2.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;

                        double va = 0;
                        if (subtype == "4")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "5")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "6")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        else if (subtype == "7")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        if (count != 3) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else if (month == 12)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第4季";
                        workRow["STATID"] = d2.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;

                        double va = 0;
                        if (subtype == "4")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "5")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "6")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        else if (subtype == "7")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        if (count != 3) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else if ((month != 3 && month != 6 && month != 9 && month != 12 && lmonth == 1) || (month != 3 && month != 6 && month != 9 && month != 12 && lmonth == -1))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["STATID"] = d2.Rows[i]["STATID"];
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
                        sum4 = 0;
                        count = 0;
                    }
                    else
                    {
                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;
                    }
                }
            }

            ldt.Add(data);
        }

        return ldt;
    }

    //計算累計平均
    public List<DataTable> computeTableSumAvg(int syear, int eyear, List<DataTable> dt, int smonth)
    {
        List<DataTable> ldt = new List<DataTable>();

        for (int i = 0; i < dt.Count; i++)
        {
            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(String));
            data.Columns.Add("MONTH", typeof(String));
            data.Columns.Add("STATID", typeof(String));
            data.Columns.Add("value", typeof(String));

            double sum = 0;
            int count = 0;
            for (int j = 0; j < dt[i].Rows.Count; j++)
            {
                DataRow workRow = data.NewRow();
                int month = Convert.ToInt32(dt[i].Rows[j]["MONTH"].ToString());
                int lmonth = -1;
                if (j + 1 != dt[i].Rows.Count)
                    lmonth = Convert.ToInt32(dt[i].Rows[j + 1]["MONTH"].ToString());

                if (month > smonth)
                {
                    sum = 0;
                    count = 0;
                    continue;
                }
                if (month == smonth)
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                    double avg = sum;
                    avg = (double)ComputeMod.ComputeAvgPepole(smonth, Convert.ToDecimal(avg), 1);
                    if (count != smonth) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "1月至" + smonth + "月";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if (month <= smonth && lmonth == -1 || (month > lmonth))
                {
                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "1月至" + smonth + "月";

                    workRow["value"] = 0;

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else
                {
                    sum += Convert.ToDouble(dt[i].Rows[j]["value"].ToString());
                    count++;
                }
            }

            ldt.Add(data);
        }

        return ldt;
    }
    //計算累計平均-率
    public List<DataTable> computeTableSumAvg2(HttpContext context, List<DataTable> table, string iclasses, bool layout, int smonth)
    {
        List<DataTable> ldt = new List<DataTable>();

        if (table.Count == 1 || layout == true)
        {
            for (int t = 0; t < table.Count; t++)
            {
                DataTable d = table[t];
                double sum = 0;
                int count = 0;
                DataTable tmp = new DataTable();
                tmp.Columns.Add("YEAR", typeof(String));
                tmp.Columns.Add("MONTH", typeof(String));
                tmp.Columns.Add("STATID", typeof(String));
                tmp.Columns.Add("value", typeof(String));

                ldt.Add(tmp);
                for (int i = 0; i < d.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d.Rows.Count)
                        lmonth = Convert.ToInt32(d.Rows[i + 1]["MONTH"].ToString());

                    if (month > smonth)
                    {
                        sum = 0;
                        count = 0;
                        continue;
                    }
                    if (month == smonth)
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "1月至" + smonth + "月";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        double va = sum;
                        if (count != smonth) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if ((month <= smonth && lmonth == -1) || (month > lmonth))
                    {
                        DataRow workRow = tmp.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["STATID"] = d.Rows[i]["STATID"];
                        workRow["MONTH"] = "1月至" + smonth + "月";

                        workRow["value"] = 0;

                        tmp.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else
                    {
                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;
                    }
                }
            }
        }
        else
        {
            DataTable data = new DataTable();
            data.Columns.Add("YEAR", typeof(String));
            data.Columns.Add("MONTH", typeof(String));
            data.Columns.Add("STATID", typeof(String));
            data.Columns.Add("value", typeof(String));

            if (iclasses == "6") //勞動力參與率
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

                    if (month > smonth)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        continue;
                    }
                    if (month == smonth)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["MONTH"] = "1月至" + smonth + "月";
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
                    else if (month <= smonth && lmonth == -1 || (month > lmonth))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["STATID"] = d1.Rows[i]["STATID"];
                        workRow["MONTH"] = "1月至" + smonth + "月";

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
            else if (iclasses == "5") //失業率
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

                    if (month > smonth)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        continue;
                    }
                    if (month == smonth)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["MONTH"] = "1月至" + smonth + "月";
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
                    else if (month <= smonth && lmonth == -1 || (month > lmonth))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["STATID"] = d1.Rows[i]["STATID"];
                        workRow["MONTH"] = "1月至" + smonth + "月";

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
            else if (iclasses == "4") //失業週數
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

                    if (month > smonth)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        continue;
                    }
                    if (month == smonth)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["MONTH"] = "1月至" + smonth + "月";
                        workRow["STATID"] = d1.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                        decimal va = ComputeMod.ComputeWeekPercent((sum2), (sum1), -1);
                        if (va == -999999)
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                    }
                    else if (month <= smonth && lmonth == -1 || (month > lmonth))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["STATID"] = d1.Rows[i]["STATID"];
                        workRow["MONTH"] = "1月至" + smonth + "月";

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
            else if (iclasses == "2") //勞動力
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                double sum1 = 0, sum2 = 0;
                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d1.Rows.Count)
                        lmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                    if (month > smonth)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        continue;
                    }
                    if (month == smonth)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["MONTH"] = "1月至" + smonth + "月";
                        workRow["STATID"] = d1.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());

                        double va = sum1 + sum2;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                    }
                    else if (month <= smonth && lmonth == -1 || (month > lmonth))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["STATID"] = d1.Rows[i]["STATID"];
                        workRow["MONTH"] = "1月至" + smonth + "月";

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
            else if (iclasses == "3") //15歲以上民間人口
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];
                DataTable d3 = table[2];

                double sum1 = 0, sum2 = 0, sum3 = 0;
                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d1.Rows.Count)
                        lmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                    if (month > smonth)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        continue;
                    }
                    if (month == smonth)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["MONTH"] = "1月至" + smonth + "月";
                        workRow["STATID"] = d1.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());

                        double va = sum1 + sum2 + sum3;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                    }
                    else if (month <= smonth && lmonth == -1 || (month > lmonth))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d1.Rows[i]["YEAR"];
                        workRow["STATID"] = d1.Rows[i]["STATID"];
                        workRow["MONTH"] = "1月至" + smonth + "月";

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
            else if (iclasses == "11") // 勞動力低度運用指標
            {
                string subtype = context.Request["subtype"] as string;

                DataTable d1 = table[0]; // PEP
                DataTable d2 = table[1]; // SFU
                DataTable d3 = table[2]; // TRU
                DataTable d4 = table[3]; // PLF

                d1 = d1.AsEnumerable()
                    .Where(r =>
                        Convert.ToInt32(r["YEAR"]) > Convert.ToInt32(d2.Rows[0]["YEAR"].ToString())
                        || (
                            Convert.ToInt32(r["YEAR"]) == Convert.ToInt32(d2.Rows[0]["YEAR"].ToString()) &&
                            Convert.ToInt32(r["MONTH"]) >= Convert.ToInt32(d2.Rows[0]["MONTH"].ToString())
                        )
                    ).CopyToDataTable();

                int count = 0;
                double sum1 = 0, sum2 = 0, sum3 = 0, sum4 = 0;
                for (int i = 0; i < d2.Rows.Count; i++)
                {
                    int month = Convert.ToInt32(d2.Rows[i]["MONTH"].ToString());
                    int lmonth = -1;
                    if (i + 1 != d2.Rows.Count)
                        lmonth = Convert.ToInt32(d2.Rows[i + 1]["MONTH"].ToString());

                    if (month > smonth)
                    {
                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                        continue;
                    }
                    if (month == smonth)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["MONTH"] = "1月至" + smonth + "月";
                        workRow["STATID"] = d2.Rows[i]["STATID"];

                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;

                        double va = 0;
                        if (subtype == "4")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "5")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                        }
                        else if (subtype == "6")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        else if (subtype == "7")
                        {
                            va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                        }
                        if (count != smonth) va = 0;
                        if (Double.IsNaN(va))
                            workRow["value"] = 0;
                        else
                            workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else if (month <= smonth && lmonth == -1 || (month > lmonth))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"];
                        workRow["STATID"] = d2.Rows[i]["STATID"];
                        workRow["MONTH"] = "1月至" + smonth + "月";

                        workRow["value"] = 0;

                        data.Rows.Add(workRow);

                        sum1 = 0;
                        sum2 = 0;
                        sum3 = 0;
                        sum4 = 0;
                        count = 0;
                    }
                    else
                    {
                        sum1 += Convert.ToInt32(d1.Rows[i]["value"].ToString());
                        sum2 += Convert.ToInt32(d2.Rows[i]["value"].ToString());
                        sum3 += Convert.ToInt32(d3.Rows[i]["value"].ToString());
                        sum4 += Convert.ToInt32(d4.Rows[i]["value"].ToString());
                        count++;
                    }
                }
            }

            ldt.Add(data);
        }

        return ldt;
    }

    public DataTable GetAllTaiwanData(int syear, int eyear, string code)
    {
        DataTable dt = new DataTable();

        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT DISTINCT (CAST(YEAR AS decimal)-1911) as YEAR, CAST(MONTH AS decimal) as MONTH, CAST(STAT_VAL AS decimal) as value, STATID 
                        FROM STATDATA_NEW182A 
                        WHERE (YEAR >= @startyear AND YEAR <= @endyear) AND STATID=@STATID 
                      ";

            sqlStr += @" ORDER BY YEAR, MONTH ";
            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@startyear", syear),
                    new SqlParameter("@endyear", eyear),
                    new SqlParameter("@STATID", code)
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
        };

        return dt;
    }

    public void SetWeekTypeData(HttpContext context, List<listitem> litems, rdata rdata, Dictionary<string, decimal> data2)
    {
        int syear = Convert.ToInt32(context.Request["startyear"] as string) + 1911;
        int eyear = Convert.ToInt32(context.Request["endyear"] as string) + 1911;
        string[] sexes = (context.Request["sex"] as string).Split(',');
        string[] tsexes = { "T", "M", "F" };
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string output = context.Request["output"] as string;
        string smonth = context.Request["smonth"] as string;
        string classes = context.Request["classes"] as string;
        string rcs = cDictionary(classes);

        string[] css = (context.Request["classes1"] as string).Split(',');

        for (int q = 0; q < css.Length; q++)
        {
            string cs = css[q];
            string dcs = ClassesDictionary(cs);

            bool hasLayOut = false;
            if (cs != "1")
                hasLayOut = true;

            if (!hasLayOut) //總計部分
            {
                List<string> ctip = Dictionary(context);
                sortitem si = new sortitem();
                si.classes = "1";
                si.name = "失業週數";
                si.level = "3";
                rdata.sort.Add(si);

                List<DataTable> dts = new List<DataTable>();
                for (int i = 0; i < ctip.Count; i++)
                {
                    List<string> codes = new List<string>();
                    for (int j = 0; j < sexes.Length; j++)
                    {
                        string code = "";
                        code += ctip[i] + sexes[j] + "0000X0000000000000";
                        codes.Add(code);
                    }
                    DataTable dtt = getTabelByCodes(context, codes, "NEW182A");
                    dts.Add(dtt);
                }

                List<DataTable> cdts = new List<DataTable>();
                DataTable dt = MerageTable(context, dts);

                List<DataTable> fdts = new List<DataTable>();
                fdts.Add(dt);

                if (cycle == 1)
                    cdts = computeTableYear2(context, dts, classes, false);
                else if (cycle == 2)
                    cdts = computeTableHalfYear2(context, dts, classes, false);
                else if (cycle == 3)
                    cdts = computeTableSeason2(context, dts, classes, false);
                else if (cycle == 5)
                {
                    cdts = fdts;
                    for (int i = 0; i < cdts.Count; i++)
                    {
                        cdts[i] = cdts[i].Select("MONTH='" + smonth + "'").CopyToDataTable();
                    }
                }
                else if (cycle == 6)
                {
                    int iavgmonth = Convert.ToInt32(smonth);
                    cdts = computeTableSumAvg2(context, dts, classes, false, iavgmonth);
                }
                else
                    cdts = fdts;

                SetBaseStatistics1(context, cdts[0], classes, litems, output, data2);
            }
            else //含有LayOut階層部分
            {
                List<DataTable> dts = null;
                string ver = "0";
                //判斷取LayOut
                if (cs == "2") //教育程度
                {
                    dts = GetEdtionTables(context, "教育程度");
                    rdata.sort.AddRange(GetSortItems("教育程度", ver));
                }
                else if (cs == "3") //年齡
                {
                    dts = GetAgeTables(context, "年齡");
                    rdata.sort.AddRange(GetSortItems("年齡", ver));
                }
                else if (cs == "6") //失業原因
                {
                    dts = GetROUTables(context, "失業原因");
                    rdata.sort.AddRange(GetSortItems("失業原因", ver));
                }

                //取得Layout
                string layoutstring = GetLayouts(dcs, ver);
                string[] layouts = layoutstring.Split(',');
                //取得CodeTable
                DataTable code = GetCodeTable(dcs, ver);
                List<DataTable> cdts = new List<DataTable>();
                DataTable dt = MerageTable(context, dts);

                for (int i = 0; i < dts.Count; i++)
                {
                    List<DataTable> tmp = new List<DataTable>();
                    tmp.Add(dts[i]);

                    if (cycle == 1)
                    {
                        DataTable t = computeTableYear2(context, tmp, classes, false)[0];
                        cdts.Add(t);
                    }
                    else if (cycle == 2)
                    {
                        DataTable t = computeTableHalfYear2(context, tmp, classes, false)[0];
                        cdts.Add(t);
                    }
                    else if (cycle == 3)
                    {
                        DataTable t = computeTableSeason2(context, tmp, classes, false)[0];
                        cdts.Add(t);
                    }
                    else if (cycle == 5)
                    {
                        DataTable t = dts[i].Select("MONTH='" + smonth + "'").CopyToDataTable();
                        cdts.Add(t);
                    }
                    else if (cycle == 6)
                    {
                        int iavgmonth = Convert.ToInt32(smonth);
                        DataTable t = computeTableSumAvg2(context, tmp, classes, false, iavgmonth)[0];
                        cdts.Add(t);
                    }
                    else
                    {
                        cdts = dts;
                        break;
                    }
                }

                SetLayOutUTypeStatistics1(context, cdts, classes, litems, layouts, code, output, dcs, data2);
            }
        }
    }

    public string getdcsclasses(string classes)
    {
        if (classes == "1")
            return "行業";
        else if (classes == "2")
            return "職業";
        else if (classes == "3")
            return "從業身分";
        else if (classes == "4")
            return "失業原因";
        else if (classes == "5")
            return "失業原因";
        else if (classes == "6")
            return "從業身分";
        else if (classes == "7")
            return "非勞動原因";
        else
            return "";
    }

    public class cstable
    {
        public List<DataTable> table { get; set; }
        public List<List<string>> cs { get; set; }
    }

    public void SetSecondTypeData(HttpContext context, List<listitem> litems, rdata rdata, Dictionary<string, decimal> data2)
    {
        int syear = Convert.ToInt32(context.Request["startyear"] as string) + 1911;
        int eyear = Convert.ToInt32(context.Request["endyear"] as string) + 1911;
        string[] sexes = (context.Request["sex"] as string).Split(',');
        string[] tsexes = { "T", "M", "F" };
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string output = context.Request["output"] as string;
        string smonth = context.Request["smonth"] as string;
        string classes = context.Request["classes"] as string; //統計項
        string subtype = context.Request["subtype"] as string; //下拉選單

        string classes2 = context.Request["classes2"] as string; //(二)下拉選單
        string subtype2 = context.Request["subtype2"] as string; //分類下拉選單
        string[] asubtype2 = subtype2.Split(',');

        string classes3 = context.Request["classes3"] as string; //分類LayOut

        string dcs2 = getdcsclasses(classes2);

        cstable dts = null;
        string ver = "0";
        string dcs = "";
        //判斷取LayOut
        if (classes3 == "2") //教育程度
        {
            dts = GetEdtionTables2(context, "教育程度", classes2, asubtype2, subtype);
            rdata.sort = GetSortItems("教育程度", ver);
            dcs = "教育程度";
        }
        else if (classes3 == "3") //年齡
        {
            dts = GetAgeTables2(context, "年齡", classes2, asubtype2, subtype);
            rdata.sort = GetSortItems("年齡", ver);
            dcs = "年齡";
        }
        else if (classes3 == "4") //行業
        {
            ver = GetLayOutIndVer(context);
            dts = GetIndTables2(context, "行業", ver, classes2, asubtype2, subtype);
            rdata.sort = GetSortItems("行業", ver);
            dcs = "行業";
        }
        else if (classes3 == "5") //職業
        {
            ver = GetLayOutOccVer(context);
            dts = GetOCCTables2(context, "職業", ver, classes2, asubtype2, subtype);
            rdata.sort = GetSortItems("職業", ver);
            dcs = "職業";
        }
        else if (classes3 == "6") //失業前從業身分
        {
            dts = GetCOWTables2(context, "從業身分", classes2, asubtype2, subtype);
            rdata.sort = GetSortItems("從業身分", ver);
            dcs = "從業身分";
        }

        //取得Layout
        string layoutstring = GetLayouts(dcs, ver);
        string[] layouts = layoutstring.Split(',');
        //取得CodeTable
        DataTable code = GetCodeTable(dcs, ver);

        List<DataTable> cdts = new List<DataTable>();
        if (cycle == 1)
            cdts = computeTableYear2(context, dts.table, classes, true);
        else if (cycle == 2)
            cdts = computeTableHalfYear2(context, dts.table, classes, true);
        else if (cycle == 3)
            cdts = computeTableSeason2(context, dts.table, classes, true);
        else if (cycle == 4)
        {
            for (int i = 0; i < dts.table.Count; i++)
            {
                cdts.Add(dts.table[i]);
            }
        }
        else if (cycle == 5)
        {
            for (int i = 0; i < dts.table.Count; i++)
            {
                dts.table[i] = dts.table[i].Select("MONTH='" + smonth + "'").CopyToDataTable();
                cdts.Add(dts.table[i]);
            }
        }
        else if (cycle == 6)
        {
            int iavgmonth = Convert.ToInt32(smonth);
            cdts = computeTableSumAvg2(context, dts.table, classes, true, iavgmonth);
        }

        SetSecondLayOutStatistics1(context, cdts, classes, litems, layouts, code, output, dcs, dcs2, dts.cs, rdata, data2);
    }

    public void SetBaseTypeData(HttpContext context, List<listitem> litems, rdata rdata, Dictionary<string, decimal> data2)
    {
        int syear = Convert.ToInt32(context.Request["startyear"] as string) + 1911;
        int eyear = Convert.ToInt32(context.Request["endyear"] as string) + 1911;
        string[] sexes = (context.Request["sex"] as string).Split(',');
        string[] tsexes = { "T", "M", "F" };
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string output = context.Request["output"] as string;
        string smonth = context.Request["smonth"] as string;
        string classes = context.Request["classes"] as string;
        string rcs = cDictionary(classes);

        string[] css = (context.Request["classes1"] as string).Split(',');

        for (int q = 0; q < css.Length; q++)
        {
            string cs = css[q];
            string dcs = ClassesDictionary(cs);

            bool hasLayOut = false;
            if (cs != "1")
                hasLayOut = true;

            if (!hasLayOut) //總計部分
            {
                List<string> ctip = Dictionary(context);
                string des = cDictionary(classes);
                sortitem si = new sortitem();
                si.classes = "1";
                si.name = des;
                si.level = "3";
                rdata.sort.Add(si);

                List<DataTable> dts = new List<DataTable>();
                for (int i = 0; i < ctip.Count; i++)
                {
                    List<string> codes = new List<string>();
                    for (int j = 0; j < tsexes.Length; j++)
                    {
                        string code = "";
                        code += ctip[i] + tsexes[j] + "0000X0000000000000";
                        codes.Add(code);
                    }
                    DataTable dt = getTabelByCodes(context, codes, "NEW182A");
                    dts.Add(dt);
                }

                if (classes != "5" && classes != "6")
                {
                    List<DataTable> cdts = new List<DataTable>();
                    DataTable dt = MerageTable(context, dts);

                    List<DataTable> fdts = new List<DataTable>();
                    fdts.Add(dt);

                    if (cycle == 1)
                        cdts = computeTableYear(syear, eyear, fdts);
                    else if (cycle == 2)
                        cdts = computeTableHalfYear(syear, eyear, fdts);
                    else if (cycle == 3)
                        cdts = computeTableSeason(syear, eyear, fdts);
                    else if (cycle == 5)
                    {
                        DataTable tmp = dt.Select("MONTH='" + smonth + "'").CopyToDataTable();
                        cdts.Add(tmp);
                    }
                    else if (cycle == 6)
                    {
                        int iavgmonth = Convert.ToInt32(smonth);
                        cdts = computeTableSumAvg(syear, eyear, fdts, iavgmonth);
                    }
                    else
                        cdts = fdts;

                    SetBaseStatistics1(context, cdts[0], classes, litems, output, data2);
                    if (output.IndexOf("S") != -1)
                        SetBaseStatistics2(context, dt, classes, litems, data2);
                }
                else //基底-率 額外處理
                {
                    List<DataTable> cdts = new List<DataTable>();
                    DataTable dt = MerageTable(context, dts);

                    List<DataTable> fdts = new List<DataTable>();
                    fdts.Add(dt);

                    if (cycle == 1)
                        cdts = computeTableYear2(context, dts, classes, false);
                    else if (cycle == 2)
                        cdts = computeTableHalfYear2(context, dts, classes, false);
                    else if (cycle == 3)
                        cdts = computeTableSeason2(context, dts, classes, false);
                    else if (cycle == 5)
                    {
                        DataTable tmp = dt.Select("MONTH='" + smonth + "'").CopyToDataTable();
                        cdts.Add(tmp);
                    }
                    else if (cycle == 6)
                    {
                        int iavgmonth = Convert.ToInt32(smonth);
                        cdts = computeTableSumAvg2(context, dts, classes, false, iavgmonth);
                    }
                    else
                        cdts = fdts;

                    SetBaseStatistics1(context, cdts[0], classes, litems, output, data2);
                }
            }
            else //含有LayOut階層部分
            {
                List<DataTable> dts = null;
                string ver = "0";
                //判斷取LayOut
                if (cs == "2") //教育程度
                {
                    dts = GetEdtionTables(context, "教育程度");
                    rdata.sort.AddRange(GetSortItems("教育程度", ver));
                }
                else if (cs == "3") //年齡
                {
                    dts = GetAgeTables(context, "年齡");
                    rdata.sort.AddRange(GetSortItems("年齡", ver));
                }
                else if (cs == "4") //行業
                {
                    ver = GetLayOutIndVer(context);
                    dts = GetIndTables(context, "行業", ver);
                    rdata.sort.AddRange(GetSortItems("行業", ver));
                }
                else if (cs == "5") //職業
                {
                    ver = GetLayOutOccVer(context);
                    dts = GetOCCTables(context, "職業", ver);
                    rdata.sort.AddRange(GetSortItems("職業", ver));
                }
                else if (cs == "6") //失業原因
                {
                    dts = GetROUTables(context, "失業原因");
                    rdata.sort.AddRange(GetSortItems("失業原因", ver));
                }
                else if (cs == "7") //從業身分
                {
                    dts = GetCOWTables(context, "從業身分");
                    rdata.sort.AddRange(GetSortItems("從業身分", ver));
                }
                else if (cs == "8") //未勞動原因
                {
                    dts = GetRONTables(context, "非勞動原因");
                    rdata.sort.AddRange(GetSortItems("非勞動原因", ver));
                }

                if (classes != "5" && classes != "6")
                {
                    //取得Layout
                    string layoutstring = GetLayouts(dcs, ver);
                    string[] layouts = layoutstring.Split(',');
                    //取得CodeTable
                    DataTable code = GetCodeTable(dcs, ver);
                    List<DataTable> cdts = new List<DataTable>();
                    DataTable dt = MerageTable(context, dts);

                    List<DataTable> fdts = new List<DataTable>();
                    fdts.Add(dt);

                    if (cycle == 1)
                        cdts = computeTableYear2(context, dts, classes, false);
                    else if (cycle == 2)
                        cdts = computeTableHalfYear2(context, dts, classes, false);
                    else if (cycle == 3)
                        cdts = computeTableSeason2(context, dts, classes, false);
                    else if (cycle == 5)
                    {
                        DataTable tmp = dt.Select("MONTH='" + smonth + "'").CopyToDataTable();
                        cdts.Add(tmp);
                    }
                    else if (cycle == 6)
                    {
                        int iavgmonth = Convert.ToInt32(smonth);
                        cdts = computeTableSumAvg2(context, dts, classes, false, iavgmonth);
                    }
                    else
                        cdts = fdts;

                    SetLayOutStatistics1(context, cdts[0], classes, litems, layouts, code, output, dcs, data2);
                }
                else //基底-率 額外處理
                {
                    //取得Layout
                    string layoutstring = GetLayouts(dcs, ver);
                    string[] layouts = layoutstring.Split(',');
                    //取得CodeTable
                    DataTable code = GetCodeTable(dcs, ver);
                    List<DataTable> cdts = new List<DataTable>();
                    DataTable dt = MerageTable(context, dts);

                    List<DataTable> fdts = new List<DataTable>();
                    fdts.Add(dt);

                    for (int i = 0; i < dts.Count; i++)
                    {
                        List<DataTable> tmp = new List<DataTable>();
                        tmp.Add(dts[i]);

                        if (cycle == 1)
                        {
                            DataTable t = computeTableYear2(context, tmp, classes, true)[0];
                            cdts.Add(t);
                        }
                        else if (cycle == 2)
                        {
                            DataTable t = computeTableHalfYear2(context, tmp, classes, true)[0];
                            cdts.Add(t);
                        }
                        else if (cycle == 3)
                        {
                            DataTable t = computeTableSeason2(context, tmp, classes, true)[0];
                            cdts.Add(t);
                        }
                        else if (cycle == 5)
                        {
                            DataTable t = dts[i].Select("MONTH='" + smonth + "'").CopyToDataTable();
                            cdts.Add(t);
                        }
                        else if (cycle == 6)
                        {
                            int iavgmonth = Convert.ToInt32(smonth);
                            DataTable t = computeTableSumAvg2(context, tmp, classes, false, iavgmonth)[0];
                            cdts.Add(t);
                        }
                        else
                        {
                            cdts.Add(dts[i]);
                        }
                    }

                    SetLayOutUTypeStatistics1(context, cdts, classes, litems, layouts, code, output, dcs, data2);
                }
            }
        }
    }

    public DataTable MerageTable(HttpContext context, List<DataTable> table)
    {
        string type = context.Request["classes"] as string;

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

                double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString());
                double va = dv1;

                workRow["value"] = va;
                data.Rows.Add(workRow);
            }
        }
        else
        {
            if (type == "2") //勞動力
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"].ToString();
                    workRow["MONTH"] = d1.Rows[i]["MONTH"].ToString();
                    workRow["STATID"] = d1.Rows[i]["STATID"].ToString();

                    double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString());
                    double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString());
                    double va = dv1 + dv2;

                    workRow["value"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "3") //15歲以上民間人口
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

                    double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString());
                    double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString());
                    double dv3 = Convert.ToDouble(d3.Rows[i]["value"].ToString());
                    double va = dv1 + dv2 + dv3;

                    workRow["value"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "6") //勞動力參與率
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

                    double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString());
                    double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString());
                    double dv3 = Convert.ToDouble(d3.Rows[i]["value"].ToString());
                    double va = ((dv1 + dv2) / (dv1 + dv2 + dv3)) * 100;

                    workRow["value"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "5") //失業率
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = d1.Rows[i]["MONTH"];
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString());
                    double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString());
                    double va = (dv2 / (dv1 + dv2)) * 100;

                    workRow["value"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "4") //失業週數
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = d1.Rows[i]["MONTH"];
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString());
                    double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString());
                    double va = dv2 / dv1;

                    workRow["value"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "11") // 勞動力低度運用指標
            {
                string subtype = context.Request["subtype"] as string;

                DataTable d1 = table[0]; // PEP
                DataTable d2 = table[1]; // SFU
                DataTable d3 = table[2]; // TRU
                DataTable d4 = table[3]; // PLF

                if (subtype == "1") // SFU
                {
                    for (int i = 0; i < d2.Rows.Count; i++)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"].ToString();
                        workRow["MONTH"] = d2.Rows[i]["MONTH"].ToString();
                        workRow["STATID"] = d2.Rows[i]["STATID"].ToString();

                        double dv1 = Convert.ToDouble(d2.Rows[i]["value"].ToString());
                        double va = dv1;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
                else if (subtype == "2") // TRU
                {
                    for (int i = 0; i < d3.Rows.Count; i++)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d3.Rows[i]["YEAR"].ToString();
                        workRow["MONTH"] = d3.Rows[i]["MONTH"].ToString();
                        workRow["STATID"] = d3.Rows[i]["STATID"].ToString();

                        double dv1 = Convert.ToDouble(d3.Rows[i]["value"].ToString());
                        double va = dv1;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
                else if (subtype == "3") // PLF
                {
                    for (int i = 0; i < d4.Rows.Count; i++)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d4.Rows[i]["YEAR"].ToString();
                        workRow["MONTH"] = d4.Rows[i]["MONTH"].ToString();
                        workRow["STATID"] = d4.Rows[i]["STATID"].ToString();

                        double dv1 = Convert.ToDouble(d4.Rows[i]["value"].ToString());
                        double va = dv1;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
                else if (subtype == "4")
                {
                    for (int i = 0; i < d2.Rows.Count; i++)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"].ToString();
                        workRow["MONTH"] = d2.Rows[i]["MONTH"].ToString();
                        workRow["STATID"] = d2.Rows[i]["STATID"].ToString();

                        double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString());
                        double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString());
                        double va = dv2 / (dv1 + dv2) * 100;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
                else if (subtype == "5")
                {
                    for (int i = 0; i < d2.Rows.Count; i++)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"].ToString();
                        workRow["MONTH"] = d2.Rows[i]["MONTH"].ToString();
                        workRow["STATID"] = d2.Rows[i]["STATID"].ToString();

                        double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString()); // PEP
                        double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString()); // SFU
                        double dv3 = Convert.ToDouble(d3.Rows[i]["value"].ToString()); // TRU
                        double va = (dv2 + dv3) / (dv1 + dv2) * 100;

                        int y = Convert.ToInt32(workRow["YEAR"]) - 1911;
                        int m = Convert.ToInt32(workRow["MONTH"]);
                        if (y == 113 && m <= 5)
                            va = -999999;
                        else if (y < 113)
                            va = -999999;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
                else if (subtype == "6")
                {
                    for (int i = 0; i < d2.Rows.Count; i++)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"].ToString();
                        workRow["MONTH"] = d2.Rows[i]["MONTH"].ToString();
                        workRow["STATID"] = d2.Rows[i]["STATID"].ToString();

                        double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString()); // PEP
                        double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString()); // SFU
                        double dv4 = Convert.ToDouble(d4.Rows[i]["value"].ToString()); // PLF
                        double va = (dv2 + dv4) / (dv1 + dv2 + dv4) * 100;

                        int y = Convert.ToInt32(workRow["YEAR"]) - 1911;
                        int m = Convert.ToInt32(workRow["MONTH"]);
                        if (y == 113 && m <= 5)
                            va = -999999;
                        else if (y < 113)
                            va = -999999;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
                else if (subtype == "7")
                {
                    for (int i = 0; i < d2.Rows.Count; i++)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d2.Rows[i]["YEAR"].ToString();
                        workRow["MONTH"] = d2.Rows[i]["MONTH"].ToString();
                        workRow["STATID"] = d2.Rows[i]["STATID"].ToString();

                        double dv1 = Convert.ToDouble(d1.Rows[i]["value"].ToString()); // PEP
                        double dv2 = Convert.ToDouble(d2.Rows[i]["value"].ToString()); // SFU
                        double dv3 = Convert.ToDouble(d3.Rows[i]["value"].ToString()); // TRU
                        double dv4 = Convert.ToDouble(d4.Rows[i]["value"].ToString()); // PLF
                        double va = (dv2 + dv3 + dv4) / (dv1 + dv2 + dv4) * 100;

                        int y = Convert.ToInt32(workRow["YEAR"]) - 1911;
                        int m = Convert.ToInt32(workRow["MONTH"]);
                        if (y == 113 && m <= 5)
                            va = -999999;
                        else if (y < 113)
                            va = -999999;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
            }
        }

        return data;
    }

    //統計值
    public void SetBaseStatistics1(HttpContext context, DataTable tar, string iclasses, List<listitem> listitem, string output, Dictionary<string, decimal> data2)
    {
        string classes = cDictionary(iclasses);
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string xstring = context.Request["sex"] as string;
        string subtype = context.Request["subtype"] as string;

        bool hasp = output.IndexOf("P") != -1 ? true : false;
        bool hast = output.IndexOf("T") != -1 ? true : false;
        bool hasd1 = output.IndexOf("D1") != -1 ? true : false;
        bool hasd2 = output.IndexOf("D2") != -1 ? true : false;

        for (int i = 0; i < tar.Rows.Count; i++)
        {
            string y = tar.Rows[i]["YEAR"].ToString(); //有抓比設定年份早一年需跳過

            int rocy = Convert.ToInt32(y);
            rocy = rocy - 1911;
            string m = tar.Rows[i]["MONTH"].ToString();
            string d = "";
            if (m != "-")
                d = rocy + "年" + m;
            else
                d = rocy + "年";

            if (cycle == 4 || cycle == 5)
                d += "月";

            double va = Convert.ToDouble(tar.Rows[i]["value"].ToString());

            if (hast == true)
            {
                listitem tmp = new listitem();
                tmp.m = "總計";
                tmp.c = classes;
                tmp.st = "統計值";

                tmp.d = d;
                tmp.l = "1";

                tmp.v = va;

                if (tmp.v != -999999)
                    tmp.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)tmp.v, 1000);

                tmp.st += " (千人)";

                if (classes == "勞動力低度運用指標" && (subtype == "2" || subtype == "3"))
                    tmp.v = CheckHideValue2("LU", tmp.v, rocy.ToString(), m);
                else
                    tmp.v = CheckHideValue(classes, tmp.v, rocy.ToString());

                tmp.v = CheckDashValue(tmp.v);

                string statid = tar.Rows[i]["STATID"].ToString();
                bool add = false;
                if (statid.IndexOf('T', 4) != -1 && xstring.IndexOf('T') != -1)
                {
                    tmp.s = "總計";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('M', 4) != -1 && xstring.IndexOf('M') != -1)
                {
                    tmp.s = "男";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('F', 4) != -1 && xstring.IndexOf('F') != -1)
                {
                    tmp.s = "女";
                    listitem.Add(tmp);
                    add = true;
                }
                if (data2 != null && add == true)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}_{4}", tmp.m, tmp.d, tmp.c, tmp.s, tmp.st);
                    data2.Add(key, (decimal)tmp.v);
                }
            }
            if (hasp == true)
            {
                listitem tmp = new listitem();
                tmp.m = "總計";
                tmp.c = classes;
                tmp.st = "統計值";

                tmp.d = d;
                tmp.l = "1";

                tmp.v = va;

                if (tmp.v != -999999)
                    tmp.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)tmp.v, 1);

                tmp.st += " (人)";

                if (classes == "勞動力低度運用指標" && (subtype == "2" || subtype == "3"))
                    tmp.v = CheckHideValue2("LU", tmp.v, rocy.ToString(), m);
                else
                    tmp.v = CheckHideValue(classes, tmp.v, rocy.ToString());

                tmp.v = CheckDashValue(tmp.v);

                string statid = tar.Rows[i]["STATID"].ToString();
                bool add = false;
                if (statid.IndexOf('T', 4) != -1 && xstring.IndexOf('T') != -1)
                {
                    tmp.s = "總計";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('M', 4) != -1 && xstring.IndexOf('M') != -1)
                {
                    tmp.s = "男";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('F', 4) != -1 && xstring.IndexOf('F') != -1)
                {
                    tmp.s = "女";
                    listitem.Add(tmp);
                    add = true;
                }
                if (data2 != null && add == true)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}_{4}", tmp.m, tmp.d, tmp.c, tmp.s, tmp.st);
                    data2.Add(key, (decimal)tmp.v);
                }
            }
            if (hasd2 == true)
            {
                listitem tmp = new listitem();
                tmp.m = "總計";
                tmp.c = classes;
                tmp.st = "統計值";

                tmp.d = d;
                tmp.l = "1";

                tmp.v = va;

                if (tmp.v != -999999)
                    tmp.v = (double)ComputeMod.ComputeWeekPercent((decimal)tmp.v, 1, 2);

                tmp.st += "-小數2位 (%)";
                if (classes == "失業週數")
                    tmp.st = "統計值-小數2位";

                if (classes == "勞動力低度運用指標" && (subtype == "5" || subtype == "6" || subtype == "7"))
                    tmp.v = CheckHideValue2("LU", tmp.v, rocy.ToString(), m);
                else
                    tmp.v = CheckHideValue(classes, tmp.v, rocy.ToString());

                tmp.v = CheckDashValue(tmp.v);

                string statid = tar.Rows[i]["STATID"].ToString();
                bool add = false;
                if (statid.IndexOf('T', 4) != -1 && xstring.IndexOf('T') != -1)
                {
                    tmp.s = "總計";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('M', 4) != -1 && xstring.IndexOf('M') != -1)
                {
                    tmp.s = "男";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('F', 4) != -1 && xstring.IndexOf('F') != -1)
                {
                    tmp.s = "女";
                    listitem.Add(tmp);
                    add = true;
                }
                if (data2 != null && add == true)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}_{4}", tmp.m, tmp.d, tmp.c, tmp.s, tmp.st);
                    data2.Add(key, (decimal)tmp.v);
                }
            }
            if (hasd1 == true)
            {
                listitem tmp = new listitem();
                tmp.m = "總計";
                tmp.c = classes;
                tmp.st = "統計值";

                tmp.d = d;
                tmp.l = "1";

                tmp.v = va;

                if (tmp.v != -999999)
                    tmp.v = (double)ComputeMod.ComputeWeekPercent((decimal)tmp.v, 1, 1);

                tmp.st += "-小數1位 (%)";
                if (classes == "失業週數")
                    tmp.st = "統計值-小數1位";

                if (classes == "勞動力低度運用指標" && (subtype == "5" || subtype == "6" || subtype == "7"))
                    tmp.v = CheckHideValue2("LU", tmp.v, rocy.ToString(), m);
                else
                    tmp.v = CheckHideValue(classes, tmp.v, rocy.ToString());

                tmp.v = CheckDashValue(tmp.v);

                string statid = tar.Rows[i]["STATID"].ToString();
                bool add = false;
                if (statid.IndexOf('T', 4) != -1 && xstring.IndexOf('T') != -1)
                {
                    tmp.s = "總計";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('M', 4) != -1 && xstring.IndexOf('M') != -1)
                {
                    tmp.s = "男";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('F', 4) != -1 && xstring.IndexOf('F') != -1)
                {
                    tmp.s = "女";
                    listitem.Add(tmp);
                    add = true;
                }
                if (data2 != null && add == true)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}_{4}", tmp.m, tmp.d, tmp.c, tmp.s, tmp.st);
                    data2.Add(key, (decimal)tmp.v);
                }
            }
        }
    }

    //結構比
    public void SetBaseStatistics2(HttpContext context, DataTable tb, string iclasses, List<listitem> listitem, Dictionary<string, decimal> data2)
    {
        string classes = cDictionary(iclasses);
        string xstring = context.Request["sex"] as string;
        string smonth = context.Request["smonth"] as string;
        string[] sex = xstring.Split(',');
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        List<string> tlist = Dictionary(context);

        List<DataTable> cdts = new List<DataTable>();
        cdts.Add(tb);
        if (cycle == 1)
            cdts = computeTableYear2(context, cdts, iclasses, false);
        else if (cycle == 2)
            cdts = computeTableHalfYear2(context, cdts, iclasses, false);
        else if (cycle == 3)
            cdts = computeTableSeason2(context, cdts, iclasses, false);
        else if (cycle == 5)
        {
            for (int i = 0; i < cdts.Count; i++)
            {
                cdts[i] = cdts[i].Select("MONTH='" + smonth + "'").CopyToDataTable();
            }
        }
        else if (cycle == 6)
        {
            int iavgmonth = Convert.ToInt32(smonth);
            cdts = computeTableSumAvg2(context, cdts, classes, false, iavgmonth);
        }

        DataTable tar = cdts[0];

        DataView dv = tar.DefaultView;
        DataTable dtd = dv.ToTable(true, "STATID");

        string fid = dtd.Rows[0]["STATID"].ToString();
        string mid = dtd.Rows[1]["STATID"].ToString();

        DataRow[] mdr = tar.Select("STATID = '" + mid + "'");
        DataRow[] fdr = tar.Select("STATID = '" + fid + "'");

        for (int i = 0; i < mdr.Length; i++)
        {
            decimal mv = Convert.ToDecimal(mdr[i]["value"].ToString());
            decimal fv = Convert.ToDecimal(fdr[i]["value"].ToString());

            decimal total = mv + fv;

            decimal tvs = ComputeMod.ComputeAvgPercent(total, total, 2);
            decimal mvs = ComputeMod.ComputeAvgPercent(mv, total, 2);
            decimal fvs = ComputeMod.ComputeAvgPercent(fv, total, 2);

            string y = (Convert.ToInt16(mdr[i]["YEAR"].ToString()) - 1911).ToString();
            string m = mdr[i]["MONTH"].ToString();

            string d = "";
            if (m != "-")
                d = y + "年" + m;
            else
                d = y + "年";

            if (cycle == 4 || cycle == 5)
                d += "月";

            for (int k = 0; k < sex.Length; k++)
            {
                if (sex[k] == "M")
                {
                    listitem lm = new listitem()
                    {
                        m = "總計",
                        c = classes,
                        s = "男",
                        d = d,
                        st = "結構比 (%)",
                        l = "1",
                        v = (double)mvs
                    };
                    listitem.Add(lm);
                    if (data2 != null)
                    {
                        string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                        data2.Add(key, (decimal)lm.v);
                    }
                }
                else if (sex[k] == "F")
                {
                    listitem lf = new listitem()
                    {
                        m = "總計",
                        c = classes,
                        s = "女",
                        d = d,
                        st = "結構比 (%)",
                        l = "1",
                        v = (double)fvs
                    };
                    listitem.Add(lf);
                    if (data2 != null)
                    {
                        string key = string.Format("{0}_{1}_{2}_{3}_{4}", lf.m, lf.d, lf.c, lf.s, lf.st);
                        data2.Add(key, (decimal)lf.v);
                    }
                }
                else if (sex[k] == "T")
                {
                    listitem lt = new listitem()
                    {
                        m = "總計",
                        c = classes,
                        s = "總計",
                        d = d,
                        st = "結構比 (%)",
                        l = "1",
                        v = (double)tvs
                    };
                    listitem.Add(lt);
                    if (data2 != null)
                    {
                        string key = string.Format("{0}_{1}_{2}_{3}_{4}", lt.m, lt.d, lt.c, lt.s, lt.st);
                        data2.Add(key, (decimal)lt.v);
                    }
                }
            }
        }
    }

    //統計值-LayOut
    public void SetLayOutStatistics1(HttpContext context, DataTable tar, string iclasses, List<listitem> listitem, string[] layouts, DataTable code, string output, string dcs, Dictionary<string, decimal> data2)
    {
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');
        string classes = cDictionary(iclasses);
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string cclasses = context.Request["classes"] as string;

        bool hasp = output.IndexOf("P") != -1 ? true : false;
        bool hast = output.IndexOf("T") != -1 ? true : false;
        bool hasd1 = output.IndexOf("D1") != -1 ? true : false;
        bool hasd2 = output.IndexOf("D2") != -1 ? true : false;
        bool hass = output.IndexOf("S") != -1 ? true : false;

        string subtype = context.Request["subtype"] as string;

        List<double> totalvalue = new List<double>();
        List<double> totalvalueM = new List<double>();
        List<double> totalvalueF = new List<double>();
        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');
            List<string> calcodes = null;
            calcodes = setMultiCodes(dcs, cals, classes);

            List<DataTable> dsm = new List<DataTable>();
            List<DataTable> dsf = new List<DataTable>();

            int tablecount = 0;
            for (int j = 0; j < calcodes.Count; j++)
            {
                DataRow[] dm = tar.Select("STATID like '%M" + calcodes[j] + "%'");
                if (dm.Length > 0)
                {
                    DataTable dt = dm.CopyToDataTable();
                    dsm.Add(dt);
                    tablecount = dm.Length;
                }

                DataRow[] df = tar.Select("STATID like '%F" + calcodes[j] + "%'");
                if (df.Length > 0)
                {
                    DataTable dt = df.CopyToDataTable();
                    dsf.Add(dt);
                    tablecount = df.Length;
                }
            }
            bool hasT = false;
            if (ssex.IndexOf("T") != -1)
                hasT = true;

            if (hasT)
            {
                for (int j = 0; j < tablecount; j++)
                {
                    string y = dsm[0].Rows[j]["YEAR"].ToString();
                    string m = dsm[0].Rows[j]["MONTH"].ToString();
                    string d = "";

                    double value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        double dm = Convert.ToDouble(dsm[k].Rows[j]["value"].ToString());
                        double df = Convert.ToDouble(dsf[k].Rows[j]["value"].ToString());

                        if (Double.IsNaN(dm))
                            dm = 0;
                        if (Double.IsNaN(df))
                            df = 0;

                        value += dm;
                        value += df;
                    }

                    string dy = (Convert.ToInt16(y) - 1911).ToString();
                    if (m != "-")
                        d = dy + "年" + m;
                    else
                        d = dy + '年';

                    if (cycle == 4 || cycle == 5)
                        d += "月";

                    if (hast)
                    {
                        listitem lm = new listitem();
                        lm.v = value;
                        if (cycle == 1)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                            if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                            if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 4 || cycle == 5)
                        {
                            if (lm.v == 0)
                                lm.v = -999999;
                        }
                        else if (cycle == 6)
                        {
                            int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                            lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }

                        lm.m = dcs;

                        lm.c = des;
                        lm.l = lvl;

                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "統計值";

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)lm.v, 1000);

                        lm.st += " (千人)";

                        if (classes == "勞動力低度運用指標" && (subtype == "2" || subtype == "3"))
                            lm.v = CheckHideValue2("LU", lm.v, dy, m);
                        else
                            lm.v = CheckHideValue(classes, lm.v, dy);

                        lm.v = CheckDashValue(lm.v);

                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                            data2.Add(key, (decimal)lm.v);
                        }
                    }
                    if (hasp)
                    {
                        listitem lm = new listitem();
                        lm.v = value;
                        if (cycle == 1)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                            if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                            if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 4 || cycle == 5)
                        {
                            if (lm.v == 0)
                                lm.v = -999999;
                        }
                        else if (cycle == 6)
                        {
                            int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                            lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }

                        lm.m = dcs;

                        lm.c = des;
                        lm.l = lvl;

                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "統計值";

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)lm.v, 1);

                        lm.st += " (人)";

                        if (classes == "勞動力低度運用指標" && (subtype == "2" || subtype == "3"))
                            lm.v = CheckHideValue2("LU", lm.v, dy, m);
                        else
                            lm.v = CheckHideValue(classes, lm.v, dy);

                        lm.v = CheckDashValue(lm.v);

                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                            data2.Add(key, (decimal)lm.v);
                        }
                    }
                    if (hasd2)
                    {
                        listitem lm = new listitem();
                        lm.v = value;
                        if (cycle == 1)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                            if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                            if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 4 || cycle == 5)
                        {
                            if (lm.v == 0)
                                lm.v = -999999;
                        }
                        else if (cycle == 6)
                        {
                            int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                            lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }

                        lm.m = dcs;

                        lm.c = des;
                        lm.l = lvl;

                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "統計值";

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)lm.v, 1, 2);

                        lm.st += "-小數2位 (%)";

                        if (classes == "失業週數")
                            lm.st = "統計值-小數2位";

                        lm.v = CheckHideValue(des, lm.v, dy);
                        lm.v = CheckDashValue(lm.v);

                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                            data2.Add(key, (decimal)lm.v);
                        }
                    }
                    if (hasd1)
                    {
                        listitem lm = new listitem();
                        lm.v = value;
                        if (cycle == 1)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                            if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                            if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 4 || cycle == 5)
                        {
                            if (lm.v == 0)
                                lm.v = -999999;
                        }
                        else if (cycle == 6)
                        {
                            int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                            lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }

                        lm.m = dcs;

                        lm.c = des;
                        lm.l = lvl;

                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "統計值";

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)lm.v, 1, 1);

                        lm.st += "-小數1位 (%)";

                        if (classes == "失業週數")
                            lm.st = "統計值-小數1位";

                        lm.v = CheckHideValue(des, lm.v, dy);
                        lm.v = CheckDashValue(lm.v);

                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                            data2.Add(key, (decimal)lm.v);
                        }
                    }
                    if (hass)
                    {
                        listitem lm = new listitem();
                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;

                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "結構比 (%)";

                        if (des == "總計")
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)value, (decimal)value, 2);
                            totalvalue.Add(value);
                        }
                        else
                        {
                            double v = (double)ComputeMod.ComputeAvgPercent((decimal)value, (decimal)totalvalue[j], 2);
                            lm.v = v;
                        }

                        if (cycle == 1 || cycle == 6)
                        {
                            if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                lm.v = -999999;
                        }

                        lm.v = CheckHideValue(des, lm.v, dy);
                        lm.v = CheckDashValue(lm.v);
                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                            data2.Add(key, (decimal)lm.v);
                        }
                    }
                }
            }
            if (ssex.IndexOf('M') != -1)
            {
                if (dsm.Count > 0)
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = dsm[0].Rows[j]["YEAR"].ToString();
                        string m = dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double value = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            double dm = Convert.ToDouble(dsm[k].Rows[j]["value"].ToString());
                            if (Double.IsNaN(dm))
                                dm = 0;

                            value += dm;
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hast)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 4 || cycle == 5)
                            {
                                if (lm.v == 0)
                                    lm.v = -999999;
                            }
                            else if (cycle == 6)
                            {
                                int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                                lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)lm.v, 1000);

                            lm.st += " (千人)";

                            if (classes == "勞動力低度運用指標" && (subtype == "2" || subtype == "3"))
                                lm.v = CheckHideValue2("LU", lm.v, dy, m);
                            else
                                lm.v = CheckHideValue(classes, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasp)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 4 || cycle == 5)
                            {
                                if (lm.v == 0)
                                    lm.v = -999999;
                            }
                            else if (cycle == 6)
                            {
                                int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                                lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)lm.v, 1);

                            lm.st += " (人)";

                            if (classes == "勞動力低度運用指標" && (subtype == "2" || subtype == "3"))
                                lm.v = CheckHideValue2("LU", lm.v, dy, m);
                            else
                                lm.v = CheckHideValue(classes, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 4 || cycle == 5)
                            {
                                if (lm.v == 0)
                                    lm.v = -999999;
                            }
                            else if (cycle == 6)
                            {
                                int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                                lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)lm.v, 1, 2);

                            lm.st += "-小數2位 (%)";
                            if (classes == "失業週數")
                                lm.st = "統計值-小數2位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 4 || cycle == 5)
                            {
                                if (lm.v == 0)
                                    lm.v = -999999;
                            }
                            else if (cycle == 6)
                            {
                                int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                                lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)lm.v, 1, 1);

                            lm.st += "-小數1位 (%)";

                            if (classes == "失業週數")
                                lm.st = "統計值-小數1位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hass)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "結構比 (%)";
                            if (des == "總計")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)value, (decimal)value, 2);
                                totalvalueM.Add(value);
                            }
                            else
                            {
                                double v = (double)ComputeMod.ComputeAvgPercent((decimal)value, (decimal)totalvalueM[j], 2);
                                lm.v = v;
                            }

                            if (cycle == 1 || cycle == 6)
                            {
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
            }

            if (ssex.IndexOf('F') != -1)
            {
                if (dsf.Count > 0)
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = dsf[0].Rows[j]["YEAR"].ToString();
                        string m = dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double value = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            double dm = Convert.ToDouble(dsf[k].Rows[j]["value"].ToString());
                            if (Double.IsNaN(dm))
                                dm = 0;

                            value += Convert.ToDouble(dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hast)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 4 || cycle == 5)
                            {
                                if (lm.v == 0)
                                    lm.v = -999999;
                            }
                            else if (cycle == 6)
                            {
                                int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                                lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }

                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)lm.v, 1000);

                            lm.st += " (千人)";

                            if (classes == "勞動力低度運用指標" && (subtype == "2" || subtype == "3"))
                                lm.v = CheckHideValue2("LU", lm.v, dy, m);
                            else
                                lm.v = CheckHideValue(classes, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasp)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 4 || cycle == 5)
                            {
                                if (lm.v == 0)
                                    lm.v = -999999;
                            }
                            else if (cycle == 6)
                            {
                                int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                                lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)lm.v, 1);

                            lm.st += " (人)";

                            if (classes == "勞動力低度運用指標" && (subtype == "2" || subtype == "3"))
                                lm.v = CheckHideValue2("LU", lm.v, dy, m);
                            else
                                lm.v = CheckHideValue(classes, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 4 || cycle == 5)
                            {
                                if (lm.v == 0)
                                    lm.v = -999999;
                            }
                            else if (cycle == 6)
                            {
                                int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                                lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)lm.v, 1, 2);

                            lm.st += "-小數2位 (%)";
                            if (classes == "失業週數")
                                lm.st = "統計值-小數2位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 4 || cycle == 5)
                            {
                                if (lm.v == 0)
                                    lm.v = -999999;
                            }
                            else if (cycle == 6)
                            {
                                int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                                lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }

                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)lm.v, 1, 1);

                            lm.st += "-小數1位 (%)";
                            if (classes == "失業週數")
                                lm.st = "統計值-小數1位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hass)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "結構比 (%)";
                            if (des == "總計")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)value, (decimal)value, 2);
                                totalvalueF.Add(value);
                            }
                            else
                            {
                                double v = (double)ComputeMod.ComputeAvgPercent((decimal)value, (decimal)totalvalueF[j], 2);
                                lm.v = v;
                            }

                            if (cycle == 1 || cycle == 6)
                            {
                                if ((dy == "95") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 2)
                            {
                                if ((d == "95年上半年") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }
                            else if (cycle == 3)
                            {
                                if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (des == "傷病或健康不良" || des == "賦閒"))
                                    lm.v = -999999;
                            }

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
            }
        }
    }

    public string getSubLayOutString(string code, string dcs, string ver)
    {
        string d = "";
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM CODE  
                        WHERE CAT = @classes AND CODE = @code AND VER = @ver AND INTERNAL = 1 ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@classes", dcs),
                    new SqlParameter("@code", code),
                    new SqlParameter("@ver", ver)
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

                d = ds.Tables[0].Rows[0]["DES_ZH"].ToString();
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
        return d;
    }

    //統計值-SecondLayOut
    public void SetSecondLayOutStatistics1(HttpContext context, List<DataTable> tar, string iclasses, List<listitem> listitem, string[] layouts, DataTable code, string output, string dcs, string dcs2, List<List<string>> lcs, rdata rdata, Dictionary<string, decimal> data2)
    {
        string classes = cDictionary(iclasses);
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string subtype2 = context.Request["subtype2"] as string; //分類下拉選單
        string[] asubtype2 = subtype2.Split(',');
        List<string> roctype = new List<string>();

        string cclasses = context.Request["classes"] as string;
        string class2 = context.Request["classes2"] as string;
        string class3 = context.Request["classes3"] as string;

        string subver = "0";
        if (dcs2 == "行業")
            subver = GetLayOutIndVer(context);
        else if (dcs2 == "職業")
            subver = GetLayOutOccVer(context);

        bool hasp = output.IndexOf("P") != -1 ? true : false;
        bool hast = output.IndexOf("T") != -1 ? true : false;
        bool hass = output.IndexOf("S") != -1 ? true : false;

        for (int i = 0; i < asubtype2.Length; i++)
        {
            string sf = getSubLayOutString(asubtype2[i], dcs2, subver);
            roctype.Add(sf);
        }

        rdata.subclasses = roctype;

        List<List<double>> ttary = new List<List<double>>();
        for (int i = 0; i < layouts.Length; i++)
        {
            for (int p = 0; p < lcs.Count; p++)
            {
                DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
                string cal = cd[0]["CAL_ITEM"].ToString();
                string des = cd[0]["DES_ZH"].ToString();
                string lvl = cd[0]["LVL"].ToString();

                if (des == "總計" && hass == true)
                {
                    List<double> totalvalue = new List<double>();
                    ttary.Add(totalvalue);
                }

                if (cal == "NULL")
                {
                    cal = layouts[i];
                }

                string[] cals = cal.Split(',');
                List<string> calcodes = setMultiCodes2(dcs, cals, lcs[p]);

                List<DataRow[]> dsm = new List<DataRow[]>();

                int tablecount = 0;
                for (int j = 0; j < calcodes.Count; j++)
                {
                    DataRow[] dm = tar[p].Select("STATID like '%T" + calcodes[j] + "%'");
                    if (dm.Length > 0)
                    {
                        dsm.Add(dm);
                        tablecount = dm.Length;
                    }
                }

                for (int j = 0; j < tablecount; j++)
                {
                    string y = dsm[0][j]["YEAR"].ToString();
                    string m = dsm[0][j]["MONTH"].ToString();
                    string d = "";
                    double value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        double dm = Convert.ToDouble(dsm[k][j]["value"].ToString());
                        if (Double.IsNaN(dm))
                            dm = 0;

                        value += dm;
                    }

                    string dy = (Convert.ToInt16(y) - 1911).ToString();
                    if (m != "-")
                        d = dy + "年" + m;
                    else
                        d = dy + '年';

                    if (cycle == 4 || cycle == 5)
                        d += "月";

                    if (hasp)
                    {
                        listitem lm = new listitem();
                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;

                        lm.d = d;
                        lm.s = roctype[p];
                        lm.st = "統計值";
                        lm.v = value;

                        if (cycle == 1)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                            if ((dy == "80") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                            if ((dy == "95") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                            if ((d == "80年上半年") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                            if ((d == "95年上半年") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                            if ((d == "80年第1季") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                            if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 4 || cycle == 5)
                        {
                            if (lm.v == 0)
                            {
                                lm.v = -999999;
                            }
                        }
                        else if (cycle == 6)
                        {
                            int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                            lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                            if ((dy == "80") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                            if ((dy == "95") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)lm.v, 1);

                        lm.st += " (人)";

                        lm.v = CheckHideValue(des, lm.v, dy);
                        lm.v = CheckDashValue(lm.v);

                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                            data2.Add(key, (decimal)lm.v);
                        }
                    }
                    if (hast)
                    {
                        listitem lm = new listitem();
                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;

                        lm.d = d;
                        lm.s = roctype[p];
                        lm.st = "統計值";
                        lm.v = value;

                        if (cycle == 1)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(12, (decimal)lm.v, 1);
                            if ((dy == "80") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                            if ((dy == "95") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(6, (decimal)lm.v, 1);
                            if ((d == "80年上半年") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                            if ((d == "95年上半年") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPepole(3, (decimal)lm.v, 1);
                            if ((d == "80年第1季") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                            if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 4 || cycle == 5)
                        {
                            if (lm.v == 0)
                            {
                                lm.v = -999999;
                            }
                        }
                        else if (cycle == 6)
                        {
                            int smonth = Convert.ToInt32(context.Request["smonth"] as string);
                            lm.v = (double)ComputeMod.ComputeAvgPepole(smonth, (decimal)lm.v, 1);
                            if ((dy == "80") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                            if ((dy == "95") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)lm.v, 1000);

                        lm.st += " (千人)";

                        lm.v = CheckHideValue(des, lm.v, dy);
                        lm.v = CheckDashValue(lm.v);

                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                            data2.Add(key, (decimal)lm.v);
                        }
                    }
                    if (hass)
                    {
                        listitem lm = new listitem();
                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;

                        lm.d = d;
                        lm.s = roctype[p];
                        lm.st = "結構比 (%)";

                        if (des == "總計")
                        {
                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)value, (decimal)value, 2);
                            ttary[p].Add(value);
                        }
                        else
                        {
                            double v = (double)ComputeMod.ComputeAvgPercent((decimal)value, (decimal)ttary[p][j], 2);
                            lm.v = v;
                        }

                        if (cycle == 1 || cycle == 6)
                        {
                            if ((dy == "80") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            if ((d == "80年上半年") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            if ((d == "80年第1季") && (class2 == "1" || class2 == "2" || class3 == "4" || class3 == "5"))
                                lm.v = -999999;
                        }

                        if (cycle == 1 || cycle == 6)
                        {
                            if ((dy == "95") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 2)
                        {
                            if ((d == "95年上半年") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }
                        else if (cycle == 3)
                        {
                            if ((d == "95年第1季" || d == "95年第2季") && (cclasses == "10") && (lm.s == "傷病或健康不良" || lm.s == "賦閒"))
                                lm.v = -999999;
                        }

                        lm.v = CheckHideValue(des, lm.v, dy);
                        lm.v = CheckDashValue(lm.v);
                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                            data2.Add(key, (decimal)lm.v);
                        }
                    }
                }
            }
        }
    }

    public class UtypeTables
    {
        public int index { get; set; }
        public List<DataTable> dsm { get; set; }
        public List<DataTable> dsf { get; set; }
        public int tablecount { get; set; }
    }
    //統計值-UTypeLayOut
    public void SetLayOutUTypeStatistics1(HttpContext context, List<DataTable> tar, string iclasses, List<listitem> listitem, string[] layouts, DataTable code, string output, string dcs, Dictionary<string, decimal> data2)
    {
        string ssex = context.Request["sex"] as string;
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string[] sexs = ssex.Split(',');
        string classes = cDictionary(iclasses);

        bool hast = output.IndexOf("T") != -1 ? true : false;
        bool hasp = output.IndexOf("P") != -1 ? true : false;
        bool hasd1 = output.IndexOf("D1") != -1 ? true : false;
        bool hasd2 = output.IndexOf("D2") != -1 ? true : false;

        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');

            List<UtypeTables> utables = new List<UtypeTables>();

            List<string> calcodes = setMultiCodes(dcs, cals, classes);
            int tablecount = 0;

            for (int k = 0; k < tar.Count; k++)
            {
                UtypeTables item = new UtypeTables();
                DataTable t = tar[k];

                List<DataTable> dsm = new List<DataTable>();
                List<DataTable> dsf = new List<DataTable>();

                for (int j = 0; j < calcodes.Count; j++)
                {
                    DataRow[] dm = t.Select("STATID like '%M" + calcodes[j] + "%'");
                    if (dm.Length > 0)
                    {
                        DataTable dt = dm.CopyToDataTable();
                        dsm.Add(dt);
                        tablecount = dm.Length;
                    }

                    DataRow[] df = t.Select("STATID like '%F" + calcodes[j] + "%'");
                    if (df.Length > 0)
                    {
                        DataTable dt = df.CopyToDataTable();
                        dsf.Add(dt);
                        tablecount = df.Length;
                    }
                }

                item.index = k;
                item.tablecount = tablecount;
                item.dsm = dsm;
                item.dsf = dsf;

                utables.Add(item);
            }

            bool hasT = false;
            if (ssex.IndexOf("T") != -1)
                hasT = true;

            if (hasT)
            {
                if (iclasses == "4")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pupvalue = 0;
                        double wouvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pupvalue += Convert.ToDouble(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                            wouvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                            wouvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)wouvalue, (decimal)pupvalue, 2);
                            lm.st += "-小數2位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)wouvalue, (decimal)pupvalue, 1);
                            lm.st += "-小數1位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "5")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDouble(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pepvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)pupvalue, (decimal)(pepvalue + pupvalue), 2);
                            lm.st += "-小數2位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)pupvalue, (decimal)(pepvalue + pupvalue), 1);
                            lm.st += "-小數1位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "6")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double pupvalue = 0;
                        double nlfvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDouble(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pepvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                            nlfvalue += Convert.ToDouble(utables[2].dsm[k].Rows[j]["value"].ToString());
                            nlfvalue += Convert.ToDouble(utables[2].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(pepvalue + pupvalue), (decimal)(pepvalue + pupvalue + nlfvalue), 2);
                            lm.st += "-小數2位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(pepvalue + pupvalue), (decimal)(pepvalue + pupvalue + nlfvalue), 1);
                            lm.st += "-小數1位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "11")
                {
                    string subtype = context.Request["subtype"] as string;

                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[1].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[1].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double sfuvalue = 0;
                        double truvalue = 0;
                        double plfvalue = 0;

                        for (int k = 0; k < utables[1].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDouble(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pepvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                            sfuvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                            sfuvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                            truvalue += Convert.ToDouble(utables[2].dsm[k].Rows[j]["value"].ToString());
                            truvalue += Convert.ToDouble(utables[2].dsf[k].Rows[j]["value"].ToString());
                            plfvalue += Convert.ToDouble(utables[3].dsm[k].Rows[j]["value"].ToString());
                            plfvalue += Convert.ToDouble(utables[3].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hast)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            if (subtype == "1")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(sfuvalue), 1000);
                            }
                            else if (subtype == "2")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(truvalue), 1000);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "3")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(plfvalue), 1000);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }

                            lm.st += " (千人)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasp)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            if (subtype == "1")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(sfuvalue), 1);
                            }
                            else if (subtype == "2")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(truvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "3")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }

                            lm.st += " (人)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            if (subtype == "4")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue(des, lm.v, dy);
                            }
                            else if (subtype == "5")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "6")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "7")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }

                            lm.st += "-小數2位 (%)";
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            if (subtype == "4")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue(des, lm.v, dy);
                            }
                            else if (subtype == "5")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "6")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "7")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            lm.st += "-小數1位 (%)";

                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
            }
            if (ssex.IndexOf('M') != -1)
            {
                if (iclasses == "4")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pupvalue = 0;
                        double wouvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pupvalue += Convert.ToDouble(utables[0].dsm[k].Rows[j]["value"].ToString());
                            wouvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)wouvalue, (decimal)pupvalue, 2);
                            lm.st += "-小數2位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)wouvalue, (decimal)pupvalue, 1);
                            lm.st += "-小數1位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "5")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDouble(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)pupvalue, (decimal)(pepvalue + pupvalue), 2);
                            lm.st += "-小數2位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)pupvalue, (decimal)(pepvalue + pupvalue), 1);
                            lm.st += "-小數1位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "6")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double pupvalue = 0;
                        double nlfvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDouble(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                            nlfvalue += Convert.ToDouble(utables[2].dsm[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(pepvalue + pupvalue), (decimal)(pepvalue + pupvalue + nlfvalue), 2);
                            lm.st += "-小數2位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(pepvalue + pupvalue), (decimal)(pepvalue + pupvalue + nlfvalue), 1);
                            lm.st += "-小數1位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "11")
                {
                    string subtype = context.Request["subtype"] as string;

                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[1].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[1].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double sfuvalue = 0;
                        double truvalue = 0;
                        double plfvalue = 0;

                        // 單獨處理PEP
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            for (int f = 0; f < utables[0].dsm[k].Rows.Count; f++)
                            {
                                if (y == utables[0].dsm[k].Rows[f]["YEAR"].ToString() && m == utables[0].dsm[k].Rows[f]["MONTH"].ToString())
                                {
                                    pepvalue += Convert.ToDouble(utables[0].dsm[k].Rows[j]["value"].ToString());
                                }
                            }
                        }

                        for (int k = 0; k < utables[1].dsm.Count; k++)
                        {
                            sfuvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                            truvalue += Convert.ToDouble(utables[2].dsm[k].Rows[j]["value"].ToString());
                            plfvalue += Convert.ToDouble(utables[3].dsm[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hast)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (subtype == "1")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(sfuvalue), 1000);
                            }
                            else if (subtype == "2")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(truvalue), 1000);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "3")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(plfvalue), 1000);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }

                            lm.st += " (千人)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasp)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (subtype == "1")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(sfuvalue), 1);
                            }
                            else if (subtype == "2")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(truvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "3")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }

                            lm.st += " (人)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (subtype == "4")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue(des, lm.v, dy);
                            }
                            else if (subtype == "5")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "6")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "7")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }

                            lm.st += "-小數2位 (%)";
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (subtype == "4")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue(des, lm.v, dy);
                            }
                            else if (subtype == "5")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "6")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "7")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            lm.st += "-小數1位 (%)";
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
            }

            if (ssex.IndexOf('F') != -1)
            {
                if (iclasses == "4")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pupvalue = 0;
                        double wouvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pupvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                            wouvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.v = wouvalue / pupvalue;
                            lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)(wouvalue), (decimal)(pupvalue), 2);
                            lm.st += "-小數2位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.v = wouvalue / pupvalue;
                            lm.v = (double)ComputeMod.ComputeWeekPercent((decimal)(wouvalue), (decimal)(pupvalue), 1);
                            lm.st += "-小數1位";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "5")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double pupvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(pupvalue), (decimal)(pepvalue + pupvalue), 2);
                            lm.st += "-小數2位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(pupvalue), (decimal)(pepvalue + pupvalue), 1);
                            lm.st += "-小數1位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "6")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double pupvalue = 0;
                        double nlfvalue = 0;

                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                            nlfvalue += Convert.ToDouble(utables[2].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(pepvalue + pupvalue), (decimal)(pepvalue + pupvalue + nlfvalue), 2);
                            lm.st += "-小數2位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(pepvalue + pupvalue), (decimal)(pepvalue + pupvalue + nlfvalue), 1);
                            lm.st += "-小數1位 (%)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "11")
                {
                    string subtype = context.Request["subtype"] as string;

                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[1].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[1].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        double pepvalue = 0;
                        double sfuvalue = 0;
                        double truvalue = 0;
                        double plfvalue = 0;

                        // 單獨處理PEP
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            for (int f = 0; f < utables[0].dsm[k].Rows.Count; f++)
                            {
                                if (y == utables[0].dsm[k].Rows[f]["YEAR"].ToString() && m == utables[0].dsm[k].Rows[f]["MONTH"].ToString())
                                {
                                    pepvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                                }
                            }
                        }
                        for (int k = 0; k < utables[1].dsm.Count; k++)
                        {
                            sfuvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                            truvalue += Convert.ToDouble(utables[2].dsf[k].Rows[j]["value"].ToString());
                            plfvalue += Convert.ToDouble(utables[3].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                            d = dy + "年" + m;
                        else
                            d = dy + '年';

                        if (cycle == 4 || cycle == 5)
                            d += "月";

                        if (hast)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (subtype == "1")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(sfuvalue), 1000);
                            }
                            else if (subtype == "2")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(truvalue), 1000);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "3")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(plfvalue), 1000);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }

                            lm.st += " (千人)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasp)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (subtype == "1")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(sfuvalue), 1);
                            }
                            else if (subtype == "2")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(truvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "3")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPepole(1, (decimal)(plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }

                            lm.st += " (人)";

                            lm.v = CheckHideValue(des, lm.v, dy);
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (subtype == "4")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue(des, lm.v, dy);
                            }
                            else if (subtype == "5")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "6")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "7")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            lm.st += "-小數2位 (%)";
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (subtype == "4")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue(des, lm.v, dy);
                            }
                            else if (subtype == "5")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "6")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            else if (subtype == "7")
                            {
                                lm.v = (double)ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m);
                            }
                            lm.st += "-小數1位 (%)";
                            lm.v = CheckDashValue(lm.v);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}", lm.m, lm.d, lm.c, lm.s, lm.st);
                                data2.Add(key, (decimal)lm.v);
                            }
                        }
                    }
                }
            }
        }
    }

    public List<DataTable> GetAgeTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();

        List<string> tlist = Dictionary(context);

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        for (int i = 0; i < tlist.Count; i++)
        {
            List<string> cs = new List<string>();
            for (int j = 0; j < sex.Length; j++)
            {
                for (int k = 0; k < layouts.Length; k++)
                {
                    string code = tlist[i] + sex[j] + layouts[k] + "00X0000000000000";
                    cs.Add(code);
                }
            }
            DataTable tmp = getTabelByCodes(context, cs, "NEW182A");
            dlist.Add(tmp);
        }

        return dlist;
    }

    public List<DataTable> GetEdtionTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();

        List<string> tlist = Dictionary(context);

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        for (int i = 0; i < tlist.Count; i++)
        {
            List<string> cs = new List<string>();
            for (int j = 0; j < sex.Length; j++)
            {
                for (int k = 0; k < layouts.Length; k++)
                {
                    if (tlist[i] == "SFU09" || tlist[i] == "TRU09" || tlist[i] == "PLF09")
                    {
                        string code = tlist[i] + sex[j] + "00" + layouts[k] + "X00000000000" + layouts[k];
                        cs.Add(code);
                    }
                    else
                    {
                        string code = tlist[i] + sex[j] + "00" + layouts[k] + "X0000000000000";
                        cs.Add(code);
                    }
                }
            }
            DataTable tmp = getTabelByCodes(context, cs, "NEW182A");
            dlist.Add(tmp);
        }

        return dlist;
    }

    public List<DataTable> GetIndTables(HttpContext context, string classes, string ver)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        string subtype = context.Request["subtype"] as string;
        string table = subtype == "5" ? "NEW182A" : "NEW172A";
        string source = ind8code;

        if (ver == "6")
        {
            table = "NEW69";
            source = ind6code;
        }
        else if (ver == "7")
        {
            table = "NEW84";
            source = ind7code;
        }

        List<DataTable> dlist = new List<DataTable>();

        string layoutstring = GetLayoutAllTable(classes, ver);
        string[] layouts = layoutstring.Split(',');

        List<string> cs = new List<string>();
        for (int j = 0; j < sex.Length; j++)
        {
            for (int k = 0; k < layouts.Length; k++)
            {
                string code = source + sex[j] + "0000X" + layouts[k] + "0000000000";
                cs.Add(code);
            }
        }
        DataTable tmp = getTabelByCodes(context, cs, table);
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetOCCTables(HttpContext context, string classes, string ver)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        string table = "NEW182A";
        string source = occ6code;
        if (ver == "5")
        {
            table = "NEW103";
            source = occ5code;
        }

        List<DataTable> dlist = new List<DataTable>();

        string layoutstring = GetLayoutAllTable(classes, ver);
        string[] layouts = layoutstring.Split(',');

        List<string> cs = new List<string>();
        for (int j = 0; j < sex.Length; j++)
        {
            for (int k = 0; k < layouts.Length; k++)
            {
                string code = source + sex[j] + "0000X000" + layouts[k] + "00000000";
                cs.Add(code);
            }
        }
        DataTable tmp = getTabelByCodes(context, cs, table);
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetCOWTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        List<string> cs = new List<string>();
        for (int j = 0; j < sex.Length; j++)
        {
            for (int k = 0; k < layouts.Length; k++)
            {
                string code = cowcode + sex[j] + "0000X00000" + layouts[k] + "000000";
                cs.Add(code);
            }
        }
        DataTable tmp = getTabelByCodes(context, cs, "NEW182A");
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetRONTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();

        List<string> tlist = Dictionary(context);

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        List<string> cs = new List<string>();
        for (int j = 0; j < sex.Length; j++)
        {
            for (int k = 0; k < layouts.Length; k++)
            {
                string code = roncode + sex[j] + "0000X000000000" + layouts[k] + "00";
                cs.Add(code);
            }
        }

        DataTable tmp = getTabelByCodes(context, cs, "NEW182A");
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetROUTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();
        List<string> tlist = Dictionary(context);

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        tlist[0] = roucode;
        for (int i = 0; i < tlist.Count; i++)
        {
            List<string> cs = new List<string>();
            for (int j = 0; j < sex.Length; j++)
            {
                for (int k = 0; k < layouts.Length; k++)
                {
                    string code = tlist[i] + sex[j] + "0000X0000000" + layouts[k] + "0000";
                    cs.Add(code);
                }
            }
            DataTable tmp = getTabelByCodes(context, cs, "NEW182A");
            dlist.Add(tmp);
        }

        return dlist;
    }

    public cstable GetAgeTables2(HttpContext context, string classes, string classes2, string[] subcode, string subtype)
    {
        cstable dlist = new cstable() {
            table = new List<DataTable>(),
            cs = new List<List<string>>()
        };

        List<string> tlist = Dictionary(context);

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');
        string table = "NEW182A";

        string dcs2 = getdcsclasses(classes2);
        for (int i = 0; i < subcode.Length; i++)
        {
            string sver = "0";
            if (classes2 == "1") //行業
            {
                sver = GetLayOutIndVer(context);
            }
            else if (classes2 == "2") //職業
            {
                sver = GetLayOutOccVer(context);
            }
            DataTable sctable = GetZoneCode(dcs2, subcode[i], sver);
            List<string> codes = new List<string>();
            if (sctable.Rows[0]["CAL_ITEM"].ToString() != "NULL")
            {
                string[] cal = sctable.Rows[0]["CAL_ITEM"].ToString().Split(',');
                for (int t = 0; t < cal.Length; t++)
                    codes.Add(cal[t]);
            }
            else
            {
                codes.Add(subcode[i]);
            }

            List<string> cs = new List<string>();
            List<string> lcs = new List<string>();
            for (int f = 0; f < codes.Count; f++)
            {
                for (int k = 0; k < layouts.Length; k++)
                {
                    string lcode = "";
                    string code = "";
                    if (classes2 == "1")
                    {
                        string tcode = ind8code;
                        if (subtype == "1")
                        {
                            table = "NEW69";
                            tcode = ind6code;
                        }
                        else if (subtype == "2")
                        {
                            table = "NEW84";
                            tcode = ind7code;
                        }
                        else if (subtype == "3" || subtype == "4")
                        {
                            table = "NEW172A";
                        }
                        else if (subtype == "5")
                        {
                            table = "NEW182A";
                        }

                        code = tcode + "T" + layouts[k] + "00X" + codes[f] + "0000000000";
                        lcode = layouts[k] + "00X" + codes[f] + "0000000000";
                    }
                    else if (classes2 == "2")
                    {
                        string tcode = occ6code;
                        if (subtype == "1" || subtype == "2" || subtype == "3")
                        {
                            table = "NEW103";
                            tcode = occ5code;
                        }
                        else if (subtype == "4")
                        {
                            table = "NEW172A";
                        }
                        else if (subtype == "5")
                        {
                            table = "NEW182A";
                        }
                        code = tcode + "T" + layouts[k] + "00X000" + codes[f] + "00000000";
                        lcode = layouts[k] + "00X000" + codes[f] + "00000000";
                    }
                    else if (classes2 == "3")
                    {
                        code = "COW04" + "T" + layouts[k] + "00X00000" + codes[f] + "000000";
                        lcode = layouts[k] + "00X00000" + codes[f] + "000000";
                    }
                    else if (classes2 == "4")
                    {
                        code = "ROU04" + "T" + layouts[k] + "00X0000000" + codes[f] + "0000";
                        lcode = layouts[k] + "00X0000000" + codes[f] + "0000";
                    }
                    else if (classes2 == "7")
                    {
                        code = "RON04" + "T" + layouts[k] + "00X000000000" + codes[f] + "00";
                        lcode = layouts[k] + "00X000000000" + codes[f] + "00";
                    }

                    cs.Add(code);
                    lcs.Add(lcode);
                }
            }
            DataTable tmp = getTabelByCodes(context, cs, table);
            dlist.table.Add(tmp);
            dlist.cs.Add(lcs);
        }
        return dlist;
    }

    public cstable GetEdtionTables2(HttpContext context, string classes, string classes2, string[] subcode, string subtype)
    {
        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        string table = "NEW182A";

        cstable dlist = new cstable() {
            table = new List<DataTable>(),
            cs = new List<List<string>>()
        };

        string dcs2 = getdcsclasses(classes2);
        for (int i = 0; i < subcode.Length; i++)
        {
            string sver = "0";
            if (classes2 == "1") //行業
            {
                sver = GetLayOutIndVer(context);
            }
            else if (classes2 == "2") //職業
            {
                sver = GetLayOutOccVer(context);
            }

            DataTable sctable = GetZoneCode(dcs2, subcode[i], sver);
            List<string> codes = new List<string>();

            if (sctable.Rows.Count > 0 && sctable.Rows[0]["CAL_ITEM"].ToString() != "NULL")
            {
                string[] cal = sctable.Rows[0]["CAL_ITEM"].ToString().Split(',');
                for (int t = 0; t < cal.Length; t++)
                    codes.Add(cal[t]);
            }
            else
            {
                codes.Add(subcode[i]);
            }

            List<string> cs = new List<string>();
            List<string> lcs = new List<string>();

            for (int f = 0; f < codes.Count; f++)
            {
                for (int k = 0; k < layouts.Length; k++)
                {
                    string code = "";
                    string lcode = "";
                    if (classes2 == "1")
                    {
                        string tcode = ind8code;
                        if (subtype == "1")
                        {
                            table = "NEW69";
                            tcode = ind6code;
                        }
                        else if (subtype == "2")
                        {
                            table = "NEW84";
                            tcode = ind7code;
                        }
                        else if (subtype == "3" || subtype == "4")
                        {
                            table = "NEW172A";
                        }
                        else if (subtype == "5")
                        {
                            table = "NEW182A";
                        }

                        code = tcode + "T" + "00" + layouts[k] + "X" + codes[f] + "0000000000";
                        lcode = "00" + layouts[k] + "X" + codes[f] + "0000000000";
                    }
                    else if (classes2 == "2")
                    {
                        string tcode = occ6code;
                        if (subtype == "1" || subtype == "2" || subtype == "3")
                        {
                            table = "NEW103";
                            tcode = occ5code;
                        }
                        else if (subtype == "4")
                        {
                            table = "NEW172A";
                        }
                        else if (subtype == "5")
                        {
                            table = "NEW182A";
                        }
                        code = tcode + "T" + "00" + layouts[k] + "X000" + codes[f] + "00000000";
                        lcode = "00" + layouts[k] + "X000" + codes[f] + "00000000";
                    }
                    else if (classes2 == "3")
                    {
                        code = "COW04" + "T" + "00" + layouts[k] + "X00000" + codes[f] + "000000";
                        lcode = "00" + layouts[k] + "X00000" + codes[f] + "000000";
                    }
                    else if (classes2 == "4")
                    {
                        code = "ROU04" + "T" + "00" + layouts[k] + "X0000000" + codes[f] + "0000";
                        lcode = "00" + layouts[k] + "X0000000" + codes[f] + "0000";
                    }
                    else if (classes2 == "7")
                    {
                        code = "RON04" + "T" + "00" + layouts[k] + "X000000000" + codes[f] + "00";
                        lcode = "00" + layouts[k] + "X000000000" + codes[f] + "00";
                    }

                    cs.Add(code);
                    lcs.Add(lcode);
                }
            }
            DataTable tmp = getTabelByCodes(context, cs, table);
            dlist.table.Add(tmp);
            dlist.cs.Add(lcs);
        }

        return dlist;
    }

    public cstable GetIndTables2(HttpContext context, string classes, string ver, string classes2, string[] subcode, string subtype)
    {
        string table = "NEW182A";
        string source = ind8code;
        string iver = GetLayOutIndVer(context);
        string sc = "04";
        if (ver == "6")
        {
            table = "NEW69";
            source = ind6code;
            sc = "01";
        }
        else if (ver == "7")
        {
            table = "NEW84";
            source = ind7code;
            sc = "02";
        }
        else if (ver == "8-10" && iver == "5")
        {
            table = "NEW103";
            source = "OCC03";
            sc = "03";
        }

        cstable dlist = new cstable() {
            table = new List<DataTable>(),
            cs = new List<List<string>>()
        };

        string layoutstring = GetLayoutAllTable(classes, ver);
        string[] layouts = layoutstring.Split(',');

        string dcs2 = getdcsclasses(classes2);
        for (int i = 0; i < subcode.Length; i++)
        {
            DataTable sctable = GetZoneCode(dcs2, subcode[i], "0");
            List<string> codes = new List<string>();
            if (sctable.Rows[0]["CAL_ITEM"].ToString() != "NULL")
            {
                string[] cal = sctable.Rows[0]["CAL_ITEM"].ToString().Split(',');
                for (int t = 0; t < cal.Length; t++)
                    codes.Add(cal[t]);
            }
            else
            {
                codes.Add(subcode[i]);
            }

            List<string> cs = new List<string>();
            List<string> lcs = new List<string>();
            for (int f = 0; f < codes.Count; f++)
            {
                for (int k = 0; k < layouts.Length; k++)
                {
                    string code = source + "T";
                    string lcode = "";

                    if (classes2 == "5")
                    {
                        code = "ROU" + sc + "T" + "0000X" + layouts[k] + "0000" + codes[f] + "0000";
                        lcode = "0000X" + layouts[k] + "0000" + codes[f] + "0000";
                    }
                    else if (classes2 == "6")
                    {
                        code = "IBU" + sc + "T" + "0000X" + layouts[k] + "00" + codes[f] + "000000";
                        lcode = "0000X" + layouts[k] + "00" + codes[f] + "000000";
                    }

                    cs.Add(code);
                    lcs.Add(lcode);
                }
            }
            DataTable tmp = getTabelByCodes(context, cs, table);
            dlist.table.Add(tmp);
            dlist.cs.Add(lcs);
        }
        return dlist;
    }

    public cstable GetOCCTables2(HttpContext context, string classes, string ver, string classes2, string[] subcode, string subtype)
    {
        string table = "NEW182A";
        string source = occ6code;
        string iver = GetLayOutIndVer(context);
        string sc = "04";

        if (iver == "6")
        {
            table = "NEW84";
            source = "OCC02";
            sc = "02";
        }
        else if (iver == "7")
        {
            table = "NEW84";
            source = "OCC02";
            sc = "02";
        }
        else if (iver == "8-10" && ver == "5")
        {
            table = "NEW103";
            source = "OCC03";
            sc = "03";
        }

        cstable dlist = new cstable() {
            table = new List<DataTable>(),
            cs = new List<List<string>>()
        };

        string layoutstring = GetLayoutAllTable(classes, ver);
        string[] layouts = layoutstring.Split(',');
        string dcs2 = getdcsclasses(classes2);
        for (int i = 0; i < subcode.Length; i++)
        {
            DataTable sctable = GetZoneCode(dcs2, subcode[i], "0");
            List<string> codes = new List<string>();
            if (sctable.Rows[0]["CAL_ITEM"].ToString() != "NULL")
            {
                string[] cal = sctable.Rows[0]["CAL_ITEM"].ToString().Split(',');
                for (int t = 0; t < cal.Length; t++)
                    codes.Add(cal[t]);
            }
            else
            {
                codes.Add(subcode[i]);
            }

            List<string> cs = new List<string>();
            List<string> lcs = new List<string>();

            for (int f = 0; f < codes.Count; f++)
            {
                for (int k = 0; k < layouts.Length; k++)
                {
                    string code = source + "T";
                    string lcode = "";

                    if (classes2 == "5")
                    {
                        code = "ROU" + sc + "T" + "0000X000" + layouts[k] + "00" + codes[f] + "0000";
                        lcode = "0000X000" + layouts[k] + "00" + codes[f] + "0000";
                    }
                    else if (classes2 == "6")
                    {
                        code = "IBU" + sc + "T" + "0000X000" + layouts[k] + codes[f] + "000000";
                        lcode = "0000X000" + layouts[k] + codes[f] + "000000";
                    }

                    lcs.Add(lcode);
                    cs.Add(code);
                }
            }

            DataTable tmp = getTabelByCodes(context, cs, table);
            dlist.table.Add(tmp);
            dlist.cs.Add(lcs);
        }
        return dlist;
    }

    public cstable GetCOWTables2(HttpContext context, string classes, string classes2, string[] subcode, string subtype)
    {
        cstable dlist = new cstable() {
            table = new List<DataTable>(),
            cs = new List<List<string>>()
        };

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');
        string dcs2 = getdcsclasses(classes2);

        for (int i = 0; i < subcode.Length; i++)
        {
            DataTable sctable = GetZoneCode(dcs2, subcode[i], "0");
            List<string> codes = new List<string>();
            if (sctable.Rows[0]["CAL_ITEM"].ToString() != "NULL")
            {
                string[] cal = sctable.Rows[0]["CAL_ITEM"].ToString().Split(',');
                for (int t = 0; t < cal.Length; t++)
                    codes.Add(cal[t]);
            }
            else
            {
                codes.Add(subcode[i]);
            }

            List<string> cs = new List<string>();
            List<string> lcs = new List<string>();
            for (int f = 0; f < codes.Count; f++)
            {
                for (int k = 0; k < layouts.Length; k++)
                {
                    string code = cowcode + "T";
                    string lcode = "";
                    if (classes2 == "5")
                    {
                        code = "ROU04" + "T" + "0000X00000" + layouts[k] + codes[f] + "0000";
                        lcode = "0000X00000" + layouts[k] + codes[f] + "0000";
                    }
                    cs.Add(code);
                    lcs.Add(lcode);
                }
            }
            DataTable tmp = getTabelByCodes(context, cs, "NEW182A");
            dlist.table.Add(tmp);
            dlist.cs.Add(lcs);
        }

        return dlist;
    }

    public string GetLayoutAllTable(string classes, string ver)
    {
        string data = "";

        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM LAYOUT 
                        WHERE CAT = @classes AND VER = @ver AND INTERNAL = 1 ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@classes", classes),
                    new SqlParameter("@ver", ver)
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

                if (ds.Tables[0].Rows.Count > 0)
                    data = ds.Tables[0].Rows[0]["COL_ORDER"].ToString();
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

        //取得總計Cols當作所需取的Table數量
        string[] dary = data.Split(',');
        string all = dary[0];

        DataTable code = GetCodeTable(classes, ver);
        DataRow ca = code.Select("CAT = '" + classes + "' AND CODE = '" + all + "'").FirstOrDefault();
        data = ca["CAL_ITEM"].ToString();

        return data;
    }

    public List<string> setMultiCodes(string classes, string[] codes, string subclasses)
    {
        List<string> cs = new List<string>();

        if (classes == "年齡")
        {
            for (int i = 0; i < codes.Length; i++)
            {
                cs.Add(codes[i] + "00X0000000000000");
            }
        }
        else if (classes == "教育程度")
        {
            for (int i = 0; i < codes.Length; i++)
            {
                cs.Add("00" + codes[i] + "X00000000000");
            }
        }
        else if (classes.IndexOf("行業") != -1)
        {
            for (int i = 0; i < codes.Length; i++)
            {
                cs.Add("0000X" + codes[i] + "0000000000");
            }
        }
        else if (classes.IndexOf("職業") != -1)
        {
            for (int i = 0; i < codes.Length; i++)
            {
                cs.Add("0000X000" + codes[i] + "00000000");
            }
        }
        else if (classes == "從業身分")
        {
            for (int i = 0; i < codes.Length; i++)
            {
                cs.Add("0000X00000" + codes[i] + "000000");
            }
        }
        else if (classes == "非勞動原因" || classes == "未參與勞動原因")
        {
            for (int i = 0; i < codes.Length; i++)
            {
                cs.Add("0000X000000000" + codes[i] + "00");
            }
        }
        else if (classes == "失業原因")
        {
            for (int i = 0; i < codes.Length; i++)
            {
                cs.Add("0000X0000000" + codes[i] + "0000");
            }
        }

        return cs;
    }

    public List<string> setMultiCodes2(string classes, string[] codes, List<string> lcs)
    {
        List<string> cs = new List<string>();

        if (classes == "年齡")
        {
            for (int j = 0; j < codes.Length; j++)
            {
                for (int i = 0; i < lcs.Count; i++)
                {
                    if (lcs[i].IndexOf(codes[j]) == 0)
                    {
                        string k = lcs[i];
                        cs.Add(k);
                    }
                }
            }
        }
        else if (classes == "教育程度")
        {
            for (int j = 0; j < codes.Length; j++)
            {
                for (int i = 0; i < lcs.Count; i++)
                {
                    if (lcs[i].IndexOf(codes[j]) == 2)
                    {
                        string k = lcs[i];
                        cs.Add(k);
                    }
                }
            }
        }
        else if (classes.IndexOf("行業") != -1)
        {
            for (int j = 0; j < codes.Length; j++)
            {
                for (int i = 0; i < lcs.Count; i++)
                {
                    if (lcs[i].IndexOf(codes[j]) == 5)
                    {
                        string k = lcs[i];
                        cs.Add(k);
                    }
                }
            }
        }
        else if (classes.IndexOf("職業") != -1)
        {
            for (int j = 0; j < codes.Length; j++)
            {
                for (int i = 0; i < lcs.Count; i++)
                {
                    if (lcs[i].IndexOf(codes[j]) == 8)
                    {
                        string k = lcs[i];
                        cs.Add(k);
                    }
                }
            }
        }
        else if (classes == "從業身分")
        {
            for (int j = 0; j < codes.Length; j++)
            {
                for (int i = 0; i < lcs.Count; i++)
                {
                    if (lcs[i].IndexOf(codes[j]) == 10)
                    {
                        string k = lcs[i];
                        cs.Add(k);
                    }
                }
            }
        }
        else if (classes == "非勞動原因" || classes == "未參與勞動原因")
        {
            for (int j = 0; j < codes.Length; j++)
            {
                for (int i = 0; i < lcs.Count; i++)
                {
                    if (lcs[i].IndexOf(codes[j]) == 14)
                    {
                        string k = lcs[i];
                        cs.Add(k);
                    }
                }
            }
        }
        else if (classes == "失業原因")
        {
            for (int j = 0; j < codes.Length; j++)
            {
                for (int i = 0; i < lcs.Count; i++)
                {
                    if (lcs[i].IndexOf(codes[j]) == 12)
                    {
                        string k = lcs[i];
                        cs.Add(k);
                    }
                }
            }
        }

        return cs;
    }

    public List<DataTable> GetBaseTablesForStructure(HttpContext context)
    {
        string[] sex = new[] { "M", "F" };
        List<DataTable> dlist = new List<DataTable>();

        List<string> tlist = Dictionary(context);

        for (int i = 0; i < tlist.Count; i++)
        {
            List<string> cs = new List<string>();
            for (int j = 0; j < sex.Length; j++)
            {
                string code = tlist[i] + sex[j] + "0000X0000000000000";
                cs.Add(code);
            }
            DataTable tmp = getTabelByCodes(context, cs, "NEW182A");
            dlist.Add(tmp);
        }

        return dlist;
    }

    public string GetLayouts(string classes, string ver)
    {
        string data = "";

        if (classes == "未參與勞動原因")
            classes = "非勞動原因";

        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM LAYOUT 
                        WHERE CAT = @classes AND VER = @ver AND INTERNAL = 1 ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@classes", classes),
                    new SqlParameter("@ver", ver)
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

                if (ds.Tables[0].Rows.Count > 0)
                    data = ds.Tables[0].Rows[0]["COL_ORDER"].ToString();
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

        return data;
    }

    public DataTable GetCodeTable(string CAT, string VER)
    {
        DataTable dt = new DataTable();

        if (CAT == "未參與勞動原因")
            CAT = "非勞動原因";

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM CODE WHERE CAT=@CAT AND VER=@VER AND INTERNAL = 1 ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@CAT", CAT),
                    new SqlParameter("@VER", VER)
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

    public DataTable getTabelByCodes(HttpContext context, List<string> codes, string table)
    {
        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        syear = (1911 + Convert.ToInt16(syear)).ToString();
        eyear = (1911 + Convert.ToInt16(eyear)).ToString();

        DataTable data = new DataTable();

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT DISTINCT YEAR, cast(MONTH AS int) AS MONTH, STATID, cast(STAT_VAL AS int) AS value FROM STATDATA_" + table +
                @" WHERE (YEAR >= @startyear AND YEAR <= @endyear) ";

            if (codes.Count > 0)
                sqlStr += "AND ( ";
            for (int i = 0; i < codes.Count; i++)
            {
                if (i != 0)
                    sqlStr += " OR ";
                sqlStr += "STATID = @STATID_" + i;
            }
            if (codes.Count > 0)
                sqlStr += " ) ";

            sqlStr += " ORDER BY STATID, YEAR, MONTH ";
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
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                data = ds.Tables[0];
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

        return data;
    }

    public DataTable GetBaseTypeData(int syear, int eyear, string code)
    {
        DataTable dt = new DataTable();

        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT DISTINCT (CAST(YEAR AS decimal)-1911) as YEAR, CAST(MONTH AS decimal) as MONTH, CAST(STAT_VAL AS decimal) as value, STATID, COUNTY 
                        FROM STATDATA_NEW182A 
                        WHERE (YEAR >= @startyear AND YEAR <= @endyear) AND STATID=@STATID 
                      ";

            sqlStr += @" ORDER BY YEAR, MONTH ";
            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@startyear", syear),
                    new SqlParameter("@endyear", eyear),
                    new SqlParameter("@STATID", code)
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
        };

        return dt;
    }

    public string ClassesDictionary(string classes)
    {
        string s = "";
        switch (classes)
        {
            case "1":
                s = "總計";
                break;
            case "2":
                s = "教育程度";
                break;
            case "3":
                s = "年齡";
                break;
            case "4":
                s = "行業";
                break;
            case "5":
                s = "職業";
                break;
            case "6":
                s = "失業原因";
                break;
            case "7":
                s = "從業身分";
                break;
            case "8":
                s = "未參與勞動原因";
                break;
        }

        return s;
    }

    public List<string> Dictionary(HttpContext context)
    {
        List<string> list = new List<string>();
        string type = context.Request["classes"] as string;

        string pepcode = "PEP04";
        string pupcode = "PUP04";
        string nlfcode = "NLF04";
        string woucode = "WOU04";
        string sfucode = "SFU09";
        string trucode = "TRU09";
        string plfcode = "PLF09";

        switch (type)
        {
            case "7":
            case "8":
                list.Add(pepcode);
                break;
            case "9":
                list.Add(pupcode);
                break;
            case "10":
                list.Add(nlfcode);
                break;
            case "2":
            case "5":
                list.Add(pepcode);
                list.Add(pupcode);
                break;
            case "3":
            case "6":
                list.Add(pepcode);
                list.Add(pupcode);
                list.Add(nlfcode);
                break;
            case "4":
                list.Add(pupcode);
                list.Add(woucode);
                break;
            case "11":
                list.Add(pepcode);
                list.Add(sfucode);
                list.Add(trucode);
                list.Add(plfcode);
                break;
        }

        return list;
    }

    public string GetLayOutIndVer(HttpContext context)
    {
        string ver = "0";
        string type = context.Request["subtype"] as string;

        switch (type)
        {
            case "1":
                ver = "6";
                break;
            case "2":
                ver = "7";
                break;
            case "3":
            case "4":
                ver = "8-10";
                break;
            case "5":
                ver = "12";
                break;
        }

        return ver;
    }

    public DataTable GetZoneCode(string CAT, string CODE, string VER)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM CODE WHERE CAT=@CAT AND CODE=@CODE AND VER=@VER AND INTERNAL = 1 ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@CAT", CAT),
                    new SqlParameter("@CODE", CODE),
                    new SqlParameter("@VER", VER)
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

    public string GetLayOutOccVer(HttpContext context)
    {
        string ver = "0";
        string type = context.Request["subtype"] as string;

        switch (type)
        {
            case "1":
            case "2":
            case "3":
                ver = "5";
                break;
            case "4":
            case "5":
                ver = "6";
                break;
        }

        return ver;
    }

    public List<sortitem> GetSortItems(string classes, string ver)
    {
        //取得Layout
        string layoutstring = GetLayouts(classes, ver);
        string[] layouts = layoutstring.Split(',');
        //取得CodeTable
        DataTable code = GetCodeTable(classes, ver);

        List<sortitem> items = new List<sortitem>();
        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string des = cd[0]["DES_ZH"].ToString();
            string lvl = cd[0]["LVL"].ToString();
            string cod = cd[0]["CODE"].ToString();

            sortitem item = new sortitem()
            {
                code = cod,
                name = des,
                level = lvl,
                classes = classesDictionary(classes)
            };

            items.Add(item);
        }

        return items;
    }

    public double CheckHideValue(string des, double value, string sy)
    {
        int y = Convert.ToInt32(sy);
        if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
            return Double.NaN;
        if (Double.IsNaN(value))
            return Double.NaN;

        return value;
    }

    public double CheckHideValue2(string des, double value, string sy, string sm)
    {
        int y = Convert.ToInt32(sy);
        if (y >= 1911) y = y - 1911;
        if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
            return -999999;
        int r = 0;
        bool tm = int.TryParse(sm, out r);
        if (tm == true)
        {
            int m = Convert.ToInt32(sm);
            if (y == 113 && m <= 5 && des == "LU")
                return -999999;
            if (y < 113 && des == "LU")
                return -999999;
        }

        if (sm == "上半年" && y == 113 && des == "LU")
            return -999999;
        if ((sm == "上半年" || sm == "下半年") && y < 113 && des == "LU")
            return -999999;

        if (sm == "-" && y <= 113 && des == "LU")
            return -999999;
        if ((sm == "第1季" || sm == "第2季") && y == 113 && des == "LU")
            return -999999;
        if ((sm == "第1季" || sm == "第2季" || sm == "第3季" || sm == "第4季") && y < 113 && des == "LU")
            return -999999;

        bool isMatch = Regex.IsMatch(sm, @"^1月至(1[0-2]|[1-9])月$");
        if (isMatch && y <= 113 && des == "LU")
            return -999999;

        return value;
    }

    public double CheckDashValue(double value)
    {
        if (Double.IsNaN(value))
            return -999999;

        return value;
    }

    public string cDictionary(string classes)
    {
        switch (classes)
        {
            case "2":
                return "勞動力";
            case "3":
                return "十五歲以上民間人口";
            case "4":
                return "失業週數";
            case "5":
                return "失業率";
            case "6":
                return "勞動力參與率";
            case "7":
                return "就業者(一)";
            case "8":
                return "就業者(二)";
            case "9":
                return "失業者(一)";
            case "10":
                return "非勞動力(一)";
            case "11":
                return "勞動力低度運用指標";
            default:
                return "";
        }
    }

    public string classesDictionary(string classes)
    {
        switch (classes)
        {
            case "教育程度":
                return "2";
            case "年齡":
                return "3";
            case "行業":
                return "4";
            case "職業":
                return "5";
            case "失業原因":
                return "6";
            case "從業身分":
                return "7";
            case "非勞動原因":
                return "8";
            default:
                return "";
        }
    }

    public int CheckDataType(HttpContext context)
    {
        string type = context.Request["classes"] as string;
        string subtype = context.Request["subtype"] as string;

        if (type == "1")
            return 1;

        if (type == "2" || type == "3" ||
            type == "5" || type == "6" || type == "7" ||
            (type == "9" && subtype == "5") || (type == "10" && subtype == "1")
           )
        {
            return 2;
        }

        if (type == "4")
            return 3;

        if (type == "8" || type == "9" || type == "10")
            return 4;

        if (type == "11")
            return 5;

        return -1;
    }

    public string GetExcelForTaiwanIntranet(HttpContext context)
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

        int type = CheckDataType(context);

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        string cycle = context.Request["cycle"] as string;
        string smonth = context.Request["smonth"] as string;

        string[] ssex = (context.Request["sex"] as string).Replace("T", "總計").Replace("M", "男").Replace("F", "女").Split(',');
        string[] output;
        if (type == 3)
        {
            output = (context.Request["output"] as string).Replace("T", "統計值 (千人)").Replace("P", "統計值 (人)").Replace("S", "結構比 (%)").Replace("D2", "統計值-小數2位").Replace("D1", "統計值-小數1位").Split(',');
        }
        else
        {
            output = (context.Request["output"] as string).Replace("T", "統計值 (千人)").Replace("P", "統計值 (人)").Replace("S", "結構比 (%)").Replace("D2", "統計值-小數2位 (%)").Replace("D1", "統計值-小數1位 (%)").Split(',');
        }

        string exporttype = context.Request["exporttype"] as string;

        try
        {
            Supergeo.Tools.HiResTimer timer = new Supergeo.Tools.HiResTimer();
            Int64 StartTime = timer.Value;

            string title = setExcelTitle(context);
            ISheet ExcelSheet = null;
            ExcelSheet = workbook.CreateSheet("sheet");

            Int64 oneFromAddr = timer.Value;

            rdata dat = new rdata();

            dat = GetRequestTables2(context);

            // 處理sort 變成 Dictionary
            Dictionary<string, List<string>> sort = new Dictionary<string, List<string>>();
            foreach (sortitem item in dat.sort)
            {
                if (item.name == "軍人" && type != 4) continue;
                List<string> value = null;
                bool f = sort.TryGetValue(item.classes, out value);
                if (f == false)
                {
                    sort.Add(item.classes, new List<string>());
                    sort[item.classes].Add(item.name);
                }
                else
                {
                    sort[item.classes].Add(item.name);
                }
            }

            WriteLog("取資料耗費時間:" + timer.End(oneFromAddr).ToString("F6") + "秒");

            WriteLog("資料筆數:" + dat.data.Count);
            WriteLog("Layout筆數:" + dat.sort.Count);

            //title
            ExcelSheet.CreateRow(0);
            ExcelSheet.GetRow(0).CreateCell(0).SetCellValue(title);
            ExcelSheet.GetRow(0).CreateCell(3);
            ExcelSheet.AddMergedRegion(new NPOI.SS.Util.CellRangeAddress(0, 0, 0, 3));

            if (type != 4) // 性別的部分
            {
                string[] classes = (context.Request["classes1"] as string).Split(',');
                if (classes[0] == "") classes[0] = "1"; //總計
                // 計算Layout所需要用到的長度
                int totalCol = dat.sort.Count * ssex.Length * output.Length;

                // 建立Head
                Int64 tt2 = timer.Value;

                int scol = 3;
                // 建立Head空欄位

                for (int i = 1; i <= 5; i++)
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
                NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(1, 4, 0, 2);
                ExcelSheet.AddMergedRegion(range);

                NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range, ExcelSheet); //Bottom border  
                NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range, ExcelSheet); //Left border  
                NPOI.SS.Util.RegionUtil.SetBorderRight(1, range, ExcelSheet); //Right border  
                NPOI.SS.Util.RegionUtil.SetBorderTop(1, range, ExcelSheet); //Top border

                int rcol1 = scol;
                int rcol2 = scol;
                int rcol3 = scol;
                int rcol4 = scol;
                // 根據Class填入格子
                foreach (string r in classes)
                {
                    string c = ClassesDictionary(r);
                    List<string> tar = sort[r];

                    // Row 1-類別
                    int ccol = tar.Count * ssex.Length * output.Length;
                    ExcelSheet.GetRow(1).CreateCell(rcol1).SetCellValue(c);
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
                    // Row 2-Layout
                    foreach (string r2 in tar)
                    {
                        int ttcol = ssex.Length * output.Length;
                        ExcelSheet.GetRow(2).CreateCell(rcol2).SetCellValue(r2);
                        ExcelSheet.GetRow(2).GetCell(rcol2).CellStyle = styleHead;
                        if (ttcol > 1)
                        {
                            NPOI.SS.Util.CellRangeAddress range3 = new NPOI.SS.Util.CellRangeAddress(2, 2, rcol2, rcol2 + ttcol - 1);
                            ExcelSheet.AddMergedRegion(range3);

                            NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range3, ExcelSheet); //Bottom border  
                            NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range3, ExcelSheet); //Left border  
                            NPOI.SS.Util.RegionUtil.SetBorderRight(1, range3, ExcelSheet); //Right border  
                            NPOI.SS.Util.RegionUtil.SetBorderTop(1, range3, ExcelSheet); //Top border
                        }


                        rcol2 = rcol2 + ttcol;
                        // Row 3-性別
                        foreach (string r3 in ssex)
                        {
                            int sscol = output.Length;
                            ExcelSheet.GetRow(3).CreateCell(rcol3).SetCellValue(r3);
                            ExcelSheet.GetRow(3).GetCell(rcol3).CellStyle = styleHead;

                            if (sscol > 1)
                            {
                                NPOI.SS.Util.CellRangeAddress range4 = new NPOI.SS.Util.CellRangeAddress(3, 3, rcol3, rcol3 + sscol - 1);
                                ExcelSheet.AddMergedRegion(range4);

                                NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range4, ExcelSheet); //Bottom border  
                                NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range4, ExcelSheet); //Left border  
                                NPOI.SS.Util.RegionUtil.SetBorderRight(1, range4, ExcelSheet); //Right border  
                                NPOI.SS.Util.RegionUtil.SetBorderTop(1, range4, ExcelSheet); //Top border
                            }

                            rcol3 = rcol3 + sscol;
                            // Row 4-輸出
                            foreach (string r4 in output)
                            {
                                ExcelSheet.GetRow(4).CreateCell(rcol4).SetCellValue(r4);
                                ExcelSheet.GetRow(4).GetCell(rcol4).CellStyle = styleHead;

                                rcol4++;
                            }
                        }
                    }
                }

                WriteLog("建Head耗費時間:" + timer.End(tt2).ToString("F6") + "秒");

                // 計算年份縣市長度
                Int64 tt3 = timer.Value;

                Dictionary<int, string> clock = new Dictionary<int, string>();
                foreach (listitem d in dat.data)
                {
                    string value = string.Empty;
                    int key = GetClockDicKey(d.d, cycle);

                    bool f = clock.TryGetValue(key, out value);
                    if (f == false)
                        clock.Add(key, d.d);
                }
                clock = clock.OrderBy(x => x.Key).ToDictionary(x => x.Key, x => x.Value);
                WriteLog("計算年分長度耗費時間:" + timer.End(tt3).ToString("F6") + "秒");

                Int64 tt4 = timer.Value;
                int srow = 5;
                int rrow1 = srow;

                foreach (KeyValuePair<int, string> item in clock)
                {
                    string c = item.Value;
                    ExcelSheet.CreateRow(rrow1);
                    ExcelSheet.GetRow(rrow1).CreateCell(0).SetCellValue(c);
                    ExcelSheet.GetRow(rrow1).GetCell(0).CellStyle = styleLeft;

                    NPOI.SS.Util.CellRangeAddress range5 = new NPOI.SS.Util.CellRangeAddress(rrow1, rrow1, 0, 2);
                    ExcelSheet.AddMergedRegion(range5);

                    NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range5, ExcelSheet); //Bottom border  
                    NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range5, ExcelSheet); //Left border  
                    NPOI.SS.Util.RegionUtil.SetBorderRight(1, range5, ExcelSheet); //Right border  
                    NPOI.SS.Util.RegionUtil.SetBorderTop(1, range5, ExcelSheet); //Top border

                    // 填值部分
                    int rcol = 3;
                    foreach (string r in classes)
                    {
                        string rc = ClassesDictionary(r);
                        List<string> tar = sort[r];
                        foreach (string r2 in tar)
                        {
                            foreach (string r3 in ssex)
                            {
                                foreach (string r4 in output)
                                {
                                    string key = string.Format("{0}_{1}_{2}_{3}_{4}", rc, c, r2, r3, r4);
                                    decimal value = 0;
                                    bool f = dat.data2.TryGetValue(key, out value);

                                    if (f == false) value = -999999;

                                    string vstr = "";

                                    if (value == -999999) vstr = "-";
                                    else if (r4 == "統計值 (千人)" || r4 == "統計值 (人)")
                                        vstr = value.ToString("N0");
                                    else vstr = value.ToString();

                                    ExcelSheet.GetRow(rrow1).CreateCell(rcol).SetCellValue(vstr);
                                    ExcelSheet.GetRow(rrow1).GetCell(rcol).CellStyle = styleRight;
                                    rcol++;
                                }
                            }
                        }
                    }
                    rrow1++;
                    srow = rrow1;
                }

                if (title.Contains("失業原因"))
                {
                    int endrow = rrow1;

                    ExcelSheet.CreateRow(endrow);

                    NPOI.SS.Util.CellRangeAddress range2 = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                    ExcelSheet.AddMergedRegion(range2);

                    ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("註：112年1月起「女性結婚或生育」修改為「結婚或生育」。");
                }
                if (title.Contains("未參與勞動原因"))
                {
                    int endrow = rrow1;

                    ExcelSheet.CreateRow(endrow);

                    NPOI.SS.Util.CellRangeAddress range2 = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                    ExcelSheet.AddMergedRegion(range2);

                    ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("註：自114年起，非勞動力未參與勞動原因「想工作而未找工作且隨時可以開始工作」者，依實際狀況分別歸入「求學及準備升學」、「料理家務」、「高齡、身心障礙」及「其他」4類，不再單獨列示。");
                }
            }
            else // 有SUBTYPE的部分
            {
                string[] classes = (context.Request["classes3"] as string).Split(',');
                if (classes[0] == "") classes[0] = "1"; //總計
                // 計算Layout所需要用到的長度
                int totalCol = dat.sort.Count * dat.subclasses.Count * output.Length;

                // 建立Head
                Int64 tt2 = timer.Value;

                int scol = 3;
                // 建立Head空欄位

                for (int i = 1; i <= 5; i++)
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
                NPOI.SS.Util.CellRangeAddress range = new NPOI.SS.Util.CellRangeAddress(1, 4, 0, 2);
                ExcelSheet.AddMergedRegion(range);

                NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range, ExcelSheet); //Bottom border  
                NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range, ExcelSheet); //Left border  
                NPOI.SS.Util.RegionUtil.SetBorderRight(1, range, ExcelSheet); //Right border  
                NPOI.SS.Util.RegionUtil.SetBorderTop(1, range, ExcelSheet); //Top border

                int rcol1 = scol;
                int rcol2 = scol;
                int rcol3 = scol;
                int rcol4 = scol;
                // 根據Class填入格子
                foreach (string r in classes)
                {
                    string t = r;
                    if (r == "6") t = "7";
                    string c = ClassesDictionary(t);
                    List<string> tar = sort[t];

                    // Row 1-類別
                    int ccol = tar.Count * dat.subclasses.Count * output.Length;
                    ExcelSheet.GetRow(1).CreateCell(rcol1).SetCellValue(c);
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
                    // Row 2-Layout
                    foreach (string r2 in tar)
                    {
                        int ttcol = dat.subclasses.Count * output.Length;
                        ExcelSheet.GetRow(2).CreateCell(rcol2).SetCellValue(r2);
                        ExcelSheet.GetRow(2).GetCell(rcol2).CellStyle = styleHead;
                        if (ttcol > 1)
                        {
                            NPOI.SS.Util.CellRangeAddress range3 = new NPOI.SS.Util.CellRangeAddress(2, 2, rcol2, rcol2 + ttcol - 1);
                            ExcelSheet.AddMergedRegion(range3);

                            NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range3, ExcelSheet); //Bottom border  
                            NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range3, ExcelSheet); //Left border  
                            NPOI.SS.Util.RegionUtil.SetBorderRight(1, range3, ExcelSheet); //Right border  
                            NPOI.SS.Util.RegionUtil.SetBorderTop(1, range3, ExcelSheet); //Top border
                        }


                        rcol2 = rcol2 + ttcol;
                        // Row 3-SUBTYPE
                        foreach (string r3 in dat.subclasses)
                        {
                            int sscol = output.Length;
                            ExcelSheet.GetRow(3).CreateCell(rcol3).SetCellValue(r3);
                            ExcelSheet.GetRow(3).GetCell(rcol3).CellStyle = styleHead;

                            if (sscol > 1)
                            {
                                NPOI.SS.Util.CellRangeAddress range4 = new NPOI.SS.Util.CellRangeAddress(3, 3, rcol3, rcol3 + sscol - 1);
                                ExcelSheet.AddMergedRegion(range4);

                                NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range4, ExcelSheet); //Bottom border  
                                NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range4, ExcelSheet); //Left border  
                                NPOI.SS.Util.RegionUtil.SetBorderRight(1, range4, ExcelSheet); //Right border  
                                NPOI.SS.Util.RegionUtil.SetBorderTop(1, range4, ExcelSheet); //Top border
                            }

                            rcol3 = rcol3 + sscol;
                            // Row 4-輸出
                            foreach (string r4 in output)
                            {
                                ExcelSheet.GetRow(4).CreateCell(rcol4).SetCellValue(r4);
                                ExcelSheet.GetRow(4).GetCell(rcol4).CellStyle = styleHead;

                                rcol4++;
                            }
                        }
                    }
                }

                WriteLog("建Head耗費時間:" + timer.End(tt2).ToString("F6") + "秒");

                // 計算年份縣市長度
                Int64 tt3 = timer.Value;

                Dictionary<int, string> clock = new Dictionary<int, string>();
                foreach (listitem d in dat.data)
                {
                    string value = string.Empty;
                    int key = GetClockDicKey(d.d, cycle);

                    bool f = clock.TryGetValue(key, out value);
                    if (f == false)
                        clock.Add(key, d.d);
                }
                clock = clock.OrderBy(x => x.Key).ToDictionary(x => x.Key, x => x.Value);
                WriteLog("計算年分長度耗費時間:" + timer.End(tt3).ToString("F6") + "秒");

                Int64 tt4 = timer.Value;
                int srow = 5;
                int rrow1 = srow;

                foreach (KeyValuePair<int, string> item in clock)
                {
                    string c = item.Value;
                    ExcelSheet.CreateRow(rrow1);
                    ExcelSheet.GetRow(rrow1).CreateCell(0).SetCellValue(c);
                    ExcelSheet.GetRow(rrow1).GetCell(0).CellStyle = styleLeft;

                    NPOI.SS.Util.CellRangeAddress range5 = new NPOI.SS.Util.CellRangeAddress(rrow1, rrow1, 0, 2);
                    ExcelSheet.AddMergedRegion(range5);

                    NPOI.SS.Util.RegionUtil.SetBorderBottom(1, range5, ExcelSheet); //Bottom border  
                    NPOI.SS.Util.RegionUtil.SetBorderLeft(1, range5, ExcelSheet); //Left border  
                    NPOI.SS.Util.RegionUtil.SetBorderRight(1, range5, ExcelSheet); //Right border  
                    NPOI.SS.Util.RegionUtil.SetBorderTop(1, range5, ExcelSheet); //Top border

                    // 填值部分
                    int rcol = 3;
                    foreach (string r in classes)
                    {
                        string t = r;
                        if (r == "6") t = "7";
                        string rc = ClassesDictionary(t);
                        List<string> tar = sort[t];
                        foreach (string r2 in tar)
                        {
                            foreach (string r3 in dat.subclasses)
                            {
                                foreach (string r4 in output)
                                {
                                    string key = string.Format("{0}_{1}_{2}_{3}_{4}", rc, c, r2, r3, r4);
                                    decimal value = 0;
                                    bool f = dat.data2.TryGetValue(key, out value);

                                    if (f == false) value = -999999;

                                    string vstr = "";

                                    if (value == -999999) vstr = "-";
                                    else if (r4 == "統計值 (千人)" || r4 == "統計值 (人)")
                                        vstr = value.ToString("N0");
                                    else vstr = value.ToString();

                                    ExcelSheet.GetRow(rrow1).CreateCell(rcol).SetCellValue(vstr);
                                    ExcelSheet.GetRow(rrow1).GetCell(rcol).CellStyle = styleRight;
                                    rcol++;
                                }
                            }
                        }
                    }
                    rrow1++;
                    srow = rrow1;
                }

                if (title.Contains("失業原因"))
                {
                    int endrow = rrow1;

                    ExcelSheet.CreateRow(endrow);

                    NPOI.SS.Util.CellRangeAddress range2 = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                    ExcelSheet.AddMergedRegion(range2);

                    ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("註：112年1月起「女性結婚或生育」修改為「結婚或生育」。");
                }
                if (title.Contains("未參與勞動原因"))
                {
                    int endrow = rrow1;

                    ExcelSheet.CreateRow(endrow);

                    NPOI.SS.Util.CellRangeAddress range2 = new NPOI.SS.Util.CellRangeAddress(endrow, endrow, 0, 5);
                    ExcelSheet.AddMergedRegion(range2);

                    ExcelSheet.GetRow(endrow).CreateCell(0).SetCellValue("註：自114年起，非勞動力未參與勞動原因「想工作而未找工作且隨時可以開始工作」者，依實際狀況分別歸入「求學及準備升學」、「料理家務」、「高齡、身心障礙」及「其他」4類，不再單獨列示。");
                }
            }

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

    public int GetClockDicKey(string date, string cycle)
    {
        if (cycle == "1") // 年
        {
            string tmp = date.Replace("年", "");
            int itmp = Convert.ToInt32(tmp);
            return itmp;
        }
        else if (cycle == "2") // 半年平均
        {
            string tmp = date.Replace("-", "").Replace("年上半年", "1").Replace("年下半年", "2");
            int itmp = Convert.ToInt32(tmp);
            return itmp;
        }
        else if (cycle == "3") // 季
        {
            string tmp = date.Replace("-", "").Replace("年第1季", "1").Replace("年第2季", "2").Replace("年第3季", "3").Replace("年第4季", "4");
            int itmp = Convert.ToInt32(tmp);
            return itmp;
        }
        else if (cycle == "4" || cycle == "5") // 月
        {
            string tmp = date.Replace("-", "").Replace("年", "_").Replace("月", "_");
            string[] atmp = tmp.Split('_');
            string tint = atmp[0] + atmp[1].PadLeft(2, '0');
            int itmp = Convert.ToInt32(tint);
            return itmp;
        }
        else if (cycle == "6")
        {
            string[] atmp = date.Split('年');
            int itmp = Convert.ToInt32(atmp[0]);
            return itmp;
        }
        else
        {
            return -1;
        }
    }

    public string setExcelTitle(HttpContext context)
    {
        string ts = "";

        int classes = -1;
        int subtype = -1;
        int classes2 = -1;
        int classes3 = -1;

        bool c = Int32.TryParse(context.Request["classes"] as string, out classes);
        bool s = Int32.TryParse(context.Request["subtype"] as string, out subtype);
        bool c2 = Int32.TryParse(context.Request["classes2"] as string, out classes2);
        bool c3 = Int32.TryParse(context.Request["classes3"] as string, out classes3);

        string classes1 = context.Request["classes1"] as string;
        string[] aclasses1 = classes1.Split(',');
        string subtype2 = context.Request["subtype2"] as string; //分類下拉選單
        string[] asubtype2 = subtype2.Split(',');

        ts += getrocclasses(classes);

        if (classes >= 2 && classes <= 6)
        {
            foreach (string cc in aclasses1)
            {
                int cc1 = -1;
                bool c1 = Int32.TryParse(cc, out cc1);
                ts += "-" + getrocclasses1(cc1);
            }
        }
        else if (classes == 7)
        {
            foreach (string cc in aclasses1)
            {
                int cc1 = -1;
                bool c1 = Int32.TryParse(cc, out cc1);
                ts += "-" + getrocclasses1(cc1);
            }
            if (subtype == 1)
                ts += "-" + "就業者(一)舊行業(6th)舊職業(5th)(67~90年)";
            else if (subtype == 2)
                ts += "-" + "就業者(一)舊行業(7th)舊職業(5th)(88~95年)";
            else if (subtype == 3)
                ts += "-" + "就業者(一)新行業(8th)舊職業(5th)(90~99年)";
            else if (subtype == 4)
                ts += "-" + "就業者(一)舊行業(8th-11th)(96年以後)";
            else if (subtype == 5)
                ts += "-" + "就業者(一)新行業(12th)(105年以後)";
        }
        else if (classes == 8)
        {
            if (subtype == 1)
                ts += "-" + "就業者(二)舊行業(6th)舊職業(5th)(67~90年)";
            else if (subtype == 2)
                ts += "-" + "就業者(二)舊行業(7th)舊職業(5th)(88~95年)";
            else if (subtype == 3)
                ts += "-" + "就業者(二)舊行業(8th)舊職業(5th)(96~99年)";
            else if (subtype == 4)
                ts += "-" + "就業者(二)舊行業(8th-11th)新職業(6th)(100年以後)";
            else if (subtype == 5)
                ts += "-" + "就業者(二)新行業(12th)新職業(6th)(105年以後)";

            ts += "-" + getrocclasses2(classes2);
            ts += asubtype2.Length > 1 ? "-複選" : "-單選";
            ts += "-" + getrocclasses3(classes3);
        }
        else if (classes == 9)
        {
            if (subtype == 5)
            {
                ts += "-" + "失業者(一)";
                foreach (string cc in aclasses1)
                {
                    int cc1 = -1;
                    bool c1 = Int32.TryParse(cc, out cc1);
                    ts += "-" + getrocclasses1(cc1);
                }
            }
            else
            {
                if (subtype == 1)
                    ts += "-" + "失業者(二)舊行業(6th)舊職業(5th)(67~90年)";
                else if (subtype == 2)
                    ts += "-" + "失業者(二)舊行業(7th)舊職業(5th)(88~95年)";
                else if (subtype == 3)
                    ts += "-" + "失業者(二)新行業(8th)舊職業(5th)(96~99年)";
                else if (subtype == 4)
                    ts += "-" + "失業者(二)新行業(8th-11th)新職業(6th)(100年以後)";

                ts += "-" + getrocclasses2(classes2);
                ts += asubtype2.Length > 1 ? "-複選" : "-單選";
                ts += "-" + getrocclasses3(classes3);
            }
        }
        else if (classes == 10)
        {
            if (subtype == 1)
            {
                ts += "-" + "非勞動力(一)";
                foreach (string cc in aclasses1)
                {
                    int cc1 = -1;
                    bool c1 = Int32.TryParse(cc, out cc1);
                    ts += "-" + getrocclasses1(cc1);
                }
            }
            else if (subtype == 2)
            {
                ts += "-" + "非勞動力(二)";
                ts += "-" + getrocclasses2(classes2);
                ts += asubtype2.Length > 1 ? "-複選" : "-單選";
                ts += "-" + getrocclasses3(classes3);
            }
        }
        else if (classes == 11)
        {
            if (subtype == 1)
                ts += "-" + "4週失業者";
            else if (subtype == 2)
                ts += "-" + "工時不足就業者";
            else if (subtype == 3)
                ts += "-" + "潛在勞動力";
            else if (subtype == 4)
                ts += "-" + "LU1";
            else if (subtype == 5)
                ts += "-" + "LU2";
            else if (subtype == 6)
                ts += "-" + "LU3";
            else if (subtype == 7)
                ts += "-" + "LU4";

            foreach (string cc in aclasses1)
            {
                int cc1 = -1;
                bool c1 = Int32.TryParse(cc, out cc1);
                ts += "-" + getrocclasses1(cc1);
            }
        }

        return ts;
    }

    public string getrocclasses(int type)
    {
        switch (type)
        {
            case 1:
                return "總人口";
            case 2:
                return "勞動力";
            case 3:
                return "15歲以上民間人口";
            case 4:
                return "失業週數";
            case 5:
                return "失業率";
            case 6:
                return "勞動力參與率";
            case 7:
                return "就業者(一)";
            case 8:
                return "就業者(二)";
            case 9:
                return "失業者";
            case 10:
                return "非勞動力";
            case 11:
                return "勞動力低度運用指標";
        }
        return "";
    }

    public string getrocclasses1(int type)
    {
        switch (type)
        {
            case 1:
                return "總計";
            case 2:
                return "教育程度";
            case 3:
                return "年齡";
            case 4:
                return "行業";
            case 5:
                return "職業";
            case 6:
                return "失業原因";
            case 7:
                return "從業身分";
            case 8:
                return "未參與勞動原因";
        }
        return "";
    }
    public string getrocclasses2(int type)
    {
        switch (type)
        {
            case 1:
                return "行業";
            case 2:
                return "職業";
            case 3:
                return "從業身分";
            case 4:
                return "失業原因";
            case 5:
                return "非初次尋職者原因";
            case 6:
                return "失業前從業身分";
            case 7:
                return "未參與勞動原因";
        }
        return "";
    }
    public string getrocclasses3(int type)
    {
        switch (type)
        {
            case 1:
                return "總計";
            case 2:
                return "教育程度";
            case 3:
                return "年齡";
            case 4:
                return "失業前行業";
            case 5:
                return "失業前職業";
            case 6:
                return "失業前從業身分";
        }
        return "";
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
