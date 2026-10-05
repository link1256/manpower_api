<%@ WebHandler Language="C#" Class="More_Inquire" %>

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

public class More_Inquire : IHttpHandler
{
    public class tableitem
    {
        public String name { get; set; }
        public DataTable table { get; set; }
    }

    string pepcode = "PEP04";
    string pupcode = "PUP04";
    string nlfcode = "NLF04";
    string ind6code = "IND01";
    string ind7code = "IND02";
    string ind8code = "IND04";
    string occ5code = "OCC03";
    string occ6code = "OCC04";
    string cowcode = "COW04";
    string roncode = "RON04";
    string roucode = "ROU04";

    public string icsyear = "";
    public string iceyear = "";

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

    public String GetBaseInfo(HttpContext context)
    {
        String jData = "";

        MNYear target = GetYears();
        string month = getShowMonth();
        jData = JsonConvert.SerializeObject(new { MNYear = target, maxmonth = month });

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
                FROM STATDATA_NEW69;

                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM STATDATA_NEW103;

                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM STATDATA_NEW84;

                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM STATDATA_NEW172a;

                SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                FROM STATDATA_NEW182a;
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

    public int GetMaxMonth(string maxyear)
    {
        String sqlStr = "";
        DataSet ds = new DataSet();
        int month = 12;
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
                SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW69 WHERE YEAR=@YEAR;

                SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW103 WHERE YEAR=@YEAR;

                SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW84 WHERE YEAR=@YEAR;

                SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW172a WHERE YEAR=@YEAR;

                SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW182a WHERE YEAR=@YEAR;
            ";
            command.CommandText = sqlStr;
            SqlParameter[] p = {
                new SqlParameter("@YEAR", maxyear)
            };
            
            command.Parameters.Clear();
            command.Parameters.AddRange(p);
            
            try
            {
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                int maxmonth = -9999;
                for (int i = 0; i < ds.Tables.Count; i++)
                {
                    int tmax = 0;
                    bool t = Int32.TryParse(ds.Tables[i].Rows[0]["maxmonth"].ToString(), out tmax);
                    if (!t) continue;

                    if (maxmonth <= tmax)
                        maxmonth = tmax;
                }
                month = maxmonth;
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

        return (month);
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
            case "SEA":
                roctype = "失業率(季節調整)";
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
                    new SqlParameter("@FunctionName", "更多資料查詢"),
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
                           SET BrowseCount=@BrowseCount 
                           WHERE Sno=@Sno ";
            }
            else
            {
                sqlStr = @" INSERT INTO Count_List (Time, FunctionName, StatisticItem, BrowseCount, DownloadTable, DownloadChart) 
                           VALUES (@Time, '更多資料查詢', @StatisticItem, 1, 0, 0) ";
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
                sqlStr = @" UPDATE Count_List 
                            SET DownloadTable=@DownloadTable 
                            WHERE Sno=@Sno ";
            }
            else
            {
                sqlStr = @" INSERT INTO Count_List (Time, FunctionName, StatisticItem, BrowseCount, DownloadTable, DownloadChart) 
                            VALUES (@Time, '更多資料查詢', @StatisticItem, 0, 1, 0) ";
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
                sqlStr = @" UPDATE Count_List 
                            SET DownloadChart=@DownloadChart 
                            WHERE Sno=@Sno ";
            }
            else
            {
                sqlStr = @" INSERT INTO Count_List (Time, FunctionName, StatisticItem, BrowseCount, DownloadTable, DownloadChart) 
                            VALUES (@Time, '更多資料查詢', @StatisticItem, 0, 0, 1) ";
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

    public class listitem
    {
        public string d { get; set; } //年月
        public string c { get; set; } //分類
        public string s { get; set; } //性別
        public string st { get; set; } //統計項
        public decimal v { get; set; } //值
        public string l { get; set; } //階層
        public string d_e { get; set; } //年月-英文
        public string c_e { get; set; } //分類-英文
        public string s_e { get; set; } //性別-英文
        public string st_e { get; set; } //統計項-英文
    }

    public class sortitem
    {
        public string name { get; set; } //名稱
        public string name_eng { get; set; } //名稱-英文
        public string level { get; set; } //階層
        public string show { get; set; } //畫圖時是否顯示
    }

    public class reponseData
    {
        public List<listitem> BASE { get; set; }
        public List<sortitem> BASE_SORT { get; set; }
        public List<listitem> AGE { get; set; }
        public List<sortitem> AGE_SORT { get; set; }
        public List<listitem> EDTION { get; set; }
        public List<sortitem> EDTION_SORT { get; set; }
        public List<listitem> IND6 { get; set; }
        public List<sortitem> IND6_SORT { get; set; }
        public List<listitem> IND7 { get; set; }
        public List<sortitem> IND7_SORT { get; set; }
        public List<listitem> IND8 { get; set; }
        public List<sortitem> IND8_SORT { get; set; }
        public List<listitem> IND12 { get; set; }
        public List<sortitem> IND12_SORT { get; set; }
        public List<listitem> OCC5 { get; set; }
        public List<sortitem> OCC5_SORT { get; set; }
        public List<listitem> OCC6 { get; set; }
        public List<sortitem> OCC6_SORT { get; set; }
        public List<listitem> COW { get; set; }
        public List<sortitem> COW_SORT { get; set; }
        public List<listitem> RON { get; set; }
        public List<sortitem> RON_SORT { get; set; }
        public List<listitem> ROU { get; set; }
        public List<sortitem> ROU_SORT { get; set; }
    }

    public String GetRequestTables(HttpContext context) {
        string cstring = context.Request["classes"] as string;
        string[] classes = cstring.Split(',');

        bool hasbase = false, hasage = false, hasedtion = false, hasind6 = false, hasind7 = false;
        string hasbaseS = "", hasageS = "", hasedtionS = "", hasind6S = "", hasind7S = "";
        bool hasind8 = false, hasind12 = false, hasocc5 = false, hasocc6 = false, hascow = false, hasron = false, hasrou = false;
        string hasind8S = "", hasind12S = "", hasocc5S = "", hasocc6S = "", hascowS = "", hasronS = "", hasrouS = "";
        for (int i = 0; i < classes.Length; i++)
        {
            if (classes[i] == "總計" || classes[i] == "失業率" || classes[i] == "勞動力參與率")
            {
                hasbase = true;
                hasbaseS = classes[i];
            }
            if (classes[i] == "年齡")
            {
                hasage = true;
                hasageS = classes[i];
            }
            if (classes[i] == "教育程度")
            {
                hasedtion = true;
                hasedtionS = classes[i];
            }
            if (classes[i] == "行業_6")
            {
                hasind6 = true;
                hasind6S = classes[i];
            }
            if (classes[i] == "行業_7")
            {
                hasind7 = true;
                hasind7S = classes[i];
            }
            if (classes[i] == "行業_8")
            {
                hasind8 = true;
                hasind8S = classes[i];
            }
            if (classes[i] == "行業_12")
            {
                hasind12 = true;
                hasind12S = classes[i];
            }
            if (classes[i] == "職業_5")
            {
                hasocc5 = true;
                hasocc5S = classes[i];
            }
            if (classes[i] == "職業_6")
            {
                hasocc6 = true;
                hasocc6S = classes[i];
            }
            if (classes[i] == "從業身分")
            {
                hascow = true;
                hascowS = classes[i];
            }
            if (classes[i] == "非勞動原因")
            {
                hasron = true;
                hasronS = classes[i];
            }
            if (classes[i] == "失業原因")
            {
                hasrou = true;
                hasrouS = classes[i];
            }
        }
        string jData = "";
        reponseData rd = new reponseData();
        if (hasbase)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> basetables = GetBaseTables(context);
            CompileBaseData(context, basetables, data, hasbaseS);
            rd.BASE = data;
        }
        if (hasage)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> agetables = GetAgeTables(context, "年齡");
            CompileLayOutData(context, agetables, data, "年齡", "0");
            rd.AGE = data;
            rd.AGE_SORT = GetSortItems("年齡", "0");
        }
        if (hasedtion)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> edtiontables = GetEdtionTables(context, "教育程度");
            CompileLayOutData(context, edtiontables, data, "教育程度", "0");
            rd.EDTION = data;
            rd.EDTION_SORT = GetSortItems("教育程度", "0");
        }
        if (hasind6)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> ind6tables = GetIndTables(context, "行業", "6");
            CompileLayOutData(context, ind6tables, data, "行業", "6");
            rd.IND6 = data;
            rd.IND6_SORT = GetSortItems("行業", "6");
        }
        if (hasind7)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> ind7tables = GetIndTables(context, "行業", "7");
            CompileLayOutData(context, ind7tables, data, "行業", "7");
            rd.IND7 = data;
            rd.IND7_SORT = GetSortItems("行業", "7");
        }
        if (hasind8)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> ind8tables = GetIndTables(context, "行業", "8-10");
            CompileLayOutData(context, ind8tables, data, "行業", "8-10");
            rd.IND8 = data;
            rd.IND8_SORT = GetSortItems("行業", "8-10");
        }
        if (hasind12)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> ind12tables = GetIndTables(context, "行業", "12", "NEW182A");
            CompileLayOutData(context, ind12tables, data, "行業", "12");
            rd.IND12 = data;
            rd.IND12_SORT = GetSortItems("行業", "12");
        }
        if (hasocc5)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> occ5tables = GetOCCTables(context, "職業", "5");
            CompileLayOutData(context, occ5tables, data, "職業", "5");
            rd.OCC5 = data;
            rd.OCC5_SORT = GetSortItems("職業", "5");
        }
        if (hasocc6)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> occ6tables = GetOCCTables(context, "職業", "6");
            CompileLayOutData(context, occ6tables, data, "職業", "6");
            rd.OCC6 = data;
            rd.OCC6_SORT = GetSortItems("職業", "6");
        }
        if (hascow)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> cowtables = GetCOWTables(context, "從業身分");
            CompileLayOutData(context, cowtables, data, "從業身分", "0");
            rd.COW = data;
            rd.COW_SORT = GetSortItems("從業身分", "0");
        }
        if (hasron)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> rontables = GetRONTables(context, "非勞動原因");
            CompileLayOutData(context, rontables, data, "非勞動原因", "0");
            rd.RON = data;
            rd.RON_SORT = GetSortItems("非勞動原因", "0");
        }
        if (hasrou)
        {
            List<listitem> data = new List<listitem>();
            List<DataTable> routables = GetROUTables(context, "失業原因");
            CompileLayOutData(context, routables, data, "失業原因", "0");
            rd.ROU = data;
            rd.ROU_SORT = GetSortItems("失業原因", "0");
        }
        jData = JsonConvert.SerializeObject(rd);
        return (jData);
    }

    public String GetSeasonData(HttpContext context) {
        string jData = "";
        List<listitem> data = new List<listitem>();

        DataTable dt = GetSeasonTable(context);

        foreach (DataRow r in dt.Rows)
        {
            string year = (Convert.ToInt16(r["Year"].ToString()) - 1911).ToString();
            string month = r["Month"].ToString();
            string date = year + "年" + month + "月";

            listitem total = new listitem();
            total.d = date;
            total.c = "總計";
            total.s = "總計";
            total.st = "統計值 (%)";

            total.c_e = "Total";
            total.s_e = "Total";
            total.d_e = DictionaryMonth_Eng(month) + " " + r["Year"].ToString();
            total.st_e = "Data value (%)";

            total.v = Convert.ToDecimal(r["Total"].ToString());
            total.v = CheckHideValue4(total.v, year, month);

            if (total.v != -999998) data.Add(total);
        }

        jData = JsonConvert.SerializeObject(data);
        return (jData);
    }

    public DataTable GetSeasonTable(HttpContext context)
    {
        string infotype = context.Request["infotype"] as string;
        string cycle = context.Request["cycle"] as string;
        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        syear = (1911 + Convert.ToInt16(syear)).ToString();
        eyear = (1911 + Convert.ToInt16(eyear)).ToString();

        DataTable dt = new DataTable();

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT * FROM Unemployedrate_Adjust 
                        WHERE (Year >= @startyear AND Year <= @endyear) ";

            if (infotype == "1" && cycle != "0")
            {
                sqlStr += " AND Month = @Month ";
            }

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@startyear", syear),
                    new SqlParameter("@endyear", eyear)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (infotype == "1" && cycle != "0")
                {
                    command.Parameters.Add(new SqlParameter("@Month", cycle));
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
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();
            string perc = cd[0]["PERCENTAGE_SHOW"].ToString();

            sortitem item = new sortitem()
            {
                name = des,
                name_eng = dese,
                level = lvl,
                show = perc
            };

            items.Add(item);
        }

        return items;
    }

    public List<DataTable> GetBaseTables(HttpContext context)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');
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
            DataTable tmp = getTabelByCodes(context, cs, "NEW172A");
            dlist.Add(tmp);
        }

        return dlist;
    }

    public List<DataTable> GetAgeTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (sex[0] == "T")
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
            DataTable tmp = getTabelByCodes(context, cs, "NEW172A");
            dlist.Add(tmp);
        }

        return dlist;
    }

    public List<DataTable> GetEdtionTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (sex[0] == "T")
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
                    string code = tlist[i] + sex[j] + "00" + layouts[k] + "X0000000000000";
                    cs.Add(code);
                }
            }
            DataTable tmp = getTabelByCodes(context, cs, "NEW172A");
            dlist.Add(tmp);
        }

        return dlist;
    }

    public List<DataTable> GetIndTables(HttpContext context, string classes, string ver, string table = "NEW172A")
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (sex[0] == "T")
            sex = new string[] { "M", "F" };

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
        // DataTable tmp = getTabelByCodes(context, cs, table);
        DataTable tmp = getINDTabelByCodes(context, cs, table, ver);
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetOCCTables(HttpContext context, string classes, string ver)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (sex[0] == "T")
            sex = new string[] { "M", "F" };

        string table = "NEW172A";
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
        //DataTable tmp = getTabelByCodes(context, cs, table);
        DataTable tmp = getOCCTabelByCodes(context, cs, table, ver);
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetCOWTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (sex[0] == "T")
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
        DataTable tmp = getTabelByCodes(context, cs, "NEW172A");
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetRONTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (sex[0] == "T")
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

        DataTable tmp = getTabelByCodes(context, cs, "NEW172A");
        dlist.Add(tmp);

        return dlist;
    }

    public List<DataTable> GetROUTables(HttpContext context, string classes)
    {
        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');

        if (sex[0] == "T")
            sex = new string[] { "M", "F" };

        List<DataTable> dlist = new List<DataTable>();

        string layoutstring = GetLayoutAllTable(classes, "0");
        string[] layouts = layoutstring.Split(',');

        List<string> cs = new List<string>();
        for (int j = 0; j < sex.Length; j++)
        {
            for (int k = 0; k < layouts.Length; k++)
            {
                string code = roucode + sex[j] + "0000X0000000" + layouts[k] + "0000";
                cs.Add(code);
            }
        }

        DataTable tmp = getTabelByCodes(context, cs, "NEW172A");
        dlist.Add(tmp);

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
                        WHERE CAT = @classes AND VER = @ver AND INTERNAL = 0 ";

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

    public string GetLayouts(string classes, string ver)
    {
        string data = "";

        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM LAYOUT 
                        WHERE CAT = @classes AND VER = @ver AND INTERNAL = 0 ";

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

    public DataTable getTabelByCodes(HttpContext context, List<string> codes, string table)
    {
        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        syear = (1911 + Convert.ToInt16(syear) - 1).ToString(); //會多撈前一年份的資料供計算
        eyear = (1911 + Convert.ToInt16(eyear)).ToString();

        DataTable data = new DataTable();

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT DISTINCT YEAR, cast(MONTH AS int) AS MONTH, STATID, STAT_VAL FROM STATDATA_" + table +
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

    public DataTable getINDTabelByCodes(HttpContext context, List<string> codes, string table, string ver)
    {
        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        syear = (1911 + Convert.ToInt16(syear) - 1).ToString(); //會多撈前一年份的資料供計算
        eyear = (1911 + Convert.ToInt16(eyear)).ToString();

        if (ver == "6")
        {
            int s = (1911 + Convert.ToInt16(67) - 1);
            int e = (1911 + Convert.ToInt16(90));

            if (Convert.ToInt16(syear) < s)
                syear = s.ToString();
            if (Convert.ToInt16(eyear) > e)
                eyear = e.ToString();
        }
        else if (ver == "7")
        {
            int s = (1911 + Convert.ToInt16(88) - 1);
            int e = (1911 + Convert.ToInt16(95));

            if (Convert.ToInt16(syear) < s)
                syear = s.ToString();
            if (Convert.ToInt16(eyear) > e)
                eyear = e.ToString();
        }
        else if (table == "NEW182A")
        {
            int s = (1911 + Convert.ToInt16(105) - 1);

            if (Convert.ToInt16(syear) < s)
                syear = s.ToString();
        }
        else
        {
            int s = (1911 + Convert.ToInt16(90) - 1);
            int e = (1911 + Convert.ToInt16(115));

            if (Convert.ToInt16(syear) < s)
                syear = s.ToString();
            if (Convert.ToInt16(eyear) > e)
                eyear = e.ToString();
        }

        icsyear = syear;
        iceyear = eyear;

        DataTable data = new DataTable();

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT DISTINCT YEAR, cast(MONTH AS int) AS MONTH, STATID, STAT_VAL FROM STATDATA_" + table +
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

    public DataTable getOCCTabelByCodes(HttpContext context, List<string> codes, string table, string ver)
    {
        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        syear = (1911 + Convert.ToInt16(syear) - 1).ToString(); //會多撈前一年份的資料供計算
        eyear = (1911 + Convert.ToInt16(eyear)).ToString();

        if (ver == "5")
        {
            int s = (1911 + Convert.ToInt16(67) - 1);
            int e = (1911 + Convert.ToInt16(99));

            if (Convert.ToInt16(syear) < s)
                syear = s.ToString();
            if (Convert.ToInt16(eyear) > e)
                eyear = e.ToString();
        }
        else
        {
            int s = (1911 + Convert.ToInt16(90) - 1);

            if (Convert.ToInt16(syear) < s)
                syear = s.ToString();
        }

        DataTable data = new DataTable();

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT DISTINCT YEAR, cast(MONTH AS int) AS MONTH, STATID, STAT_VAL FROM STATDATA_" + table +
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

    public List<string> Dictionary(HttpContext context)
    {
        List<string> list = new List<string>();
        string type = context.Request["type"] as string;

        switch (type)
        {
            case "PEP":
                list.Add(pepcode);
                break;
            case "PUP":
                list.Add(pupcode);
                break;
            case "NLF":
                list.Add(nlfcode);
                break;
            case "LAF":
            case "UPR":
                list.Add(pepcode);
                list.Add(pupcode);
                break;
            case "FPS":
            case "LFP":
                list.Add(pepcode);
                list.Add(pupcode);
                list.Add(nlfcode);
                break;
        }

        return list;
    }

    public void CompileBaseData(HttpContext context, List<DataTable> table, List<listitem> listitem, string classes)
    {
        string infotype = context.Request["infotype"] as string;
        string cycle = context.Request["cycle"] as string;
        string type = context.Request["type"] as string;

        List<string> tlist = Dictionary(context);

        DataTable tar = null, tar2 = null;
        tar = MerageTable(context, table);
        tar2 = tar.Copy();

        if (infotype == "1")
        {
            if (cycle != "0")
            {
                tar = tar.Select("MONTH = '" + cycle + "'").CopyToDataTable();
            }
            tar = sortTable(tar);
        }
        else if (infotype == "2")
        {
            if (type == "LFP" || type == "UPR")
                tar = BaseAvgTable2(context, table);
            else
                tar = BaseAvgTable(context, tar);
        }
        else if (infotype == "3")
        {
            if (type == "LFP" || type == "UPR")
                tar = BaseSumAvgTable2(context, table);
            else
                tar = BaseSumAvgTable(context, tar);
        }

        string statstring = context.Request["statistics"] as string;
        string[] statistics = statstring.Split(',');

        for (int i = 0; i < statistics.Length; i++)
        {
            string tmp = statistics[i];

            switch (tmp)
            {
                case "1":
                    SetBaseStatistics1(context, tar, classes, listitem);
                    break;
                case "2":
                    SetBaseStatistics2(context, tar, classes, listitem, tar2);
                    break;
                case "3":
                    SetBaseStatistics3(context, tar, classes, listitem, tar2);
                    break;
                case "4":
                    SetBaseStatistics4(context, tar, classes, listitem);
                    break;
                case "5":
                    SetBaseStatistics5(context, tar, classes, listitem, tar2);
                    break;
                case "6":
                    SetBaseStatistics6(context, tar, classes, listitem, tar2);
                    break;
            }
        }
    }

    public void CompileLayOutData(HttpContext context, List<DataTable> table, List<listitem> listitem, string classes, string ver)
    {
        string infotype = context.Request["infotype"] as string;
        string cycle = context.Request["cycle"] as string;
        string type = context.Request["type"] as string;

        if (type != "UPR" && type != "LFP")
        {
            List<string> tlist = Dictionary(context);

            DataTable tar = null, tar2 = null;
            tar = MerageTable(context, table);
            tar2 = tar.Copy();

            if (infotype == "1")
            {
                if (cycle != "0")
                {
                    tar = tar.Select("MONTH = '" + cycle + "'").CopyToDataTable();
                }
                tar = sortTable(tar);
            }
            else if (infotype == "2")
            {
                tar = BaseAvgTable(context, tar);
            }
            else if (infotype == "3")
            {
                tar = BaseSumAvgTable(context, tar);
            }

            //取得Layout
            string layoutstring = GetLayouts(classes, ver);
            string[] layouts = layoutstring.Split(',');
            //取得CodeTable
            DataTable code = GetCodeTable(classes, ver);

            string statstring = context.Request["statistics"] as string;
            string[] statistics = statstring.Split(',');

            for (int i = 0; i < statistics.Length; i++)
            {
                string tmp = statistics[i];

                switch (tmp)
                {
                    case "1":
                        SetLayOutStatistics1(context, tar, classes, listitem, layouts, code, ver);
                        break;
                    case "2":
                        SetLayOutStatistics2(context, tar, classes, listitem, layouts, code, tar2, ver);
                        break;
                    case "3":
                        SetLayOutStatistics3(context, tar, classes, listitem, layouts, code, tar2, ver);
                        break;
                    case "4":
                        SetLayOutStatistics4(context, tar, classes, listitem, layouts, code, ver);
                        break;
                    case "5":
                        SetLayOutStatistics5(context, tar, classes, listitem, layouts, code, tar2, ver);
                        break;
                    case "6":
                        SetLayOutStatistics6(context, tar, classes, listitem, layouts, code, tar2, ver);
                        break;
                }
            }
        }
        else
        {
            List<DataTable> table2 = new List<DataTable>();
            for (int i = 0; i < table.Count; i++)
            {
                DataTable tmp = new DataTable();
                if (infotype == "1")
                {
                    tmp = sortTable(table[i]);
                    if (cycle != "0")
                    {
                        table[i] = table[i].Select("MONTH = '" + cycle + "'").CopyToDataTable();
                    }
                    table[i] = sortTable(table[i]);
                }
                else if (infotype == "2")
                {
                    table[i] = BaseAvgTable(context, table[i]);
                    tmp = table[i].Copy();
                }
                else if (infotype == "3")
                {
                    table[i] = BaseSumAvgTable(context, table[i]);
                    tmp = table[i].Copy();
                }
                table2.Add(tmp);
            }
            //取得Layout
            string layoutstring = GetLayouts(classes, ver);
            string[] layouts = layoutstring.Split(',');
            //取得CodeTable
            DataTable code = GetCodeTable(classes, ver);

            string statstring = context.Request["statistics"] as string;
            string[] statistics = statstring.Split(',');

            for (int i = 0; i < statistics.Length; i++)
            {
                string tmp = statistics[i];

                switch (tmp)
                {
                    case "1":
                        SetLayOutUTypeStatistics1(context, table, classes, listitem, layouts, code);
                        break;
                    case "2":
                        SetLayOutUTypeStatistics2(context, table, classes, listitem, layouts, code, table2);
                        break;
                    case "3":
                        SetLayOutUTypeStatistics3(context, table, classes, listitem, layouts, code);
                        break;
                }
            }
        }
    }

    public DataTable sortTable(DataTable dt)
    {
        DataTable dt2 = dt.Clone();
        dt2.Columns["YEAR"].DataType = Type.GetType("System.Int32");
        dt2.Columns["MONTH"].DataType = Type.GetType("System.Int32");

        foreach (DataRow dr in dt.Rows)
        {
            dt2.ImportRow(dr);
        }
        dt2.AcceptChanges();
        DataView dv = dt2.DefaultView;
        dv.Sort = "YEAR ASC, MONTH ASC";

        return dt2;
    }

    public class UtypeTables
    {
        public int index { get; set; }
        public List<DataTable> dsm { get; set; }
        public List<DataTable> dsf { get; set; }
        public int tablecount { get; set; }
    }

    //統計值-UTypeLayOut
    public void SetLayOutUTypeStatistics1(HttpContext context, List<DataTable> tar, string classes, List<listitem> listitem, string[] layouts, DataTable code)
    {
        string type = context.Request["type"] as string;
        string infotype = context.Request["infotype"] as string;
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');

        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用

        string utype = context.Request["type"] as string;

        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');

            List<UtypeTables> utables = new List<UtypeTables>();

            List<string> calcodes = setMultiCodes(classes, cals);
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
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "總計";
                        lm.s_e = "Total";
                        lm.st = "統計值 (%)";
                        lm.st_e = "Data value (%)";

                        lm.v = ComputeMod.ComputeAvgPercent(pupvalue, (pepvalue + pupvalue), 2);

                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }

                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "總計";
                        lm.s_e = "Total";
                        lm.st = "統計值 (%)";
                        lm.st_e = "Data value (%)";

                        lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 2);

                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }
            if (ssex.IndexOf('M') != -1)
            {
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "男";
                        lm.s_e = "Male";
                        lm.st = "統計值 (%)";
                        lm.st_e = "Data value (%)";

                        lm.v = ComputeMod.ComputeAvgPercent((pupvalue), (pepvalue + pupvalue), 2);

                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "男";
                        lm.s_e = "Male";
                        lm.st = "統計值 (%)";
                        lm.st_e = "Data value (%)";

                        lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 2);

                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }

            if (ssex.IndexOf('F') != -1)
            {
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "女";
                        lm.s_e = "Female";
                        lm.st = "統計值 (%)";
                        lm.st_e = "Data value (%)";

                        lm.v = ComputeMod.ComputeAvgPercent((pupvalue), (pepvalue + pupvalue), 2);

                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }

                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "女";
                        lm.s_e = "Female";
                        lm.st = "統計值 (%)";
                        lm.st_e = "Data value (%)";

                        lm.v = ComputeMod.ComputeAvgPercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), 2);

                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }
        }
    }
    //較上期增減值-UTypeLayOut
    public void SetLayOutUTypeStatistics2(HttpContext context, List<DataTable> tar, string classes, List<listitem> listitem, string[] layouts, DataTable code, List<DataTable> tar2)
    {
        string type = context.Request["type"] as string;
        string infotype = context.Request["infotype"] as string;
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');

        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用
        int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
        string utype = context.Request["type"] as string;

        bool ispreyear = false;
        string statstr = "較上期增減百分點";
        string esatastr = "Change from previous period (level, percentage point) (%)";
        if (infotype == "3")
        {
            statstr = "較上年同期增減百分點";
            esatastr = "Change from that of previous year (level, percentage point) (%)";
            ispreyear = true;
        }

        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');

            List<UtypeTables> utables = new List<UtypeTables>();

            List<string> calcodes = setMultiCodes(classes, cals);
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
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;

                            for (int k = 0; k < utables[0].dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf = tar2[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm2 = tar2[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf2 = tar2[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }

                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "總計";
                            lm.s_e = "Total";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            for (int k = 0; k < utables[0].dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2[0].Select("YEAR = '" + iy + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf = tar2[0].Select("YEAR = '" + iy + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm2 = tar2[1].Select("YEAR = '" + iy + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf2 = tar2[1].Select("YEAR = '" + iy + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "總計";
                            lm.s_e = "Total";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            decimal lnlfvalue = 0;

                            for (int k = 0; k < utables[0].dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf = tar2[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm2 = tar2[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf2 = tar2[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm3 = tar2[2].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[2].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm3.Length > 0)
                                    lnlfvalue += Convert.ToDecimal(ldsm3[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf3 = tar2[2].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[2].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf3.Length > 0)
                                    lnlfvalue += Convert.ToDecimal(ldsf3[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "總計";
                            lm.s_e = "Total";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            decimal lnlfvalue = 0;

                            for (int k = 0; k < utables[0].dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2[0].Select("YEAR = '" + iy + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf = tar2[0].Select("YEAR = '" + iy + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm2 = tar2[1].Select("YEAR = '" + iy + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf2 = tar2[1].Select("YEAR = '" + iy + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm3 = tar2[2].Select("YEAR = '" + iy + "' AND STATID = '" + utables[2].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm3.Length > 0)
                                    lnlfvalue += Convert.ToDecimal(ldsm3[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf3 = tar2[2].Select("YEAR = '" + iy + "' AND STATID = '" + utables[2].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf3.Length > 0)
                                    lnlfvalue += Convert.ToDecimal(ldsf3[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "總計";
                            lm.s_e = "Total";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                    }
                }
            }
            if (ssex.IndexOf('M') != -1)
            {
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;

                            for (int k = 0; k < utables[0].dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm2 = tar2[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "男";
                            lm.s_e = "Male";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            for (int k = 0; k < utables[0].dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2[0].Select("YEAR = '" + iy + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm2 = tar2[1].Select("YEAR = '" + iy + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "男";
                            lm.s_e = "Male";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            if (lm.v != -999998) listitem.Add(lm);
                        }
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            decimal lnlfvalue = 0;

                            for (int k = 0; k < utables[0].dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm2 = tar2[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm3 = tar2[2].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[2].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm3.Length > 0)
                                    lnlfvalue += Convert.ToDecimal(ldsm3[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;

                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }

                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "男";
                            lm.s_e = "Male";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            decimal lnlfvalue = 0;

                            for (int k = 0; k < utables[0].dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2[0].Select("YEAR = '" + iy + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm2 = tar2[1].Select("YEAR = '" + iy + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsm3 = tar2[2].Select("YEAR = '" + iy + "' AND STATID = '" + utables[2].dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm3.Length > 0)
                                    lnlfvalue += Convert.ToDecimal(ldsm3[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "男";
                            lm.s_e = "Male";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            if (lm.v != -999998) listitem.Add(lm);
                        }
                    }
                }
            }

            if (ssex.IndexOf('F') != -1)
            {
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;

                            for (int k = 0; k < utables[0].dsf.Count; k++)
                            {
                                DataRow[] ldsf = tar2[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf2 = tar2[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "女";
                            lm.s_e = "Female";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            for (int k = 0; k < utables[0].dsf.Count; k++)
                            {
                                DataRow[] ldsf = tar2[0].Select("YEAR = '" + iy + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf2 = tar2[1].Select("YEAR = '" + iy + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "女";
                            lm.s_e = "Female";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            if (lm.v != -999998) listitem.Add(lm);
                        }
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            decimal lnlfvalue = 0;

                            for (int k = 0; k < utables[0].dsf.Count; k++)
                            {
                                DataRow[] ldsf = tar2[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf2 = tar2[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf3 = tar2[2].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[2].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf3.Length > 0)
                                    lnlfvalue += Convert.ToDecimal(ldsf3[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "女";
                            lm.s_e = "Female";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lpepvalue = 0;
                            decimal lpupvalue = 0;
                            decimal lnlfvalue = 0;

                            for (int k = 0; k < utables[0].dsf.Count; k++)
                            {
                                DataRow[] ldsf = tar2[0].Select("YEAR = '" + iy + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf2 = tar2[1].Select("YEAR = '" + iy + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf2.Length > 0)
                                    lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());

                                DataRow[] ldsf3 = tar2[2].Select("YEAR = '" + iy + "' AND STATID = '" + utables[2].dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf3.Length > 0)
                                    lnlfvalue += Convert.ToDecimal(ldsf3[0]["STAT_VAL"].ToString());
                            }

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + '年';
                                de = y;
                            }
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "女";
                            lm.s_e = "Female";
                            lm.st = statstr;
                            lm.st_e = esatastr;

                            lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            if (lm.v != -999998) listitem.Add(lm);
                        }
                    }
                }
            }
        }
    }

    //較上年增減值-UTypeLayOut
    public void SetLayOutUTypeStatistics3(HttpContext context, List<DataTable> tar, string classes, List<listitem> listitem, string[] layouts, DataTable code)
    {
        string type = context.Request["type"] as string;
        string infotype = context.Request["infotype"] as string;
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');
        int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用

        string utype = context.Request["type"] as string;
        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');

            List<UtypeTables> utables = new List<UtypeTables>();

            List<string> calcodes = setMultiCodes(classes, cals);
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
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        iy = iy - 1;
                        int im = Convert.ToInt32(m);

                        decimal lpepvalue = 0;
                        decimal lpupvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                            DataRow[] ldsf = tar[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                            DataRow[] ldsm2 = tar[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm2.Length > 0)
                                lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                            DataRow[] ldsf2 = tar[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf2.Length > 0)
                                lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "總計";
                        lm.s_e = "Total";
                        lm.st = "較上年同期增減百分點";
                        lm.st_e = "Change from that of previous year (level, percentage point) (%)";

                        lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        iy = iy - 1;
                        int im = Convert.ToInt32(m);

                        decimal lpepvalue = 0;
                        decimal lpupvalue = 0;
                        decimal lnlfvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                            DataRow[] ldsf = tar[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                            DataRow[] ldsm2 = tar[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm2.Length > 0)
                                lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                            DataRow[] ldsf2 = tar[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf2.Length > 0)
                                lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());

                            DataRow[] ldsm3 = tar[2].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[2].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm3.Length > 0)
                                lnlfvalue += Convert.ToDecimal(ldsm3[0]["STAT_VAL"].ToString());

                            DataRow[] ldsf3 = tar[2].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[2].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf3.Length > 0)
                                lnlfvalue += Convert.ToDecimal(ldsf3[0]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "總計";
                        lm.s_e = "Total";
                        lm.st = "較上年同期增減百分點";
                        lm.st_e = "Change from that of previous year (level, percentage point) (%)";

                        lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }
            if (ssex.IndexOf('M') != -1)
            {
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        iy = iy - 1;
                        int im = Convert.ToInt32(m);

                        decimal lpepvalue = 0;
                        decimal lpupvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                            DataRow[] ldsm2 = tar[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm2.Length > 0)
                                lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "男";
                        lm.s_e = "Male";
                        lm.st = "較上年同期增減百分點";
                        lm.st_e = "Change from that of previous year (level, percentage point) (%)";

                        lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsm[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsm[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsm[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        iy = iy - 1;
                        int im = Convert.ToInt32(m);

                        decimal lpepvalue = 0;
                        decimal lpupvalue = 0;
                        decimal lnlfvalue = 0;

                        for (int k = 0; k < utables[0].dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lpepvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());

                            DataRow[] ldsm2 = tar[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm2.Length > 0)
                                lpupvalue += Convert.ToDecimal(ldsm2[0]["STAT_VAL"].ToString());

                            DataRow[] ldsm3 = tar[2].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[2].dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm3.Length > 0)
                                lnlfvalue += Convert.ToDecimal(ldsm3[0]["STAT_VAL"].ToString());

                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "男";
                        lm.s_e = "Male";
                        lm.st = "較上年同期增減百分點";
                        lm.st_e = "Change from that of previous year (level, percentage point) (%)";

                        lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }

            if (ssex.IndexOf('F') != -1)
            {
                if (type == "UPR")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        iy = iy - 1;
                        int im = Convert.ToInt32(m);


                        decimal lpepvalue = 0;
                        decimal lpupvalue = 0;

                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            DataRow[] ldsf = tar[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                            DataRow[] ldsf2 = tar[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf2.Length > 0)
                                lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "女";
                        lm.s_e = "Female";
                        lm.st = "較上年同期增減百分點";
                        lm.st_e = "Change from that of previous year (level, percentage point) (%)";

                        lm.v = ComputeMod.ComputeChangePercent((pupvalue), (pepvalue + pupvalue), (lpupvalue), (lpepvalue + lpupvalue), 2);

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
                else if (type == "LFP")
                {
                    for (int j = 0; j < tablecount; j++)
                    {
                        string y = utables[0].dsf[0].Rows[j]["YEAR"].ToString();
                        string m = utables[0].dsf[0].Rows[j]["MONTH"].ToString();
                        string d = "";
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        decimal pepvalue = 0;
                        decimal pupvalue = 0;
                        decimal nlfvalue = 0;
                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            pepvalue += Convert.ToDecimal(utables[0].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            pupvalue += Convert.ToDecimal(utables[1].dsf[k].Rows[j]["STAT_VAL"].ToString());
                            nlfvalue += Convert.ToDecimal(utables[2].dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }

                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        iy = iy - 1;
                        int im = Convert.ToInt32(m);

                        decimal lpepvalue = 0;
                        decimal lpupvalue = 0;
                        decimal lnlfvalue = 0;

                        for (int k = 0; k < utables[0].dsf.Count; k++)
                        {
                            DataRow[] ldsf = tar[0].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[0].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lpepvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());

                            DataRow[] ldsf2 = tar[1].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[1].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf2.Length > 0)
                                lpupvalue += Convert.ToDecimal(ldsf2[0]["STAT_VAL"].ToString());

                            DataRow[] ldsf3 = tar[2].Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + utables[2].dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf3.Length > 0)
                                lnlfvalue += Convert.ToDecimal(ldsf3[0]["STAT_VAL"].ToString());
                        }

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + '年';
                            de = y;
                        }
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "女";
                        lm.s_e = "Female";
                        lm.st = "較上年同期增減百分點";
                        lm.st_e = "Change from that of previous year (level, percentage point) (%)";

                        lm.v = ComputeMod.ComputeChangePercent((pepvalue + pupvalue), (pepvalue + pupvalue + nlfvalue), (lpepvalue + lpupvalue), (lpepvalue + lpupvalue + lnlfvalue), 2);

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }
        }
    }

    //統計值-LayOut
    public void SetLayOutStatistics1(HttpContext context, DataTable tar, string classes, List<listitem> listitem, string[] layouts, DataTable code, string ver)
    {
        string infotype = context.Request["infotype"] as string;
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');

        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用
        string eyear = "";
        if (classes == "行業" || classes == "職業")
        {
            if (tar.Rows.Count > 0)
            {
                if (context.Request["startyear"].ToString() == "67" && tar.Rows[0]["YEAR"].ToString() == "1978") // 67首年判斷
                    syear = "1977";
                else
                    syear = tar.Rows[0]["YEAR"].ToString();

                if (classes == "行業")
                {
                    if (ver == "6") eyear = "2001";
                    else if (ver == "7")
                    {
                        eyear = "2006";
                        if (Convert.ToInt32(syear) < 1999)
                        {
                            syear = "1998";
                        }
                    }
                    else if (ver == "8-10")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
                else if (classes == "職業")
                {
                    if (ver == "5") eyear = "2010";
                    else if (ver == "6")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
            }
        }

        string utype = context.Request["type"] as string;

        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');
            List<string> calcodes = setMultiCodes(classes, cals);
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
                    string de = "";
                    if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                        continue;
                    if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                        break;

                    listitem lm = new listitem();

                    decimal value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                    }
                    lm.c = des;
                    lm.c_e = dese;
                    lm.l = lvl;

                    string dy = (Convert.ToInt16(y) - 1911).ToString();
                    if (m != "-")
                    {
                        if (infotype != "3")
                            d = dy + "年" + m + "月";
                        else
                            d = dy + "年" + m;
                        de = DictionaryMonth_Eng(m) + " " + y;
                    }
                    else
                    {
                        d = dy + '年';
                        de = y;
                    }
                    lm.d = d;
                    lm.d_e = de;
                    lm.s = "總計";
                    lm.s_e = "Total";
                    lm.v = value;

                    lm.st = "統計值 (千人)";
                    lm.st_e = "Data value (Thousand Persons)";

                    if (infotype == "2")
                    {
                        lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1000);
                    }
                    else if (infotype == "3")
                    {
                        int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
                        lm.v = ComputeMod.ComputeAvgPepole((cycle + 1), lm.v, 1000);
                    }
                    else
                    {
                        lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1000);
                    }

                    lm.v = CheckHideValue(des, lm.v, dy, m);

                    if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        decimal value = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "男";
                        lm.s_e = "Male";

                        lm.v = value;

                        lm.st = "統計值 (千人)";
                        lm.st_e = "Data value (Thousand Persons)";

                        if (infotype == "2")
                        {
                            lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1000);
                        }
                        else if (infotype == "3")
                        {
                            int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
                            lm.v = ComputeMod.ComputeAvgPepole((cycle + 1), lm.v, 1000);
                        }
                        else
                        {
                            lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1000);
                        }

                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        decimal value = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "女";
                        lm.s_e = "Female";

                        lm.v = value;

                        lm.st = "統計值 (千人)";
                        lm.st_e = "Data value (Thousand Persons)";

                        if (infotype == "2")
                        {
                            lm.v = ComputeMod.ComputeAvgPepole(12, lm.v, 1000);
                        }
                        else if (infotype == "3")
                        {
                            int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
                            lm.v = ComputeMod.ComputeAvgPepole((cycle + 1), lm.v, 1000);
                        }
                        else
                        {
                            lm.v = ComputeMod.ComputeAvgPepole(1, lm.v, 1000);
                        }

                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }
        }
    }

    //較上期增減值(百分點)-LayOut
    public void SetLayOutStatistics2(HttpContext context, DataTable tar, string classes, List<listitem> listitem, string[] layouts, DataTable code, DataTable tar2, string ver)
    {
        string infotype = context.Request["infotype"] as string;
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');

        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用
        string eyear = "";
        if (classes == "行業" || classes == "職業")
        {
            if (tar.Rows.Count > 0)
            {
                if (context.Request["startyear"].ToString() == "67" && tar.Rows[0]["YEAR"].ToString() == "1978") // 67首年判斷
                    syear = (Convert.ToInt32(tar.Rows[0]["YEAR"].ToString()) - 1).ToString();
                else
                    syear = tar.Rows[0]["YEAR"].ToString();

                if (classes == "行業")
                {
                    if (ver == "6") eyear = "2001";
                    else if (ver == "7")
                    {
                        eyear = "2006";
                        if (Convert.ToInt32(syear) < 1999)
                        {
                            syear = "1998";
                        }
                    }
                    else if (ver == "8-10")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
                else if (classes == "職業")
                {
                    if (ver == "5") eyear = "2010";
                    else if (ver == "6")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
            }
        }

        int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
        string utype = context.Request["type"] as string;

        bool ispreyear = false;
        string statstr = "較上期增減值";
        string estatstr = "Change from previous period (level, percentage point)";
        if (infotype == "3")
        {
            statstr = "較上年同期增減值";
            estatstr = "Change from that of previous year (level, percentage point)";
            ispreyear = true;
        }

        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');
            List<string> calcodes = setMultiCodes(classes, cals);
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
                    string de = "";
                    if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                        continue;
                    if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                        break;

                    listitem lm = new listitem();

                    //目前資料
                    decimal value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                    }
                    //取得上期資料
                    int iy = Convert.ToInt32(y);

                    if (m.IndexOf("-") == -1)
                    {
                        int im = Convert.ToInt32(m);

                        im = im - 1;
                        if (im == 0)
                        {
                            iy = iy - 1;
                            im = 12;
                        }

                        decimal lvalue = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                            DataRow[] ldsf = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                        }

                        if (infotype == "2")
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                        else if (infotype == "3")
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                        else
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "總計";
                        lm.s_e = "Total";
                        lm.st = statstr + " (千人)";
                        lm.st_e = estatstr + " (Thousand Persons)";

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                    else
                    {
                        iy = iy - 1;
                        decimal lvalue = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar.Select("YEAR = '" + iy + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                            DataRow[] ldsf = tar.Select("YEAR = '" + iy + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                        }

                        if (infotype == "2")
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                        else if (infotype == "3")
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                        else
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "總計";
                        lm.s_e = "Total";

                        lm.st = statstr + " (千人)";
                        lm.st_e = estatstr + " (Thousand Persons)";

                        if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        //目前資料
                        decimal value = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lvalue = 0;
                            for (int k = 0; k < dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                            }

                            if (infotype == "2")
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                            else if (infotype == "3")
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                            else
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;

                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + "年";
                                de = y;
                            }

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "男";
                            lm.s_e = "Male";

                            lm.st = statstr + " (千人)";
                            lm.st_e = estatstr + " (Thousand Persons)";

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lvalue = 0;
                            for (int k = 0; k < dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar.Select("YEAR = '" + iy + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                            }

                            if (infotype == "2")
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                            else if (infotype == "3")
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                            else
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + "年";
                                de = y;
                            }

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "男";
                            lm.s_e = "Male";

                            lm.st = statstr + " (千人)";
                            lm.st_e = estatstr + " (Thousand Persons)";

                            if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        //目前資料
                        decimal value = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lvalue = 0;
                            for (int k = 0; k < dsf.Count; k++)
                            {
                                DataRow[] ldsf = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                            }

                            if (infotype == "2")
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                            else if (infotype == "3")
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                            else
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;

                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + "年";
                                de = y;
                            }

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "女";
                            lm.s_e = "Female";

                            lm.st = statstr + " (千人)";
                            lm.st_e = estatstr + " (Thousand Persons)";

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lvalue = 0;
                            for (int k = 0; k < dsf.Count; k++)
                            {
                                DataRow[] ldsf = tar.Select("YEAR = '" + iy + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                            }

                            if (infotype == "2")
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                            else if (infotype == "3")
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                            else
                                lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + "年";
                                de = y;
                            }

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "女";
                            lm.s_e = "Female";

                            lm.st = statstr + " (千人)";
                            lm.st_e = estatstr + " (Thousand Persons)";

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                    }
                }
            }
        }
    }

    //較上年同期增減值(百分點)-LayOut
    public void SetLayOutStatistics3(HttpContext context, DataTable tar, string classes, List<listitem> listitem, string[] layouts, DataTable code, DataTable tar2, string ver)
    {
        string infotype = context.Request["infotype"] as string;
        int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');

        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用
        string eyear = "";
        if (classes == "行業" || classes == "職業")
        {
            if (tar.Rows.Count > 0)
            {
                if (context.Request["startyear"].ToString() == "67" && tar.Rows[0]["YEAR"].ToString() == "1978") // 67首年判斷
                    syear = (Convert.ToInt32(tar.Rows[0]["YEAR"].ToString()) - 1).ToString();
                else
                    syear = tar.Rows[0]["YEAR"].ToString();

                if (classes == "行業")
                {
                    if (ver == "6") eyear = "2001";
                    else if (ver == "7")
                    {
                        eyear = "2006";
                        if (Convert.ToInt32(syear) < 1999)
                        {
                            syear = "1998";
                        }
                    }
                    else if (ver == "8-10")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
                else if (classes == "職業")
                {
                    if (ver == "5") eyear = "2010";
                    else if (ver == "6")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
            }
        }

        string utype = context.Request["type"] as string;

        bool ispreyear = true;
        string statstr = "較上年同期增減值";
        string estatstr = "Change from that of previous year (level, percentage point)";

        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');
            List<string> calcodes = setMultiCodes(classes, cals);
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
                    string de = "";
                    if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                        continue;
                    if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                        break;

                    listitem lm = new listitem();

                    //目前資料
                    decimal value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                    }
                    //取得上期資料
                    int iy = Convert.ToInt32(y);
                    int im = Convert.ToInt32(m);
                    iy = iy - 1;

                    decimal lvalue = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        DataRow[] ldsm = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                        if (ldsm.Length > 0)
                            lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                        DataRow[] ldsf = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                        if (ldsf.Length > 0)
                            lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                    }

                    if (infotype == "2")
                        lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                    else if (infotype == "3")
                        lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                    else
                        lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                    lm.c = des;
                    lm.c_e = dese;
                    lm.l = lvl;

                    string dy = (Convert.ToInt16(y) - 1911).ToString();
                    if (m != "-")
                    {
                        d = dy + "年" + m + "月";
                        de = DictionaryMonth_Eng(m) + " " + y;
                    }
                    else
                    {
                        d = dy + "年";
                        de = y;
                    }

                    lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                    lm.d = d;
                    lm.d_e = de;
                    lm.s = "總計";
                    lm.s_e = "Total";
                    lm.st = statstr + " (千人)";
                    lm.st_e = estatstr + " (Thousand Persons)";


                    if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        //目前資料
                        decimal value = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        int im = Convert.ToInt32(m);
                        iy = iy - 1;

                        decimal lvalue = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                        }

                        if (infotype == "2")
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                        else if (infotype == "3")
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                        else
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            d = dy + "年" + m + "月";
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "男";
                        lm.s_e = "Male";

                        lm.st = statstr + " (千人)";
                        lm.st_e = estatstr + " (Thousand Persons)";

                        if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;

                        listitem lm = new listitem();

                        //目前資料
                        decimal value = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        int im = Convert.ToInt32(m);
                        iy = iy - 1;

                        decimal lvalue = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            DataRow[] ldsf = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                        }

                        if (infotype == "2")
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 12, 1000);
                        else if (infotype == "3")
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, (cycle + 1), 1000);
                        else
                            lm.v = ComputeMod.ComputeChangeAvgPepole(value, lvalue, 1, 1000);

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            d = dy + "年" + m + "月";
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "女";
                        lm.s_e = "Female";

                        lm.st = statstr + " (千人)";
                        lm.st_e = estatstr + " (Thousand Persons)";

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }
        }
    }

    //結構比-LayOut
    public void SetLayOutStatistics4(HttpContext context, DataTable tar, string classes, List<listitem> listitem, string[] layouts, DataTable code, string ver)
    {
        string infotype = context.Request["infotype"] as string;
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');

        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用
        string eyear = "";
        if (classes == "行業" || classes == "職業")
        {
            if (tar.Rows.Count > 0)
            {
                if (context.Request["startyear"].ToString() == "67" && tar.Rows[0]["YEAR"].ToString() == "1978") // 67首年判斷
                    syear = (Convert.ToInt32(tar.Rows[0]["YEAR"].ToString()) - 1).ToString();
                else
                    syear = tar.Rows[0]["YEAR"].ToString();

                if (classes == "行業")
                {
                    if (ver == "6") eyear = "2001";
                    else if (ver == "7")
                    {
                        eyear = "2006";
                        if (Convert.ToInt32(syear) < 1999)
                        {
                            syear = "1998";
                        }
                    }
                    else if (ver == "8-10")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
                else if (classes == "職業")
                {
                    if (ver == "5") eyear = "2010";
                    else if (ver == "6")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
            }
        }

        List<decimal> totalvalue = new List<decimal>();
        List<decimal> totalvalueM = new List<decimal>();
        List<decimal> totalvalueF = new List<decimal>();
        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');
            List<string> calcodes = setMultiCodes(classes, cals);
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
                    string de = "";
                    if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                    {
                        totalvalue.Add(0);
                        continue;
                    }
                    if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                        break;

                    listitem lm = new listitem();

                    decimal value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                    }
                    lm.c = des;
                    lm.c_e = dese;
                    lm.l = lvl;

                    string dy = (Convert.ToInt16(y) - 1911).ToString();
                    if (m != "-")
                    {
                        if (infotype != "3")
                            d = dy + "年" + m + "月";
                        else
                            d = dy + "年" + m;

                        de = DictionaryMonth_Eng(m) + " " + y;
                    }
                    else
                    {
                        d = dy + "年";
                        de = y;
                    }

                    lm.d = d;
                    lm.d_e = de;
                    lm.s = "總計";
                    lm.s_e = "Total";
                    lm.st = "結構比 (%)";
                    lm.st_e = "% of Total";

                    if (des == "總計")
                    {
                        lm.v = ComputeMod.ComputeAvgPercent(value, value, 2);

                        totalvalue.Add(value);
                    }
                    else
                    {
                        lm.v = ComputeMod.ComputeAvgPercent(value, totalvalue[j], 2);
                    }
                    lm.v = CheckHideValue(des, lm.v, dy, m);

                    if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                        {
                            totalvalueM.Add(0);
                            continue;
                        }
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        decimal value = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "男";
                        lm.s_e = "Male";
                        lm.st = "結構比 (%)";
                        lm.st_e = "% of Total";
                        if (des == "總計")
                        {
                            lm.v = ComputeMod.ComputeAvgPercent(value, value, 2);

                            totalvalueM.Add(value);
                        }
                        else
                        {
                            lm.v = ComputeMod.ComputeAvgPercent(value, totalvalueM[j], 2);
                        }
                        lm.v = CheckHideValue(des, lm.v, dy, m);

                        if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                        {
                            totalvalueF.Add(0);
                            continue;
                        }
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        decimal value = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "女";
                        lm.s_e = "Female";
                        lm.st = "結構比 (%)";
                        lm.st_e = "% of Total";

                        if (des == "總計")
                        {
                            lm.v = ComputeMod.ComputeAvgPercent(value, value, 2);

                            totalvalueF.Add(value);
                        }
                        else
                        {
                            lm.v = ComputeMod.ComputeAvgPercent(value, totalvalueF[j], 2);
                        }
                        lm.v = CheckHideValue(des, lm.v, dy, m);
                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }
        }
    }

    //較上期增減率-LayOut
    public void SetLayOutStatistics5(HttpContext context, DataTable tar, string classes, List<listitem> listitem, string[] layouts, DataTable code, DataTable tar2, string ver)
    {
        string infotype = context.Request["infotype"] as string;
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');

        int cycle = Convert.ToInt32(context.Request["cycle"] as string);
        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用
        string eyear = "";
        if (classes == "行業" || classes == "職業")
        {
            if (tar.Rows.Count > 0)
            {
                if (context.Request["startyear"].ToString() == "67" && tar.Rows[0]["YEAR"].ToString() == "1978") // 67首年判斷
                    syear = (Convert.ToInt32(tar.Rows[0]["YEAR"].ToString()) - 1).ToString();
                else
                    syear = tar.Rows[0]["YEAR"].ToString();

                if (classes == "行業")
                {
                    if (ver == "6") eyear = "2001";
                    else if (ver == "7")
                    {
                        eyear = "2006";
                        if (Convert.ToInt32(syear) < 1999)
                        {
                            syear = "1998";
                        }
                    }
                    else if (ver == "8-10")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
                else if (classes == "職業")
                {
                    if (ver == "5") eyear = "2010";
                    else if (ver == "6")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
            }
        }

        bool ispreyear = false;
        string statstr = "較上期增減率 (%)";
        string estatstr = "Change in percent from previous period (%)";
        if (infotype == "3")
        {
            statstr = "較上年同期增減率 (%)";
            estatstr = "Change in percent from that of previous year (%)";
            ispreyear = true;
        }

        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');
            List<string> calcodes = setMultiCodes(classes, cals);
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
                    string de = "";
                    if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                        continue;
                    if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                        break;

                    listitem lm = new listitem();

                    //目前資料
                    decimal value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                    }
                    //取得上期資料
                    int iy = Convert.ToInt32(y);

                    if (m.IndexOf("-") == -1)
                    {
                        int im = Convert.ToInt32(m);

                        im = im - 1;
                        if (im == 0)
                        {
                            iy = iy - 1;
                            im = 12;
                        }

                        decimal lvalue = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                            DataRow[] ldsf = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                        }

                        lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "總計";
                        lm.s_e = "Total";
                        lm.st = statstr;
                        lm.st_e = estatstr;

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                    else
                    {
                        iy = iy - 1;

                        decimal lvalue = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar.Select("YEAR = '" + iy + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                            DataRow[] ldsf = tar.Select("YEAR = '" + iy + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                        }

                        lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            d = dy + "年" + m;
                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "總計";
                        lm.s_e = "Total";
                        lm.st = statstr;
                        lm.st_e = estatstr;

                        if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        //目前資料
                        decimal value = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        //取得上期資料
                        int iy = Convert.ToInt32(y);

                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lvalue = 0;
                            for (int k = 0; k < dsm.Count; k++)
                            {
                                DataRow[] ldsm = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsm.Length > 0)
                                    lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                            }

                            lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;

                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + "年";
                                de = y;
                            }

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "男";
                            lm.s_e = "Male";
                            lm.st = statstr;
                            lm.st_e = estatstr;

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lvalue = 0;
                            for (int k = 0; k < dsm.Count; k++)
                            {
                                string sqls = "YEAR = '" + iy + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'";
                                DataRow[] ldsm = tar.Select(sqls);
                                if (ldsm.Length > 0)
                                    lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                            }

                            lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + "年";
                                de = y;
                            }

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "男";
                            lm.s_e = "Male";
                            lm.st = statstr;
                            lm.st_e = estatstr;

                            if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        //目前資料
                        decimal value = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        if (m.IndexOf("-") == -1)
                        {
                            int im = Convert.ToInt32(m);

                            im = im - 1;
                            if (im == 0)
                            {
                                iy = iy - 1;
                                im = 12;
                            }

                            decimal lvalue = 0;
                            for (int k = 0; k < dsf.Count; k++)
                            {
                                DataRow[] ldsf = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                            }

                            lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                if (infotype != "3")
                                    d = dy + "年" + m + "月";
                                else
                                    d = dy + "年" + m;

                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + "年";
                                de = y;
                            }

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "女";
                            lm.s_e = "Female";
                            lm.st = statstr;
                            lm.st_e = estatstr;

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                        else
                        {
                            iy = iy - 1;

                            decimal lvalue = 0;
                            for (int k = 0; k < dsf.Count; k++)
                            {
                                DataRow[] ldsf = tar.Select("YEAR = '" + iy + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                                if (ldsf.Length > 0)
                                    lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                            }

                            lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                            lm.c = des;
                            lm.c_e = dese;
                            lm.l = lvl;

                            string dy = (Convert.ToInt16(y) - 1911).ToString();
                            if (m != "-")
                            {
                                d = dy + "年" + m;
                                de = DictionaryMonth_Eng(m) + " " + y;
                            }
                            else
                            {
                                d = dy + "年";
                                de = y;
                            }

                            lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, ispreyear);
                            lm.d = d;
                            lm.d_e = de;
                            lm.s = "女";
                            lm.s_e = "Female";
                            lm.st = statstr;
                            lm.st_e = estatstr;

                            if (lm.v != -999998) listitem.Add(lm);
                        }
                    }
                }
            }
        }
    }

    //較上年同期增減率-LayOut
    public void SetLayOutStatistics6(HttpContext context, DataTable tar, string classes, List<listitem> listitem, string[] layouts, DataTable code, DataTable tar2, string ver)
    {
        string infotype = context.Request["infotype"] as string;
        int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
        string ssex = context.Request["sex"] as string;
        string[] sexs = ssex.Split(',');

        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt32(syear) - 1).ToString(); //計算多撈的一年要跳過用
        string eyear = "";
        if (classes == "行業" || classes == "職業")
        {
            if (tar.Rows.Count > 0)
            {
                if (context.Request["startyear"].ToString() == "67" && tar.Rows[0]["YEAR"].ToString() == "1978") // 67首年判斷
                    syear = (Convert.ToInt32(tar.Rows[0]["YEAR"].ToString()) - 1).ToString();
                else
                    syear = tar.Rows[0]["YEAR"].ToString();

                if (classes == "行業")
                {
                    if (ver == "6") eyear = "2001";
                    else if (ver == "7")
                    {
                        eyear = "2006";
                        if (Convert.ToInt32(syear) < 1999)
                        {
                            syear = "1998";
                        }
                    }
                    else if (ver == "8-10")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
                else if (classes == "職業")
                {
                    if (ver == "5") eyear = "2010";
                    else if (ver == "6")
                    {
                        if (Convert.ToInt32(syear) < 2001)
                        {
                            syear = "2000";
                        }
                    }
                }
            }
        }

        for (int i = 0; i < layouts.Length; i++)
        {
            DataRow[] cd = code.Select("CODE = '" + layouts[i] + "'");
            string cal = cd[0]["CAL_ITEM"].ToString();
            string des = cd[0]["DES_ZH"].ToString();
            string dese = cd[0]["DES_EN"].ToString();
            string lvl = cd[0]["LVL"].ToString();

            if (cal == "NULL")
            {
                cal = layouts[i];
            }

            string[] cals = cal.Split(',');
            List<string> calcodes = setMultiCodes(classes, cals);
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
                    string de = "";
                    if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                        continue;
                    if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                        break;

                    listitem lm = new listitem();

                    //目前資料
                    decimal value = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                    }
                    //取得上期資料
                    int iy = Convert.ToInt32(y);
                    int im = Convert.ToInt32(m);
                    iy = iy - 1;

                    decimal lvalue = 0;
                    for (int k = 0; k < dsm.Count; k++)
                    {
                        DataRow[] ldsm = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                        if (ldsm.Length > 0)
                            lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                        DataRow[] ldsf = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                        if (ldsf.Length > 0)
                            lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                    }

                    lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                    lm.c = des;
                    lm.c_e = dese;
                    lm.l = lvl;

                    string dy = (Convert.ToInt16(y) - 1911).ToString();
                    if (m != "-")
                    {
                        if (infotype != "3")
                            d = dy + "年" + m + "月";
                        else
                            d = dy + "年" + m;

                        de = DictionaryMonth_Eng(m) + " " + y;
                    }
                    else
                    {
                        d = dy + "年";
                        de = y;
                    }

                    lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                    lm.d = d;
                    lm.d_e = de;
                    lm.s = "總計";
                    lm.s_e = "Total";
                    lm.st = "較上年同期增減率 (%)";
                    lm.st_e = "Change in percent from that of previous year (%)";

                    if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";
                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        //目前資料
                        decimal value = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            value += Convert.ToDecimal(dsm[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        int im = Convert.ToInt32(m);
                        iy = iy - 1;

                        decimal lvalue = 0;
                        for (int k = 0; k < dsm.Count; k++)
                        {
                            DataRow[] ldsm = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + dsm[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsm.Length > 0)
                                lvalue += Convert.ToDecimal(ldsm[0]["STAT_VAL"].ToString());
                        }

                        lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "男";
                        lm.s_e = "Male";
                        lm.st = "較上年同期增減率 (%)";
                        lm.st_e = "Change in percent from that of previous year (%)";

                        if (lm.v != -999998) listitem.Add(lm);
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
                        string de = "";

                        if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                            continue;
                        if (eyear != "" && Convert.ToInt16(y) > Convert.ToInt16(eyear))
                            break;

                        listitem lm = new listitem();

                        //目前資料
                        decimal value = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            value += Convert.ToDecimal(dsf[k].Rows[j]["STAT_VAL"].ToString());
                        }
                        //取得上期資料
                        int iy = Convert.ToInt32(y);
                        int im = Convert.ToInt32(m);
                        iy = iy - 1;

                        decimal lvalue = 0;
                        for (int k = 0; k < dsf.Count; k++)
                        {
                            DataRow[] ldsf = tar2.Select("YEAR = '" + iy + "' AND MONTH='" + im + "' AND STATID = '" + dsf[k].Rows[j]["STATID"].ToString() + "'");
                            if (ldsf.Length > 0)
                                lvalue += Convert.ToDecimal(ldsf[0]["STAT_VAL"].ToString());
                        }

                        lm.v = ComputeMod.ComputeRate(value, lvalue, 2);

                        lm.c = des;
                        lm.c_e = dese;
                        lm.l = lvl;

                        string dy = (Convert.ToInt16(y) - 1911).ToString();
                        if (m != "-")
                        {
                            if (infotype != "3")
                                d = dy + "年" + m + "月";
                            else
                                d = dy + "年" + m;

                            de = DictionaryMonth_Eng(m) + " " + y;
                        }
                        else
                        {
                            d = dy + "年";
                            de = y;
                        }

                        lm.v = CheckHideValue2(des, lm.v, dy, m, infotype, cycle, true);
                        lm.d = d;
                        lm.d_e = de;
                        lm.s = "女";
                        lm.s_e = "Female";
                        lm.st = "較上年同期增減率 (%)";
                        lm.st_e = "Change in percent from that of previous year (%)";

                        if (lm.v != -999998) listitem.Add(lm);
                    }
                }
            }
        }
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
                cs.Add("00" + codes[i] + "X0000000000000");
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
        else if (classes == "非勞動原因")
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

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM CODE WHERE CAT=@CAT AND VER=@VER AND INTERNAL = 0 ";

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

    public DataTable MerageTable(HttpContext context, List<DataTable> table)
    {
        string type = context.Request["type"] as string;

        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("STAT_VAL", typeof(Double));

        if (table.Count == 1)
        {
            DataTable d1 = table[0];
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                DataRow workRow = data.NewRow();
                workRow["YEAR"] = d1.Rows[i]["YEAR"].ToString();
                workRow["MONTH"] = d1.Rows[i]["MONTH"].ToString();
                workRow["STATID"] = d1.Rows[i]["STATID"].ToString();

                decimal dv1 = Convert.ToDecimal(d1.Rows[i]["STAT_VAL"].ToString());
                decimal va = dv1;

                workRow["STAT_VAL"] = va;
                data.Rows.Add(workRow);
            }
        }
        else
        {
            if (type == "LAF") //勞動力
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"].ToString();
                    workRow["MONTH"] = d1.Rows[i]["MONTH"].ToString();
                    workRow["STATID"] = d1.Rows[i]["STATID"].ToString();

                    decimal dv1 = Convert.ToDecimal(d1.Rows[i]["STAT_VAL"].ToString());
                    decimal dv2 = Convert.ToDecimal(d2.Rows[i]["STAT_VAL"].ToString());
                    decimal va = dv1 + dv2;

                    workRow["STAT_VAL"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "FPS") //15歲以上民間人口
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

                    decimal dv1 = Convert.ToDecimal(d1.Rows[i]["STAT_VAL"].ToString());
                    decimal dv2 = Convert.ToDecimal(d2.Rows[i]["STAT_VAL"].ToString());
                    decimal dv3 = Convert.ToDecimal(d3.Rows[i]["STAT_VAL"].ToString());
                    decimal va = dv1 + dv2 + dv3;

                    workRow["STAT_VAL"] = va;
                    data.Rows.Add(workRow);
                }
            }
            else if (type == "LFP") //勞動力參與率
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

                    decimal dv1 = Convert.ToDecimal(d1.Rows[i]["STAT_VAL"].ToString());
                    decimal dv2 = Convert.ToDecimal(d2.Rows[i]["STAT_VAL"].ToString());
                    decimal dv3 = Convert.ToDecimal(d3.Rows[i]["STAT_VAL"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((dv1 + dv2), (dv1 + dv2 + dv3), 2);
                    workRow["STAT_VAL"] = va;

                    data.Rows.Add(workRow);
                }
            }
            else if (type == "UPR") //失業率
            {
                DataTable d1 = table[0];
                DataTable d2 = table[1];

                for (int i = 0; i < d1.Rows.Count; i++)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = d1.Rows[i]["MONTH"];
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    decimal dv1 = Convert.ToDecimal(d1.Rows[i]["STAT_VAL"].ToString());
                    decimal dv2 = Convert.ToDecimal(d2.Rows[i]["STAT_VAL"].ToString());

                    decimal va = ComputeMod.ComputeAvgPercent((dv2), (dv1 + dv2), 2);
                    workRow["STAT_VAL"] = va;

                    data.Rows.Add(workRow);
                }
            }
        }

        return data;
    }

    //平均計算
    public DataTable BaseAvgTable(HttpContext context, DataTable tar)
    {
        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("STAT_VAL", typeof(String));

        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        int sy = 1911 + Convert.ToInt16(syear) - 1;
        int ey = 1911 + Convert.ToInt16(eyear);

        DataView dv = tar.DefaultView;
        DataTable dtd = dv.ToTable(true, "STATID");

        for (int i = sy; i <= ey; i++)
        {
            for (int j = 0; j < dtd.Rows.Count; j++)
            {
                string statid = dtd.Rows[j]["STATID"].ToString();
                DataRow[] fa = tar.Select("YEAR = '" + i + "' AND STATID = '" + statid + "'");
                DataRow workRow = data.NewRow();

                if (fa.Length == 12)
                {
                    decimal sum = 0;
                    for (int k = 0; k < fa.Length; k++)
                    {
                        sum += Convert.ToDecimal(fa[k]["STAT_VAL"].ToString());
                    }
                    decimal avg = sum;

                    workRow["YEAR"] = i.ToString();
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = statid;
                    workRow["STAT_VAL"] = avg.ToString();

                    data.Rows.Add(workRow);
                }
                else
                {
                    workRow["YEAR"] = i.ToString();
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = statid;
                    workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);
                }
            }
        }

        return data;
    }

    //平均計算-率
    public DataTable BaseAvgTable2(HttpContext context, List<DataTable> table)
    {
        string type = context.Request["type"] as string;

        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("STAT_VAL", typeof(String));

        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        int sy = 1911 + Convert.ToInt16(syear) - 1;
        int ey = 1911 + Convert.ToInt16(eyear);

        if (type == "LFP") //勞動力參與率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];
            DataTable d3 = table[2];

            decimal sum1 = 0, sum2 = 0, sum3 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                int nmonth = -1;

                if ((i + 1) != d1.Rows.Count)
                    nmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                if ((month != 12 && (i + 1) == d1.Rows.Count) || (month != 12 && nmonth == 1))
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = d1.Rows[i]["STATID"];
                    workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if (month == 12)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["STAT_VAL"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["STAT_VAL"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["STAT_VAL"].ToString());

                    workRow["STAT_VAL"] = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), 2);

                    if (workRow["STAT_VAL"].ToString() == "-999999") workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["STAT_VAL"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["STAT_VAL"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["STAT_VAL"].ToString());
                }
            }
        }
        else if (type == "UPR") //失業率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];

            decimal sum1 = 0, sum2 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                int nmonth = -1;

                if ((i + 1) != d1.Rows.Count)
                    nmonth = Convert.ToInt32(d1.Rows[i + 1]["MONTH"].ToString());

                if ((month != 12 && (i + 1) == d1.Rows.Count) || (month != 12 && nmonth == 1))
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = d1.Rows[i]["STATID"];
                    workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if (month == 12)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "-";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["STAT_VAL"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["STAT_VAL"].ToString());

                    workRow["STAT_VAL"] = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), 2);

                    if (workRow["STAT_VAL"].ToString() == "-999999") workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["STAT_VAL"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["STAT_VAL"].ToString());
                }
            }
        }

        return data;
    }

    //累積平均計算
    public DataTable BaseSumAvgTable(HttpContext context, DataTable tar)
    {
        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("STAT_VAL", typeof(String));

        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        int sy = 1911 + Convert.ToInt16(syear) - 1;
        int ey = 1911 + Convert.ToInt16(eyear);

        string cycle = context.Request["cycle"] as string;
        int months = Convert.ToInt16(cycle) + 1; //取得累積選擇年份

        DataView dv = tar.DefaultView;
        DataTable dtd = dv.ToTable(true, "STATID");

        for (int i = sy; i <= ey; i++)
        {
            for (int j = 0; j < dtd.Rows.Count; j++)
            {
                string statid = dtd.Rows[j]["STATID"].ToString();
                DataRow[] fa = tar.Select("YEAR = '" + i + "' AND STATID = '" + statid + "'");
                DataRow workRow = data.NewRow();

                if (fa.Length >= months)
                {
                    decimal sum = 0;
                    for (int k = 0; k < months; k++)
                    {
                        sum += Convert.ToDecimal(fa[k]["STAT_VAL"].ToString());
                    }
                    decimal avg = sum;
                    workRow["YEAR"] = i.ToString();
                    workRow["MONTH"] = "1月-" + months + "月";
                    workRow["STATID"] = statid;
                    workRow["STAT_VAL"] = avg.ToString();

                    data.Rows.Add(workRow);
                }
                else
                {
                    workRow["YEAR"] = i.ToString();
                    workRow["MONTH"] = "1月-" + months + "月";
                    workRow["STATID"] = statid;
                    workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);
                }
            }
        }

        return data;
    }

    //累計平均-率
    public DataTable BaseSumAvgTable2(HttpContext context, List<DataTable> table)
    {
        string type = context.Request["type"] as string;

        DataTable data = new DataTable();
        data.Columns.Add("YEAR", typeof(String));
        data.Columns.Add("MONTH", typeof(String));
        data.Columns.Add("STATID", typeof(String));
        data.Columns.Add("STAT_VAL", typeof(String));

        string syear = context.Request["startyear"] as string;
        string eyear = context.Request["endyear"] as string;
        int sy = 1911 + Convert.ToInt16(syear) - 1;
        int ey = 1911 + Convert.ToInt16(eyear);

        string cycle = context.Request["cycle"] as string;
        int smonths = Convert.ToInt16(cycle) + 1; //取得累積選擇年份

        if (type == "LFP") //勞動力參與率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];
            DataTable d3 = table[2];

            decimal sum1 = 0, sum2 = 0, sum3 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                if (month > smonths)
                    continue;
                else if (month == smonths)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "1月-" + month + "月";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["STAT_VAL"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["STAT_VAL"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["STAT_VAL"].ToString());

                    workRow["STAT_VAL"] = ComputeMod.ComputeAvgPercent((sum1 + sum2), (sum1 + sum2 + sum3), 2);

                    if (workRow["STAT_VAL"].ToString() == "-999999") workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                    sum3 = 0;
                }
                else if (month < smonths && (i + 1) == d1.Rows.Count)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "1月-" + month + "月";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["STAT_VAL"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["STAT_VAL"].ToString());
                    sum3 += Convert.ToInt32(d3.Rows[i]["STAT_VAL"].ToString());
                }
            }
        }
        else if (type == "UPR") //失業率
        {
            DataTable d1 = table[0];
            DataTable d2 = table[1];

            decimal sum1 = 0, sum2 = 0;
            for (int i = 0; i < d1.Rows.Count; i++)
            {
                int month = Convert.ToInt32(d1.Rows[i]["MONTH"].ToString());
                if (month > smonths)
                    continue;
                else if (month == smonths)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "1月-" + month + "月";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    sum1 += Convert.ToInt32(d1.Rows[i]["STAT_VAL"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["STAT_VAL"].ToString());

                    workRow["STAT_VAL"] = ComputeMod.ComputeAvgPercent((sum2), (sum1 + sum2), 2);

                    if (workRow["STAT_VAL"].ToString() == "-999999") workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);

                    sum1 = 0;
                    sum2 = 0;
                }
                else if (month < smonths && (i + 1) == d1.Rows.Count)
                {
                    DataRow workRow = data.NewRow();
                    workRow["YEAR"] = d1.Rows[i]["YEAR"];
                    workRow["MONTH"] = "1月-" + month + "月";
                    workRow["STATID"] = d1.Rows[i]["STATID"];

                    workRow["STAT_VAL"] = 0;

                    data.Rows.Add(workRow);
                }
                else
                {
                    sum1 += Convert.ToInt32(d1.Rows[i]["STAT_VAL"].ToString());
                    sum2 += Convert.ToInt32(d2.Rows[i]["STAT_VAL"].ToString());
                }
            }
        }

        return data;
    }

    //統計值
    public void SetBaseStatistics1(HttpContext context, DataTable tar, string classes, List<listitem> listitem)
    {
        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt16(syear) - 1).ToString();
        string eyear = context.Request["endyear"] as string;
        eyear = (1911 + Convert.ToInt16(eyear)).ToString();
        string infotype = context.Request["infotype"] as string;

        string utype = context.Request["type"] as string;
        bool people = true;
        if (classes == "失業率" || classes == "勞動力參與率" || utype == "UPR" || utype == "LFP")
            people = false;

        string cla = classes;
        if (classes == "失業率" || classes == "勞動力參與率")
            cla = "總計";

        for (int i = 0; i < tar.Rows.Count; i++)
        {
            string y = tar.Rows[i]["YEAR"].ToString(); //有抓比設定年份早一年需跳過
            if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                continue;

            listitem tmp = new listitem();
            tmp.c = cla;
            tmp.c_e = DictionaryClasses_Eng(cla);

            decimal va = Convert.ToDecimal(tar.Rows[i]["STAT_VAL"].ToString());
            tmp.v = va;

            if (utype == "LFP" || utype == "UPR")
            {
                tmp.v = tmp.v;
            }
            else
            {
                if (infotype == "2")
                    tmp.v = ComputeMod.ComputeAvgPepole(12, tmp.v, 1000);
                else if (infotype == "3")
                {
                    int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
                    tmp.v = ComputeMod.ComputeAvgPepole((cycle + 1), tmp.v, 1000);
                }
                else
                    tmp.v = ComputeMod.ComputeAvgPepole(1, tmp.v, 1000);
            }

            if (people)
            {
                tmp.st = "統計值 (千人)";
                tmp.st_e = "Data value (Thousand Persons)";
            }
            else
            {
                tmp.st = "統計值 (%)";
                tmp.st_e = "Data value (%)";
            }

            int rocy = Convert.ToInt32(y);
            rocy = rocy - 1911;
            string m = tar.Rows[i]["MONTH"].ToString();

            string d = "";
            string de = "";
            if (m != "-")
            {
                if (infotype != "3")
                    d = rocy + "年" + m + "月";
                else
                    d = rocy + "年" + m;

                de = DictionaryMonth_Eng(m) + " " + y;
            }
            else
            {
                d = rocy + "年";
                de = y;
            }

            tmp.d = d;
            tmp.d_e = de;
            tmp.l = "1";

            tmp.v = CheckHideValue3("", tmp.v, rocy.ToString(), m);

            string statid = tar.Rows[i]["STATID"].ToString();

            if (statid.IndexOf('T', 4) != -1)
            {
                tmp.s = "總計";
                tmp.s_e = "Total";
            }
            else if (statid.IndexOf('M', 4) != -1)
            {
                tmp.s = "男";
                tmp.s_e = "Male";
            }
            else if (statid.IndexOf('F', 4) != -1)
            {
                tmp.s = "女";
                tmp.s_e = "Female";
            }

            if (tmp.v != -999998) listitem.Add(tmp);
        }
    }

    //較上期增減值(百分點)
    public void SetBaseStatistics2(HttpContext context, DataTable tar, string classes, List<listitem> listitem, DataTable tar2)
    {
        string infotype = context.Request["infotype"] as string;
        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt16(syear) - 1).ToString();
        int cycle = Convert.ToInt32(context.Request["cycle"].ToString());
        string utype = context.Request["type"] as string;
        bool people = true;
        if (classes == "失業率" || classes == "勞動力參與率" || utype == "UPR" || utype == "LFP")
            people = false;

        string cla = classes;
        if (classes == "失業率" || classes == "勞動力參與率")
            cla = "總計";

        string statstr = "較上期增減值";
        string estatstr = "Change from previous period (level, percentage point)";
        if (classes == "失業率" || classes == "勞動力參與率")
            statstr = "較上期增減百分點";

        if (infotype == "3")
        {
            statstr = "較上年同期增減值";
            estatstr = "Change from that of previous year (level, percentage point)";
            if (classes == "失業率" || classes == "勞動力參與率")
                statstr = "較上年同期增減百分點";
        }

        for (int i = 0; i < tar.Rows.Count; i++)
        {
            string y = tar.Rows[i]["YEAR"].ToString(); //有抓比設定年份早一年需跳過
            if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                continue;

            listitem tmp = new listitem();

            tmp.c = cla;
            tmp.c_e = DictionaryClasses_Eng(cla);
            tmp.l = "1";

            if (people)
            {
                tmp.st = statstr + " (千人)";
                tmp.st_e = estatstr + " (Thousand Persons)";
            }
            else if (classes != "失業率" && classes != "勞動力參與率")
            {
                tmp.st = statstr + " (%)";
                tmp.st_e = estatstr + " (%)";
            }
            else
            {
                tmp.st = statstr;
                tmp.st_e = estatstr;
            }

            int iy = Convert.ToInt32(tar.Rows[i]["YEAR"].ToString());

            string mstring = tar.Rows[i]["MONTH"].ToString();
            int mdash = mstring.IndexOf("-");

            if (mdash == -1)
            {
                int im = Convert.ToInt32(tar.Rows[i]["MONTH"].ToString());

                im = im - 1;
                if (im == 0)
                {
                    iy = iy - 1;
                    im = 12;
                }

                string statid = tar.Rows[i]["STATID"].ToString();
                //取得上期資料
                DataRow[] t = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + statid + "'");

                if (t.Length > 0 && iy != 1977)
                {
                    decimal lva = Convert.ToDecimal(t[0]["STAT_VAL"].ToString());
                    decimal va = Convert.ToDecimal(tar.Rows[i]["STAT_VAL"].ToString());

                    if (utype == "LFP" || utype == "UPR")
                    {
                        tmp.v = ComputeMod.ComputeChangeValue(va, lva);
                    }
                    else
                    {
                        if (infotype == "2")
                            tmp.v = ComputeMod.ComputeChangeAvgPepole(va, lva, 12, 1000);
                        else if (infotype == "3")
                            tmp.v = ComputeMod.ComputeChangeAvgPepole(va, lva, (cycle + 1), 1000);
                        else
                            tmp.v = ComputeMod.ComputeChangeAvgPepole(va, lva, 1, 1000);
                    }
                }
                else
                {
                    tmp.v = -999999;
                }

                int rocy = Convert.ToInt32(y);
                rocy = rocy - 1911;
                tmp.d = rocy + "年" + tar.Rows[i]["MONTH"].ToString() + "月";
                tmp.d_e = DictionaryMonth_Eng(tar.Rows[i]["MONTH"].ToString()) + " " + y;

                tmp.v = CheckHideValue3("", tmp.v, rocy.ToString(), tar.Rows[i]["MONTH"].ToString());

                if (statid.IndexOf('T', 4) != -1)
                {
                    tmp.s = "總計";
                    tmp.s_e = "Total";
                }
                else if (statid.IndexOf('M', 4) != -1)
                {
                    tmp.s = "男";
                    tmp.s_e = "Male";
                }
                else if (statid.IndexOf('F', 4) != -1)
                {
                    tmp.s = "女";
                    tmp.s_e = "Female";
                }

                if (tmp.v != -999998) listitem.Add(tmp);
            }
            else
            {
                string statid = tar.Rows[i]["STATID"].ToString();
                //取得上期資料
                iy = iy - 1;
                DataRow[] t = tar.Select("YEAR = '" + iy + "' AND STATID = '" + statid + "'");

                if (t.Length > 0 && iy != 1977)
                {
                    decimal lva = Convert.ToDecimal(t[0]["STAT_VAL"].ToString());
                    decimal va = Convert.ToDecimal(tar.Rows[i]["STAT_VAL"].ToString());

                    if (utype == "LFP" || utype == "UPR")
                    {
                        tmp.v = ComputeMod.ComputeChangeValue(va, lva);
                    }
                    else
                    {
                        if (infotype == "2")
                            tmp.v = ComputeMod.ComputeChangeAvgPepole(va, lva, 12, 1000);
                        else if (infotype == "3")
                            tmp.v = ComputeMod.ComputeChangeAvgPepole(va, lva, (cycle + 1), 1000);
                        else
                            tmp.v = ComputeMod.ComputeChangeAvgPepole(va, lva, 1, 1000);
                    }
                }
                else
                {
                    tmp.v = -999999;
                }

                int rocy = Convert.ToInt32(y);
                rocy = rocy - 1911;

                if (mstring == "-")
                {
                    tmp.d = rocy + "年";
                    tmp.d_e = y;
                }
                else
                {
                    tmp.d = rocy + "年" + tar.Rows[i]["MONTH"].ToString();
                    tmp.d_e = DictionaryMonth_Eng(tar.Rows[i]["MONTH"].ToString()) + " " + y;
                }

                tmp.v = CheckHideValue3("", tmp.v, rocy.ToString(), tar.Rows[i]["MONTH"].ToString());

                if (statid.IndexOf('T', 4) != -1)
                {
                    tmp.s = "總計";
                    tmp.s_e = "Total";
                }
                else if (statid.IndexOf('M', 4) != -1)
                {
                    tmp.s = "男";
                    tmp.s_e = "Male";
                }
                else if (statid.IndexOf('F', 4) != -1)
                {
                    tmp.s = "女";
                    tmp.s_e = "Female";
                }

                if (tmp.v != -999998) listitem.Add(tmp);
            }
        }
    }

    //較上年同期增減值(百分點)
    public void SetBaseStatistics3(HttpContext context, DataTable tar, string classes, List<listitem> listitem, DataTable tar2)
    {
        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt16(syear) - 1).ToString();

        string utype = context.Request["type"] as string;
        bool people = true;
        if (classes == "失業率" || classes == "勞動力參與率" || utype == "UPR" || utype == "LFP")
            people = false;

        string cla = classes;
        if (classes == "失業率" || classes == "勞動力參與率")
            cla = "總計";

        for (int i = 0; i < tar.Rows.Count; i++)
        {
            string y = tar.Rows[i]["YEAR"].ToString(); //有抓比設定年份早一年需跳過
            if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                continue;

            listitem tmp = new listitem();

            tmp.c = cla;
            tmp.c_e = DictionaryClasses_Eng(cla);

            if (people)
            {
                tmp.st = "較上年同期增減值 (千人)";
                tmp.st_e = "Change from that of previous year (level, percentage point) (Thousand Persons)";
            }
            else if (classes != "失業率" && classes != "勞動力參與率")
            {
                tmp.st = "較上年同期增減百分點 (%)";
                tmp.st_e = "Change from that of previous year (level, percentage point) (%)";
            }
            else
            {
                tmp.st = "較上年同期增減百分點";
                tmp.st_e = "Change from that of previous year (level, percentage point)";
            }

            int iy = Convert.ToInt32(tar.Rows[i]["YEAR"].ToString());
            int im = Convert.ToInt32(tar.Rows[i]["MONTH"].ToString());

            iy = iy - 1;

            string statid = tar.Rows[i]["STATID"].ToString();
            //取得上期資料
            DataRow[] t = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + statid + "'");

            if (t.Length > 0)
            {
                decimal lva = Convert.ToDecimal(t[0]["STAT_VAL"].ToString());
                decimal va = Convert.ToDecimal(tar.Rows[i]["STAT_VAL"].ToString());

                if (people)
                    tmp.v = ComputeMod.ComputeChangeAvgPepole(va, lva, 1, 1000);
                else
                    tmp.v = ComputeMod.ComputeChangeValue(va, lva);
            }
            else
            {
                tmp.v = -999999;
            }

            int rocy = Convert.ToInt32(y);
            rocy = rocy - 1911;
            tmp.d = rocy + "年" + tar.Rows[i]["MONTH"].ToString() + "月";
            tmp.d_e = DictionaryMonth_Eng(tar.Rows[i]["MONTH"].ToString()) + " " + y;

            tmp.v = CheckHideValue3("", tmp.v, rocy.ToString(), tar.Rows[i]["MONTH"].ToString());

            if (statid.IndexOf('T', 4) != -1)
            {
                tmp.s = "總計";
                tmp.s_e = "Total";
            }
            else if (statid.IndexOf('M', 4) != -1)
            {
                tmp.s = "男";
                tmp.s_e = "Male";
            }
            else if (statid.IndexOf('F', 4) != -1)
            {
                tmp.s = "女";
                tmp.s_e = "Female";
            }
            tmp.l = "1";

            if (tmp.v != -999998) listitem.Add(tmp);
        }
    }

    //結構比
    public void SetBaseStatistics4(HttpContext context, DataTable tb, string classes, List<listitem> listitem)
    {
        List<DataTable> ds = GetBaseTablesForStructure(context);

        string xstring = context.Request["sex"] as string;
        string[] sex = xstring.Split(',');
        string infotype = context.Request["infotype"] as string;
        string cycle = context.Request["cycle"] as string;
        string syear = context.Request["startyear"] as string;
        syear = (Convert.ToInt16(syear) - 1).ToString();

        List<string> tlist = Dictionary(context);

        DataTable tar = null;
        tar = MerageTable(context, ds);

        if (infotype == "1")
        {
            if (cycle != "0")
            {
                tar = tar.Select("MONTH = '" + cycle + "'").CopyToDataTable();
            }
        }
        else if (infotype == "2")
        {
            tar = BaseAvgTable(context, tar);
        }
        else if (infotype == "3")
        {
            tar = BaseSumAvgTable(context, tar);
        }

        DataView dv = tar.DefaultView;
        DataTable dtd = dv.ToTable(true, "STATID");

        string fid = dtd.Rows[0]["STATID"].ToString();
        string mid = dtd.Rows[1]["STATID"].ToString();

        DataRow[] mdr = tar.Select("STATID = '" + mid + "'");
        DataRow[] fdr = tar.Select("STATID = '" + fid + "'");

        for (int i = 0; i < mdr.Length; i++)
        {
            decimal mv = Convert.ToDecimal(mdr[i]["STAT_VAL"].ToString());
            decimal fv = Convert.ToDecimal(fdr[i]["STAT_VAL"].ToString());
            decimal total = mv + fv;

            decimal tvs = ComputeMod.ComputeAvgPercent(total, total, 2);
            decimal mvs = ComputeMod.ComputeAvgPercent(mv, total, 2);
            decimal fvs = ComputeMod.ComputeAvgPercent(fv, total, 2);

            string y = (Convert.ToInt16(mdr[i]["YEAR"].ToString()) - 1911).ToString();
            string ry = mdr[i]["YEAR"].ToString();
            if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                continue;
            string m = mdr[i]["MONTH"].ToString();

            string d = "";
            string de = "";
            if (m != "-")
            {
                if (infotype != "3")
                    d = y + "年" + m + "月";
                else
                    d = y + "年" + m;

                de = DictionaryMonth_Eng(m) + " " + ry;
            }
            else
            {
                d = y + "年";
                de = ry;
            }

            for (int k = 0; k < sex.Length; k++)
            {
                if (sex[k] == "M")
                {
                    mvs = CheckHideValue3("", mvs, y, m);
                    listitem lm = new listitem()
                    {
                        c = classes,
                        c_e = DictionaryClasses_Eng(classes),
                        s = "男",
                        s_e = "Male",
                        d = d,
                        d_e = de,
                        st = "結構比 (%)",
                        st_e = "% of Total",
                        l = "1",
                        v = mvs
                    };
                    if (lm.v != -999998) listitem.Add(lm);
                }
                else if (sex[k] == "F")
                {
                    fvs = CheckHideValue3("", fvs, y, m);
                    listitem lf = new listitem()
                    {
                        c = classes,
                        c_e = DictionaryClasses_Eng(classes),
                        s = "女",
                        s_e = "Female",
                        d = d,
                        d_e = de,
                        st = "結構比 (%)",
                        st_e = "% of Total",
                        l = "1",
                        v = fvs
                    };
                    if (lf.v != -999998) listitem.Add(lf);
                }
                else if (sex[k] == "T")
                {
                    tvs = CheckHideValue3("", tvs, y, m);
                    listitem lt = new listitem()
                    {
                        c = classes,
                        c_e = DictionaryClasses_Eng(classes),
                        s = "總計",
                        s_e = "Total",
                        d = d,
                        d_e = de,
                        st = "結構比 (%)",
                        st_e = "% of Total",
                        l = "2",
                        v = tvs
                    };

                    if (lt.v != -999998) listitem.Add(lt);
                }
            }
        }
    }

    //較上期增減率
    public void SetBaseStatistics5(HttpContext context, DataTable tar, string classes, List<listitem> listitem, DataTable tar2)
    {
        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt16(syear) - 1).ToString();
        string infotype = context.Request["infotype"] as string;
        int cycle = Convert.ToInt32(context.Request["cycle"] as string);

        string statstr = "較上期增減率 (%)";
        string estatstr = "Change in percent from previous period (%)";

        if (infotype == "3")
        {
            statstr = "較上年同期增減率 (%)";
            estatstr = "Change in percent from that of previous year (%)";
        }

        for (int i = 0; i < tar.Rows.Count; i++)
        {
            string y = tar.Rows[i]["YEAR"].ToString(); //有抓比設定年份早一年需跳過
            if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                continue;

            listitem tmp = new listitem();

            tmp.c = classes;
            tmp.c_e = DictionaryClasses_Eng(classes);
            tmp.st = statstr;
            tmp.st_e = estatstr;

            int iy = Convert.ToInt32(tar.Rows[i]["YEAR"].ToString());
            string mstring = tar.Rows[i]["MONTH"].ToString();
            int mdash = mstring.IndexOf("-");

            if (mdash == -1)
            {
                int im = Convert.ToInt32(tar.Rows[i]["MONTH"].ToString());

                im = im - 1;
                if (im == 0)
                {
                    iy = iy - 1;
                    im = 12;
                }

                string statid = tar.Rows[i]["STATID"].ToString();
                //取得上期資料
                DataRow[] t = tar2.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + statid + "'");

                if (t.Length > 0)
                {
                    decimal lva = Convert.ToDecimal(t[0]["STAT_VAL"].ToString());
                    decimal va = Convert.ToDecimal(tar.Rows[i]["STAT_VAL"].ToString());

                    tmp.v = ComputeMod.ComputeRate(va, lva, 2);
                }
                else
                {
                    tmp.v = -999999;
                }

                int rocy = Convert.ToInt32(y);
                rocy = rocy - 1911;
                tmp.d = rocy + "年" + tar.Rows[i]["MONTH"].ToString() + "月";
                tmp.d_e = DictionaryMonth_Eng(tar.Rows[i]["MONTH"].ToString()) + " " + y;

                tmp.v = CheckHideValue3("", tmp.v, rocy.ToString(), tar.Rows[i]["MONTH"].ToString());

                if (statid.IndexOf('T', 4) != -1)
                {
                    tmp.s = "總計";
                    tmp.s_e = "Total";
                }
                else if (statid.IndexOf('M', 4) != -1)
                {
                    tmp.s = "男";
                    tmp.s_e = "Male";
                }
                else if (statid.IndexOf('F', 4) != -1)
                {
                    tmp.s = "女";
                    tmp.s_e = "Female";
                }
                tmp.l = "1";

                if (tmp.v != -999998) listitem.Add(tmp);
            }
            else
            {
                string statid = tar.Rows[i]["STATID"].ToString();
                //取得上期資料
                iy = iy - 1;
                DataRow[] t = tar.Select("YEAR = '" + iy + "' AND STATID = '" + statid + "'");

                if (t.Length > 0)
                {
                    decimal lva = Convert.ToDecimal(t[0]["STAT_VAL"].ToString());
                    decimal va = Convert.ToDecimal(tar.Rows[i]["STAT_VAL"].ToString());

                    tmp.v = ComputeMod.ComputeRate(va, lva, 2);
                }
                else
                {
                    tmp.v = -999999;
                }

                int rocy = Convert.ToInt32(y);
                rocy = rocy - 1911;

                if (mstring == "-")
                {
                    tmp.d = rocy + "年";
                    tmp.d_e = y;
                }
                else
                {
                    tmp.d = rocy + "年" + tar.Rows[i]["MONTH"].ToString();
                    tmp.d_e = DictionaryMonth_Eng(tar.Rows[i]["MONTH"].ToString()) + " " + y;
                }

                tmp.v = CheckHideValue3("", tmp.v, rocy.ToString(), tar.Rows[i]["MONTH"].ToString());

                if (statid.IndexOf('T', 4) != -1)
                {
                    tmp.s = "總計";
                    tmp.s_e = "Total";
                }
                else if (statid.IndexOf('M', 4) != -1)
                {
                    tmp.s = "男";
                    tmp.s_e = "Male";
                }
                else if (statid.IndexOf('F', 4) != -1)
                {
                    tmp.s = "女";
                    tmp.s_e = "Female";
                }

                if (tmp.v != -999998)listitem.Add(tmp);
            }
        }
    }

    //較上年同期增減率
    public void SetBaseStatistics6(HttpContext context, DataTable tar, string classes, List<listitem> listitem, DataTable tar2)
    {
        string syear = context.Request["startyear"] as string;
        syear = (1911 + Convert.ToInt16(syear) - 1).ToString();

        for (int i = 0; i < tar.Rows.Count; i++)
        {
            string y = tar.Rows[i]["YEAR"].ToString(); //有抓比設定年份早一年需跳過
            if (Convert.ToInt32(y) <= Convert.ToInt32(syear))
                continue;

            listitem tmp = new listitem();

            tmp.c = classes;
            tmp.c_e = DictionaryClasses_Eng(classes);
            tmp.st = "較上年同期增減率 (%)";
            tmp.st_e = "Change in percent from that of previous year (%)";

            int iy = Convert.ToInt32(tar.Rows[i]["YEAR"].ToString());
            int im = Convert.ToInt32(tar.Rows[i]["MONTH"].ToString());

            iy = iy - 1;

            string statid = tar.Rows[i]["STATID"].ToString();
            //取得上期資料
            DataRow[] t = tar.Select("YEAR = '" + iy + "' AND MONTH = '" + im + "' AND STATID = '" + statid + "'");

            if (t.Length > 0)
            {
                decimal lva = Convert.ToDecimal(t[0]["STAT_VAL"].ToString());
                decimal va = Convert.ToDecimal(tar.Rows[i]["STAT_VAL"].ToString());

                tmp.v = ComputeMod.ComputeRate(va, lva, 2);
            }
            else
            {
                tmp.v = -999999;
            }

            int rocy = Convert.ToInt32(y);
            rocy = rocy - 1911;
            tmp.d = rocy + "年" + tar.Rows[i]["MONTH"].ToString() + "月";
            tmp.d_e = DictionaryMonth_Eng(tar.Rows[i]["MONTH"].ToString()) + " " + y;

            tmp.v = CheckHideValue3("", tmp.v, rocy.ToString(), tar.Rows[i]["MONTH"].ToString());

            if (statid.IndexOf('T', 4) != -1)
            {
                tmp.s = "總計";
                tmp.s_e = "Total";
            }
            else if (statid.IndexOf('M', 4) != -1)
            {
                tmp.s = "男";
                tmp.s_e = "Male";
            }
            else if (statid.IndexOf('F', 4) != -1)
            {
                tmp.s = "女";
                tmp.s_e = "Female";
            }

            tmp.l = "1";

            if (tmp.v != -999998)listitem.Add(tmp);
        }
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

    public decimal CheckHideValue(string des, decimal value, string sy, string sm)
    {
        string showyear = getShowYear();
        string showmonth = getShowMonth();

        int y = Convert.ToInt32(sy);
        if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
            return -999999;

        int maxyear = Convert.ToInt32(showyear);
        int maxmonth = Convert.ToInt32(showmonth);
        if (y > maxyear)
            return -999999;

        int m = -1;
        if (Int32.TryParse(sm, out m) && y == maxyear)
        {
            if (m > maxmonth)
                return -999998;
        }

        if (y == maxyear && sm == "-" && maxmonth != 12) return -999999;
        string[] ss = sm.Split('-');
        if (y == maxyear && ss.Length > 1)
        {
            string[] ms = ss[1].Split('月');
            if (ms.Length > 1)
            {
                int ds = Convert.ToInt32(ms[0]);
                if (ds > maxmonth) return -999998;
            }
        }

        return value;
    }

    public decimal CheckHideValue2(string des, decimal value, string sy, string sm, string infotype, int cycle, bool ispreYear)
    {
        string showyear = getShowYear();
        string showmonth = getShowMonth();

        int y = Convert.ToInt32(sy);

        if (sm == "-" || sm == "")
        {
            if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
            if (y == 100 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
        }
        /* else if (infotype == "1" && cycle != 0)
        {
            int m = Convert.ToInt32(sm);
            if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
            if (y == 100 && m == cycle && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
        } */
        else if (infotype == "1" && cycle == 0 && ispreYear == true)
        {
            int m = Convert.ToInt32(sm);
            if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
            if (y == 100 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
        }
        else if (infotype == "1" && cycle == 0 && ispreYear == false)
        {
            int m = Convert.ToInt32(sm);
            if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
            if (y == 100 && m == 1 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
        }
        else if (infotype == "3")
        {
            if (y <= 100 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
        }
        else
        {
            int m = Convert.ToInt32(sm);
            if (y <= 99 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
            if (y == 100 && m == 1 && (des == "大學" || des == "碩士" || des == "博士" || des == "研究所"))
                return -999999;
        }

        int maxyear = Convert.ToInt32(showyear);
        int maxmonth = Convert.ToInt32(showmonth);
        if (y > maxyear)
            return -999999;

        int im = -1;
        if (Int32.TryParse(sm, out im) && y == maxyear)
        {
            if (im > maxmonth)
                return -999998;
        }

        if (y == maxyear && sm == "-" && maxmonth != 12) return -999999;
        string[] ss = sm.Split('-');
        if (y == maxyear && ss.Length > 1)
        {
            string[] ms = ss[1].Split('月');
            if (ms.Length > 1)
            {
                int ds = Convert.ToInt32(ms[0]);
                if (ds > maxmonth) return -999998;
            }
        }

        return value;
    }

    public decimal CheckHideValue3(string des, decimal value, string sy, string sm)
    {
        string showyear = getShowYear();
        string showmonth = getShowMonth();

        int y = Convert.ToInt32(sy);

        int maxyear = Convert.ToInt32(showyear);
        int maxmonth = Convert.ToInt32(showmonth);
        if (y > maxyear)
            return -999999;

        int m = -1;
        if (Int32.TryParse(sm, out m) && y == maxyear)
        {
            if (m > maxmonth) return -999998;
        }

        if (y == maxyear && sm == "-" && maxmonth != 12) return -999999;

        string[] ss = sm.Split('-');
        if (y == maxyear && ss.Length > 1)
        {
            string[] ms = ss[1].Split('月');
            if (ms.Length > 1)
            {
                int ds = Convert.ToInt32(ms[0]);
                if (ds > maxmonth) return -999998;
            }
        }

        return value;
    }

    //取得顯示到的年份跟月份
    public String getShowYear2()
    {
        string daystring = ConfigurationManager.AppSettings["SeasonYear"];
        return daystring;
    }

    public String getShowMonth2()
    {
        string daystring = ConfigurationManager.AppSettings["SeasonMonth"];
        return daystring;
    }

    public decimal CheckHideValue4(decimal value, string sy, string sm)
    {
        string showyear = getShowYear2();
        string showmonth = getShowMonth2();

        int y = Convert.ToInt32(sy);

        int maxyear = Convert.ToInt32(showyear);
        int maxmonth = Convert.ToInt32(showmonth);
        if (y > maxyear)
            return -999999;

        int m = -1;
        if (Int32.TryParse(sm, out m) && y == maxyear)
        {
            if (m > maxmonth)
                return -999998;
        }

        return value;
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
            DataTable tmp = getTabelByCodes(context, cs, "NEW172A");
            dlist.Add(tmp);
        }

        return dlist;
    }

    public string DictionaryType_Eng(string s)
    {
        switch (s)
        {
            case "PEP":
                return "Employed";
            case "PUP":
                return "Unemployed";
            case "NLF":
                return "Not in Labor Force";
            case "LAF":
                return "Labor Force";
            case "FPS":
                return "Civilian Population Aged 15 Years & Over";
            case "LFP":
                return "Labor Force Participation Rate";
            case "UPR":
                return "Unemployment Rate";
            default:
                return "";
        }
    }

    public string DictionaryClasses_Eng(string s)
    {
        switch (s)
        {
            case "總計":
                return "Total";
            case "失業率":
                return "Unemployment Rate";
            case "勞動力參與率":
                return "Labor Force Participation Rate";
            case "年齡":
                return "Age";
            case "教育程度":
                return "Educational Attainment";
            case "行業_6":
                return "Industry_6";
            case "行業_7":
                return "Industry_7";
            case "行業_8":
                return "Industry_8";
            case "行業_12":
                return "Industry_12";
            case "職業_5":
                return "Occupation_5";
            case "職業_6":
                return "Occupation_6";
            case "從業身分":
                return "Class of Worker";
            case "非勞動原因":
                return "Reason for Not in Labor Force";
            case "失業原因":
                return "Reason for Unemployment";
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
            case "1月-1月":
                return "Jan to Jan";
            case "1月-2月":
                return "Jan to Feb";
            case "1月-3月":
                return "Jan to Mar";
            case "1月-4月":
                return "Jan to Apr";
            case "1月-5月":
                return "Jan to May";
            case "1月-6月":
                return "Jan to June";
            case "1月-7月":
                return "Jan to July";
            case "1月-8月":
                return "Jan to Aug";
            case "1月-9月":
                return "Jan to Sept";
            case "1月-10月":
                return "Jan to Oct";
            case "1月-11月":
                return "Jan to Nov";
            case "1月-12月":
                return "Jan to Dec";
            default:
                return "";
        }
    }

    public bool IsReusable
    {
        get
        {
            return false;
        }
    }
}