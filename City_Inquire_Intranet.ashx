<%@ WebHandler Language="C#" Class="City_Inquire_Intranet" %>

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
using System.Globalization;
using NPOI.XSSF.Streaming;
using NPOI.XSSF.UserModel;
using NPOI.SS.UserModel;
using System.Web.SessionState;
using System.Text.RegularExpressions;

public class City_Inquire_Intranet : IHttpHandler, IRequiresSessionState {
    String sqlConnstr = System.Configuration.ConfigurationManager.ConnectionStrings["CensusGISADONet"].ConnectionString;
    string tablestring = "";
    string tablecode = "";

    ComputeMod ComputeMod = new ComputeMod();

    public void ProcessRequest (HttpContext context) {
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
            /*}
            else
            {
                context.Response.Write("沒有權限");
            }*/
        }
        catch (Exception e)
        {
            string ex = e.ToString();
            // context.Response.Write(ex);
        }
    }

    public String GetBaseInfo(HttpContext context)
    {
        String jData = "";

        MNYear target = GetYears();
        MNYear target2 = GetYears2();

        jData = JsonConvert.SerializeObject(new { MNYear1 = target, MNYear2 = target2 });

        return (jData);
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

    public MNYear GetYears2()
    {
        MNYear d = new MNYear();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear 
                FROM STATDATA_SHIEN12A;
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

    public class sortitem
    {
        public string name { get; set; } //名稱
        public string level { get; set; } //階層
        public string classes { get; set; }
    }

    public class rdata
    {
        public List<listitem> data { get; set; }
        public List<sortitem> sort { get; set; }
        public List<string> citys { get; set; }
        public Dictionary<string, decimal> data2 { get; set; }
    }

    public class listitem
    {
        public string m { get; set; } //分類項目
        public string d { get; set; } //年月
        public string c { get; set; } //統計項
        public string s { get; set; } //性別
        public string st { get; set; } //資料屬性
        public decimal v { get; set; } //值
        public string ct { get; set; } //地區
        public string l { get; set; } //階層
    }

    public String GetRequestTablesForOld(HttpContext context) //縣市(舊)
    {
        tablestring = "SHIEN12A";
        tablecode = "05";
        string jData = "";

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        string zostring = context.Request["zone"] as string;
        string state = context.Request["state"] as string;
        string sexstring = context.Request["sex"] as string;
        string[] zones = zostring.Split(',');
        string[] sex = sexstring.Split(',');

        rdata rData = new rdata();
        rData.citys = new List<string>();
        List<listitem> list = new List<listitem>();
        rData.data = list;
        List<sortitem> sort = new List<sortitem>();
        rData.sort = sort;

        SetZoneData(context, sy, ey, sex, zostring, list, rData, null);

        jData = JsonConvert.SerializeObject(rData);

        return (jData);
    }

    public String GetRequestTablesForNew(HttpContext context) //縣市(新)
    {
        tablestring = "SHIEN25A";
        tablecode = "06";
        string jData = "";

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        string zostring = context.Request["zone"] as string;
        string state = context.Request["state"] as string;
        string classes = context.Request["classes"] as string;
        string sexstring = context.Request["sex"] as string;
        string[] zones = zostring.Split(',');
        string[] sex = sexstring.Split(',');

        rdata rData = new rdata();
        rData.citys = new List<string>();
        List<listitem> list = new List<listitem>();
        rData.data = list;
        List<sortitem> sort = new List<sortitem>();
        rData.sort = sort;

        SetZoneData(context, sy, ey, sex, zostring, list, rData, null);

        jData = JsonConvert.SerializeObject(rData);

        return (jData);
    }

    public rdata GetRequestTablesForOld2(HttpContext context) //縣市(舊)-EXCEL查詢
    {
        tablestring = "SHIEN12A";
        tablecode = "05";

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        string zostring = context.Request["zone"] as string;
        string state = context.Request["state"] as string;
        string sexstring = context.Request["sex"] as string;
        string[] zones = zostring.Split(',');
        string[] sex = sexstring.Split(',');

        rdata rData = new rdata();
        rData.citys = new List<string>();
        List<listitem> list = new List<listitem>();
        rData.data = list;
        List<sortitem> sort = new List<sortitem>();
        rData.sort = sort;
        Dictionary<string, decimal> data2 = new Dictionary<string, decimal>();
        rData.data2 = data2;

        SetZoneData(context, sy, ey, sex, zostring, list, rData, data2);

        return (rData);
    }

    public rdata GetRequestTablesForNew2(HttpContext context) //縣市(新)-EXCEL查詢
    {
        tablestring = "SHIEN25A";
        tablecode = "06";

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        string zostring = context.Request["zone"] as string;
        string state = context.Request["state"] as string;
        string classes = context.Request["classes"] as string;
        string sexstring = context.Request["sex"] as string;
        string[] zones = zostring.Split(',');
        string[] sex = sexstring.Split(',');

        rdata rData = new rdata();
        rData.citys = new List<string>();
        List<listitem> list = new List<listitem>();
        rData.data = list;
        List<sortitem> sort = new List<sortitem>();
        rData.sort = sort;
        Dictionary<string, decimal> data2 = new Dictionary<string, decimal>();
        rData.data2 = data2;

        SetZoneData(context, sy, ey, sex, zostring, list, rData, data2);

        return (rData);
    }

    public void SetZoneData(HttpContext context, string startyear, string endyear, string[] sex, string zone, List<listitem> litems, rdata rdata, Dictionary<string,decimal> data2)
    {
        string isnew = context.Request["isnew"] as string;
        string stat = context.Request["state"] as string;
        string smonth = context.Request["smonth"] as string;
        string output = context.Request["output"] as string;
        string[] sexes = (context.Request["sex"] as string).Split(',');
        string[] tsexes = { "T", "M", "F" };
        int isy = Convert.ToInt32(startyear) + 1911;
        int iey = Convert.ToInt32(endyear) + 1911;
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);

        string[] css = (context.Request["classes"] as string).Split(',');

        bool isold = false;

        if (isnew == "N")
            isold = true;

        // 判斷要取那些ZONE回來
        String[] zs = zone.Split(',');
        DataTable zdt = GetZoneCode(zs, isold, rdata);
        // 篩選要抓出來的LVL1的縣市 並略過重複的部分
        List<string> zcodelist = GetAllRequestZones(zdt);
        // 如果是新區用來找舊的CODE 拿來對照舊職業及舊行業用
        List<string> ocodelist = new List<string>();

        if (isold == false)
        {
            ocodelist = GetAllOldRequestZones(zdt);
        }

        string[] allsex = new[] { "T", "M", "F" };

        // 外層用CLASS做區分 最多取的次數為選取CLASS的次數
        for (int p = 0; p < css.Length; p++)
        {
            string cs = css[p];
            string dcs = ClassesDictionary(cs);

            bool hasLayOut = false;
            if (cs != "1")
                hasLayOut = true;

            if (!hasLayOut) // 總計部分
            {
                List<string> ctip = Dictionary(context);
                List<DataTable> tdts = new List<DataTable>();

                string des = cDictionary(stat);
                sortitem si = new sortitem();
                si.name = des;
                si.level = "3";
                si.classes = "1";
                rdata.sort.Add(si);

                for (int i = 0; i < ctip.Count; i++)
                {
                    List<string> codes = new List<string>();
                    for (int j = 0; j < tsexes.Length; j++)
                    {
                        string code = "";
                        code += ctip[i] + tsexes[j] + "0000X0000000000000";
                        codes.Add(code);
                    }

                    DataTable dt = GetYearTable(context, isy, iey, zcodelist, codes, tablestring);
                    tdts.Add(dt);
                }

                foreach (DataRow r in zdt.Rows)
                {
                    string lvl = r["LVL"].ToString();

                    List<DataTable> dts = new List<DataTable>();

                    if (lvl == "1")
                    {
                        foreach (DataTable t in tdts)
                        {
                            DataRow[] rs = t.Select("COUNTY='" + r["CODE"].ToString() + "'");
                            dts.Add(rs.CopyToDataTable());
                        }
                    }
                    else if (lvl == "2")
                    {
                        string wstr = "";

                        string[] cals = r["CAL_ITEM"].ToString().Split(',');

                        for (int i = 0; i < cals.Length; i++)
                        {
                            if (i != 0) wstr += " OR ";
                            wstr += "COUNTY='" + cals[i] + "'";
                        }

                        dts = CompareZoneSumTable(tdts, wstr);
                    }

                    if (stat != "6" && stat != "7" && stat != "12" && stat != "13" && stat != "14" && stat != "15")
                    {
                        List<DataTable> cdts = new List<DataTable>();
                        DataTable dt = MerageTable(context, dts);
                        List<DataTable> fdts = new List<DataTable>();
                        fdts.Add(dt);

                        if (cycle == 1)
                            cdts = computeTableYear(isy, iey, fdts);
                        else if (cycle == 2)
                            cdts = computeTableHalfYear(isy, iey, fdts);
                        else if (cycle == 3)
                            cdts = computeTableSeason(isy, iey, fdts);
                        else if (cycle == 5)
                        {
                            cdts = fdts;
                            for (int i = 0; i < cdts.Count; i++)
                            {
                                DataRow[] drs = cdts[i].Select("MONTH='" + smonth + "'");
                                if (drs.Length > 0)
                                    cdts[i] = drs.CopyToDataTable();
                                else
                                {
                                    DataRow[] trs = cdts[i].Select("MONTH='1'");
                                    for (int j = 0; j < trs.Length; j++)
                                    {
                                        trs[j]["MONTH"] = smonth;
                                        trs[j]["value"] = "0";
                                    }
                                }
                            }
                        }
                        else if (cycle == 6)
                        {
                            int iavgmonth = Convert.ToInt32(smonth);
                            cdts = computeTableSumAvg(isy, iey, fdts, iavgmonth);
                        }
                        else
                            cdts = fdts;

                        SetBaseStatistics1(context, cdts[0], stat, litems, output, r["DES_ZH"].ToString(), data2);
                        if (output.IndexOf("S") != -1)
                            SetBaseStatistics2(context, dt, stat, litems, output, r["DES_ZH"].ToString(), data2);
                    }
                    else //基底-率 額外處理
                    {
                        List<DataTable> cdts = new List<DataTable>();
                        DataTable dt = MerageTable(context, dts);

                        List<DataTable> fdts = new List<DataTable>();
                        fdts.Add(dt);

                        if (cycle == 1)
                            cdts = computeTableYear2(context, dts, stat, false);
                        else if (cycle == 2)
                            cdts = computeTableHalfYear2(context, dts, stat, false);
                        else if (cycle == 3)
                            cdts = computeTableSeason2(context, dts, stat, false);
                        else if (cycle == 5)
                        {
                            cdts = fdts;
                            for (int i = 0; i < cdts.Count; i++)
                            {
                                DataRow[] drs = cdts[i].Select("MONTH='" + smonth + "'");

                                if (drs.Length > 0)
                                    cdts[i] = drs.CopyToDataTable();
                                else
                                {
                                    DataRow[] trs = cdts[i].Select("MONTH='1'");
                                    for (int j = 0; j < trs.Length; j++)
                                    {
                                        trs[j]["MONTH"] = smonth;
                                        trs[j]["value"] = "0";
                                    }

                                    cdts[i] = trs.CopyToDataTable();
                                }
                            }
                        }
                        else if (cycle == 6)
                        {
                            int iavgmonth = Convert.ToInt32(smonth);
                            cdts = computeTableSumAvg2(context, dts, stat, false, iavgmonth);
                        }
                        else
                            cdts = fdts;

                        SetBaseStatistics1(context, cdts[0], stat, litems, output, r["DES_ZH"].ToString(), data2);
                    }
                }
            }
            else
            {
                List<DataTable> tdts = null;
                string ver = "0";
                //判斷取LayOut
                if (cs == "2") //教育程度
                {
                    tdts = GetEdtionTables(context, "教育程度", zcodelist);
                    rdata.sort.AddRange(GetSortItems("教育程度", ver, cs));
                }
                else if (cs == "3") //年齡
                {
                    tdts = GetAgeTables(context, "年齡", zcodelist);
                    rdata.sort.AddRange(GetSortItems("年齡", ver, cs));
                }
                else if (cs == "4" || cs == "10") //行業
                {
                    ver = GetLayOutIndVer(context);
                    tdts = GetIndTables(context, "行業", ver, zcodelist, ocodelist, isold);
                    rdata.sort.AddRange(GetSortItems("行業", ver, "4"));
                }
                else if (cs == "5" || cs == "11") //職業
                {
                    ver = GetLayOutOccVer(context);
                    tdts = GetOCCTables(context, "職業", ver, zcodelist, ocodelist, isold);
                    rdata.sort.AddRange(GetSortItems("職業", ver, "5"));
                }
                else if (cs == "6") //失業原因
                {
                    tdts = GetROUTables(context, "失業原因", zcodelist);
                    rdata.sort.AddRange(GetSortItems("失業原因", ver, cs));
                }
                else if (cs == "7") //從業身分
                {
                    tdts = GetCOWTables(context, "從業身分", zcodelist);
                    rdata.sort.AddRange(GetSortItems("從業身分", ver, cs));
                }
                else if (cs == "8") //未勞動原因
                {
                    tdts = GetRONTables(context, "非勞動原因", zcodelist);
                    rdata.sort.AddRange(GetSortItems("非勞動原因", ver, cs));
                }

                // 判斷新地區是否要用舊碼處理
                bool useocode = false;
                if (!isold && (cs == "4" || cs == "10") && (ver == "6" || ver == "7"))
                    useocode = true;
                else if (!isold && (cs == "5" || cs == "11") && (ver == "5"))
                    useocode = true;

                foreach (DataRow r in zdt.Rows)
                {
                    List<DataTable> dts = new List<DataTable>();

                    if (!useocode)
                    {
                        string lvl = r["LVL"].ToString();

                        if (lvl == "1")
                        {
                            foreach (DataTable t in tdts)
                            {
                                DataRow[] rs = t.Select("COUNTY='" + r["CODE"].ToString() + "'");
                                dts.Add(rs.CopyToDataTable());
                            }
                        }
                        else if (lvl == "2")
                        {
                            string wstr = "";

                            string[] cals = r["CAL_ITEM"].ToString().Split(',');

                            for (int i = 0; i < cals.Length; i++)
                            {
                                if (i != 0) wstr += " OR ";
                                wstr += "COUNTY='" + cals[i] + "'";
                            }

                            dts = CompareZoneSumTable(tdts, wstr);
                        }
                    }
                    else
                    {
                        string lvl = r["OLD_LVL"].ToString();

                        string wstr = "";

                        string[] cals = new string[0];
                        if (lvl == "1")
                            cals = r["OLD_COUNTY"].ToString().Split(',');
                        else if (lvl == "2")
                            cals = r["OLD_CAL_ITEM"].ToString().Split(',');

                        for (int i = 0; i < cals.Length; i++)
                        {
                            if (i != 0) wstr += " OR ";
                            wstr += "COUNTY='" + cals[i] + "'";
                        }

                        dts = CompareZoneSumTable(tdts, wstr);
                    }

                    if (stat != "6" && stat != "7" && stat != "12" && stat != "13" && stat != "14" && stat != "15")
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

                        if (stat == "9" || stat == "10" || stat == "11")
                        {
                            dts = fdts;
                        }

                        if (cycle == 1)
                            cdts = computeTableYear2(context, dts, stat, true);
                        else if (cycle == 2)
                            cdts = computeTableHalfYear2(context, dts, stat, true);
                        else if (cycle == 3)
                            cdts = computeTableSeason2(context, dts, stat, true);
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
                            cdts = computeTableSumAvg2(context, dts, stat, true, iavgmonth);
                        }
                        else
                            cdts = fdts;

                        SetLayOutStatistics1(context, cdts[0], stat, litems, layouts, code, output, dcs, r["DES_ZH"].ToString(), data2);
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

                            if (i == 0 && (stat == "12" || stat == "13" || stat == "14" || stat == "15"))
                            {
                                DataTable tar = dts[0].AsEnumerable()
                                    .Where(g =>
                                        Convert.ToInt32(g["YEAR"]) > Convert.ToInt32(dts[1].Rows[0]["YEAR"].ToString())
                                        || (
                                            Convert.ToInt32(g["YEAR"]) == Convert.ToInt32(dts[1].Rows[0]["YEAR"].ToString()) &&
                                            Convert.ToInt32(g["MONTH"]) >= Convert.ToInt32(dts[1].Rows[0]["MONTH"].ToString())
                                        )
                                    ).CopyToDataTable();

                                tmp.Add(tar);
                            }
                            else
                            {
                                tmp.Add(dts[i]);
                            }

                            if (cycle == 1)
                            {
                                DataTable t = computeTableYear2(context, tmp, cs, true)[0];
                                cdts.Add(t);
                            }
                            else if (cycle == 2)
                            {
                                DataTable t = computeTableHalfYear2(context, tmp, cs, true)[0];
                                cdts.Add(t);
                            }
                            else if (cycle == 3)
                            {
                                DataTable t = computeTableSeason2(context, tmp, cs, true)[0];
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
                                DataTable t = computeTableSumAvg2(context, tmp, cs, true, iavgmonth)[0];
                                cdts.Add(t);
                            }
                            else
                            {
                                cdts = dts;
                                break;
                            }
                        }

                        SetLayOutUTypeStatistics1(context, cdts, stat, litems, layouts, code, output, dcs, r["DES_ZH"].ToString(), data2);
                    }
                }
            }
        }
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

    // 取回這次Requset需要的zone
    public List<string> GetAllRequestZones(DataTable zcodes)
    {
        List<string> res = new List<string>();

        foreach (DataRow r in zcodes.Rows)
        {
            string lvl = r["LVL"].ToString();

            if (lvl == "1")
            {
                string code = r["CODE"].ToString();
                bool ishas = res.Exists(t => t == code);
                if (ishas == false)
                    res.Add(code);
            }
            else if (lvl == "2")
            {
                String[] cds = r["CAL_ITEM"].ToString().Split(',');
                foreach (string code in cds)
                {
                    bool ishas = res.Exists(t => t == code);
                    if (ishas == false)
                        res.Add(code);
                }
            }
        }

        return res;
    }
    // 取回這次Requset需要的zone
    public List<string> GetAllOldRequestZones(DataTable zcodes)
    {
        List<string> res = new List<string>();

        foreach (DataRow r in zcodes.Rows)
        {
            string lvl = r["OLD_LVL"].ToString();

            if (lvl == "1")
            {
                string[] cds = r["OLD_COUNTY"].ToString().Split(',');
                foreach (string code in cds)
                {
                    bool ishas = res.Exists(t => t == code);
                    if (ishas == false)
                        res.Add(code);
                }
            }
            else if (lvl == "2")
            {
                String[] cds = r["OLD_CAL_ITEM"].ToString().Split(',');
                foreach (string code in cds)
                {
                    bool ishas = res.Exists(t => t == code);
                    if (ishas == false)
                        res.Add(code);
                }
            }
        }

        return res;
    }

    //統計值
    public void SetBaseStatistics1(HttpContext context, DataTable tar, string iclasses, List<listitem> listitem, string output, string county, Dictionary<string, decimal> data2)
    {
        string sex = context.Request["sex"] as string;
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string classes = cDictionary(iclasses);

        bool hast = output.IndexOf("T") != -1 ? true : false;
        bool hasp = output.IndexOf("P") != -1 ? true : false;
        bool hasd2 = output.IndexOf("D2") != -1 ? true : false;
        bool hasd1 = output.IndexOf("D1") != -1 ? true : false;

        for (int i = 0; i < tar.Rows.Count; i++)
        {
            string y = tar.Rows[i]["YEAR"].ToString(); //有抓比設定年份早一年需跳過

            int rocy = Convert.ToInt32(y);
            string m = tar.Rows[i]["MONTH"].ToString();

            string d = "";
            if (m != "-")
                d = rocy + "年" + m;
            else
                d = rocy + "年";

            if (cycle == 4 || cycle == 5)
                d += "月";

            if (hast)
            {
                listitem tmp = new listitem();
                tmp.m = "總計";
                tmp.c = classes;
                tmp.st = "統計值";

                tmp.st += " (千人)";

                tmp.v = Convert.ToDecimal(tar.Rows[i]["value"].ToString());

                if (tmp.v != -999999)
                    tmp.v = ComputeMod.ComputeAvgPepole(1, tmp.v, 1000);

                if (classes == "工時不足就業者" || classes == "潛在勞動力")
                    tmp.v = CheckHideValue2("LU", tmp.v, y, m, county);
                else
                    tmp.v = CheckHideValue("人口", tmp.v, y, county);

                tmp.d = d;
                tmp.l = "1";
                tmp.ct = county;

                string statid = tar.Rows[i]["STATID"].ToString();
                bool add = false;
                if (statid.IndexOf('T', 4) != -1 && sex.IndexOf('T') != -1)
                {
                    tmp.s = "總計";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('M', 4) != -1 && sex.IndexOf('M') != -1)
                {
                    tmp.s = "男";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('F', 4) != -1 && sex.IndexOf('F') != -1)
                {
                    tmp.s = "女";
                    listitem.Add(tmp);
                    add = true;
                }

                if (data2 != null && add == true)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", tmp.m, tmp.d, tmp.c, tmp.s, tmp.st, tmp.ct);
                    data2.Add(key, tmp.v);
                }
            }
            if (hasp)
            {
                listitem tmp = new listitem();
                tmp.m = "總計";
                tmp.c = classes;
                tmp.st = "統計值";

                tmp.st += " (人)";

                tmp.v = Convert.ToDecimal(tar.Rows[i]["value"].ToString());

                if (tmp.v != -999999)
                    tmp.v = ComputeMod.ComputeAvgPepole(1, tmp.v, 1);

                if (classes == "工時不足就業者" || classes == "潛在勞動力")
                    tmp.v = CheckHideValue2("LU", tmp.v, y, m, county);
                else
                    tmp.v = CheckHideValue("人口", tmp.v, y, county);

                tmp.d = d;
                tmp.l = "1";
                tmp.ct = county;

                string statid = tar.Rows[i]["STATID"].ToString();
                bool add = false;
                if (statid.IndexOf('T', 4) != -1 && sex.IndexOf('T') != -1)
                {
                    tmp.s = "總計";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('M', 4) != -1 && sex.IndexOf('M') != -1)
                {
                    tmp.s = "男";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('F', 4) != -1 && sex.IndexOf('F') != -1)
                {
                    tmp.s = "女";
                    listitem.Add(tmp);
                    add = true;
                }
                if (data2 != null && add == true)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", tmp.m, tmp.d, tmp.c, tmp.s, tmp.st, tmp.ct);
                    data2.Add(key, tmp.v);
                }
            }
            if (hasd2)
            {
                listitem tmp = new listitem();
                tmp.m = "總計";
                tmp.c = classes;
                tmp.st = "統計值";

                tmp.st += "-小數2位 (%)";

                tmp.v = Convert.ToDecimal(tar.Rows[i]["value"].ToString());

                if (tmp.v != -999999)
                    tmp.v = ComputeMod.ComputeWeekPercent(tmp.v, 1, 2);

                if (classes == "LU2" || classes == "LU3" || classes == "LU4")
                    tmp.v = CheckHideValue2("LU", tmp.v, y, m, county);
                else
                    tmp.v = CheckHideValue("人口", tmp.v, y, county);

                tmp.d = d;
                tmp.l = "1";
                tmp.ct = county;

                string statid = tar.Rows[i]["STATID"].ToString();
                bool add = false;
                if (statid.IndexOf('T', 4) != -1 && sex.IndexOf('T') != -1)
                {
                    tmp.s = "總計";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('M', 4) != -1 && sex.IndexOf('M') != -1)
                {
                    tmp.s = "男";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('F', 4) != -1 && sex.IndexOf('F') != -1)
                {
                    tmp.s = "女";
                    listitem.Add(tmp);
                    add = true;
                }
                if (data2 != null && add == true)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", tmp.m, tmp.d, tmp.c, tmp.s, tmp.st, tmp.ct);
                    data2.Add(key, tmp.v);
                }
            }
            if (hasd1)
            {
                listitem tmp = new listitem();
                tmp.m = "總計";
                tmp.c = classes;
                tmp.st = "統計值";

                tmp.st += "-小數1位 (%)";

                tmp.v = Convert.ToDecimal(tar.Rows[i]["value"].ToString());

                if (tmp.v != -999999)
                    tmp.v = ComputeMod.ComputeWeekPercent(tmp.v, 1, 1);

                if (classes == "LU2" || classes == "LU3" || classes == "LU4")
                    tmp.v = CheckHideValue2("LU", tmp.v, y, m, county);
                else
                    tmp.v = CheckHideValue("人口", tmp.v, y, county);

                tmp.d = d;
                tmp.l = "1";
                tmp.ct = county;

                string statid = tar.Rows[i]["STATID"].ToString();
                bool add = false;
                if (statid.IndexOf('T', 4) != -1 && sex.IndexOf('T') != -1)
                {
                    tmp.s = "總計";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('M', 4) != -1 && sex.IndexOf('M') != -1)
                {
                    tmp.s = "男";
                    listitem.Add(tmp);
                    add = true;
                }
                else if (statid.IndexOf('F', 4) != -1 && sex.IndexOf('F') != -1)
                {
                    tmp.s = "女";
                    listitem.Add(tmp);
                    add = true;
                }
                if (data2 != null && add == true)
                {
                    string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", tmp.m, tmp.d, tmp.c, tmp.s, tmp.st, tmp.ct);
                    data2.Add(key, tmp.v);
                }
            }
        }
    }

    private int AlignIndustryPeriods(List<DataTable> male, List<DataTable> female)
    {
        List<DataTable> tables = male.Concat(female).ToList();
        var periods = tables.SelectMany(table => table.AsEnumerable())
            .Select(row => new { Year = row["YEAR"].ToString(), Month = row["MONTH"].ToString() })
            .GroupBy(period => period.Year + "|" + period.Month)
            .Select(group => group.First())
            .OrderBy(period => Convert.ToInt32(period.Year))
            .ToList();

        // Align aggregate components while preserving labels for every query cycle.
        foreach (DataTable table in tables)
        {
            var existing = table.AsEnumerable().ToDictionary(
                row => row["YEAR"].ToString() + "|" + row["MONTH"].ToString(),
                row => row.ItemArray);
            object[] template = table.Rows[0].ItemArray;
            table.Clear();
            foreach (var period in periods)
            {
                object[] values;
                DataRow row = table.NewRow();
                if (existing.TryGetValue(period.Year + "|" + period.Month, out values))
                    row.ItemArray = values;
                else
                {
                    row.ItemArray = (object[])template.Clone();
                    row["YEAR"] = period.Year;
                    row["MONTH"] = period.Month;
                    row["value"] = 0;
                }
                table.Rows.Add(row);
            }
        }
        return periods.Count;
    }

    //統計值-LayOut
    public void SetLayOutStatistics1(HttpContext context, DataTable tar, string iclasses, List<listitem> listitem, string[] layouts, DataTable code, string output, string dcs, string county, Dictionary<string, decimal> data2)
    {
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');
        string classes = cDictionary(iclasses);
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        int smonth = Convert.ToInt32(context.Request["smonth"] as string);

        bool hast = output.IndexOf("T") != -1 ? true : false;
        bool hasp = output.IndexOf("P") != -1 ? true : false;
        bool hasd2 = output.IndexOf("D2") != -1 ? true : false;
        bool hasd1 = output.IndexOf("D1") != -1 ? true : false;
        bool hass = output.IndexOf("S") != -1 ? true : false;

        Dictionary<string, decimal> totalvalue = new Dictionary<string, decimal>();
        Dictionary<string, decimal> totalvalueM = new Dictionary<string, decimal>();
        Dictionary<string, decimal> totalvalueF = new Dictionary<string, decimal>();

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
            List<string> calcodes = setMultiCodes(dcs, cals);
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
            if (dcs == "行業" && GetLayOutIndVer(context) == "12" && calcodes.Count > 1)
                tablecount = AlignIndustryPeriods(dsm, dsf);
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

                    decimal value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        value += Convert.ToDecimal(dsm[k].Rows[j]["value"].ToString());
                        value += Convert.ToDecimal(dsf[k].Rows[j]["value"].ToString());
                    }

                    string dy = y;
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
                            lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                        else if (cycle == 2)
                            lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                        else if (cycle == 3)
                            lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                        else if (cycle == 6)
                            lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                        else
                            lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;
                        lm.ct = county;
                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "統計值";

                        lm.st += " (千人)";

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1000);

                        if (classes == "工時不足就業者" || classes == "潛在勞動力")
                            lm.v = CheckHideValue2("LU", lm.v, y, m, county);

                        lm.v = CheckHideValue(des, lm.v, y, county);
                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                            data2.Add(key, lm.v);
                        }
                    }
                    if (hasp)
                    {
                        listitem lm = new listitem();
                        lm.v = value;
                        if (cycle == 1)
                            lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                        else if (cycle == 2)
                            lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                        else if (cycle == 3)
                            lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                        else if (cycle == 6)
                            lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                        else
                            lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;
                        lm.ct = county;
                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "統計值";

                        lm.st += " (人)";

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                        if (classes == "工時不足就業者" || classes == "潛在勞動力")
                            lm.v = CheckHideValue2("LU", lm.v, y, m, county);

                        lm.v = CheckHideValue(des, lm.v, y, county);
                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                            data2.Add(key, lm.v);
                        }
                    }
                    if (hasd2)
                    {
                        listitem lm = new listitem();
                        lm.v = value;
                        if (cycle == 1)
                            lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                        else if (cycle == 2)
                            lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                        else if (cycle == 3)
                            lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                        else if (cycle == 6)
                            lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                        else
                            lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;
                        lm.ct = county;
                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "統計值";

                        lm.st += "-小數2位 (%)";

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = ComputeMod.ComputeWeekPercent(lm.v, 1, 2);

                        lm.v = CheckHideValue(des, lm.v, y, county);
                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                            data2.Add(key, lm.v);
                        }
                    }
                    if (hasd1)
                    {
                        listitem lm = new listitem();
                        lm.v = value;
                        if (cycle == 1)
                            lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                        else if (cycle == 2)
                            lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                        else if (cycle == 3)
                            lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                        else if (cycle == 6)
                            lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                        else
                            lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;
                        lm.ct = county;
                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "統計值";

                        lm.st += "-小數1位 (%)";

                        if (lm.v != 0 && lm.v != -999999)
                            lm.v = ComputeMod.ComputeWeekPercent(lm.v, 1, 1);

                        lm.v = CheckHideValue(des, lm.v, y, county);
                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                            data2.Add(key, lm.v);
                        }
                    }
                    if (hass)
                    {
                        listitem lm = new listitem();
                        lm.m = dcs;
                        lm.c = des;
                        lm.l = lvl;
                        lm.ct = county;

                        lm.d = d;
                        lm.s = "總計";
                        lm.st = "結構比 (%)";
                        if (des == "總計")
                        {
                            lm.v = ComputeMod.ComputeAvgPercent(value, value, 2);
                            totalvalue[y + "|" + m] = value;
                        }
                        else
                        {
                            lm.v = ComputeMod.ComputeAvgPercent(value, totalvalue[y + "|" + m], 2);
                        }

                        lm.v = CheckHideValue(des, lm.v, y, county);
                        listitem.Add(lm);

                        if (data2 != null)
                        {
                            string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                            data2.Add(key, lm.v);
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

                        decimal value = 0;

                        for (int k = 0; k < dsm.Count; k++)
                        {
                            value += Convert.ToDecimal(dsm[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                                lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                            else if (cycle == 2)
                                lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                            else if (cycle == 3)
                                lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                            else if (cycle == 6)
                                lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                            else
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";
                            lm.ct = county;

                            lm.st += " (千人)";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1000);

                            if (classes == "工時不足就業者" || classes == "潛在勞動力")
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasp)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                                lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                            else if (cycle == 2)
                                lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                            else if (cycle == 3)
                                lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                            else if (cycle == 6)
                                lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                            else
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";
                            lm.ct = county;

                            lm.st += " (人)";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            if (classes == "工時不足就業者" || classes == "潛在勞動力")
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                                lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                            else if (cycle == 2)
                                lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                            else if (cycle == 3)
                                lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                            else if (cycle == 6)
                                lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                            else
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";
                            lm.ct = county;

                            lm.st += "-小數2位 (%)";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = ComputeMod.ComputeWeekPercent(lm.v, 1, 2);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                                lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                            else if (cycle == 2)
                                lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                            else if (cycle == 3)
                                lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                            else if (cycle == 6)
                                lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                            else
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";
                            lm.ct = county;

                            lm.st += "-小數1位 (%)";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = ComputeMod.ComputeWeekPercent(lm.v, 1, 1);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hass)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "結構比 (%)";
                            if (des == "總計")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent(value, value, 2);
                                totalvalueM[y + "|" + m] = value;
                            }
                            else
                            {
                                lm.v = ComputeMod.ComputeAvgPercent(value, totalvalueM[y + "|" + m], 2);
                            }
                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
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

                        decimal value = 0;

                        for (int k = 0; k < dsf.Count; k++)
                        {
                            value += Convert.ToDecimal(dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                                lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                            else if (cycle == 2)
                                lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                            else if (cycle == 3)
                                lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                            else if (cycle == 6)
                                lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                            else
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.st += " (千人)";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1000);

                            if (classes == "工時不足就業者" || classes == "潛在勞動力")
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasp)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                                lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                            else if (cycle == 2)
                                lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                            else if (cycle == 3)
                                lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                            else if (cycle == 6)
                                lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                            else
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.st += " (人)";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            if (classes == "工時不足就業者" || classes == "潛在勞動力")
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd2)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                                lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                            else if (cycle == 2)
                                lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                            else if (cycle == 3)
                                lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                            else if (cycle == 6)
                                lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                            else
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.st += "-小數2位 (%)";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = ComputeMod.ComputeWeekPercent(lm.v, 1, 2);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.v = value;
                            if (cycle == 1)
                                lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1);
                            else if (cycle == 2)
                                lm.v = ComputeMod.ComputeAvgPepole(6, lm.v, 1);
                            else if (cycle == 3)
                                lm.v = ComputeMod.ComputeAvgPepole(3, lm.v, 1);
                            else if (cycle == 6)
                                lm.v = ComputeMod.ComputeAvgPepole(smonth, lm.v, 1);
                            else
                                lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1);

                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.st += "-小數1位 (%)";

                            if (lm.v != 0 && lm.v != -999999)
                                lm.v = ComputeMod.ComputeWeekPercent(lm.v, 1, 1);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hass)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;

                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;

                            lm.d = d;
                            lm.s = "女";
                            lm.st = "結構比 (%)";
                            if (des == "總計")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent(value, value, 2);
                                totalvalueF[y + "|" + m] = value;
                            }
                            else
                            {
                                lm.v = ComputeMod.ComputeAvgPercent(value, totalvalueF[y + "|" + m], 2);
                            }

                            lm.v = CheckHideValue(des, lm.v, y, county);

                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
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
    public void SetLayOutUTypeStatistics1(HttpContext context, List<DataTable> tar, string iclasses, List<listitem> listitem, string[] layouts, DataTable code, string output, string dcs, string county, Dictionary<string, decimal> data2)
    {
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');
        string classes = cDictionary(iclasses);
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);

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

            List<string> calcodes = setMultiCodes(dcs, cals);
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
                if (iclasses == "6")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.st += "-小數2位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent(pupvalue, (pepvalue + pupvalue), 2);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.st += "-小數1位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent(pupvalue, (pepvalue + pupvalue), 1);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "7")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["value"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsm[k].Rows[j]["value"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.st += "-小數2位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 2);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "總計";
                            lm.st = "統計值";

                            lm.st += "-小數1位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 1);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "12" || iclasses == "13" || iclasses == "14" || iclasses == "15")
                {
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

                        string dy = y;
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
                            lm.ct = county;
                            lm.s = "總計";
                            lm.st = "統計值";

                            if (iclasses == "12")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2(des, lm.v, y, m, county);
                            }
                            else if (iclasses == "13")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "14")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "15")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            lm.st += "-小數2位 (%)";

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
                            lm.ct = county;
                            lm.s = "總計";
                            lm.st = "統計值";

                            if (iclasses == "12")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2(des, lm.v, y, m, county);
                            }
                            else if (iclasses == "13")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "14")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "15")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            lm.st += "-小數1位 (%)";

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
                if (iclasses == "6")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                            lm.ct = county;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.st += "-小數2位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pupvalue), (pepvalue + pupvalue), 2);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;

                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.st += "-小數1位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pupvalue), (pepvalue + pupvalue), 1);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "7")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["value"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsm[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.st += "-小數2位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 2);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "男";
                            lm.st = "統計值";

                            lm.st += "-小數1位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 1);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "12" || iclasses == "13" || iclasses == "14" || iclasses == "15")
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
                            sfuvalue += Convert.ToDouble(utables[1].dsm[k].Rows[j]["value"].ToString());
                            truvalue += Convert.ToDouble(utables[2].dsm[k].Rows[j]["value"].ToString());
                            plfvalue += Convert.ToDouble(utables[3].dsm[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                            lm.ct = county;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (iclasses == "12")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2(des, lm.v, y, m, county);
                            }
                            else if (iclasses == "13")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "14")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "15")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }

                            lm.st += "-小數2位 (%)";

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
                            lm.ct = county;
                            lm.s = "男";
                            lm.st = "統計值";

                            if (iclasses == "12")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2(des, lm.v, y, m, county);
                            }
                            else if (iclasses == "13")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "14")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "15")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            lm.st += "-小數1位 (%)";

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
                if (iclasses == "6")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.st += "-小數2位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pupvalue), (pepvalue + pupvalue), 2);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.st += "-小數1位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pupvalue), (pepvalue + pupvalue), 1);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "7")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;

                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["value"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["value"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.st += "-小數2位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 2);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                        if (hasd1)
                        {
                            listitem lm = new listitem();
                            lm.m = dcs;
                            lm.c = des;
                            lm.l = lvl;
                            lm.ct = county;
                            lm.d = d;
                            lm.s = "女";
                            lm.st = "統計值";

                            lm.st += "-小數1位 (%)";
                            lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 1);

                            lm.v = CheckHideValue(des, lm.v, y, county);
                            listitem.Add(lm);

                            if (data2 != null)
                            {
                                string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                                data2.Add(key, lm.v);
                            }
                        }
                    }
                }
                else if (iclasses == "12" || iclasses == "13" || iclasses == "14" || iclasses == "15")
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
                            pepvalue += Convert.ToDouble(utables[0].dsf[k].Rows[j]["value"].ToString());
                            sfuvalue += Convert.ToDouble(utables[1].dsf[k].Rows[j]["value"].ToString());
                            truvalue += Convert.ToDouble(utables[2].dsf[k].Rows[j]["value"].ToString());
                            plfvalue += Convert.ToDouble(utables[3].dsf[k].Rows[j]["value"].ToString());
                        }

                        string dy = y;
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
                            lm.ct = county;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (iclasses == "12")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2(des, lm.v, y, m, county);
                            }
                            else if (iclasses == "13")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "14")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "15")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 2);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            lm.st += "-小數2位 (%)";

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
                            lm.ct = county;
                            lm.s = "女";
                            lm.st = "統計值";

                            if (iclasses == "12")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2(des, lm.v, y, m, county);
                            }
                            else if (iclasses == "13")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue), (decimal)(pepvalue + sfuvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "14")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            else if (iclasses == "15")
                            {
                                lm.v = ComputeMod.ComputeAvgPercent((decimal)(sfuvalue + truvalue + plfvalue), (decimal)(pepvalue + sfuvalue + plfvalue), 1);
                                lm.v = CheckHideValue2("LU", lm.v, y, m, county);
                            }
                            lm.st += "-小數1位 (%)";

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

    //結構比
    public void SetBaseStatistics2(HttpContext context, DataTable tb, string iclasses, List<listitem> listitem, string output, string county, Dictionary<string, decimal> data2)
    {
        string classes = cDictionary(iclasses);
        string xstring = context.Request["sex"] as string;
        string smonth = context.Request["smonth"] as string;
        string[] sex = xstring.Split(',');
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);

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
            cdts = computeTableSumAvg2(context, cdts, iclasses, false, iavgmonth);
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

            string y = mdr[i]["YEAR"].ToString();
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
                        v = CheckHideValue("", mvs, y, county),
                        ct = county
                    };
                    listitem.Add(lm);

                    if (data2 != null)
                    {
                        string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lm.m, lm.d, lm.c, lm.s, lm.st, lm.ct);
                        data2.Add(key, lm.v);
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
                        v = CheckHideValue("", fvs, y, county),
                        ct = county
                    };
                    listitem.Add(lf);
                    if (data2 != null)
                    {
                        string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lf.m, lf.d, lf.c, lf.s, lf.st, lf.ct);
                        data2.Add(key, lf.v);
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
                        v = CheckHideValue("", tvs, y, county),
                        ct = county
                    };
                    listitem.Add(lt);
                    if (data2 != null)
                    {
                        string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", lt.m, lt.d, lt.c, lt.s, lt.st, lt.ct);
                        data2.Add(key, lt.v);
                    }
                }
            }
        }
    }

    public DataTable MerageTable(HttpContext context, List<DataTable> table)
    {
        string type = context.Request["state"] as string;

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

                    workRow["value"] = va;

                    data.Rows.Add(workRow);
                }
            }
            else if (type == "9" || type == "10" || type == "11" || type == "12" || type == "13" || type == "14" || type == "15") // 勞動力低度運用指標
            {
                DataTable d1 = table[0]; // PEP
                DataTable d2 = table[1]; // SFU
                DataTable d3 = table[2]; // TRU
                DataTable d4 = table[3]; // PLF

                if (type == "9") // SFU
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
                else if (type == "10") // TRU
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
                else if (type == "11") // PLF
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
                else if (type == "12")
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
                else if (type == "13")
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

                        int y = Convert.ToInt32(workRow["YEAR"]);
                        int m = Convert.ToInt32(workRow["MONTH"]);
                        if (y == 113 && m <= 5)
                            va = -999999;
                        else if (y < 113)
                            va = -999999;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
                else if (type == "14")
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

                        int y = Convert.ToInt32(workRow["YEAR"]);
                        int m = Convert.ToInt32(workRow["MONTH"]);
                        if (y == 113 && m <= 5)
                            va = -999999;
                        else if (y < 113)
                            va = -999999;

                        workRow["value"] = va;
                        data.Rows.Add(workRow);
                    }
                }
                else if (type == "15")
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

                        int y = Convert.ToInt32(workRow["YEAR"]);
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
            decimal sum = 0;
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;

                    decimal avg = sum;
                    avg = ComputeMod.ComputeAvgPepole(12, avg, 1);
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                }
            }

            ldt.Add(data);
        }

        return ldt;
    }

    //計算年-率
    public List<DataTable> computeTableYear2(HttpContext context, List<DataTable> table, string iclasses, bool islayout)
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
                int count = 0;
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
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "-";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        decimal va = sum;
                        if (count != 12) va = 0;

                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
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
        else if (iclasses == "3") //勞動力
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
        else if (iclasses == "2") //15歲以上民間人口
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

                    decimal va = sum1 + sum2 + sum3;
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
        else if (iclasses == "12" || iclasses == "13" || iclasses == "14" || iclasses == "15")
        {
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
                    if (iclasses == "12")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                    }
                    else if (iclasses == "13")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                    }
                    else if (iclasses == "14")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                    }
                    else if (iclasses == "15")
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

        ldt.Add(data);

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
            decimal sum = 0;
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;

                    decimal avg = sum;
                    avg = ComputeMod.ComputeAvgPepole(6, avg, 1);
                    if (count != 6) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "下半年";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                }
                else if (month == 6)
                {
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;

                    decimal avg = sum;
                    avg = ComputeMod.ComputeAvgPepole(6, avg, 1);
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                }
            }
            ldt.Add(data);
        }

        return ldt;
    }

    //計算半年-率
    public List<DataTable> computeTableHalfYear2(HttpContext context, List<DataTable> table, string iclasses, bool islayout)
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
                int count = 0;
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
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "上半年";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        decimal va = sum;
                        if (count != 6) va = 0;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if (month == 12)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "下半年";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        decimal va = sum;
                        if (count != 6) va = 0;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
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
        else if (iclasses == "3") //勞動力
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

                    decimal va = sum1 + sum2;
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

                    decimal va = sum1 + sum2;
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
        else if (iclasses == "2") //15歲以上民間人口
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

                    decimal va = sum1 + sum2 + sum3;
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

                    decimal va = sum1 + sum2 + sum3;
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
        else if (iclasses == "12" || iclasses == "13" || iclasses == "14" || iclasses == "15")
        {
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
                    if (iclasses == "12")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                    }
                    else if (iclasses == "13")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                    }
                    else if (iclasses == "14")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                    }
                    else if (iclasses == "15")
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
                    if (iclasses == "12")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), -1);
                    }
                    else if (iclasses == "13")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), -1);
                    }
                    else if (iclasses == "14")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), -1);
                    }
                    else if (iclasses == "15")
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

            decimal sum = 0;
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                    decimal avg = sum;
                    avg = ComputeMod.ComputeAvgPepole(3, avg, 1);
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                    decimal avg = sum;
                    avg = ComputeMod.ComputeAvgPepole(3, avg, 1);
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                    decimal avg = sum;
                    avg = ComputeMod.ComputeAvgPepole(3, avg, 1);
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                    decimal avg = sum;
                    avg = ComputeMod.ComputeAvgPepole(3, avg, 1);
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                }
            }

            ldt.Add(data);
        }

        return ldt;
    }

    //計算季-率
    public List<DataTable> computeTableSeason2(HttpContext context, List<DataTable> table, string iclasses, bool islayout)
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
                int count = 0;
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
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第1季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        decimal va = sum;
                        if (count != 3) va = 0;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if (month == 6)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第2季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        decimal va = sum;
                        if (count != 3) va = 0;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if (month == 9)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第3季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        decimal va = sum;
                        if (count != 3) va = 0;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if (month == 12)
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "第4季";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        decimal va = sum;
                        if (count != 3) va = 0;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
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
        else if (iclasses == "4") //失業週期
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

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1), -1);

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

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1), -1);

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

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1), -1);

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

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1), -1);

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
        else if (iclasses == "3") //勞動力
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

                    decimal va = sum1 + sum2;
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

                    decimal va = sum1 + sum2;
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

                    decimal va = sum1 + sum2;
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

                    decimal va = sum1 + sum2;
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
        else if (iclasses == "2") //15歲以上民間人口
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

                    decimal va = sum1 + sum2 + sum3;
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

                    decimal va = sum1 + sum2 + sum3;
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

                    decimal va = sum1 + sum2 + sum3;
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

                    decimal va = sum1 + sum2 + sum3;
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
        else if (iclasses == "12" || iclasses == "13" || iclasses == "14" || iclasses == "15")
        {
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
                    if (iclasses == "12")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "13")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "14")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
                    }
                    else if (iclasses == "15")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
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
                    if (iclasses == "12")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "13")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "14")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
                    }
                    else if (iclasses == "15")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
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
                    if (iclasses == "12")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "13")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "14")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
                    }
                    else if (iclasses == "15")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
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
                    if (iclasses == "12")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "13")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "14")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
                    }
                    else if (iclasses == "15")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
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

        return ldt;
    }

    //計算累計
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

            decimal sum = 0;
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                    decimal avg = sum;
                    avg = ComputeMod.ComputeAvgPepole(smonth, avg, 1);
                    if (count != smonth) avg = 0;

                    workRow["YEAR"] = dt[i].Rows[j]["YEAR"].ToString();
                    workRow["STATID"] = dt[i].Rows[j]["STATID"].ToString();
                    workRow["MONTH"] = "1月至" + smonth + "月";
                    workRow["value"] = avg.ToString();

                    data.Rows.Add(workRow);

                    sum = 0;
                    count = 0;
                }
                else if ((month <= smonth && lmonth == -1) || (month > lmonth))
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
                    sum += Convert.ToDecimal(dt[i].Rows[j]["value"].ToString());
                    count++;
                }
            }

            ldt.Add(data);
        }

        return ldt;
    }

    //計算累計-率
    public List<DataTable> computeTableSumAvg2(HttpContext context, List<DataTable> table, string iclasses, bool islayout, int smonth)
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
                int count = 0;
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
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["MONTH"] = "1月至" + smonth + "月";
                        workRow["STATID"] = d.Rows[i]["STATID"];

                        sum += Convert.ToInt32(d.Rows[i]["value"].ToString());
                        count++;

                        decimal va = sum;
                        if (count != smonth) va = 0;
                        workRow["value"] = va;

                        data.Rows.Add(workRow);

                        sum = 0;
                        count = 0;
                    }
                    else if ((month <= smonth && lmonth == -1) || (month > lmonth))
                    {
                        DataRow workRow = data.NewRow();
                        workRow["YEAR"] = d.Rows[i]["YEAR"];
                        workRow["STATID"] = d.Rows[i]["STATID"];
                        workRow["MONTH"] = "1月至" + smonth + "月";

                        workRow["value"] = 0;

                        data.Rows.Add(workRow);

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
                else if ((month <= smonth && lmonth == -1) || (month > lmonth))
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
                else if ((month <= smonth && lmonth == -1) || (month > lmonth))
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
        else if (iclasses == "4") //失業週期
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

                    decimal va = ComputeMod.ComputeAvgPercent((sum2), (sum1), -1);

                    if (va == -999999)
                        workRow["value"] = 0;
                    else
                        workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if ((month <= smonth && lmonth == -1) || (month > lmonth))
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
        else if (iclasses == "3") //勞動力
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

                    decimal va = sum1 + sum2;
                    workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if ((month <= smonth && lmonth == -1) || (month > lmonth))
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
        else if (iclasses == "2") //15歲以上民間人口
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

                    decimal va = sum1 + sum2 + sum3;
                    workRow["value"] = va;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if ((month <= smonth && lmonth == -1) || (month > lmonth))
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
        else if (iclasses == "12" || iclasses == "13" || iclasses == "14" || iclasses == "15") // 勞動力低度運用指標
        {
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
                    if (iclasses == "12")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "13")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3), (decimal)(sum1 + sum2), 2);
                    }
                    else if (iclasses == "14")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
                    }
                    else if (iclasses == "15")
                    {
                        va = (double)ComputeMod.ComputeAvgPercent((decimal)(sum2 + sum3 + sum4), (decimal)(sum1 + sum2 + sum4), 2);
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

        return ldt;
    }

    public DataTable GetYearTable(HttpContext context, int syear, int eyear, List<string> ccode, List<string> codes, string table)
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

            sqlStr += "AND ( ";
            for (int i = 0; i < ccode.Count; i++)
            {
                if (i != 0)
                    sqlStr += " OR ";

                sqlStr += " COUNTY = @COUNTY_" + i;
            }
            sqlStr += ") ";

            sqlStr += @" ORDER BY COUNTY, STATID, YEAR, MONTH ";
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

                for (int i = 0; i < ccode.Count; i++)
                {
                    command.Parameters.Add(new SqlParameter("@COUNTY_" + i, ccode[i]));
                }

                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                DataTable data = ds.Tables[0];

                dt = data;
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

    public DataTable GetZoneCode(string[] zone, bool isold, rdata rdata)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            string CAT = "";
            List<string> cs = new List<string>();

            if (isold)
            {
                CAT = "縣市(舊)";
                sqlStr = @" 
                    SELECT * 
                    FROM CODE WHERE CAT=@CAT AND INTERNAL = 1 
                ";
            }
            else
            {
                CAT = "縣市(新)";

                sqlStr = @" 
                    SELECT [CODE].*, [COUNTY_CONTRAST].[OLD_COUNTY], [COUNTY_CONTRAST].[OLD_COUNTY_NAME], [COUNTY_CONTRAST].[OLD_CAL_ITEM], [COUNTY_CONTRAST].[LVL] as OLD_LVL
                    FROM [CODE] 
                    LEFT JOIN [COUNTY_CONTRAST] on [COUNTY_CONTRAST].[NEW_COUNTY] = [CODE].[CODE]
                    WHERE CAT=@CAT AND INTERNAL = 1 
                ";
            }

            for (int i = 0; i < zone.Length; i++)
            {
                string zstr = "";
                if (isold == true)
                    zstr = DictionaryZone_Old(zone[i]);
                else
                    zstr = DictionaryZone_New(zone[i]);

                cs.Add(zstr);
                rdata.citys.Add(zstr);
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

    public List<DataTable> GetAgeTables(HttpContext context, string classes, List<string> ocode)
    {
        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        int isy = Convert.ToInt32(sy) + 1911;
        int iey = Convert.ToInt32(ey) + 1911;

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

            DataTable tmp = GetYearTable(context, isy, iey, ocode, cs, tablestring);
            dlist.Add(tmp);
        }

        return dlist;
    }

    public List<DataTable> GetEdtionTables(HttpContext context, string classes, List<string> ocode)
    {
        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        int isy = Convert.ToInt32(sy) + 1911;
        int iey = Convert.ToInt32(ey) + 1911;
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
                    if (tlist[i] == "SFU10" || tlist[i] == "TRU10" || tlist[i] == "PLF10")
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
            DataTable tmp = GetYearTable(context, isy, iey, ocode, cs, tablestring);
            dlist.Add(tmp);
        }

        return dlist;
    }

    public List<DataTable> GetIndTables(HttpContext context, string classes, string ver, List<string> ncode, List<string> ocode, bool isold)
    {
        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        int isy = Convert.ToInt32(sy) + 1911;
        int iey = Convert.ToInt32(ey) + 1911;

        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        string table = tablestring;
        string source = "IND" + tablecode;
        List<string> codet = ncode;
        if (ver == "6")
        {
            table = "DB2";
            source = "IND07";
            // 需要判斷現在是否是新縣市 要轉換成舊縣市 2022.07.08
            if (!isold)
                codet = ocode;
        }
        else if (ver == "7")
        {
            table = "DB4";
            source = "IND08";
            // 需要判斷現在是否是新縣市 要轉換成舊縣市 2022.07.08
            if (!isold)
                codet = ocode;
        }
        else if (ver == "8-10" && !isold)
        {
            table = "SHIEN15A";
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

        DataTable tmp = GetYearTable(context, isy, iey, codet, cs, table);
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetOCCTables(HttpContext context, string classes, string ver, List<string> ncode, List<string> ocode, bool isold)
    {
        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        int isy = Convert.ToInt32(sy) + 1911;
        int iey = Convert.ToInt32(ey) + 1911;

        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        string iver = GetLayOutIndVer(context);
        string table = tablestring;
        string source = "OCC" + tablecode;
        List<string> codet = ncode;
        /* if (iver == "6")
        {
            table = "DB2";
            source = "OCC07";
            codet = GetCountyOld(ocode);
        }
        else if (iver == "7")
        {
            table = "DB4";
            source = "OCC08";
            codet = GetCountyOld(ocode);
        } */
        if (ver == "5")
        {
            table = "SHIEN12A";
            source = "OCC05";

            // 需要判斷現在是否是新縣市 要轉換成舊縣市 2022.07.08
            if (!isold)
                codet = ocode;
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
        DataTable tmp = GetYearTable(context, isy, iey, codet, cs, table);
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetCOWTables(HttpContext context, string classes, List<string> ocode)
    {
        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        int isy = Convert.ToInt32(sy) + 1911;
        int iey = Convert.ToInt32(ey) + 1911;

        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        string cowcode = "COW" + tablecode;

        List<string> cs = new List<string>();
        for (int j = 0; j < sex.Length; j++)
        {
            for (int k = 0; k < layouts.Length; k++)
            {
                string code = cowcode + sex[j] + "0000X00000" + layouts[k] + "000000";
                cs.Add(code);
            }
        }
        DataTable tmp = GetYearTable(context, isy, iey, ocode, cs, tablestring);
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetRONTables(HttpContext context, string classes, List<string> ocode)
    {
        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        int isy = Convert.ToInt32(sy) + 1911;
        int iey = Convert.ToInt32(ey) + 1911;

        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();

        List<string> tlist = Dictionary(context);

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        string roncode = "RON" + tablecode;

        List<string> cs = new List<string>();
        for (int j = 0; j < sex.Length; j++)
        {
            for (int k = 0; k < layouts.Length; k++)
            {
                string code = roncode + sex[j] + "0000X000000000" + layouts[k] + "00";
                cs.Add(code);
            }
        }

        DataTable tmp = GetYearTable(context, isy, iey, ocode, cs, tablestring);
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetROUTables(HttpContext context, string classes, List<string> ocode)
    {
        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        int isy = Convert.ToInt32(sy) + 1911;
        int iey = Convert.ToInt32(ey) + 1911;

        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (xstring.IndexOf("T") != -1)
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();
        List<string> tlist = Dictionary(context);

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        string roucode = "ROU" + tablecode;
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
            DataTable tmp = GetYearTable(context, isy, iey, ocode, cs, tablestring);
            dlist.Add(tmp);
        }

        return dlist;
    }

    public List<sortitem> GetSortItems(string classes, string ver, string cs)
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

            sortitem item = new sortitem()
            {
                name = des,
                level = lvl,
                classes = cs,
            };

            items.Add(item);
        }

        return items;
    }

    public DataTable GetCountyOld(DataTable ocode)
    {
        if (ocode.Rows[0]["CAT"].ToString() == "縣市(舊)")
            return ocode;

        String sqlStr = "";
        DataSet ds = new DataSet();
        DataTable dt = new DataTable();
        dt.Columns.Add("CODE", typeof(String));
        dt.Columns.Add("DES_ZH", typeof(String));
        dt.Columns.Add("CAL_ITEM", typeof(String));
        dt.Columns.Add("LVL", typeof(String));

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM COUNTY_CONTRAST 
                        WHERE NEW_COUNTY_NAME = @COUNTY_NAME ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@COUNTY_NAME", ocode.Rows[0]["DES_ZH"])
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

                DataTable ot = ds.Tables[0];
                for (int i = 0; i < ot.Rows.Count; i++)
                {
                    DataRow workRow = dt.NewRow();
                    workRow["CODE"] = ot.Rows[i]["NEW_COUNTY"].ToString();
                    workRow["DES_ZH"] = ot.Rows[i]["NEW_COUNTY_NAME"].ToString();
                    workRow["LVL"] = "2";

                    if (ot.Rows[i]["LVL"].ToString() != "2")
                        workRow["CAL_ITEM"] = ot.Rows[i]["OLD_COUNTY"].ToString();
                    else
                        workRow["CAL_ITEM"] = ot.Rows[i]["OLD_CAL_ITEM"].ToString();

                    dt.Rows.Add(workRow);
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

        return dt;
    }

    public List<string> Dictionary(HttpContext context)
    {
        List<string> list = new List<string>();
        string type = context.Request["state"] as string;

        string popcode = "POP" + tablecode;
        string pepcode = "PEP" + tablecode;
        string pupcode = "PUP" + tablecode;
        string nlfcode = "NLF" + tablecode;
        string sfucode = "SFU10";
        string trucode = "TRU10";
        string plfcode = "PLF10";

        switch (type)
        {
            case "1":
                list.Add(popcode);
                break;
            case "2":
            case "7":
                list.Add(pepcode);
                list.Add(pupcode);
                list.Add(nlfcode);
                break;
            case "3":
            case "6":
                list.Add(pepcode);
                list.Add(pupcode);
                break;
            case "4":
                list.Add(nlfcode);
                break;
            case "5":
                list.Add(pupcode);
                break;
            case "8":
                list.Add(pepcode);
                break;
            case "9":
            case "10":
            case "11":
            case "12":
            case "13":
            case "14":
            case "15":
                list.Add(pepcode);
                list.Add(sfucode);
                list.Add(trucode);
                list.Add(plfcode);
                break;
        }

        return list;
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

    public List<string> setMultiCodes(string classes, string[] codes)
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
                ver = "6";
                break;
        }

        return ver;
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

    public string cDictionary(string classes)
    {
        switch (classes)
        {
            case "1":
                return "總人口數";
            case "2":
                return "十五歲以上民間人口";
            case "3":
                return "勞動力";
            case "4":
                return "非勞動力";
            case "5":
                return "失業者";
            case "6":
                return "失業率";
            case "7":
                return "勞動力參與率";
            case "8":
                return "就業者";
            case "9":
                return "4週失業者";
            case "10":
                return "工時不足就業者";
            case "11":
                return "潛在勞動力";
            case "12":
                return "LU1";
            case "13":
                return "LU2";
            case "14":
                return "LU3";
            case "15":
                return "LU4";
            default:
                return "";
        }
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

    public String DictionaryZone_New(string zone)
    {
        switch (zone)
        {
            case "1":
                return "臺灣地區";
            case "2":
                return "北部區域";
            case "3":
                return "新北市";
            case "4":
                return "臺北市";
            case "5":
                return "桃園市";
            case "6":
                return "基隆市";
            case "7":
                return "新竹市";
            case "8":
                return "宜蘭縣";
            case "9":
                return "新竹縣";
            case "10":
                return "中部區域";
            case "11":
                return "臺中市";
            case "12":
                return "苗栗縣";
            case "13":
                return "彰化縣";
            case "14":
                return "南投縣";
            case "15":
                return "雲林縣";
            case "16":
                return "南部區域";
            case "17":
                return "臺南市";
            case "18":
                return "高雄市";
            case "19":
                return "嘉義市";
            case "20":
                return "嘉義縣";
            case "21":
                return "屏東縣";
            case "22":
                return "澎湖縣";
            case "23":
                return "東部區域";
            case "24":
                return "臺東縣";
            case "25":
                return "花蓮縣";
            default:
                return "";
        }
    }

    public String DictionaryZone_Old(string zone)
    {
        switch (zone)
        {
            case "1":
                return "臺灣地區";
            case "2":
                return "北部區域";
            case "3":
                return "臺北市";
            case "4":
                return "基隆市";
            case "5":
                return "新竹市";
            case "6":
                return "臺北縣";
            case "7":
                return "宜蘭縣";
            case "8":
                return "桃園縣";
            case "9":
                return "新竹縣";
            case "10":
                return "中部區域";
            case "11":
                return "臺中市";
            case "12":
                return "苗栗縣";
            case "13":
                return "臺中縣";
            case "14":
                return "彰化縣";
            case "15":
                return "南投縣";
            case "16":
                return "雲林縣";
            case "17":
                return "南部區域";
            case "18":
                return "高雄市";
            case "19":
                return "嘉義市";
            case "20":
                return "臺南市";
            case "21":
                return "嘉義縣";
            case "22":
                return "臺南縣";
            case "23":
                return "高雄縣";
            case "24":
                return "屏東縣";
            case "25":
                return "澎湖縣";
            case "26":
                return "東部區域";
            case "27":
                return "臺東縣";
            case "28":
                return "花蓮縣";
            default:
                return "";
        }
    }

    public decimal CheckHideValue(string des, decimal value, string sy, string county)
    {
        int y = Convert.ToInt32(sy);
        if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
            return -999999;
        if (y < 82 && county != "高雄市" && county != "臺北市")
            return -999999;

        return value;
    }

    public decimal CheckHideValue2(string des, decimal value, string sy, string sm, string county)
    {
        int y = Convert.ToInt32(sy);
        if (y >= 1911) y = y - 1911;
        if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
            return -999999;
        if (y < 82 && county != "高雄市" && county != "臺北市")
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

    // excel
    public string GetExcelForCityIntranet(HttpContext context)
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

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        string cycle = context.Request["cycle"] as string;
        string smonth = context.Request["smonth"] as string;

        string state = context.Request["state"] as string;
        string[] classes = (context.Request["classes"] as string).Split(',');
        string[] ssex = (context.Request["sex"] as string).Replace("T", "總計").Replace("M", "男").Replace("F", "女").Split(',');
        string[] output = (context.Request["output"] as string).Replace("T", "統計值 (千人)").Replace("P", "統計值 (人)").Replace("S", "結構比 (%)").Replace("D2", "統計值-小數2位 (%)").Replace("D1", "統計值-小數1位 (%)").Split(',');
        string exporttype = context.Request["exporttype"] as string;

        try
        {
            Supergeo.Tools.HiResTimer timer = new Supergeo.Tools.HiResTimer();
            Int64 StartTime = timer.Value;

            string title = GetExportTitle(context);
            ISheet ExcelSheet = null;
            ExcelSheet = workbook.CreateSheet("sheet");

            rdata dat = new rdata();
            string isnew = context.Request["isnew"] as string;

            Int64 oneFromAddr = timer.Value;

            if (isnew == "Y")
                dat = GetRequestTablesForNew2(context);
            else if (isnew == "N")
                dat = GetRequestTablesForOld2(context);

            // 處理sort 變成 Dictionary
            Dictionary<string, List<string>> sort = new Dictionary<string, List<string>>();
            foreach (sortitem item in dat.sort)
            {
                if (item.name == "軍人") continue;

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

            WriteLog("縣市筆數:" + dat.citys.Count);
            WriteLog("資料筆數:" + dat.data.Count);
            WriteLog("Layout筆數:" + dat.sort.Count);

            //title
            ExcelSheet.CreateRow(0);
            ExcelSheet.GetRow(0).CreateCell(0).SetCellValue(title);
            ExcelSheet.GetRow(0).CreateCell(3);
            ExcelSheet.AddMergedRegion(new NPOI.SS.Util.CellRangeAddress(0, 0, 0, 3));

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
                foreach (string ci in dat.citys)
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
                        string rc = ClassesDictionary(r);
                        List<string> tar = sort[r];
                        foreach (string r2 in tar)
                        {
                            foreach (string r3 in ssex)
                            {
                                foreach (string r4 in output)
                                {
                                    string key = string.Format("{0}_{1}_{2}_{3}_{4}_{5}", rc, c, r2, r3, r4, ci);
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
                }

                if (dat.citys.Count > 1)
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
            string tmp = date.Replace("年上半年", "1").Replace("年下半年", "2");
            int itmp = Convert.ToInt32(tmp);
            return itmp;
        }
        else if (cycle == "3") // 季
        {
            string tmp = date.Replace("年第1季", "1").Replace("年第2季", "2").Replace("年第3季", "3").Replace("年第4季", "4");
            int itmp = Convert.ToInt32(tmp);
            return itmp;
        }
        else if (cycle == "4" || cycle == "5") // 月
        {
            string tmp = date.Replace("年", "_").Replace("月", "_");
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

    public string GetExportTitle(HttpContext context)
    {
        string state = context.Request["state"] as string;
        string[] classes = (context.Request["classes"] as string).Split(',');
        string isnew = context.Request["isnew"] as string;
        string type = context.Request["subtype"] as string;

        string t = cDictionary(state);
        string c = "";
        string s = "";
        string n = "";

        foreach (string cstr in classes)
        {
            if (c != "") c += "_";
            c += ClassesDictionary(cstr);
        }

        if (classes.Length == 1)
        {
            if (isnew == "N")
            {
                if (classes[0] == "4")
                {
                    if (type == "1") s = "舊行業(6th)(67~90年)";
                    else if (type == "2") s = "舊行業(7th)(88~95年)";
                    else if (type == "3") s = "新行業(8th)(96年~99年)";
                }
                else if (classes[0] == "5")
                {
                    if (type == "3") s = "舊職業(5th)(67~99年)";
                }
            }
            else if (classes[0] == "4")
            {
                if (type == "1") s = "舊行業(6th)(67~90年)";
                else if (type == "2") s = "舊行業(7th)(88~95年)";
                else if (type == "4") s = "舊行業(12th)(96年以後)";
                else if (type == "5") s = "新行業(12th)(105年以後)";
            }
            else if (classes[0] == "5")
            {
                if (type == "1") s = "舊職業(5th)(67~99年)";
                else if (type == "4") s = "新職業(6th)(100年以後)";
            }
        }

        if (isnew == "Y") n = "改制後-";
        else n = "改制前-";

        return (n + t + '-' + c + s);
    }

    public bool IsReusable {
        get {
            return false;
        }
    }

}
