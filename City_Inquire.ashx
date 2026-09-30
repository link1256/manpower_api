<%@ WebHandler Language="C#" Class="City_Inquire" %>

using Newtonsoft.Json;
using System;
using System.Data;
using System.Web;
using System.Data.SqlClient;
using System.Reflection;
using System.Collections.Generic;
using System.Linq;
using System.Configuration;
using Supergeo.ComputeMod;

public class City_Inquire : IHttpHandler {
    String sqlConnstr = System.Configuration.ConfigurationManager.ConnectionStrings["CensusGISADONet"].ConnectionString;
    ComputeMod ComputeMod = new ComputeMod();
    public void ProcessRequest (HttpContext context) {
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
            context.Response.Write(ex);
        }
    }
    public String GetBaseInfo(HttpContext context)
    {
        String jData = "";

        MNYear target = GetYears();
        jData = JsonConvert.SerializeObject(new { MNYear = target });

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
                FROM STATDATA_SHIEN15A 
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
                d.minyear = 1993;
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
        }
        return roctype;
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
                    new SqlParameter("@FunctionName", "縣市資料查詢"),
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

    public void SetBrowserCount(HttpContext context)
    {
        string tstring = context.Request["classes"] as string;
        string[] types = tstring.Split(',');

        foreach (string type in types)
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
                               VALUES (@Time, '縣市資料查詢', @StatisticItem, 1, 0, 0)";
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
    }

    public void SetTableCount(HttpContext context)
    {
        string tstring = context.Request["classes"] as string;
        string[] types = tstring.Split(',');
        foreach (string type in types)
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
                               SET DownloadTable=@DownloadTable 
                               WHERE Sno=@Sno ";
                }
                else
                {
                    sqlStr = @"INSERT INTO Count_List (Time, FunctionName, StatisticItem, BrowseCount, DownloadTable, DownloadChart) 
                               VALUES (@Time, '縣市資料查詢', @StatisticItem, 0, 1, 0)";
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
    }

    public void SetChartCount(HttpContext context)
    {
        string tstring = context.Request["classes"] as string;
        string[] types = tstring.Split(',');
        foreach (string type in types)
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
                               SET DownloadChart=@DownloadChart 
                               WHERE Sno=@Sno ";
                }
                else
                {
                    sqlStr = @"INSERT INTO Count_List (Time, FunctionName, StatisticItem, BrowseCount, DownloadTable, DownloadChart) 
                               VALUES (@Time, '縣市資料查詢', @StatisticItem, 0, 0, 1)";
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
    }

    public class listitem
    {
        public string d { get; set; } //年月
        public string c { get; set; } //統計項
        public string s { get; set; } //性別
        public string st { get; set; } //資料屬性
        public decimal v { get; set; } //值
        public string d_e { get; set; } //年月
        public string c_e { get; set; } //統計項
        public string s_e { get; set; } //性別
        public string st_e { get; set; } //資料屬性
        public string ct { get; set; } //縣市
        public string ct_e { get; set; } //縣市
    }

    public class formitems
    {
        public string name { get; set; } //表名稱
        public string name_eng { get; set; } //表名稱
        public bool tshow { get; set; }
        public bool drawSet { get; set; }
        public bool show { get; set; }
        public object chartOption { get; set; }
        public List<listitem> data { get; set; }
    }

    public String GetRequestTables(HttpContext context)
    {
        string jData = "";

        SetBrowserCount(context);

        string clstring = context.Request["classes"] as string;
        string zostring = context.Request["zone"] as string;
        string sexstring = context.Request["sex"] as string;
        string statstring = context.Request["statistics"] as string;

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        string[] classes = clstring.Split(',');
        string[] zones = zostring.Split(',');
        string[] sex = sexstring.Split(',');
        string[] stats = statstring.Split(',');

        List<formitems> list = new List<formitems>();

        for (int i = 0; i < zones.Length; i++)
        {
            List<ClassesTable> tar = GetZoneTables(context, sy, ey, sex, zones[i]);
            formitems l = new formitems() {
                name = "",
                name_eng = "",
                show = true,
                tshow = true,
                drawSet = false,
                chartOption = new object(),
                data = new List<listitem>()
            };
            l.name = DictionaryZone(zones[i]);
            l.name_eng = DictionaryZone_Eng(zones[i]);
            for (int j = 0; j < stats.Length; j++)
            {
                switch (stats[j])
                {
                    case "1":
                        SetStatistics1(context, l, tar, classes, sex);
                        break;
                    case "2":
                        SetStatistics2(context, l, tar, classes, sex);
                        break;
                    case "3":
                        SetStatistics3(context, l, tar, classes, sex);
                        break;
                    case "4":
                        SetStatistics4(context, l, tar, classes, sex);
                        break;
                    case "5":
                        SetStatistics5(context, l, tar, classes, sex);
                        break;
                    case "6":
                        SetStatistics6(context, l, tar, classes, sex);
                        break;
                }
            }
            list.Add(l);
        }
        jData = JsonConvert.SerializeObject(list);

        return (jData);
    }

    public String GetRequestCombineTables(HttpContext context)
    {
        string jData = "";

        SetBrowserCount(context);

        string clstring = context.Request["classes"] as string;
        string zostring = context.Request["zone"] as string;
        string sexstring = context.Request["sex"] as string;
        string statstring = context.Request["statistics"] as string;

        string sy = context.Request["startyear"] as string;
        string ey = context.Request["endyear"] as string;
        string[] classes = clstring.Split(',');
        string[] zones = zostring.Split(',');
        string[] sex = sexstring.Split(',');
        string[] stats = statstring.Split(',');

        int isy = Convert.ToInt16(sy);
        if (isy <= 82)
            sy = "82";

        List<formitems> list = new List<formitems>();
        formitems l = new formitems() {
            name = "",
            name_eng = "",
            show = true,
            tshow = true,
            drawSet = false,
            chartOption = new object(),
            data = new List<listitem>()
        };
        list.Add(l);

        string lname = "";
        string ename = "";
        for (int i = 0; i < zones.Length; i++)
        {
            l.name = DictionaryZone(zones[i]);
            l.name_eng = DictionaryZone_Eng(zones[i]);

            if (lname != "") lname += ",";
            lname += DictionaryZone(zones[i]);

            if (ename != "") ename += ",";
            ename += DictionaryZone_Eng(zones[i]);

            List<ClassesTable> tar = GetZoneTables(context, sy, ey, sex, zones[i]);
            for (int j = 0; j < stats.Length; j++)
            {
                switch (stats[j])
                {
                    case "1":
                        SetStatistics1(context, l, tar, classes, sex);
                        break;
                    case "2":
                        SetStatistics2(context, l, tar, classes, sex);
                        break;
                    case "3":
                        SetStatistics3(context, l, tar, classes, sex);
                        break;
                    case "4":
                        SetStatistics4(context, l, tar, classes, sex);
                        break;
                    case "5":
                        SetStatistics5(context, l, tar, classes, sex);
                        break;
                    case "6":
                        SetStatistics6(context, l, tar, classes, sex);
                        break;
                }
            }
        }
        l.name = lname;
        l.name_eng = ename;

        jData = JsonConvert.SerializeObject(list);

        return (jData);
    }

    public List<int> GetSexTables(List<ClassesTable> tar, string sex)
    {
        List<int> idxs = new List<int>();
        for (int i = 0; i < tar.Count; i++)
        {
            if (tar[i].sex == sex)
                idxs.Add(i);
        }

        return idxs;
    }

    //統計值
    public void SetStatistics1(HttpContext context, formitems litem, List<ClassesTable> tar, string[] classes, string[] sex)
    {
        string type = context.Request["infotype"] as string;
        int infotype = Convert.ToInt32(type);
        int sy = Convert.ToInt32(context.Request["startyear"] as string);
        if (sy <= 82) sy = 82;

        List<int> Tdxs = GetSexTables(tar, "T");
        List<int> Mdxs = GetSexTables(tar, "M");
        List<int> Fdxs = GetSexTables(tar, "F");
        for (int i = 0; i < classes.Length; i++)
        {
            if (classes[i] == "LAF")
            {
                string cal = "勞動力";
                string ecal = "Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "統計值 (千人)";
                        it.st_e = "Statistical value (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        decimal dPEP = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal dPUP = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();

                            it.v = ComputeMod.ComputeAvgPepole(12, (dPEP + dPUP), 1000);
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                            it.v = ComputeMod.ComputeAvgPepole(6, (dPEP + dPUP), 1000);
                        }

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "FPS")
            {
                string cal = "15歲以上民間人口";
                string ecal = "Civilian Population Aged 15 Years & Over";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "統計值 (千人)";
                        it.st_e = "Statistical value (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        decimal pepv = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal pupv = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal nlfv = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();

                            it.v = ComputeMod.ComputeAvgPepole(12, (pepv + pupv + nlfv), 1000);
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                            it.v = ComputeMod.ComputeAvgPepole(6, (pepv + pupv + nlfv), 1000);
                        }

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "LFP")
            {
                string cal = "勞動力參與率";
                string ecal = "Labor Force Participation Rate";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "統計值 (%)";
                        it.st_e = "Statistical value (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal pepv = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal pupv = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal nlfv = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeAvgPercent((pepv + pupv), (pepv + pupv + nlfv), 1);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "UPR")
            {
                string cal = "失業率";
                string ecal = "Unemployment Rate";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "統計值 (%)";
                        it.st_e = "Statistical value (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal pepv = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal pupv = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeAvgPercent((pupv), (pepv + pupv), 1);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PEP")
            {
                string cal = "就業者";
                string ecal = "Employed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "統計值 (千人)";
                        it.st_e = "Statistical value (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                            decimal va = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());

                            it.v = ComputeMod.ComputeAvgPepole(12, va, 1000);
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                            decimal va = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                            it.v = ComputeMod.ComputeAvgPepole(6, va, 1000);
                        }

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PUP")
            {
                string cal = "失業者";
                string ecal = "Unemployed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PUP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "統計值 (千人)";
                        it.st_e = "Statistical value (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PUP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                            decimal va = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                            it.v = ComputeMod.ComputeAvgPepole(12, va, 1000);
                        }
                        else if (infotype == 2)
                        {
                            it.d = PUP.Rows[k]["YEAR"].ToString() + '-' + PUP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[k]["MONTH"].ToString());
                            decimal va = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                            it.v = ComputeMod.ComputeAvgPepole(6, va, 1000);
                        }

                        it.v = CheckHideValue(it.v, PUP.Rows[k]["YEAR"].ToString(), PUP.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "NLF")
            {
                string cal = "非勞動力";
                string ecal = "Not in Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < NLF.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "統計值 (千人)";
                        it.st_e = "Statistical value (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = NLF.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                            decimal va = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());
                            it.v = ComputeMod.ComputeAvgPepole(12, va, 1000);
                        }
                        else if (infotype == 2)
                        {
                            it.d = NLF.Rows[k]["YEAR"].ToString() + '-' + NLF.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[k]["MONTH"].ToString());
                            decimal va = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());
                            it.v = ComputeMod.ComputeAvgPepole(6, va, 1000);
                        }

                        it.v = CheckHideValue(it.v, NLF.Rows[k]["YEAR"].ToString(), NLF.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
        }
    }

    //性別結構比
    public void SetStatistics2(HttpContext context, formitems litem, List<ClassesTable> tar, string[] classes, string[] sex)
    {
        string type = context.Request["infotype"] as string;
        int infotype = Convert.ToInt32(type);
        int sy = Convert.ToInt32(context.Request["startyear"] as string);
        if (sy <= 82) sy = 82;

        List<int> Tdxs = GetSexTables(tar, "T");
        List<int> Mdxs = GetSexTables(tar, "M");
        List<int> Fdxs = GetSexTables(tar, "F");
        for (int i = 0; i < classes.Length; i++)
        {
            if (classes[i] == "LAF")
            {
                string cal = "勞動力";
                string ecal = "Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable TPEP = tar[Tdxs[0]].table;
                    DataTable TPUP = tar[Tdxs[1]].table;
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "性別結構比 (%)";
                        it.st_e = "% of total";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal tv1 = Convert.ToDecimal(TPEP.Rows[k]["value"].ToString());
                        decimal tv2 = Convert.ToDecimal(TPUP.Rows[k]["value"].ToString());
                        decimal tvalue = tv1 + tv2;

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal value = v1 + v2;

                        it.v = ComputeMod.ComputeAvgPercent(value, tvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "FPS")
            {
                string cal = "15歲以上民間人口";
                string ecal = "Civilian Population Aged 15 Years & Over";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable TPEP = tar[Tdxs[0]].table;
                    DataTable TPUP = tar[Tdxs[1]].table;
                    DataTable TNLF = tar[Tdxs[2]].table;
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;

                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "性別結構比 (%)";
                        it.st_e = "% of total";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal tv1 = Convert.ToDecimal(TPEP.Rows[k]["value"].ToString());
                        decimal tv2 = Convert.ToDecimal(TPUP.Rows[k]["value"].ToString());
                        decimal tv3 = Convert.ToDecimal(TNLF.Rows[k]["value"].ToString());
                        decimal tvalue = tv1 + tv2 + tv3;

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal v3 = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());
                        decimal value = v1 + v2 + v3;

                        it.v = ComputeMod.ComputeAvgPercent(value, tvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PEP")
            {
                string cal = "就業者";
                string ecal = "Employed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable TPEP = tar[Tdxs[0]].table;
                    DataTable PEP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "性別結構比 (%)";
                        it.st_e = "% of total";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal tv = Convert.ToDecimal(TPEP.Rows[k]["value"].ToString());
                        decimal tvalue = tv;

                        decimal v = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal value = v;

                        it.v = ComputeMod.ComputeAvgPercent(value, tvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PUP")
            {
                string cal = "失業者";
                string ecal = "Unemployed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable TPUP = tar[Tdxs[1]].table;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < PUP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "性別結構比 (%)";
                        it.st_e = "% of total";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PUP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PUP.Rows[k]["YEAR"].ToString() + '-' + PUP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[k]["MONTH"].ToString());
                        }

                        decimal tv1 = Convert.ToDecimal(TPUP.Rows[k]["value"].ToString());
                        decimal tvalue = tv1;

                        decimal v1 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal value = v1;

                        it.v = ComputeMod.ComputeAvgPercent(value, tvalue, 2);

                        it.v = CheckHideValue(it.v, PUP.Rows[k]["YEAR"].ToString(), PUP.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "NLF")
            {
                string cal = "非勞動力";
                string ecal = "Not in Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable TNLF = tar[Tdxs[2]].table;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                        idx = 0;

                    for (int k = idx; k < NLF.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "性別結構比 (%)";
                        it.st_e = "% of total";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = NLF.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = NLF.Rows[k]["YEAR"].ToString() + '-' + NLF.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[k]["MONTH"].ToString());
                        }

                        decimal tvalue = Convert.ToDecimal(TNLF.Rows[k]["value"].ToString());
                        decimal value = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeAvgPercent(value, tvalue, 2);

                        it.v = CheckHideValue(it.v, NLF.Rows[k]["YEAR"].ToString(), NLF.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
        }
    }

    //較上期增減值
    public void SetStatistics3(HttpContext context, formitems litem, List<ClassesTable> tar, string[] classes, string[] sex)
    {
        string type = context.Request["infotype"] as string;
        int infotype = Convert.ToInt32(type);
        int sy = Convert.ToInt32(context.Request["startyear"] as string);
        if (sy <= 82) sy = 82;
        int mths = 12;

        if (infotype == 2)
            mths = 6;

        List<int> Tdxs = GetSexTables(tar, "T");
        List<int> Mdxs = GetSexTables(tar, "M");
        List<int> Fdxs = GetSexTables(tar, "F");
        for (int i = 0; i < classes.Length; i++)
        {
            if (classes[i] == "LAF")
            {
                string cal = "勞動力";
                string ecal = "Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal lv1 = Convert.ToDecimal(PEP.Rows[idx - 1]["value"].ToString());
                    decimal lv2 = Convert.ToDecimal(PUP.Rows[idx - 1]["value"].ToString());
                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole((v1 + v2), (lv1 + lv2), mths, 1000);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        lv1 = v1;
                        lv2 = v2;

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "FPS")
            {
                string cal = "15歲以上民間人口";
                string ecal = "Civilian Population Aged 15 Years & Over";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal lv1 = Convert.ToDecimal(PEP.Rows[idx - 1]["value"].ToString());
                    decimal lv2 = Convert.ToDecimal(PUP.Rows[idx - 1]["value"].ToString());
                    decimal lv3 = Convert.ToDecimal(NLF.Rows[idx - 1]["value"].ToString());
                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal v3 = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole((v1 + v2 + v3), (lv1 + lv2 + lv3), mths, 1000);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        lv1 = v1;
                        lv2 = v2;
                        lv3 = v3;

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "LFP")
            {
                string cal = "勞動力參與率";
                string ecal = "Labor Force Participation Rate";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }
                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值(百分點)";
                        it.st_e = "Change from Previous Period (level, percentage point) (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal pepv0 = Convert.ToDecimal(PEP.Rows[idx-1]["value"].ToString());
                    decimal pupv0 = Convert.ToDecimal(PUP.Rows[idx-1]["value"].ToString());
                    decimal nlfv0 = Convert.ToDecimal(NLF.Rows[idx-1]["value"].ToString());

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值(百分點)";
                        it.st_e = "Change from Previous Period (level, percentage point) (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal pepv = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal pupv = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal nlfv = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangePercent((pepv + pupv), (pepv + pupv + nlfv), (pepv0 + pupv0), (pepv0 + pupv0 + nlfv0), 1);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        pepv0 = pepv;
                        pupv0 = pupv;
                        nlfv0 = nlfv;

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "UPR")
            {
                string cal = "失業率";
                string ecal = "Unemployment Rate";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值(百分點)";
                        it.st_e = "Change from Previous Period (level, percentage point) (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal pepv0 = Convert.ToDecimal(PEP.Rows[idx-1]["value"].ToString());
                    decimal pupv0 = Convert.ToDecimal(PUP.Rows[idx-1]["value"].ToString());

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值(百分點)";
                        it.st_e = "Change from Previous Period (level, percentage point) (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal pepv = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal pupv = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangePercent((pupv), (pepv + pupv), (pupv0), (pepv0 + pupv0), 1);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        pepv0 = pepv;
                        pupv0 = pupv;

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PEP")
            {
                string cal = "就業者";
                string ecal = "Employed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal lv = Convert.ToDecimal(PEP.Rows[idx - 1]["value"].ToString());
                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal v = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole(v, lv, mths, 1000);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        lv = v;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PUP")
            {
                string cal = "失業者";
                string ecal = "Unemployed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PUP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PUP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PUP.Rows[0]["YEAR"].ToString() + '-' + PUP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PUP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal lv = Convert.ToDecimal(PUP.Rows[idx-1]["value"].ToString());

                    for (int k = idx; k < PUP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PUP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PUP.Rows[k]["YEAR"].ToString() + '-' + PUP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[k]["MONTH"].ToString());
                        }

                        decimal v = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole(v, lv, mths, 1000);

                        it.v = CheckHideValue(it.v, PUP.Rows[k]["YEAR"].ToString(), PUP.Rows[k]["MONTH"].ToString());

                        lv = v;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "NLF")
            {
                string cal = "非勞動力";
                string ecal = "Not in Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = NLF.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(NLF.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = NLF.Rows[0]["YEAR"].ToString() + '-' + NLF.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(NLF.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal lv = Convert.ToDecimal(NLF.Rows[idx-1]["value"].ToString());
                    for (int k = idx; k < NLF.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減值 (千人)";
                        it.st_e = "Change from Previous Period (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = NLF.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = NLF.Rows[k]["YEAR"].ToString() + '-' + NLF.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[k]["MONTH"].ToString());
                        }

                        decimal v = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole(v, lv, mths, 1000);

                        it.v = CheckHideValue(it.v, NLF.Rows[k]["YEAR"].ToString(), NLF.Rows[k]["MONTH"].ToString());

                        lv = v;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
        }
    }

    //較上年同期增減值
    public void SetStatistics4(HttpContext context, formitems litem, List<ClassesTable> tar, string[] classes, string[] sex)
    {
        string type = context.Request["infotype"] as string;
        int infotype = Convert.ToInt32(type);
        int sy = Convert.ToInt32(context.Request["startyear"] as string);
        if (sy <= 82) sy = 82;
        if (infotype != 2)
            return;

        int mths = 6;

        List<int> Tdxs = GetSexTables(tar, "T");
        List<int> Mdxs = GetSexTables(tar, "M");
        List<int> Fdxs = GetSexTables(tar, "F");
        for (int i = 0; i < classes.Length; i++)
        {
            if (classes[i] == "LAF")
            {
                string cal = "勞動力";
                string ecal = "Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減值 (千人)";
                        it2.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;

                        it2.d = PEP.Rows[1]["YEAR"].ToString() + '-' + PEP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PEP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                        decimal lv1 = Convert.ToDecimal(PEP.Rows[k - 2]["value"].ToString());
                        decimal lv2 = Convert.ToDecimal(PUP.Rows[k - 2]["value"].ToString());
                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole((v1 + v2), (lv1 + lv2), mths, 1000);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "FPS")
            {
                string cal = "15歲以上民間人口";
                string ecal = "Civilian Population Aged 15 Years & Over";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減值 (千人)";
                        it2.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PEP.Rows[1]["YEAR"].ToString() + '-' + PEP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PEP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                        decimal lv1 = Convert.ToDecimal(PEP.Rows[k - 2]["value"].ToString());
                        decimal lv2 = Convert.ToDecimal(PUP.Rows[k - 2]["value"].ToString());
                        decimal lv3 = Convert.ToDecimal(NLF.Rows[k - 2]["value"].ToString());

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal v3 = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole((v1 + v2 + v3), (lv1 + lv2 + lv3), mths, 1000);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "LFP")
            {
                string cal = "勞動力參與率";
                string ecal = "Labor Force Participation Rate";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值(百分點)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減值(百分點)";
                        it2.st_e = "Change from That of Previous Year (level, percentage point) (%)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PEP.Rows[1]["YEAR"].ToString() + '-' + PEP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PEP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值(百分點)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                        decimal pepv0 = Convert.ToDecimal(PEP.Rows[k - 2]["value"].ToString());
                        decimal pupv0 = Convert.ToDecimal(PUP.Rows[k - 2]["value"].ToString());
                        decimal nlfv0 = Convert.ToDecimal(NLF.Rows[k - 2]["value"].ToString());

                        decimal pepv = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal pupv = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal nlfv = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangePercent((pepv + pupv), (pepv + pupv + nlfv), (pepv0 + pupv0), (pepv0 + pupv0 + nlfv0), 1);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "UPR")
            {
                string cal = "失業率";
                string ecal = "Unemployment Rate";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值(百分點)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減值(百分點)";
                        it2.st_e = "Change from That of Previous Year (level, percentage point) (%)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PEP.Rows[1]["YEAR"].ToString() + '-' + PEP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PEP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值(百分點)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                        decimal pepv0 = Convert.ToDecimal(PEP.Rows[k - 2]["value"].ToString());
                        decimal pupv0 = Convert.ToDecimal(PUP.Rows[k - 2]["value"].ToString());

                        decimal pepv = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal pupv = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangePercent((pupv), (pepv + pupv), (pupv0), (pepv0 + pupv0), 1);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PEP")
            {
                string cal = "就業者";
                string ecal = "Employed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                    }
                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減值 (千人)";
                        it2.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PEP.Rows[1]["YEAR"].ToString() + '-' + PEP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PEP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }
                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                        decimal lv = Convert.ToDecimal(PEP.Rows[k - 2]["value"].ToString());
                        decimal v = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole(v, lv, mths, 1000);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PUP")
            {
                string cal = "失業者";
                string ecal = "Unemployed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PUP = tar[Fdxs[1]].table;
                    }
                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PUP.Rows[0]["YEAR"].ToString() + '-' + PUP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PUP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[0]["MONTH"].ToString());
                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減值 (千人)";
                        it2.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PUP.Rows[1]["YEAR"].ToString() + '-' + PUP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PUP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[1]["MONTH"].ToString());
                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PUP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PUP.Rows[k]["YEAR"].ToString() + '-' + PUP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[k]["MONTH"].ToString());

                        decimal lv = Convert.ToDecimal(PUP.Rows[k - 2]["value"].ToString());
                        decimal v = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole(v, lv, mths, 1000);

                        it.v = CheckHideValue(it.v, PUP.Rows[k]["YEAR"].ToString(), PUP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "NLF")
            {
                string cal = "非勞動力";
                string ecal = "Not in Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = NLF.Rows[0]["YEAR"].ToString() + '-' + NLF.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(NLF.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減值 (千人)";
                        it2.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = NLF.Rows[1]["YEAR"].ToString() + '-' + NLF.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(NLF.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[1]["MONTH"].ToString());
                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < NLF.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減值 (千人)";
                        it.st_e = "Change from That of Previous Year (level, percentage point) (Thousand Persons)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = NLF.Rows[k]["YEAR"].ToString() + '-' + NLF.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[k]["MONTH"].ToString());

                        decimal lv = Convert.ToDecimal(NLF.Rows[k - 2]["value"].ToString());
                        decimal v = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());

                        it.v = ComputeMod.ComputeChangeAvgPepole(v, lv, mths, 1000);

                        it.v = CheckHideValue(it.v, NLF.Rows[k]["YEAR"].ToString(), NLF.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
        }
    }

    //較上期增減率
    public void SetStatistics5(HttpContext context, formitems litem, List<ClassesTable> tar, string[] classes, string[] sex)
    {
        int sy = Convert.ToInt32(context.Request["startyear"] as string);
        if (sy <= 82) sy = 82;
        string type = context.Request["infotype"] as string;
        int infotype = Convert.ToInt32(type);
        List<int> Tdxs = GetSexTables(tar, "T");
        List<int> Mdxs = GetSexTables(tar, "M");
        List<int> Fdxs = GetSexTables(tar, "F");

        for (int i = 0; i < classes.Length; i++)
        {
            if (classes[i] == "LAF")
            {
                string cal = "勞動力";
                string ecal = "Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal lv1 = Convert.ToDecimal(PEP.Rows[idx - 1]["value"].ToString());
                    decimal lv2 = Convert.ToDecimal(PUP.Rows[idx - 1]["value"].ToString());
                    decimal lastvalue = lv1 + lv2;
                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal value = v1 + v2;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        lastvalue = value;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "FPS")
            {
                string cal = "15歲以上民間人口";
                string ecal = "Civilian Population Aged 15 Years & Over";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal lv1 = Convert.ToDecimal(PEP.Rows[idx - 1]["value"].ToString());
                    decimal lv2 = Convert.ToDecimal(PUP.Rows[idx - 1]["value"].ToString());
                    decimal lv3 = Convert.ToDecimal(NLF.Rows[idx - 1]["value"].ToString());
                    decimal lastvalue = lv1 + lv2 + lv3;

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal v3 = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());
                        decimal value = v1 + v2 + v3;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        lastvalue = value;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PEP")
            {
                string cal = "就業者";
                string ecal = "Employed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }

                    decimal lv = Convert.ToDecimal(PEP.Rows[idx - 1]["value"].ToString());
                    decimal lastvalue = lv;
                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());
                        }

                        decimal v = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal value = v;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        lastvalue = value;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PUP")
            {
                string cal = "失業者";
                string ecal = "Unemployed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PUP.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PUP.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PUP.Rows[0]["YEAR"].ToString() + '-' + PUP.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PUP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }
                    decimal lv = Convert.ToDecimal(PUP.Rows[idx - 1]["value"].ToString());
                    decimal lastvalue = lv;
                    for (int k = idx; k < PUP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = PUP.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = PUP.Rows[k]["YEAR"].ToString() + '-' + PUP.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[k]["MONTH"].ToString());
                        }

                        decimal v = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal value = v;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, PUP.Rows[k]["YEAR"].ToString(), PUP.Rows[k]["MONTH"].ToString());

                        lastvalue = value;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "NLF")
            {
                string cal = "非勞動力";
                string ecal = "Not in Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = NLF.Rows[0]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(NLF.Rows[0]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = NLF.Rows[0]["YEAR"].ToString() + '-' + NLF.Rows[0]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(NLF.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[0]["MONTH"].ToString());
                        }

                        it.v = -999999;
                        litem.data.Add(it);
                        idx = 1;
                    }
                    decimal lv = Convert.ToDecimal(NLF.Rows[idx-1]["value"].ToString());
                    decimal lastvalue = lv;
                    for (int k = idx; k < NLF.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上期增減率 (%)";
                        it.st_e = "Change in Percent from Previous Period (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        if (infotype == 1)
                        {
                            it.d = NLF.Rows[k]["YEAR"].ToString() + "年";
                            it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString();
                        }
                        else if (infotype == 2)
                        {
                            it.d = NLF.Rows[k]["YEAR"].ToString() + '-' + NLF.Rows[k]["MONTH"].ToString();
                            it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[k]["MONTH"].ToString());
                        }

                        decimal v = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());
                        decimal value = v;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, NLF.Rows[k]["YEAR"].ToString(), NLF.Rows[k]["MONTH"].ToString());

                        lastvalue = value;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
        }
    }

    //較上年同期增減率
    public void SetStatistics6(HttpContext context, formitems litem, List<ClassesTable> tar, string[] classes, string[] sex)
    {
        int sy = Convert.ToInt32(context.Request["startyear"] as string);
        if (sy <= 82) sy = 82;
        string type = context.Request["infotype"] as string;
        int infotype = Convert.ToInt32(type);

        if (infotype != 2)
            return;

        List<int> Tdxs = GetSexTables(tar, "T");
        List<int> Mdxs = GetSexTables(tar, "M");
        List<int> Fdxs = GetSexTables(tar, "F");
        for (int i = 0; i < classes.Length; i++)
        {
            if (classes[i] == "LAF")
            {
                string cal = "勞動力";
                string ecal = "Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減率 (%)";
                        it2.st_e = "Change in Percent from That of Previous Year (%)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PEP.Rows[1]["YEAR"].ToString() + '-' + PEP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PEP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                        decimal lv1 = Convert.ToDecimal(PEP.Rows[k - 2]["value"].ToString());
                        decimal lv2 = Convert.ToDecimal(PUP.Rows[k - 2]["value"].ToString());
                        decimal lastvalue = lv1 + lv2;

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal value = v1 + v2;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "FPS")
            {
                string cal = "15歲以上民間人口";
                string ecal = "Civilian Population Aged 15 Years & Over";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    DataTable PUP = null;
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                        PUP = tar[Tdxs[1]].table;
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                        PUP = tar[Mdxs[1]].table;
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                        PUP = tar[Fdxs[1]].table;
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減率 (%)";
                        it2.st_e = "Change in Percent from That of Previous Year (%)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PEP.Rows[1]["YEAR"].ToString() + '-' + PEP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PEP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                        decimal lv1 = Convert.ToDecimal(PEP.Rows[k - 2]["value"].ToString());
                        decimal lv2 = Convert.ToDecimal(PUP.Rows[k - 2]["value"].ToString());
                        decimal lv3 = Convert.ToDecimal(NLF.Rows[k - 2]["value"].ToString());
                        decimal lastvalue = lv1 + lv2 + lv3;

                        decimal v1 = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal v2 = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal v3 = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());
                        decimal value = v1 + v2 + v3;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PEP")
            {
                string cal = "就業者";
                string ecal = "Employed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PEP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PEP = tar[Tdxs[0]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PEP = tar[Mdxs[0]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PEP = tar[Fdxs[0]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[0]["YEAR"].ToString() + '-' + PEP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減率 (%)";
                        it2.st_e = "Change in Percent from That of Previous Year (%)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PEP.Rows[1]["YEAR"].ToString() + '-' + PEP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PEP.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PEP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PEP.Rows[k]["YEAR"].ToString() + '-' + PEP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PEP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PEP.Rows[k]["MONTH"].ToString());

                        decimal lv = Convert.ToDecimal(PEP.Rows[k - 2]["value"].ToString());
                        decimal lastvalue = lv;

                        decimal v = Convert.ToDecimal(PEP.Rows[k]["value"].ToString());
                        decimal value = v;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, PEP.Rows[k]["YEAR"].ToString(), PEP.Rows[k]["MONTH"].ToString());
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "PUP")
            {
                string cal = "失業者";
                string ecal = "Unemployed";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable PUP = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        PUP = tar[Tdxs[1]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        PUP = tar[Mdxs[1]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        PUP = tar[Fdxs[1]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PUP.Rows[0]["YEAR"].ToString() + '-' + PUP.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PUP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減率 (%)";
                        it2.st_e = "Change in Percent from That of Previous Year (%)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = PUP.Rows[1]["YEAR"].ToString() + '-' + PUP.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(PUP.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[0]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < PUP.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = PUP.Rows[k]["YEAR"].ToString() + '-' + PUP.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(PUP.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(PUP.Rows[k]["MONTH"].ToString());

                        decimal lv = Convert.ToDecimal(PUP.Rows[k - 2]["value"].ToString());
                        decimal lastvalue = lv;
                        decimal v = Convert.ToDecimal(PUP.Rows[k]["value"].ToString());
                        decimal value = v;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, PUP.Rows[k]["YEAR"].ToString(), PUP.Rows[k]["MONTH"].ToString());

                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
            else if (classes[i] == "NLF")
            {
                string cal = "非勞動力";
                string ecal = "Not in Labor Force";
                for (int j = 0; j < sex.Length; j++)
                {
                    string s = "";
                    string es = "";
                    DataTable NLF = null;
                    if (sex[j] == "T")
                    {
                        s = "總計";
                        es = "Total";
                        NLF = tar[Tdxs[2]].table;
                    }
                    else if (sex[j] == "M")
                    {
                        s = "男";
                        es = "Male";
                        NLF = tar[Mdxs[2]].table;
                    }
                    else if (sex[j] == "F")
                    {
                        s = "女";
                        es = "Female";
                        NLF = tar[Fdxs[2]].table;
                    }

                    int idx = infotype;
                    if (sy == 82)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = NLF.Rows[0]["YEAR"].ToString() + '-' + NLF.Rows[0]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(NLF.Rows[0]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[0]["MONTH"].ToString());

                        it.v = -999999;
                        litem.data.Add(it);

                        listitem it2 = new listitem();
                        it2.c = cal;
                        it2.c_e = ecal;
                        it2.s = s;
                        it2.s_e = es;
                        it2.st = "較上年同期增減率 (%)";
                        it2.st_e = "Change in Percent from That of Previous Year (%)";
                        it2.ct = litem.name;
                        it2.ct_e = litem.name_eng;
                        it2.d = NLF.Rows[1]["YEAR"].ToString() + '-' + NLF.Rows[1]["MONTH"].ToString();
                        it2.d_e = (Convert.ToInt32(NLF.Rows[1]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[1]["MONTH"].ToString());

                        it2.v = -999999;
                        litem.data.Add(it2);
                    }

                    for (int k = idx; k < NLF.Rows.Count; k++)
                    {
                        listitem it = new listitem();
                        it.c = cal;
                        it.c_e = ecal;
                        it.s = s;
                        it.s_e = es;
                        it.st = "較上年同期增減率 (%)";
                        it.st_e = "Change in Percent from That of Previous Year (%)";
                        it.ct = litem.name;
                        it.ct_e = litem.name_eng;

                        it.d = NLF.Rows[k]["YEAR"].ToString() + '-' + NLF.Rows[k]["MONTH"].ToString();
                        it.d_e = (Convert.ToInt32(NLF.Rows[k]["YEAR"].ToString()) + 1911).ToString() + '-' + DictionaryMonth_Eng(NLF.Rows[k]["MONTH"].ToString());

                        decimal lv = Convert.ToDecimal(NLF.Rows[k - 2]["value"].ToString());
                        decimal lastvalue = lv;
                        decimal v = Convert.ToDecimal(NLF.Rows[k]["value"].ToString());
                        decimal value = v;

                        it.v = ComputeMod.ComputeRate(value, lastvalue, 2);

                        it.v = CheckHideValue(it.v, NLF.Rows[k]["YEAR"].ToString(), NLF.Rows[k]["MONTH"].ToString());

                        lastvalue = value;
                        if (it.v != -999998) litem.data.Add(it);
                    }
                }
            }
        }
    }

    public DataTable GetZoneCode(string zone, bool isold)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM CODE WHERE CAT=@CAT AND INTERNAL = 0 ";

            string CAT = "";
            List<string> cs = new List<string>();
            if (isold)
            {
                CAT = "縣市(舊)";
                if (zone == "高雄市")
                {
                    cs.Add("高雄市");
                    cs.Add("高雄縣");
                }
                else if (zone == "桃園市")
                {
                    cs.Add("桃園縣");
                }
                else if (zone == "臺中市")
                {
                    cs.Add("臺中縣");
                }
                else if (zone == "臺南市")
                {
                    cs.Add("臺南市");
                    cs.Add("臺南縣");
                }
                else
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

    public DataTable GetYearTable(HttpContext context, int syear, int eyear, DataTable code, string statid)
    {
        string infotype = context.Request["infotype"] as string;
        string classes = context.Request["classes"] as string;
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            if (infotype == "1")
            {
                SqlCommand command = new SqlCommand("", connection);

                sqlStr = @"SELECT DISTINCT (CAST(YEAR AS decimal)-1911) as YEAR, CAST(MONTH AS decimal) as MONTH, CAST(STAT_VAL AS decimal) as value, COUNTY FROM STATDATA_SHIEN15A "
                            + @"WHERE (YEAR >= @startyear AND YEAR <= @endyear) AND STATID=@STATID ";

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

                sqlStr += @" ORDER BY YEAR, MONTH, COUNTY ";
                command.CommandText = sqlStr;

                try
                {
                    SqlParameter[] p = {
                        new SqlParameter("@startyear", syear),
                        new SqlParameter("@endyear", eyear),
                        new SqlParameter("@STATID", statid)
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);

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

                    DataTable tt = ds.Tables[0];
                    DataTable data = new DataTable();
                    data.Columns.Add("YEAR", typeof(String));
                    data.Columns.Add("MONTH", typeof(String));
                    data.Columns.Add("value", typeof(Double));

                    decimal sum = 0, year = 0;
                    for (int i = 0; i < tt.Rows.Count; i++)
                    {
                        int month = Convert.ToInt32(tt.Rows[i]["MONTH"].ToString());
                        int lmonth = -1;
                        if (i + 1 != tt.Rows.Count)
                            lmonth = Convert.ToInt32(tt.Rows[i + 1]["MONTH"].ToString());

                        if (month == 12 && lmonth == 1 || (month == 12 && lmonth == -1))
                        {
                            year = Convert.ToInt32(tt.Rows[i]["YEAR"].ToString());
                            sum += Convert.ToDecimal(tt.Rows[i]["value"].ToString());
                            DataRow workRow = data.NewRow();
                            workRow["YEAR"] = year.ToString();

                            decimal avg = sum;
                            workRow["value"] = avg.ToString();

                            data.Rows.Add(workRow);
                            sum = 0;
                        }
                        else if (lmonth == -1)
                        {
                            year = Convert.ToInt32(tt.Rows[i]["YEAR"].ToString());

                            DataRow workRow = data.NewRow();
                            workRow["YEAR"] = year.ToString();
                            workRow["value"] = 0;

                            data.Rows.Add(workRow);
                            sum = 0;
                        }
                        else
                        {
                            year = Convert.ToInt32(tt.Rows[i]["YEAR"].ToString());
                            sum += Convert.ToDecimal(tt.Rows[i]["value"].ToString());
                        }
                    }
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
            }
            else
            {
                SqlCommand command = new SqlCommand("", connection);

                sqlStr = @"SELECT DISTINCT (CAST(YEAR AS decimal)-1911) as YEAR, CAST(MONTH AS decimal) as MONTH, CAST(STAT_VAL AS decimal) as value, COUNTY FROM STATDATA_SHIEN15A "
                            + @"WHERE (YEAR >= @startyear AND YEAR <= @endyear) AND STATID=@STATID ";

                string lvl = code.Rows[0]["LVL"].ToString();
                string cal = code.Rows[0]["CAL_ITEM"].ToString();
                string[] cals = cal.Split(',');

                if (lvl == "1")
                {
                    sqlStr += "AND (COUNTY = @COUNTY) ";
                }
                else
                {
                    sqlStr += "AND ( ";
                    for (int i = 0; i < cals.Length; i++)
                    {
                        if (i != 0)
                        {
                            sqlStr += " OR ";
                        }

                        sqlStr += " COUNTY = @COUNTY_" + i;
                    }
                    sqlStr += ") ";
                }

                sqlStr += @" ORDER BY YEAR, MONTH, COUNTY  ";
                command.CommandText = sqlStr;

                try
                {
                    SqlParameter[] p = {
                        new SqlParameter("@startyear", syear),
                        new SqlParameter("@endyear", eyear),
                        new SqlParameter("@STATID", statid)
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);

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

                    DataTable tt = ds.Tables[0];
                    DataTable data = new DataTable();
                    data.Columns.Add("YEAR", typeof(String));
                    data.Columns.Add("MONTH", typeof(String));
                    data.Columns.Add("value", typeof(Double));

                    decimal sum = 0, year = 0;
                    for (int i = 0; i < tt.Rows.Count; i++)
                    {
                        int month = Convert.ToInt32(tt.Rows[i]["MONTH"].ToString());
                        int lmonth = -1;
                        if (i + 1 != tt.Rows.Count)
                            lmonth = Convert.ToInt32(tt.Rows[i + 1]["MONTH"].ToString());

                        if ((month == 6 && lmonth == 7) || (month == 6 && lmonth == -1))
                        {
                            year = Convert.ToInt32(tt.Rows[i]["YEAR"].ToString());
                            sum += Convert.ToDecimal(tt.Rows[i]["value"].ToString());

                            DataRow workRow = data.NewRow();
                            workRow["YEAR"] = year.ToString();
                            workRow["MONTH"] = "上半年";

                            decimal avg = sum;
                            workRow["value"] = avg.ToString();

                            data.Rows.Add(workRow);
                            sum = 0;
                        }
                        else if ((month == 12 && lmonth == 1) || (month == 12 && lmonth == -1))
                        {
                            year = Convert.ToInt32(tt.Rows[i]["YEAR"].ToString());
                            sum += Convert.ToDecimal(tt.Rows[i]["value"].ToString());

                            DataRow workRow = data.NewRow();
                            workRow["YEAR"] = year.ToString();
                            workRow["MONTH"] = "下半年";

                            decimal avg = sum;
                            workRow["value"] = avg.ToString();

                            data.Rows.Add(workRow);
                            sum = 0;
                        }
                        else if (month < 6 && lmonth == -1)
                        {
                            year = Convert.ToInt32(tt.Rows[i]["YEAR"].ToString());

                            DataRow workRow = data.NewRow();
                            workRow["YEAR"] = year.ToString();
                            workRow["value"] = 0;
                            workRow["MONTH"] = "上半年";

                            data.Rows.Add(workRow);
                            sum = 0;
                        }
                        else if (lmonth == -1)
                        {
                            year = Convert.ToInt32(tt.Rows[i]["YEAR"].ToString());

                            DataRow workRow = data.NewRow();
                            workRow["YEAR"] = year.ToString();
                            workRow["value"] = 0;
                            workRow["MONTH"] = "下半年";

                            data.Rows.Add(workRow);
                            sum = 0;
                        }
                        else
                        {
                            year = Convert.ToInt32(tt.Rows[i]["YEAR"].ToString());
                            sum += Convert.ToDecimal(tt.Rows[i]["value"].ToString());
                        }
                    }
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
            }
        };

        return dt;
    }

    public class ClassesTable
    {
        public string name { get; set; }
        public string sex { get; set; }
        public DataTable table { get; set; }
    }

    public List<ClassesTable> GetZoneTables(HttpContext context, string startyear, string endyear, string[] sex, string zone)
    {
        int isy = Convert.ToInt32(startyear) + 1911 - 1; //多撈前一年資料計算用
        if (Convert.ToInt32(startyear) == 82)
            isy += 1;

        int iey = Convert.ToInt32(endyear) + 1911;

        List<ClassesTable> tables = new List<ClassesTable>();
        string szone = DictionaryZone(zone);
        DataTable ocode = GetZoneCode(szone, false);

        string[] allsex = new[] { "T", "M", "F" };
        string[] tablecode = new[] { "PEP06", "PUP06", "NLF06" };

        for (int i = 0; i < tablecode.Length; i++)
        {
            for (int j = 0; j < allsex.Length; j++)
            {
                string code = tablecode[i] + allsex[j] + "0000X0000000000000";
                ClassesTable item = new ClassesTable();
                DataTable otable = GetYearTable(context, isy, iey, ocode, code);
                item.name = tablecode[i];
                item.sex = allsex[j];
                item.table = otable;
                tables.Add(item);
            }
        }

        return tables;
    }

    //取得顯示到的年份跟月份
    public String getShowYear()
    {
        string daystring = ConfigurationManager.AppSettings["CityYear"];
        return daystring;
    }
    public String getShowMonth()
    {
        string daystring = ConfigurationManager.AppSettings["CityMonth"];
        return daystring;
    }

    public decimal CheckHideValue(decimal value, string sy, string sm)
    {
        string showyear = getShowYear();

        int y = Convert.ToInt32(sy);

        int maxyear = Convert.ToInt32(showyear);
        if (y > maxyear)
            return -999999;

        string showmonth = getShowMonth();
        if (y == maxyear && showmonth == "6" && sm == "下半年")
            return -999998;
        if (y == maxyear && showmonth == "6" && sm == "")
            return -999999;

        return value;
    }

    public String DictionaryZone(string zone)
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
            case "6":
                return "基隆市";
            case "5":
                return "桃園市";
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
                return "東部區域";
            case "17":
                return "臺東縣";
            case "18":
                return "花蓮縣";
            case "19":
                return "南部區域";
            case "20":
                return "臺南市";
            case "21":
                return "高雄市";
            case "22":
                return "嘉義市";
            case "23":
                return "嘉義縣";
            case "24":
                return "屏東縣";
            case "25":
                return "澎湖縣";
            default:
                return "";
        }
    }

    public String DictionaryZone_Eng(string zone)
    {
        switch (zone)
        {
            case "1":
                return "Taiwan Area";
            case "2":
                return "Northern region";
            case "3":
                return "New Taipei City";
            case "4":
                return "Taipei City";
            case "6":
                return "Keelung City";
            case "5":
                return "Taoyuan City";
            case "7":
                return "Hsinchu City";
            case "8":
                return "Yilan County";
            case "9":
                return "Hsinchu County";
            case "10":
                return "Central region";
            case "11":
                return "Taichung City";
            case "12":
                return "Miaoli County";
            case "13":
                return "Changhua County";
            case "14":
                return "Nantou County";
            case "15":
                return "Yunlin County";
            case "16":
                return "Eastern region";
            case "17":
                return "Taitung County";
            case "18":
                return "Hualien County";
            case "19":
                return "Southern region";
            case "20":
                return "Tainan City";
            case "21":
                return "Kaohsiung City";
            case "22":
                return "Chiayi City";
            case "23":
                return "Chiayi County";
            case "24":
                return "Pingtung County";
            case "25":
                return "Penghu County";
            default:
                return "";
        }
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
                return "Jun";
            case "7":
                return "Jul";
            case "8":
                return "Aug";
            case "9":
                return "Sep";
            case "10":
                return "Oct";
            case "11":
                return "Nov";
            case "12":
                return "Dec";
            case "上半年":
                return "First half";
            case "下半年":
                return "Second half";
            default:
                return "";
        }
    }

    public bool IsReusable {
        get {
            return false;
        }
    }

}