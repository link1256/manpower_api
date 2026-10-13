<%@ WebHandler Language="C#" Class="BackDataUpload" %>

using Newtonsoft.Json;
using System;
using System.Data;
using System.Configuration;
using System.Web;
using System.Web.Configuration;
using System.Data.SqlClient;
using System.Reflection;
using System.Diagnostics;
using System.IO;
using System.Collections.Generic;
using System.Threading;
using System.Windows.Forms;
using Supergeo.StatUtils;
using Microsoft.VisualBasic.FileIO;
using System.Web.SessionState;
using NPOI.HSSF.UserModel;
using NPOI.SS.UserModel;
using NPOI.XSSF.UserModel;
using Supergeo.Utilities;

public class BackDataUpload : IHttpHandler, IRequiresSessionState
{
    String sqlConnstr = System.Configuration.ConfigurationManager.ConnectionStrings["sqlconn"].ConnectionString;
    private ManPowerProcess process = null;
    private HttpContext glcontext = null;
    public void ProcessRequest (HttpContext context) {
        try
        {
            String result = "";
            Type t = GetType();
            MethodInfo m = t.GetMethod(context.Request.Form["op"] as String);
            if (m != null)
                result = m.Invoke(this, new object[] { context }) as string;

            context.Response.Write(result);
        }
        catch (Exception e)
        {
            string ex = e.ToString();
            context.Response.Write("ERROR");
            // // context.Response.Write(ex);
        }
    }

    public string UploadFiled(HttpContext context)
    {
        string jdata = "";
        try
        {
            //if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
            //{
                string type = context.Request.Form["type"] as string;
                glcontext = context;
                if (context.Request.Files.Count > 0)
                {
                    HttpPostedFile file = null;
                    file = context.Request.Files[0];
                    string fileName = HttpUtility.HtmlEncode(file.FileName);
                    string extension = System.IO.Path.GetExtension(file.FileName);
                    if (extension != ".txt") return "上傳檔案格式錯誤";

                    string path = HttpContext.Current.Server.MapPath(".\\upload\\" + fileName);
                    file.SaveAs(path);

                    if (type == "3")
                        UpdataMonthlyTable(context, path);
                    else if (type == "4")
                        UpdataSeasonTable(context, path);
                    else if (type == "5")
                        UpdataYearReportTable(context, path);
                    else
                        UpdateTable(context, path);

                    jdata = "OK";
                }
                else
                {
                    jdata = "NO FILE";
                }
            //}
        }
        catch (Exception ex)
        {
            WriteLog(ex.ToString());
            jdata = "ERROR";
        }

        return jdata;
    }

    public void UpdataYearReportTable(HttpContext context, string path)
    {
        string guid = context.Request.Form["GUUID"] as string;
        string table = context.Request.Form["table"] as string;
        string datetype = context.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string startdate = context.Request.Form["startdate"] as string;
        string enddate = context.Request.Form["enddate"] as string;
        string type = context.Request.Form["type"] as string;

        guid = HttpUtility.HtmlEncode(guid);
        type = HttpUtility.HtmlEncode(type);
        table = HttpUtility.HtmlEncode(table);
        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        if (File.Exists(path))
        {
            Dictionary<String, Object> objs = new Dictionary<String, Object>();
            objs.Add("guid", guid);
            objs.Add("type", type);
            objs.Add("table", table);
            objs.Add("datetype", datetype);
            objs.Add("startdate", startdate);
            objs.Add("enddate", enddate);
            objs.Add("path", path);

            Thread workerThread = new Thread(new ParameterizedThreadStart(DoYearReportUpdate));
            workerThread.Start(objs);
        }
    }

    public void UpdataSeasonTable(HttpContext context, string path)
    {
        string guid = glcontext.Request.Form["GUUID"] as string;
        string type = context.Request.Form["type"] as string; //1: 全臺 2: 縣市
        string table = context.Request.Form["table"] as string;
        string datetype = context.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string startdate = context.Request.Form["startdate"] as string;
        string enddate = context.Request.Form["enddate"] as string;

        guid = HttpUtility.HtmlEncode(guid);
        type = HttpUtility.HtmlEncode(type);
        table = HttpUtility.HtmlEncode(table);
        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        if (File.Exists(path))
        {
            Dictionary<String, Object> objs = new Dictionary<String, Object>();
            objs.Add("guid", guid);
            objs.Add("type", type);
            objs.Add("table", table);
            objs.Add("datetype", datetype);
            objs.Add("startdate", startdate);
            objs.Add("enddate", enddate);
            objs.Add("path", path);
            Thread workerThread = new Thread(new ParameterizedThreadStart(DoSeasonUpdate));
            workerThread.Start(objs);
        }
    }

    public void DoYearReportUpdate(object parameters)
    {
        Dictionary<String, Object> objs = parameters as Dictionary<String, Object>;
        string datetype = objs["datetype"] as string;
        string type = objs["type"] as string;
        string guid = objs["guid"] as string;
        string tb = objs["table"] as string;
        string startdate = objs["startdate"] as string;
        string enddate = objs["enddate"] as string;

        if (objs != null)
        {
            Int32 Status = 0;
            try
            {
                String Path = objs["path"] as String;
                DataTable dt = GetYearReportDataFromCSVFile(Path);
                dt.DefaultView.Sort = "欄位1 ";
                dt = dt.DefaultView.ToTable();
                List<string> lstYM = new List<string>();
                lstYM.Add(dt.Rows[0]["欄位1"].ToString());
                lstYM.Add(dt.Rows[dt.Rows.Count - 1]["欄位1"].ToString());
                // UpdateToDB4(lstYM, true, objs["table"].ToString());
                DataLogInsert(lstYM, true);

                int isy = 0, iey = 0;
                if (glcontext != null)
                {
                    bool ismonthly = true;
                    string syear = "";
                    string eyear = "";

                    if (datetype == "1" && ismonthly != true)
                    {
                        syear = lstYM[0].ToString();
                        eyear = lstYM[lstYM.Count - 1].ToString();
                    }
                    else if (datetype == "2" || ismonthly == true)
                    {
                        syear = startdate;
                        eyear = enddate;
                    }

                    isy = Convert.ToInt32(syear);
                    iey = Convert.ToInt32(eyear);

                    string t = "年報資料";
                    string tf = "表側為年分";
                    if (tb == "Year_Table_Nonetimeline")
                        tf = "表側非年分";
                    else if (tb == "Table3")
                        tf = "Table3";

                    uploadlog(glcontext, "資料維護", "更新(" + t + ") 資料 (" + tf + "),(" + syear + "年" + " - " + eyear + "年" + ")");
                }

                if (tb == "Table3")
                    tb = "Year_Table_Timeline";

                Int32 nBatchLimit = 1000;
                string sqlStr = "";
                int expectcount = 0;
                for (int i = 0; i < dt.Rows.Count; i++)
                {
                    int dy = Convert.ToInt32(dt.Rows[i]["欄位1"].ToString());
                    if (dy < isy || dy > iey)
                        continue;

                    // 先刪除已有的資料
                    sqlStr += String.Format(@"
                        DELETE FROM {0}
                        WHERE [欄位1]={1} AND [欄位2]={2} AND [欄位3]={3} AND [欄位4]={4} AND [欄位5]={5};
                    ", tb, dt.Rows[i]["欄位1"].ToString(), dt.Rows[i]["欄位2"].ToString(),dt.Rows[i]["欄位3"].ToString(),dt.Rows[i]["欄位4"].ToString(),dt.Rows[i]["欄位5"].ToString());

                    // 匯入新資料
                    sqlStr += @" INSERT INTO " + tb + " ";
                    string sqlStr1 = @" ( ";
                    string sqlStr2 = @" VALUES ('";

                    for (int j = 1; j <= 76; j++)
                    {
                        if (j != 1)
                        {
                            sqlStr1 += ", ";
                            sqlStr2 += "', '";
                        }
                        sqlStr1 += "[欄位" + j + "]";
                        sqlStr2 += dt.Rows[i]["欄位" + j].ToString();
                    }
                    sqlStr1 += ") ";
                    sqlStr2 += "'); ";

                    sqlStr += sqlStr1;
                    sqlStr += sqlStr2;

                    expectcount++;
                    if (expectcount % nBatchLimit == 0) // 每N筆處理一次
                    {
                        using (SqlConnection connection = new SqlConnection(sqlConnstr))
                        {
                            SqlCommand command = new SqlCommand("", connection);
                            command.CommandText = sqlStr;
							command.CommandTimeout = 30000;

                            try
                            {
                                if (connection.State == ConnectionState.Closed)
                                {
                                    connection.Open();
                                    command.ExecuteNonQuery();
                                }
                            }
                            catch (Exception ex)
                            {
                                WriteLog(ex.ToString());
                            }
                            finally
                            {
                                sqlStr = "";
                                expectcount = 0;
                                connection.Close();
                            }
                        };
                    }
                }
                if (expectcount != 0) // 結束後有殘存的 需要再處理
                {
                    using (SqlConnection connection = new SqlConnection(sqlConnstr))
                    {
                        SqlCommand command = new SqlCommand("", connection);
                        command.CommandText = sqlStr;
						command.CommandTimeout = 30000;

                        try
                        {
                            if (connection.State == ConnectionState.Closed)
                            {
                                connection.Open();
                                command.ExecuteNonQuery();
                            }
                        }
                        catch (Exception ex)
                        {
                            WriteLog(ex.ToString());
                        }
                        finally
                        {
                            connection.Close();
                        }
                    };
                }
            }
            catch (Exception ex)
            {
                Status = 2;
                WriteLog(ex.ToString());
            }
            finally
            {
                UpdateFinishedFromCallback(new FinishItem() { UniqueID = objs["guid"].ToString(), UserBreak=Status });
            }
        }
    }

    public void DoSeasonUpdate(object parameters)
    {
        string datetype = glcontext.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string type = glcontext.Request.Form["type"] as string;
        string guid = glcontext.Request.Form["GUUID"] as string;
        string tb = glcontext.Request.Form["table"] as string;
        string startdate = glcontext.Request.Form["startdate"] as string;
        string enddate = glcontext.Request.Form["enddate"] as string;

        guid = HttpUtility.HtmlEncode(guid);
        type = HttpUtility.HtmlEncode(type);
        tb = HttpUtility.HtmlEncode(tb);
        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        Dictionary<String, Object> objs = parameters as Dictionary<String, Object>;
        if (objs != null)
        {
            Int32 Status = 0;
            try
            {
                String Path = objs["path"] as String;
                DataTable dt = GetSeasonDataFromCSVFile(Path);
                List<string> lstYM = new List<string>();
                lstYM.Add(dt.Rows[0]["Date"].ToString().Substring(0, 4) + "/" + dt.Rows[0]["Date"].ToString().Substring(4, 2));
                lstYM.Add(dt.Rows[dt.Rows.Count - 1]["Date"].ToString().Substring(0, 4) + "/" + dt.Rows[dt.Rows.Count - 1]["Date"].ToString().Substring(4, 2));
                UpdateToDB3(lstYM, true, objs["table"].ToString());
                DataLogInsert(lstYM, true);

                int isy = 0, iey = 0, ism = 0, iem = 0;
                if (glcontext != null)
                {
                    bool ismonthly = true;
                    string syear = "";
                    string eyear = "";
                    string smonth = "";
                    string emonth = "";

                    if (datetype == "1" && ismonthly != true)
                    {
                        syear = lstYM[0][0].ToString() + lstYM[0][1].ToString() + lstYM[0][2].ToString() + lstYM[0][3].ToString();
                        eyear = lstYM[lstYM.Count - 1][0].ToString() + lstYM[lstYM.Count - 1][1].ToString() + lstYM[lstYM.Count - 1][2].ToString() + lstYM[lstYM.Count - 1][3].ToString();
                        smonth = lstYM[0][4].ToString() + lstYM[0][5].ToString();
                        emonth = lstYM[lstYM.Count - 1][4].ToString() + lstYM[lstYM.Count - 1][5].ToString();
                    }
                    else if (datetype == "2" || ismonthly == true)
                    {
                        string[] asy = startdate.Split('/');
                        string[] esy = enddate.Split('/');
                        syear = asy[0];
                        eyear = esy[0];
                        smonth = asy[1];
                        emonth = esy[1];
                    }

                    isy = Convert.ToInt32(syear);
                    iey = Convert.ToInt32(eyear);
                    ism = Convert.ToInt32(smonth);
                    iem = Convert.ToInt32(emonth);

                    string t = "季節調整";

                    uploadlog(glcontext, "資料維護", "更新(" + t + ") 資料 (" + tb + "),(" + syear + "年" + smonth + "月 - " + eyear + "年" + emonth + "月)");
                }

                Int32 nBatchLimit = 1000;
                string sqlStr = "";
                int expectcount = 0;
                for (int i = 0; i < dt.Rows.Count; i++)
                {
                    int dy = Convert.ToInt32(dt.Rows[i]["Date"].ToString().Substring(0, 4));
                    int dm = Convert.ToInt32(dt.Rows[i]["Date"].ToString().Substring(4, 2));

                    if (dy < isy || dy > iey)
                        continue;
                    else if ((dy == iey && dm < ism) || (dy == iey && dm > iem))
                        continue;

                    sqlStr += @" INSERT INTO Unemployedrate_Adjust ([Year],[Month],[Employed],[Unemployed],[Labor_Force],[Not_In_Labor_Force],[Unemployment_Rate],[Labor_Force_Participation_Rate]) ";
                    sqlStr += @" VALUES ('" + dt.Rows[i]["Date"].ToString().Substring(0, 4) + "','" + dt.Rows[i]["Date"].ToString().Substring(4, 2) + "','" + dt.Rows[i]["Employed"].ToString() + "','" + dt.Rows[i]["Unemployed"].ToString() + "','" + dt.Rows[i]["Labor_Force"].ToString()
                            + "','" + dt.Rows[i]["Not_In_Labor_Force"].ToString() + "','" + dt.Rows[i]["Unemployment_Rate"].ToString() + "','" + dt.Rows[i]["Labor_Force_Participation_Rate"].ToString() + "') ";

                    expectcount++;
                    if (expectcount % nBatchLimit == 0) //每1000筆處理一次
                    {
                        using (SqlConnection connection = new SqlConnection(sqlConnstr))
                        {
                            SqlCommand command = new SqlCommand("", connection);
                            command.CommandText = sqlStr;

                            try
                            {
                                if (connection.State == ConnectionState.Closed)
                                {
                                    connection.Open();
                                    command.ExecuteNonQuery();
                                }
                            }
                            finally
                            {
                                sqlStr = "";
                                expectcount = 0;
                                connection.Close();
                            }
                        };
                    }
                }
                if (expectcount != 0) // 結束後有殘存的 需要再處理
                {
                    using (SqlConnection connection = new SqlConnection(sqlConnstr))
                    {
                        SqlCommand command = new SqlCommand("", connection);
                        command.CommandText = sqlStr;

                        try
                        {
                            if (connection.State == ConnectionState.Closed)
                            {
                                connection.Open();
                                command.ExecuteNonQuery();
                            }
                        }
                        finally
                        {
                            connection.Close();
                        }
                    };
                }
            }
            catch (Exception ex)
            {
                Status = 2;
                ex.StackTrace.ToString();
            }
            finally
            {
                UpdateFinishedFromCallback(new FinishItem() { UniqueID = objs["guid"].ToString(), UserBreak=Status });
            }
        }
    }

    public void UpdataMonthlyTable(HttpContext context, string path)
    {
        string guid = glcontext.Request.Form["GUUID"] as string;
        string type = context.Request.Form["type"] as string; //1: 全臺 2: 縣市
        string table = context.Request.Form["table"] as string;
        string datetype = context.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string startdate = context.Request.Form["startdate"] as string;
        string enddate = context.Request.Form["enddate"] as string;

        guid = HttpUtility.HtmlEncode(guid);
        type = HttpUtility.HtmlEncode(type);
        table = HttpUtility.HtmlEncode(table);
        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        if (File.Exists(path))
        {
            Dictionary<String, Object> objs = new Dictionary<String, Object>();
            objs.Add("guid", guid);
            objs.Add("type", type);
            objs.Add("table", table);
            objs.Add("datetype", datetype);
            objs.Add("startdate", startdate);
            objs.Add("enddate", type);
            objs.Add("path", path);
            Thread workerThread = new Thread(new ParameterizedThreadStart(DoMonthlyUpdate));
            workerThread.Start(objs);
        }
    }

    public void DoMonthlyUpdate(object parameters)
    {
        string datetype = glcontext.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string type = glcontext.Request.Form["type"] as string;
        string guid = glcontext.Request.Form["GUUID"] as string;
        string tb = glcontext.Request.Form["table"] as string;
        string startdate = glcontext.Request.Form["startdate"] as string;
        string enddate = glcontext.Request.Form["enddate"] as string;

        guid = HttpUtility.HtmlEncode(guid);
        type = HttpUtility.HtmlEncode(type);
        tb = HttpUtility.HtmlEncode(tb);
        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        Dictionary<String, Object> objs = parameters as Dictionary<String, Object>;
        if (objs != null)
        {
            Int32 Status = 0;

            try
            {
                String Path = objs["path"] as String;
                DataTable dt = GetDataTabletFromCSVFile(Path);
                List<string> lstYM = new List<string>();

                lstYM.Add(dt.Rows[0]["欄位1"].ToString() + "/" + dt.Rows[0]["欄位2"].ToString());
                lstYM.Add(dt.Rows[dt.Rows.Count - 1]["欄位1"].ToString() + "/" + dt.Rows[dt.Rows.Count - 1]["欄位2"].ToString());

                UpdateToDB2(lstYM, true, objs["table"].ToString());
                DataLogInsert(lstYM, true);

                int isy = 0, iey = 0, ism = 0, iem = 0;
                if (glcontext != null)
                {
                    bool ismonthly = true;
                    string syear = "";
                    string eyear = "";
                    string smonth = "";
                    string emonth = "";

                    if (datetype == "1" && ismonthly != true)
                    {
                        syear = lstYM[0][0].ToString() + lstYM[0][1].ToString() + lstYM[0][2].ToString() + lstYM[0][3].ToString();
                        eyear = lstYM[lstYM.Count - 1][0].ToString() + lstYM[lstYM.Count - 1][1].ToString() + lstYM[lstYM.Count - 1][2].ToString() + lstYM[lstYM.Count - 1][3].ToString();
                        smonth = lstYM[0][4].ToString() + lstYM[0][5].ToString();
                        emonth = lstYM[lstYM.Count - 1][4].ToString() + lstYM[lstYM.Count - 1][5].ToString();
                    }
                    else if (datetype == "2" || ismonthly == true)
                    {
                        string[] asy = startdate.Split('/');
                        string[] esy = enddate.Split('/');
                        syear = asy[0];
                        eyear = esy[0];
                        smonth = asy[1];
                        emonth = esy[1];
                    }

                    isy = Convert.ToInt32(syear);
                    iey = Convert.ToInt32(eyear);
                    ism = Convert.ToInt32(smonth);
                    iem = Convert.ToInt32(emonth);

                    WriteLog(syear + "/" + smonth + "~" + eyear + "/" + emonth);

                    string t = "臺灣地區";
                    if (type == "2")
                        t = "縣市";
                    else if (type == "3")
                        t = "縣市重要指標";

                    uploadlog(glcontext, "資料維護", "更新(" + t + ") 資料 (" + tb + "),(" + syear + "年" + smonth + "月 - " + eyear + "年" + emonth + "月)");
                }


                Int32 nBatchLimit = 1000;
                string sqlStr = "";
                int expectcount = 0;
                for (int i = 0; i < dt.Rows.Count; i++)
                {
                    int dy = Convert.ToInt32(dt.Rows[i]["欄位1"].ToString());
                    int dm = Convert.ToInt32(dt.Rows[i]["欄位2"].ToString());

                    if (dy < isy || dy > iey)
                        continue;
                    else if ((dy == iey && dm < ism) || (dy == iey && dm > iem))
                        continue;

                    sqlStr += @" INSERT INTO Mt30 ([欄位1],[欄位2],[欄位3],[欄位4],[欄位5],[欄位6],[欄位7],[欄位8],[欄位9],[欄位10],[欄位11], 
                                [欄位12],[欄位13],[欄位14],[欄位15],[欄位16],[欄位17],[欄位18],[欄位19],[欄位20],[欄位21],[欄位22],[欄位23],[欄位24]) 
                               ";
                    sqlStr += @" VALUES ('" + dt.Rows[i]["欄位1"].ToString() + "','" + dt.Rows[i]["欄位2"].ToString() + "','" + dt.Rows[i]["欄位3"].ToString() + "','" + dt.Rows[i]["欄位4"].ToString() + "','" + dt.Rows[i]["欄位5"].ToString() + "','" + dt.Rows[i]["欄位6"].ToString() + "','" +
                            dt.Rows[i]["欄位7"].ToString() + "','" + dt.Rows[i]["欄位8"].ToString() + "','" + dt.Rows[i]["欄位9"].ToString() + "','" + dt.Rows[i]["欄位10"].ToString() + "','" + dt.Rows[i]["欄位11"].ToString() + "','" + dt.Rows[i]["欄位12"].ToString() + "','" +
                            dt.Rows[i]["欄位13"].ToString() + "','" + dt.Rows[i]["欄位14"].ToString() + "','" + dt.Rows[i]["欄位15"].ToString() + "','" + dt.Rows[i]["欄位16"].ToString() + "','" + dt.Rows[i]["欄位17"].ToString() + "','" + dt.Rows[i]["欄位18"].ToString() + "','" +
                            dt.Rows[i]["欄位19"].ToString() + "','" + dt.Rows[i]["欄位20"].ToString() + "','" + dt.Rows[i]["欄位21"].ToString() + "','" + dt.Rows[i]["欄位22"].ToString() + "','" + dt.Rows[i]["欄位23"].ToString() + "','" + dt.Rows[i]["欄位24"].ToString() + "') ";

                    expectcount++;
                    if (expectcount % nBatchLimit == 0) //處理1000筆匯入一次
                    {
                        using (SqlConnection connection = new SqlConnection(sqlConnstr))
                        {
                            SqlCommand command = new SqlCommand("", connection);
                            command.CommandText = sqlStr;

                            try
                            {
                                if (connection.State == ConnectionState.Closed)
                                {
                                    connection.Open();
                                    command.ExecuteNonQuery();
                                }
                            }
                            finally
                            {
                                sqlStr = "";
                                expectcount = 0;
                                connection.Close();
                            }
                        };
                    }
                }
                if (expectcount != 0) // 結束後有殘存的 需要再處理
                {
                    using (SqlConnection connection = new SqlConnection(sqlConnstr))
                    {
                        SqlCommand command = new SqlCommand("", connection);
                        command.CommandText = sqlStr;

                        try
                        {
                            if (connection.State == ConnectionState.Closed)
                            {
                                connection.Open();
                                command.ExecuteNonQuery();
                            }
                        }
                        finally
                        {
                            connection.Close();
                        }
                    };
                }
            }
            catch (Exception ex)
            {
                Status = 2;
                ex.StackTrace.ToString();
            }
            finally
            {
                UpdateFinishedFromCallback(new FinishItem() { UniqueID = objs["guid"].ToString(), UserBreak=Status });
            }
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

    public void UpdateTable(HttpContext context, string path)
    {
        string type = context.Request.Form["type"] as string; //1: 全臺 2: 縣市
        string table = context.Request.Form["table"] as string;
        string datetype = context.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string startdate = context.Request.Form["startdate"] as string;
        string enddate = context.Request.Form["enddate"] as string;

        type = HttpUtility.HtmlEncode(type);
        table = HttpUtility.HtmlEncode(table);
        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        string st = "";
        if (datetype != "1" && datetype != "2")
            throw new ArgumentException("Invalid import date mode.");
        if (table == "DB2")
            st = "DB2";
        else if (table == "DB4")
            st = "DB4";
        else if (table == "NEW103")
            st = "NEW103";
        else if (table == "NEW172A")
            st = "NEW172a";
        else if (table == "NEW182A")
            st = "NEW182a";
        else if (table == "NEW69")
            st = "NEW69";
        else if (table == "NEW84")
            st = "NEW84";
        else if (table == "SHIEN12A")
            st = "SHIEN12A";
        else if (table == "SHIEN15A")
            st = "SHIEN15A";
        else if (table == "SHIEN25A")
            st = "SHIEN25A";
        else
            st = "ERROR";

        string thePath = ".\\layout\\" + st + "_layout.csv";
        String strLayoutFile = HttpContext.Current.Server.MapPath(thePath);

        String strDataFile = path;
        String strConnectionString = sqlConnstr;
        String strTableMetadata = "STATLIST_METADATA_MERGE";
        String strTableDataValue = "STATDATA_" + st;
        String strSourceMetadata = st;
        String strDataSeparator = "Layout";
        String strStartYearMonth = "";
        String strEndYearMonth = "";
        String strCountyFilter = "";
        String strBatchLimit = "";
        Int32 nBatchLimit = 1000;

        if (strBatchLimit != null)
        {
            Int32 nV;
            if (Int32.TryParse(strBatchLimit, out nV))
            {
                nBatchLimit = nV;
            }
        }
        if (datetype == "2")
        {
            strStartYearMonth = startdate;
            strEndYearMonth = enddate;
        }

        Boolean bDisplayIgnoreMessage = false;
        if (File.Exists(strLayoutFile) && File.Exists(strDataFile)
            && strConnectionString.Length > 0 && strTableMetadata.Length > 0
            && strSourceMetadata.Length > 0 && strTableDataValue.Length > 0
            && nBatchLimit > 0)
        {
            Dictionary<String, Object> objs = new Dictionary<String, Object>();
            objs.Add("ConnectionString", strConnectionString);
            objs.Add("TableMetadata", strTableMetadata);
            objs.Add("SourceMetadata", strSourceMetadata);
            objs.Add("TableDataValue", strTableDataValue);
            objs.Add("TableDataSeparator", strDataSeparator);
            objs.Add("LayoutFile", strLayoutFile);
            objs.Add("DataFile", strDataFile);
            objs.Add("StartYearMonth", strStartYearMonth);
            objs.Add("EndYearMonth", strEndYearMonth);
            objs.Add("CountyFilter", strCountyFilter);
            objs.Add("DisplayIgnoreMessage", bDisplayIgnoreMessage);
            objs.Add("BatchLimit", strBatchLimit);
            objs.Add("Guid", context.Request.Form["GUUID"]);
            objs.Add("Type", type);
            objs.Add("Table", table);
            objs.Add("DateType", datetype);

            Thread workerThread = new Thread(new ParameterizedThreadStart(DoManPowerProcess));
            workerThread.Start(objs);
        }
        else
        {
            context.Response.Write("參數錯誤.");
        }
    }

    private void DoManPowerProcess(object parameters)
    {
        Dictionary<String, Object> objs = parameters as Dictionary<String, Object>;
        try
        {
            string datetype = objs["DateType"] as string;
            string type = objs["Type"] as string;
            string guid = objs["Guid"] as string;
            string tb = objs["Table"] as string;
            string startdate = objs["StartYearMonth"] as string;
            string enddate = objs["EndYearMonth"] as string;

            guid = HttpUtility.HtmlEncode(guid);
            type = HttpUtility.HtmlEncode(type);
            tb = HttpUtility.HtmlEncode(tb);
            datetype = HttpUtility.HtmlEncode(datetype);
            startdate = HttpUtility.HtmlEncode(startdate);
            enddate = HttpUtility.HtmlEncode(enddate);

            if (objs != null)
            {
                String strLayoutFile = objs["LayoutFile"] as String;
                String strDataFile = objs["DataFile"] as String;
                String strConnectionString = objs["ConnectionString"] as String;
                String strTableMetadata = objs["TableMetadata"] as String;
                String strSourceMetadata = objs["SourceMetadata"] as String;
                String strTableDataValue = objs["TableDataValue"] as String;
                String strDataSeparator = objs["TableDataSeparator"] as String;
                String strStartYearMonth = objs["StartYearMonth"] as String;
                String strEndYearMonth = objs["EndYearMonth"] as String;
                String strCountyFilter = objs["CountyFilter"] as String;
                String strBatchLimit = objs["BatchLimit"] as String;
                Boolean bDisplayIgnore = (Boolean)objs["DisplayIgnoreMessage"];
                Int32 nBatchLimit = 1000;

                if (strBatchLimit != null)
                {
                    Int32 nV;
                    if (Int32.TryParse(strBatchLimit, out nV))
                    {
                        nBatchLimit = nV;
                    }
                }
                System.Diagnostics.Stopwatch elapsed = new System.Diagnostics.Stopwatch();
                elapsed.Start();

                process = new ManPowerProcess(strConnectionString);
                if (process != null)
                {
                    WriteLog("inProcess");
                    // 設定GUUID
                    process.SetUniqueID(guid);
                    // 設定批次寫入的筆數
                    process.SetBatchLimit(nBatchLimit);
                    // 設定年月必須包含 "/", 可無值, 例 "1980/"
                    process.SetStartYearMonth(strStartYearMonth);
                    // 設定年月必須包含 "/", 可無值, 例 "1981/"
                    process.SetEndYearMonth(strEndYearMonth);
                    process.SetCountyFilter(strCountyFilter);
                    process.DisplayIgnoreMessage = bDisplayIgnore;
                    if (!process.SetMetadataTable(strTableMetadata, strSourceMetadata)
                        || !process.SetDataValueTable(strTableDataValue))
                        throw new InvalidOperationException("Unable to load import mappings or destination table.");
                    Boolean bLayoutLoaded = false;
                    if (String.Compare("Layout", strDataSeparator, true) == 0)
                    {
                        bLayoutLoaded = process.LoadLayout(strLayoutFile, LayoutTypeEnum.Layout);
                    }
                    else if (String.Compare("Header", strDataSeparator, true) == 0)
                    {
                        bLayoutLoaded = process.LoadLayout(strDataFile, LayoutTypeEnum.Header);
                    }

                    if (bLayoutLoaded)
                    {
                        WriteLog("inLayoutLoaded");
                        // 預載資料, 並取得所有資料筆的年月 ()
                        List<String> lstYM = process.LoadDataFile(strDataFile, "yyyy/MM");
                        if (lstYM == null || lstYM.Count == 0)
                            throw new InvalidOperationException("The uploaded file contains no valid periods.");

                        int isy = 0, iey = 0, ism = 0, iem = 0;
                        if (glcontext != null)
                        {
                            bool ismonthly = false;
                            string syear = "";
                            string eyear = "";
                            string smonth = "";
                            string emonth = "";

                            if (datetype == "1" && ismonthly != true)
                            {
                                syear = lstYM[0][0].ToString() + lstYM[0][1].ToString() + lstYM[0][2].ToString() + lstYM[0][3].ToString();
                                eyear = lstYM[lstYM.Count - 1][0].ToString() + lstYM[lstYM.Count - 1][1].ToString() + lstYM[lstYM.Count - 1][2].ToString() + lstYM[lstYM.Count - 1][3].ToString();
                                smonth = lstYM[0][4].ToString() + lstYM[0][5].ToString();
                                emonth = lstYM[lstYM.Count - 1][4].ToString() + lstYM[lstYM.Count - 1][5].ToString();
                            }
                            else if (datetype == "2" || ismonthly == true)
                            {
                                string[] asy = startdate.Split('/');
                                string[] esy = enddate.Split('/');
                                syear = asy[0];
                                eyear = esy[0];
                                smonth = asy[1];
                                emonth = esy[1];
                            }

                            isy = Convert.ToInt32(syear);
                            iey = Convert.ToInt32(eyear);
                            ism = Convert.ToInt32(smonth);
                            iem = Convert.ToInt32(emonth);

                            DateTime replaceStart = new DateTime(isy, ism, 1);
                            DateTime replaceEnd = new DateTime(iey, iem, 1);
                            if (replaceStart > replaceEnd)
                                throw new ArgumentException("The start period must not exceed the end period.");
                            WriteLog("goImport");
                            Int32 nImported = process.ImportData(replaceStart, replaceEnd);
                            if (nImported <= 0)
                                throw new InvalidOperationException("No records were imported.");

                            // Record history only after the replacement transaction commits.
                            DataLogInsert(lstYM, false);

                            string t = "臺灣地區";
                            if (type == "2")
                                t = "縣市";
                            else if (type == "3")
                                t = "縣市重要指標";

                            uploadlog(glcontext, "資料維護", "更新(" + t + ") 資料 (" + tb + "),(" + syear + "年" + smonth + "月 - " + eyear + "年" + emonth + "月)");
                        }

                        UpdateFinishedFromCallback(new FinishItem() { UniqueID = guid, UserBreak = 0 });
                    }
                    else
                        throw new InvalidOperationException("Unable to load import layout.");
                }
                elapsed.Stop();
            }
        }
        catch (Exception ex)
        {
            if (objs != null && objs.ContainsKey("Guid"))
                glcontext.Application[objs["Guid"].ToString()] = "ERROR";
            WriteLog(ex.ToString());
        }
    }


    private void UpdateToDB2(List<String> lstYM, bool ismonthly, string table)
    {
        string datetype = glcontext.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string startdate = glcontext.Request.Form["startdate"] as string;
        string enddate = glcontext.Request.Form["enddate"] as string;

        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        string syear = "";
        string eyear = "";
        string smonth = "";
        string emonth = "";
        if (datetype == "1")
        {
            string[] asy = lstYM[0].Split('/');
            string[] esy = lstYM[lstYM.Count - 1].Split('/');
            syear = asy[0];
            eyear = esy[0];
            smonth = asy[1];
            emonth = esy[1];
        }
        else if (datetype == "2")
        {
            string[] asy = startdate.Split('/');
            string[] esy = enddate.Split('/');
            syear = asy[0];
            eyear = esy[0];
            smonth = asy[1];
            emonth = esy[1];
        }

        WriteLog(syear + "/" + smonth + "~" + eyear + "/" + emonth);

        int sy = Convert.ToInt16(syear);
        int ey = Convert.ToInt16(eyear);
        int sm = Convert.ToInt16(smonth);
        int em = Convert.ToInt16(emonth);

        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            if (sy == ey && sm == em)
            {
                sqlStr = @" DELETE FROM " + table +
                    @" WHERE ([欄位1] = @SYEAR AND [欄位2] = @SMONTH) ";
            }
            else if (sy == ey)
            {
                sqlStr = @" DELETE FROM " + table +
                    @" WHERE ([欄位1] = @SYEAR AND [欄位2] >= @SMONTH AND [欄位2] <= @EMONTH) ";
            }
            else
            {
                sqlStr = @" DELETE FROM " + table +
                    @" WHERE ([欄位1] > @SYEAR AND [欄位1] < @EYEAR) OR ([欄位1] = @SYEAR AND [欄位2] >= @SMONTH) OR ([欄位1] = @EYEAR AND [欄位2] <= @EMONTH) ";
            }

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@SYEAR", sy),
                    new SqlParameter("@EYEAR", ey),
                    new SqlParameter("@SMONTH", sm),
                    new SqlParameter("@EMONTH", em)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                WriteLog(ex.ToString());
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        };
    }

    private void UpdateToDB3(List<String> lstYM, bool ismonthly, string table)
    {
        string datetype = glcontext.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string startdate = glcontext.Request.Form["startdate"] as string;
        string enddate = glcontext.Request.Form["enddate"] as string;

        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        string syear = "";
        string eyear = "";
        string smonth = "";
        string emonth = "";
        if (datetype == "1")
        {
            string[] asy = lstYM[0].Split('/');
            string[] esy = lstYM[lstYM.Count - 1].Split('/');
            syear = asy[0];
            eyear = esy[0];
            smonth = asy[1];
            emonth = esy[1];
        }
        else if (datetype == "2")
        {
            string[] asy = startdate.Split('/');
            string[] esy = enddate.Split('/');
            syear = asy[0];
            eyear = esy[0];
            smonth = asy[1];
            emonth = esy[1];
        }

        int sy = Convert.ToInt16(syear);
        int ey = Convert.ToInt16(eyear);
        int sm = Convert.ToInt16(smonth);
        int em = Convert.ToInt16(emonth);

        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            if (sy == ey && sm == em)
            {
                sqlStr = @" DELETE FROM " + table +
                    @" WHERE ([Year] = @SYEAR AND [Month] = @SMONTH) ";
            }
            else if (sy == ey)
            {
                sqlStr = @" DELETE FROM " + table +
                    @" WHERE ([Year] = @SYEAR AND [Month] >= @SMONTH AND [Month] <= @EMONTH) ";
            }
            else
            {
                sqlStr = @" DELETE FROM " + table +
                    @" WHERE ([Year] > @SYEAR AND [Year] < @EYEAR) OR ([Year] = @SYEAR AND [Month] >= @SMONTH) OR ([Year] = @EYEAR AND [Month] <= @EMONTH) ";
            }

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@SYEAR", sy),
                    new SqlParameter("@EYEAR", ey),
                    new SqlParameter("@SMONTH", sm),
                    new SqlParameter("@EMONTH", em)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

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

    private void UpdateToDB4(List<String> lstYM, bool ismonthly, string stable)
    {
        string datetype = glcontext.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string startdate = glcontext.Request.Form["startdate"] as string;
        string enddate = glcontext.Request.Form["enddate"] as string;

        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        string table = "";
        if (stable == "Table3")
            table = "Year_Table_Timeline";
        else
            table = stable;

        string syear = "";
        string eyear = "";
        if (datetype == "1")
        {
            syear = lstYM[0];
            eyear = lstYM[lstYM.Count - 1];
        }
        else if (datetype == "2")
        {
            syear = startdate;
            eyear = enddate;
        }

        int sy = Convert.ToInt16(syear);
        int ey = Convert.ToInt16(eyear);

        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            if (sy == ey)
            {
                sqlStr = @" DELETE FROM " + table +
                    @" WHERE ([欄位1] = @SYEAR) ";
            }
            else
            {
                sqlStr = @" DELETE FROM " + table +
                    @" WHERE ([欄位1] >= @SYEAR AND [欄位1] <= @EYEAR) ";
            }

            if (stable == "Table3")
            {
                sqlStr += " AND [欄位3] = '3' ";
            }
            else if (stable == "Year_Table_Timeline")
            {
                sqlStr += " AND [欄位3] != '3' ";
            }

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@SYEAR", sy),
                    new SqlParameter("@EYEAR", ey)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

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

    private void DataLogInsert(List<String> lstYM, bool ismonthly)
    {
        string type = glcontext.Request.Form["type"] as string; //1: 全臺 2: 縣市
        string table = glcontext.Request.Form["table"] as string;
        string datetype = glcontext.Request.Form["datetype"] as string; //1: 全部 2: 時間
        string startdate = glcontext.Request.Form["startdate"] as string;
        string enddate = glcontext.Request.Form["enddate"] as string;
        string updatename = glcontext.Request.Form["updatename"] as string;

        updatename = HttpUtility.HtmlEncode(updatename);
        type = HttpUtility.HtmlEncode(type);
        table = HttpUtility.HtmlEncode(table);
        datetype = HttpUtility.HtmlEncode(datetype);
        startdate = HttpUtility.HtmlEncode(startdate);
        enddate = HttpUtility.HtmlEncode(enddate);

        DateTime ndate = DateTime.Now;
        HttpPostedFile file = null;
        file = glcontext.Request.Files[0];

        string fileName = file.FileName;
        string syear = "";
        string eyear = "";
        if (datetype == "1")
        {
            if (lstYM[0].ToString().Length == 6)
            {
                string ssyear = lstYM[0].ToString().Substring(0, 4);
                string ssmonth = lstYM[0].ToString().Substring(4, 2);
                string esyear = lstYM[lstYM.Count - 1].ToString().Substring(0, 4);
                string esmonth = lstYM[lstYM.Count - 1].ToString().Substring(4, 2);

                syear = ssyear + "/" + ssmonth;
                eyear = esyear + "/" + esmonth;
            }
            else
            {
                syear = lstYM[0].ToString();
                eyear = lstYM[lstYM.Count - 1].ToString();
            }
        }
        else if (datetype == "2")
        {
            syear = startdate;
            eyear = enddate;
        }

        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"INSERT INTO Data_Log (DateTime, Account, FileName, Area, DataType, DateStart, DateEnd) 
                              VALUES (@DateTime, @Account, @FileName, @Area, @DataType, @DateStart, @DateEnd)";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@DateTime", ndate),
                    new SqlParameter("@Account", updatename),
                    new SqlParameter("@FileName", fileName),
                    new SqlParameter("@Area", type),
                    new SqlParameter("@DataType", table),
                    new SqlParameter("@DateStart", syear),
                    new SqlParameter("@DateEnd", eyear)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                WriteLog(ex.ToString());
            }
            finally
            {
                connection.Close();
            }
        };
    }

    private void UpdateFinishedFromCallback(FinishItem item)
    {
        string strText = "";
        if (item.UserBreak == 0)
            strText = "OK";
        else
            strText = "ERROR";

        glcontext.Application[item.UniqueID] = strText;
    }

    public string GetUploadSchedule(HttpContext context)
    {
        string guid = context.Request.Form["GUUID"] as string;
        string jData = "NULL";

        if (context.Application[guid] != null)
        {
            jData = context.Application[guid] as String;
        }

        return jData;
    }

    public void ClearApplication(HttpContext context)
    {
        string guid = context.Request.Form["GUUID"] as string;
        context.Application[guid] = null;
    }

    private DataTable GetDataTabletFromCSVFile(string path)
    {
        DataTable csvData = new DataTable();
        try
        {
            using(TextFieldParser csvReader = new TextFieldParser(path))
            {
                csvReader.SetDelimiters(new string[] { "," });
                csvReader.HasFieldsEnclosedInQuotes = true;
                string[] colFields = new string[] { "欄位1", "欄位2","欄位3","欄位4","欄位5","欄位6","欄位7","欄位8",
                    "欄位9","欄位10","欄位11","欄位12","欄位13","欄位14","欄位15","欄位16","欄位17","欄位18","欄位19","欄位20",
                    "欄位21","欄位22","欄位23","欄位24" };
                foreach (string column in colFields)
                {
                    DataColumn datecolumn = new DataColumn(column);
                    datecolumn.AllowDBNull = true;
                    csvData.Columns.Add(datecolumn);
                }
                while (!csvReader.EndOfData)
                {
                    string[] fieldData = csvReader.ReadFields();
                    for (int i = 0; i < fieldData.Length; i++)
                    {
                        if (fieldData[i] == "")
                        {
                            fieldData[i] = null;
                        }
                    }
                    csvData.Rows.Add(fieldData);
                }
            }
        }
        catch (Exception ex)
        {
            return null;
        }

        return csvData;
    }

    private DataTable GetYearReportDataFromCSVFile(string path)
    {
        DataTable csvData = new DataTable();
        try
        {
            using(TextFieldParser csvReader = new TextFieldParser(path))
            {
                csvReader.SetDelimiters(new string[] { "," });
                csvReader.HasFieldsEnclosedInQuotes = true;
                string[] colFields = new string[] { "欄位1" ,"欄位2" ,"欄位3" ,"欄位4" ,"欄位5" ,"欄位6" ,"欄位7" ,"欄位8" ,"欄位9" ,"欄位10" ,
                    "欄位11" ,"欄位12" ,"欄位13" ,"欄位14" ,"欄位15" ,"欄位16" ,"欄位17" ,"欄位18" ,
                    "欄位19" ,"欄位20" ,"欄位21" ,"欄位22" ,"欄位23" ,"欄位24" ,"欄位25" ,"欄位26" ,
                    "欄位27" ,"欄位28" ,"欄位29" ,"欄位30" ,"欄位31" ,"欄位32" ,"欄位33" ,"欄位34" ,
                    "欄位35" ,"欄位36" ,"欄位37" ,"欄位38" ,"欄位39" ,"欄位40" ,"欄位41" ,"欄位42" ,
                    "欄位43" ,"欄位44" ,"欄位45" ,"欄位46" ,"欄位47" ,"欄位48" ,"欄位49" ,"欄位50" ,
                    "欄位51" ,"欄位52" ,"欄位53" ,"欄位54" ,"欄位55" ,"欄位56" ,"欄位57" ,"欄位58" ,
                    "欄位59" ,"欄位60" ,"欄位61" ,"欄位62" ,"欄位63" ,"欄位64" ,"欄位65" ,"欄位66" ,
                    "欄位67" ,"欄位68" ,"欄位69" ,"欄位70" ,"欄位71" ,"欄位72" ,"欄位73" ,"欄位74" , "欄位75", "欄位76" };

                foreach (string column in colFields)
                {
                    DataColumn datecolumn = new DataColumn(column);
                    datecolumn.AllowDBNull = true;

                    if (column == "欄位1")
                        csvData.Columns.Add(column, typeof(int));
                    else
                        csvData.Columns.Add(datecolumn);
                }
                while (!csvReader.EndOfData)
                {
                    string[] fieldData = csvReader.ReadFields();
                    for (int i = 0; i < fieldData.Length; i++)
                    {
                        if (fieldData[i] == "")
                        {
                            fieldData[i] = null;
                        }
                    }
                    csvData.Rows.Add(fieldData);
                }
            }
        }
        catch (Exception ex)
        {
            return null;
        }

        return csvData;
    }

    private DataTable GetSeasonDataFromCSVFile(string path)
    {
        DataTable csvData = new DataTable();
        try
        {
            using(TextFieldParser csvReader = new TextFieldParser(path))
            {
                csvReader.SetDelimiters(new string[] { "      " });
                csvReader.HasFieldsEnclosedInQuotes = true;
                string[] colFields = new string[] { "Date", "Employed", "Unemployed", "Labor_Force", "Not_In_Labor_Force", "Unemployment_Rate", "Labor_Force_Participation_Rate" };
                foreach (string column in colFields)
                {
                    DataColumn datecolumn = new DataColumn(column);
                    datecolumn.AllowDBNull = true;
                    csvData.Columns.Add(datecolumn);
                }
                while (!csvReader.EndOfData)
                {
                    string[] fieldData = csvReader.ReadFields();
                    for (int i = 0; i < fieldData.Length; i++)
                    {
                        if (fieldData[i] == "")
                        {
                            fieldData[i] = null;
                        }
                    }
                    csvData.Rows.Add(fieldData);
                }
            }
        }
        catch (Exception ex)
        {
            return null;
        }

        return csvData;
    }

    private void uploadlog(HttpContext context, string features, string description)
    {
        string id = glcontext.Request.Form["updateaccount"] as string;
        DateTime ndate = DateTime.Now;
        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"INSERT INTO Log_Record (Account, DateTime, [Function], Description) 
                              VALUES (@Account, @DateTime, @Features, @Description) ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Account", id),
                    new SqlParameter("@DateTime", ndate),
                    new SqlParameter("@Features", features),
                    new SqlParameter("@Description", description)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                WriteLog(ex.ToString());
            }
            finally
            {
                connection.Close();
            }
        }
    }

    public string AddNewLayout(HttpContext context)
    {
        string jdata = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        {
            string check = CheckUploadFiles(context);
            if (check != "Extension Error")
            {
                string sno = AddNewLayoutToDB(context);
                SaveLayoutFiles(context, sno);
                jdata = "OK";
            }
            else
                jdata = check;
        }

        return (jdata);
    }

    public string AddNewLayout_Has(HttpContext context)
    {
        string jdata = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        {
            string check = CheckUploadFiles(context);
            if (check != "Extension Error")
            {
                string sno = AddNewLayoutHasToDB(context);
                SaveLayoutFiles(context, sno);
                jdata = "OK";
            }
            else
                jdata = check;
        }

        return (jdata);
    }

    public string PlugsLayout(HttpContext context)
    {
        string jdata = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        {
            string check = CheckUploadFiles(context);
            if (check != "Extension Error")
            {
                UpdateTNumber(context);
                string sno = AddNewLayoutToDB(context);
                SaveLayoutFiles(context, sno);
                jdata = "OK";
            }
            else
                jdata = check;
        }

        return (jdata);
    }

    public string UpdateLayout(HttpContext context)
    {
        string jdata = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        {
            string check = CheckUploadFiles(context);
            if (check != "Extension Error")
            {
                UpdateLayoutToDB(context);
                string SNO = context.Request.Form["SNO"] as string;
                SaveLayoutFiles(context, SNO);
                jdata = "OK";
            }
            else
                jdata = check;
        }

        return (jdata);
    }

    public string DeleteLayout(HttpContext context)
    {
        string jdata = "";
        DeleteLayoutFromDB(context);
        jdata = "OK";
        return (jdata);
    }

    public string CheckUploadFiles(HttpContext context)
    {
        if (context.Request.Files.Count > 0)
        {
            HttpPostedFile file = null;
            file = context.Request.Files[0];
            string extension = System.IO.Path.GetExtension(file.FileName);
            if (extension != ".xlsx" && extension != ".xls") return "Extension Error";

            return "Success";
        }
        else
            return "Not Upload";
    }

    public bool SaveLayoutFiles(HttpContext context, string sno)
    {
        if (sno == null || sno == "")
            return false;

        if (context.Request.Files.Count > 0)
        {
            HttpPostedFile file = null;
            file = context.Request.Files[0];
            string extension = System.IO.Path.GetExtension(file.FileName);
            if (extension != ".xlsx" && extension != ".xls") return false;
            string fileName = sno + extension;

            string path = HttpContext.Current.Server.MapPath(".\\layoutupload\\" + fileName);
            file.SaveAs(path);

            transhtm(path);
        }

        return true;
    }

    public void transhtm(string strExcel)
    {
        if (File.Exists(strExcel))
        {
            try
            {
                IWorkbook originWorkbook = null;
                String strPath = Path.GetDirectoryName(strExcel);
                String strMainFile = Path.GetFileNameWithoutExtension(strExcel);
                String strExt = Path.GetExtension(strExcel);
                // 載入 Excel 檔.
                using (FileStream fs = new FileStream(strExcel, FileMode.Open, FileAccess.Read))
                {
                    if (String.Compare(".xlsx", strExt, true) == 0)
                    {
                        originWorkbook = new XSSFWorkbook(fs);
                    }
                    else if (String.Compare(".xls", strExt, true) == 0)
                    {
                        originWorkbook = new HSSFWorkbook(fs);
                    }
                }
                if (originWorkbook != null)
                {
                    // 解譯 Excel 樣版檔資料, 轉換成 htm 樣版.
                    TemplateHelper template = new TemplateHelper(originWorkbook);
                    if (template != null && template.Loaded)
                    {
                        for (Int32 i = 0; i < template.TemplateCount; i++)
                        {
                            TemplateItem item = template.Get(i);
                            // 樣版 Htm
                            if (item.Html != null)
                            {
                                // 輸出目前 Htm 樣版
                                String outFileName = Path.ChangeExtension(Path.Combine(strPath, strMainFile + String.Format("_{0}", i + 1)), ".htm");
                                File.WriteAllText(outFileName, item.Html);
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
        }
    }

    public void UpdateTNumber(HttpContext context)
    {
        string T_ID = context.Request.Form["T_ID"] as string;
        string sqlStr = "";

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" UPDATE Y_TB_LIST 
                        SET T_ID = T_ID + 1 
                        WHERE T_ID >= @T_ID ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@T_ID", T_ID)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

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
        }
    }

    public string AddNewLayoutToDB(HttpContext context)
    {
        string T_ID = context.Request.Form["T_ID"] as string;
        string T_NAME = context.Request.Form["T_NAME"] as string;
        string EDITION = context.Request.Form["EDITION"] as string;
        string CAT = context.Request.Form["CAT"] as string;
        string S_YEAR = context.Request.Form["S_YEAR"] as string;
        string E_YEAR = context.Request.Form["E_YEAR"] as string;
        if (E_YEAR == "--") E_YEAR = "-1";

        string UNIT = context.Request.Form["UNIT"] as string;
        string COMMENT = context.Request.Form["COMMENT"] as string;
        string NEXT = context.Request.Form["NEXT"] as string;
        string TIMELINE = context.Request.Form["TIMELINE"] as string;
        string STAT_PERIOD = context.Request.Form["STAT_PERIOD"] as string;

        string ISUPLOAD = "0";
        if (context.Request.Files.Count > 0) ISUPLOAD = "1";

        string FILENAME = "";
        if (context.Request.Files.Count > 0)
        {
            FILENAME = context.Request.Files[0].FileName;
        }
        DataTable dt = new DataTable();
        string sqlStr = "";
        string tar = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"INSERT INTO Y_TB_LIST ([T_ID], [ORDER], [T_NAME], [EDITION], [SUB_NAME], [S_YEAR], [E_YEAR], [STAT_PERIOD], [UNIT], [COMMENT], [NEXT], [TIMELINE], [CAT], [EDITTIME], [ISUPLOAD], [FORM_NAME]) 
                              VALUES (@T_ID, 1, @T_NAME, @EDITION, '', @S_YEAR, @E_YEAR, @STAT_PERIOD, @UNIT, @COMMENT, @NEXT, @TIMELINE, @CAT, GETDATE(), @ISUPLOAD, @FORM_NAME);
                       SELECT SCOPE_IDENTITY();";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@T_ID", T_ID),
                    new SqlParameter("@T_NAME", T_NAME),
                    new SqlParameter("@EDITION", EDITION),
                    new SqlParameter("@S_YEAR", S_YEAR),
                    new SqlParameter("@E_YEAR", E_YEAR),
                    new SqlParameter("@STAT_PERIOD", STAT_PERIOD),
                    new SqlParameter("@UNIT", UNIT),
                    new SqlParameter("@COMMENT", COMMENT),
                    new SqlParameter("@NEXT", NEXT),
                    new SqlParameter("@TIMELINE", TIMELINE),
                    new SqlParameter("@CAT", CAT),
                    new SqlParameter("@ISUPLOAD", ISUPLOAD),
                    new SqlParameter("@FORM_NAME", FILENAME)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);
                DataSet ds = new DataSet();
                ds.Clear();
                da.Fill(ds);
                dt = ds.Tables[0];
                if (dt.Rows.Count > 0)
                    tar = dt.Rows[0]["Column1"].ToString();

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

        return tar;
    }

    public string AddNewLayoutHasToDB(HttpContext context)
    {
        string T_ID = context.Request.Form["T_ID"] as string;
        string ORDER = context.Request.Form["ORDER"] as string;
        string T_NAME = context.Request.Form["T_NAME"] as string;
        string EDITION = context.Request.Form["EDITION"] as string;
        string SUB_NAME = context.Request.Form["SUB_NAME"] as string;
        string CAT = context.Request.Form["CAT"] as string;
        string S_YEAR = context.Request.Form["S_YEAR"] as string;
        string E_YEAR = context.Request.Form["E_YEAR"] as string;
        if (E_YEAR == "--") E_YEAR = "-1";

        string UNIT = context.Request.Form["UNIT"] as string;
        string COMMENT = context.Request.Form["COMMENT"] as string;
        string NEXT = context.Request.Form["NEXT"] as string;
        string TIMELINE = context.Request.Form["TIMELINE"] as string;
        string STAT_PERIOD = context.Request.Form["STAT_PERIOD"] as string;

        string ISUPLOAD = "0";
        if (context.Request.Files.Count > 0) ISUPLOAD = "1";
        string FILENAME = "";
        if (context.Request.Files.Count > 0) FILENAME = context.Request.Files[0].FileName;

        DataTable dt = new DataTable();
        string sqlStr = "";
        string tar = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"INSERT INTO Y_TB_LIST ([T_ID], [ORDER], [T_NAME], [EDITION], [SUB_NAME], [S_YEAR], [E_YEAR], [STAT_PERIOD], [UNIT], [COMMENT], [NEXT], [TIMELINE], [CAT], [EDITTIME], [ISUPLOAD], [FORM_NAME]) 
                              VALUES (@T_ID, @ORDER, @T_NAME, @EDITION, @SUB_NAME, @S_YEAR, @E_YEAR, @STAT_PERIOD, @UNIT, @COMMENT, @NEXT, @TIMELINE, @CAT, GETDATE(), @ISUPLOAD, @FORM_NAME);
                       SELECT SCOPE_IDENTITY();";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@T_ID", T_ID),
                    new SqlParameter("@ORDER", ORDER),
                    new SqlParameter("@T_NAME", T_NAME),
                    new SqlParameter("@EDITION", EDITION),
                    new SqlParameter("@SUB_NAME", SUB_NAME),
                    new SqlParameter("@S_YEAR", S_YEAR),
                    new SqlParameter("@E_YEAR", E_YEAR),
                    new SqlParameter("@STAT_PERIOD", STAT_PERIOD),
                    new SqlParameter("@UNIT", UNIT),
                    new SqlParameter("@COMMENT", COMMENT),
                    new SqlParameter("@NEXT", NEXT),
                    new SqlParameter("@TIMELINE", TIMELINE),
                    new SqlParameter("@CAT", CAT),
                    new SqlParameter("@ISUPLOAD", ISUPLOAD),
                    new SqlParameter("@FORM_NAME", FILENAME)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);
                DataSet ds = new DataSet();
                ds.Clear();
                da.Fill(ds);
                dt = ds.Tables[0];
                if (dt.Rows.Count > 0)
                    tar = dt.Rows[0]["Column1"].ToString();

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

        return tar;
    }

    public void UpdateLayoutToDB(HttpContext context)
    {
        string SNO = context.Request.Form["SNO"] as string;
        string T_ID = context.Request.Form["T_ID"] as string;
        string T_NAME = context.Request.Form["T_NAME"] as string;
        string EDITION = context.Request.Form["EDITION"] as string;
        string SUB_NAME = context.Request.Form["SUB_NAME"] as string;
        string CAT = context.Request.Form["CAT"] as string;
        string S_YEAR = context.Request.Form["S_YEAR"] as string;
        string E_YEAR = context.Request.Form["E_YEAR"] as string;
        if (E_YEAR == "--") E_YEAR = "-1";

        string UNIT = context.Request.Form["UNIT"] as string;
        string COMMENT = context.Request.Form["COMMENT"] as string;
        string NEXT = context.Request.Form["NEXT"] as string;
        string TIMELINE = context.Request.Form["TIMELINE"] as string;
        string STAT_PERIOD = context.Request.Form["STAT_PERIOD"] as string;

        string PISUPLOAD = context.Request.Form["ISUPLOAD"] as string;
        string ISUPLOAD = "0";
        if (context.Request.Files.Count > 0) ISUPLOAD = "1";
        if (PISUPLOAD == "1") ISUPLOAD = "1";

        string FILENAME = "";
        if (context.Request.Files.Count > 0) FILENAME = context.Request.Files[0].FileName;

        DataTable dt = new DataTable();
        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"UPDATE Y_TB_LIST 
                       SET [T_ID] = @T_ID, [T_NAME] = @T_NAME, [EDITION] = @EDITION, [SUB_NAME] = @SUB_NAME, [S_YEAR] = @S_YEAR, [E_YEAR] = @E_YEAR, [STAT_PERIOD] = @STAT_PERIOD, [UNIT] = @UNIT, [COMMENT] = @COMMENT, [NEXT] = @NEXT, [TIMELINE] = @TIMELINE, [CAT] = @CAT, [EDITTIME] = GETDATE(), [ISUPLOAD] = @ISUPLOAD ";

            if (FILENAME != "")
            {
                sqlStr += @", [FORM_NAME] = @FORM_NAME ";
            }
            sqlStr += @" WHERE SNO = @SNO ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@SNO", SNO),
                    new SqlParameter("@T_ID", T_ID),
                    new SqlParameter("@T_NAME", T_NAME),
                    new SqlParameter("@EDITION", EDITION),
                    new SqlParameter("@SUB_NAME", SUB_NAME),
                    new SqlParameter("@S_YEAR", S_YEAR),
                    new SqlParameter("@E_YEAR", E_YEAR),
                    new SqlParameter("@STAT_PERIOD", STAT_PERIOD),
                    new SqlParameter("@UNIT", UNIT),
                    new SqlParameter("@COMMENT", COMMENT),
                    new SqlParameter("@NEXT", NEXT),
                    new SqlParameter("@TIMELINE", TIMELINE),
                    new SqlParameter("@CAT", CAT),
                    new SqlParameter("@ISUPLOAD", ISUPLOAD),
                    new SqlParameter("@FORM_NAME", FILENAME)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

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
        }
    }

    public void DeleteLayoutFromDB(HttpContext context)
    {
        string SNO = context.Request.Form["SNO"] as string;
        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"DELETE FROM Y_TB_LIST 
                       WHERE SNO = @SNO ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@SNO", SNO)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

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
        }
    }

    public string UploadImage(HttpContext context)
    {
        string jdata = "";
        if (context.Request.Files.Count > 0)
        {
            HttpPostedFile file = null;
            file = context.Request.Files[0];
            string fileName = file.FileName;
            string extension = System.IO.Path.GetExtension(file.FileName);

            if (extension == ".png" || extension == ".jpeg" || extension == ".jpg" || extension == ".PNG" || extension == ".JPEG" || extension == ".JPG")
            { }
            else
                return "Extension Error";

            string guid = System.Guid.NewGuid().ToString();

            string path = HttpContext.Current.Server.MapPath(".\\uploadimage\\" + guid + extension);
            file.SaveAs(path);

            jdata = guid + extension;
        }
        else
        {
            jdata = "NO FILE";
        }

        return jdata;
    }

    public string AddStatItem(HttpContext context)
    {
        string jdata = "ERROR";

        try
        {
            string T_NAME = context.Request.Form["T_NAME"] as string;
            string T_URLLINK = context.Request.Form["T_URLLINK"] as string;
            string ISFOREVER = context.Request.Form["ISFOREVER"] as string;
            string S_TIME = context.Request.Form["S_TIME"] as string;
            string E_TIME = context.Request.Form["E_TIME"] as string;

            string FILENAME = UploadImage(context);

            if (FILENAME == "Extension Error" || FILENAME == "NO FILE")
            {
                jdata = FILENAME;
                return jdata;
            }

            HttpPostedFile file = context.Request.Files[0];
            string O_FILENAME = "";
            if (context.Request.Files.Count > 0)
            {
                O_FILENAME = file.FileName;
            }

            string sqlStr = "";
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                sqlStr = @"
                    DECLARE @COUNT int;
                    SET @COUNT = (SELECT COUNT(*) FROM [Interactive]);
                    INSERT INTO [Interactive]
                    (
                        [Order], [Title], [LinkURL], [Inter_Pic], [FileName_Pic], [CreateDate], [OnlineDate], [OfflineDate], [Forever]
                    )
                    VALUES
                    (
                        (@COUNT + 1), @Title, @LinkURL, @Inter_Pic, @FileName_Pic, GETDATE(), @OnlineDate, @OfflineDate, @Forever
                    );
                ";

                command.CommandText = sqlStr;

                List<SqlParameter> p = new List<SqlParameter>();

                if (ISFOREVER == "1")
                {
                    p.Add(new SqlParameter("@Title", T_NAME));
                    p.Add(new SqlParameter("@LinkURL", T_URLLINK));
                    p.Add(new SqlParameter("@Inter_Pic", FILENAME));
                    p.Add(new SqlParameter("@FileName_Pic", O_FILENAME));
                    p.Add(new SqlParameter("@OnlineDate", DBNull.Value));
                    p.Add(new SqlParameter("@OfflineDate", DBNull.Value));
                    p.Add(new SqlParameter("@Forever", ISFOREVER));
                }
                else
                {
                    p.Add(new SqlParameter("@Title", T_NAME));
                    p.Add(new SqlParameter("@LinkURL", T_URLLINK));
                    p.Add(new SqlParameter("@Inter_Pic", FILENAME));
                    p.Add(new SqlParameter("@FileName_Pic", O_FILENAME));
                    p.Add(new SqlParameter("@OnlineDate", S_TIME));
                    p.Add(new SqlParameter("@OfflineDate", E_TIME));
                    p.Add(new SqlParameter("@Forever", ISFOREVER));
                }

                command.Parameters.Clear();
                command.Parameters.AddRange(p.ToArray());

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                connection.Close();
            };

            jdata = "OK";

            uploadlog2(context, "統計互動管理", "新增(" + T_NAME + ")");
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        return jdata;
    }

    public string EditStatItem(HttpContext context)
    {
        string jdata = "ERROR";

        try
        {
            string SNO = context.Request.Form["SNO"] as string;
            string OT_NAME = context.Request.Form["OT_NAME"] as string;
            string T_NAME = context.Request.Form["T_NAME"] as string;
            string T_URLLINK = context.Request.Form["T_URLLINK"] as string;
            string ISFOREVER = context.Request.Form["ISFOREVER"] as string;
            string S_TIME = context.Request.Form["S_TIME"] as string;
            string E_TIME = context.Request.Form["E_TIME"] as string;

            string FILENAME = UploadImage(context);

            if (FILENAME == "Extension Error")
            {
                jdata = FILENAME;
                return jdata;
            }

            if (FILENAME == "NO FILE")
            {
                FILENAME = "";
            }

            HttpPostedFile file = null;
            string O_FILENAME = "";
            if (context.Request.Files.Count > 0)
            {
                file = context.Request.Files[0];
                O_FILENAME = file.FileName;
            }

            string sqlStr = "";
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);

                if (FILENAME != "")
                {
                    sqlStr = @"
                        UPDATE [Interactive]
                        SET [Title]=@Title, [LinkURL]=@LinkURL, [Inter_Pic]=@Inter_Pic, [FileName_Pic]=@FileName_Pic,
                            [OnlineDate]=@OnlineDate, [OfflineDate]=@OfflineDate, [Forever]=@Forever
                        WHERE [SNO]=@Sno;
                    ";
                }
                else
                {
                    sqlStr = @"
                        UPDATE [Interactive]
                        SET [Title]=@Title, [LinkURL]=@LinkURL, [OnlineDate]=@OnlineDate, [OfflineDate]=@OfflineDate, [Forever]=@Forever
                        WHERE [SNO]=@Sno;
                    ";
                }

                command.CommandText = sqlStr;

                List<SqlParameter> p = new List<SqlParameter>();

                if (ISFOREVER == "1")
                {
                    p.Add(new SqlParameter("@Sno", SNO));
                    p.Add(new SqlParameter("@Title", T_NAME));
                    p.Add(new SqlParameter("@LinkURL", T_URLLINK));
                    p.Add(new SqlParameter("@OnlineDate", DBNull.Value));
                    p.Add(new SqlParameter("@OfflineDate", DBNull.Value));
                    p.Add(new SqlParameter("@Forever", ISFOREVER));

                    if (FILENAME != "")
                    {
                        p.Add(new SqlParameter("@Inter_Pic", FILENAME));
                        p.Add(new SqlParameter("@FileName_Pic", O_FILENAME));
                    }
                }
                else
                {
                    p.Add(new SqlParameter("@Sno", SNO));
                    p.Add(new SqlParameter("@Title", T_NAME));
                    p.Add(new SqlParameter("@LinkURL", T_URLLINK));
                    p.Add(new SqlParameter("@OnlineDate", S_TIME));
                    p.Add(new SqlParameter("@OfflineDate", E_TIME));
                    p.Add(new SqlParameter("@Forever", ISFOREVER));

                    if (FILENAME != "")
                    {
                        p.Add(new SqlParameter("@Inter_Pic", FILENAME));
                        p.Add(new SqlParameter("@FileName_Pic", O_FILENAME));
                    }
                }

                command.Parameters.Clear();
                command.Parameters.AddRange(p.ToArray());

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                connection.Close();
            };

            jdata = "OK";

            uploadlog2(context, "統計互動管理", "更新(" + T_NAME + ")至(" + OT_NAME + ")");
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        return jdata;
    }

    // Start Log
    private string uploadlog2(HttpContext context, string features, string description)
    {
        string id = context.Session["logaccount"] as string;
        DateTime ndate = DateTime.Now;
        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"INSERT INTO Log_Record (Account, DateTime, [Function], Description) 
                              VALUES (@Account, @DateTime, @Features, @Description) ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Account", id == null ? "supergeo_tmp" : id),
                    new SqlParameter("@DateTime", ndate),
                    new SqlParameter("@Features", features),
                    new SqlParameter("@Description", description)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                return ex.ToString();
            }
            finally
            {
                connection.Close();
            }
        }
        return "OK";
    }

    public bool IsReusable {
        get {
            return false;
        }
    }

}
