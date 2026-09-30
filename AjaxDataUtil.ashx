<%@ WebHandler Language="C#" Class="AjaxDataUtil" %>
using Newtonsoft.Json;
using System;
using System.Data;
using System.Configuration;
using System.Web;
using System.Data.SqlClient;
using System.Reflection;
using System.Web.SessionState;
using System.Xml;
using System.IO;
using System.Net;
using Supergeo.Utilities;
using System.Collections.Generic;
using System.Text;
using NPOI.HSSF.UserModel;
using NPOI.SS.UserModel;
using NPOI.XSSF.UserModel;
using StringEncrypt;

public class AjaxDataUtil : IHttpHandler, IRequiresSessionState
{
    String sqlConnstr = System.Configuration.ConfigurationManager.ConnectionStrings["CensusGISADONet"].ConnectionString;
    string key = System.Web.Configuration.WebConfigurationManager.OpenWebConfiguration("~").AppSettings.Settings["EncryptKey"].Value;
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
            context.Response.Write(ex);
            // context.Response.Write("ERROR");
        }
    }

    public class MNYear
    {
        public int maxyear { get; set; }
        public int minyear { get; set; }
    }

    public int GetMaxMonth(string maxyear, HttpContext context)
    {
        String sqlStr = "";
        DataSet ds = new DataSet();
        int month = 12;
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            String type = context.Request["type"] as String;

            if (type == "2")
            {
                sqlStr = @"
                    SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_SHIEN15A WHERE YEAR=@YEAR;
                ";
            }
            else if (type == "4")
            {
                sqlStr = @"
                    SELECT MAX(CAST(Month AS Int)) as maxmonth FROM Unemployedrate_Adjust WHERE YEAR=@YEAR;
                ";
            }
            else
            {
                sqlStr = @"
                    SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW69 WHERE YEAR=@YEAR;

                    SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW103 WHERE YEAR=@YEAR;

                    SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW84 WHERE YEAR=@YEAR;

                    SELECT MAX(CAST(MONTH AS Int)) as maxmonth FROM STATDATA_NEW172a WHERE YEAR=@YEAR;
                ";
            }

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

    public MNYear GetTaiwanYears(HttpContext context)
    {
        MNYear d = new MNYear();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            String type = context.Request["type"] as String;
            if (type == "2")
            {
                sqlStr = @"
                    SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                    FROM STATDATA_SHIEN15A;
                ";
            }
            else if (type == "4")
            {
                sqlStr = @"
                    SELECT MAX(Year) as maxyear, MIN(Year) as minyear
                    FROM Unemployedrate_Adjust;
                ";
            }
            else
            {
                sqlStr = @"
                    SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                    FROM STATDATA_NEW69;

                    SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                    FROM STATDATA_NEW103;

                    SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                    FROM STATDATA_NEW84;

                    SELECT MAX(YEAR) as maxyear, MIN(YEAR) as minyear
                    FROM STATDATA_NEW172a;
                ";
            }

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

        return (d);
    }

    public MNYear GetCityYears()
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

        return (d);
    }

    // Start UserManagement
    public String GetBaseUserManagement(HttpContext context)
    {
        /* if (isLogin(context) == "NotLogin")
        {
            return "NotLogin";
        } */
        String jData = "";
        DataTable tar = GetAccountList(context);
        DataTable tar2 = GetRoleList(context);
        jData = JsonConvert.SerializeObject(new { Account = tar, Role = tar2 });

        return (jData);
    }

    public DataTable GetRoleList(HttpContext context)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('1') > -1)
        {
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                sqlStr = @"SELECT * 
                           FROM Role_Template 
                           WHERE Status = '1' ";

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
        }

        return dt;
    }

    public DataTable GetAccountList(HttpContext context)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('1') > -1)
        {
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                sqlStr = @"SELECT * 
                           FROM Account_List ";

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
                    dt = ds.Tables[0];

                    for (int i = 0; i < dt.Rows.Count; i++)
                    {
                        dt.Rows[i]["name"] = StringEncrypt.StringEncrypt.aesDecryptBase64(dt.Rows[i]["name"].ToString(), key);
                        dt.Rows[i]["deptname"] = StringEncrypt.StringEncrypt.aesDecryptBase64(dt.Rows[i]["deptname"].ToString(), key);
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

        return dt;
    }

    public String DeleteAccount(HttpContext context)
    {
        String sqlStr = "";
        string id = context.Request["id"] as string;
        string today = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss:fff");

        DataTable dt = new DataTable();
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT * FROM Account_List as a
						WHERE id = @id ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@id", id)
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

        string dcs = "刪除帳號";
        uploadlog(context, "使用者管理", dcs + "(" + dt.Rows[0]["Account"].ToString() + ")");

        sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" DELETE FROM Account_List 
						WHERE id = @id ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@id", id)
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
        return ("OK");
    }

    public String InsertNewAccount(HttpContext context)
    {
        string stat = "OK";
        string sqlstr = "";
        string id = context.Request["id"] as string;
        string status = context.Request["status"] as string;
        string role = context.Request["role"] as string;

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            sqlstr = " INSERT INTO Account_List (Account, Role, Status, CreateTime, EditTime) ";
            sqlstr += " VALUES(@Account, @classid, @status, GETDATE(), GETDATE()) ";

            command.CommandText = sqlstr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Account", id),
                    new SqlParameter("@status", status),
                    new SqlParameter("@classid", role)
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
                stat = "ERROR";
                ex.StackTrace.ToString();
            }
            finally
            {
                connection.Close();
            }
        };

        return stat;
    }

    public String UpdateAccountStatus(HttpContext context)
    {
        String sqlStr = "";
        string id = context.Request["id"] as string;
        string status = context.Request["status"] as string;
        string role = context.Request["role"] as string;
        string today = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss:fff");

        DataTable dt = new DataTable();
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT * FROM Account_List as a
						WHERE id = @id ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@id", id)
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

        if (dt.Rows[0]["Status"].ToString() != status)
        {
            string dcs = "停用帳號";
            if (status == "1")
                dcs = "啟用帳號";

            uploadlog(context, "使用者管理", dcs + "(" + dt.Rows[0]["Account"].ToString() + ")");
        }
        if (dt.Rows[0]["Role"].ToString() != role)
        {
            string rolename = getRoleName(role);
            uploadlog(context, "使用者管理", "更改(" + dt.Rows[0]["Account"].ToString() + ")群組權限為(" + rolename + ")");
        }

        sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" UPDATE Account_List 
						SET Status = @status,
							Edittime = @edittime,
                            Role = @role
						WHERE id = @id ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@id", id),
                    new SqlParameter("@status", status),
                    new SqlParameter("@edittime", today),
                    new SqlParameter("@role", role)
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
        return ("OK");
    }

    public string getRoleName(string sno)
    {
        string rolename = "";
        DataTable dt = new DataTable();
        DataSet ds = new DataSet();
        string sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT * FROM Role_Template as a
						WHERE Sno = @sno ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@sno", sno)
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
                rolename = dt.Rows[0]["Name"].ToString();
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
        return rolename;
    }
    // End UserManagement

    // Start AuthorityManagement
    public String getRoleTemplate(HttpContext context)
    {
        String jData = "";
        String sqlStr = "";
        DataSet ds = new DataSet();

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('1') > -1)
        {
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                sqlStr = @"SELECT a.*, b.Name as AccountName 
                           FROM Role_Template a 
					       LEFT JOIN Account_List b ON a.EditAccount = b.Account ";

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

                    DataTable dt = ds.Tables[0];

                    for (int i = 0; i < dt.Rows.Count; i++)
                    {
                        dt.Rows[i]["AccountName"] = StringEncrypt.StringEncrypt.aesDecryptBase64(dt.Rows[i]["AccountName"].ToString(), key);
                    }

                    jData = JsonConvert.SerializeObject(dt);
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

        return (jData);
    }

    public String getRoleList(HttpContext context)
    {
        String jData = "";
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT *
                       FROM Role_List";

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

    public String AddNewRoleTemplate(HttpContext context)
    {
        String jData = "";
        String sqlStr = "";

        //Parameter
        String Name = context.Request["Name"] as String;
        String EditAccount = context.Request["EditAccount"] as String;
        string today = DateTime.Now.ToString("yyyy/MM/dd HH:MM:ss:fff");
        String RoleSno = context.Request["RoleSno"] as String;
        String Status = context.Request["Status"] as String;

        uploadlog(context, "權限群組管理", "新增群組(" + Name + ")");
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
				INSERT INTO Role_Template  
                (Name, EditTime, EditAccount, RoleSno, Status)
                values
                (@Name, @EditTime, @EditAccount, @RoleSno, @Status) ";

            command.CommandText = sqlStr;
            try
            {
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlParameter[] p = {
                    new SqlParameter("@Name", Name),
                    new SqlParameter("@EditTime", today),
                    new SqlParameter("@EditAccount", EditAccount),
                    new SqlParameter("@RoleSno", RoleSno),
                    new SqlParameter("@Status", Status)
                };

                command.Parameters.Clear();
                command.Parameters.AddRange(p);
                command.ExecuteNonQuery();
                jData = JsonConvert.SerializeObject("OK");
            }
            catch (Exception ex)
            {
                jData = ex.ToString();
            }
            finally
            {
                connection.Close();
            }
        }
        return (jData);
    }

    public String EditRoleTemplate(HttpContext context)
    {
        String jData = "";
        String sqlStr = "";

        //Parameter
        String Sno = context.Request["Sno"] as String;
        String Name = context.Request["Name"] as String;
        String EditAccount = context.Request["EditAccount"] as String;
        string today = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss:fff");
        String RoleSno = context.Request["RoleSno"] as String;
        String Status = context.Request["Status"] as String;

        uploadlog(context, "權限群組管理", "編輯群組(" + Name + ")");
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
				UPDATE Role_Template 
				SET Name = @Name,
					EditTime = @EditTime,
					EditAccount = @EditAccount,
					RoleSno = @RoleSno,
					Status = @Status
				WHERE Sno = @Sno ";

            command.CommandText = sqlStr;
            try
            {
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlParameter[] p = {
                    new SqlParameter("@Sno", Sno),
                    new SqlParameter("@Name", Name),
                    new SqlParameter("@EditTime", today),
                    new SqlParameter("@EditAccount", EditAccount),
                    new SqlParameter("@RoleSno", RoleSno),
                    new SqlParameter("@Status", Status)
                };

                command.Parameters.Clear();
                command.Parameters.AddRange(p);
                command.ExecuteNonQuery();
                jData = JsonConvert.SerializeObject("OK");
            }
            catch (Exception ex)
            {
                jData = ex.ToString();
            }
            finally
            {
                connection.Close();
            }
        }
        return (jData);
    }

    public String DeleteRoleTemplate(HttpContext context) {
        String jData = "";
        String sqlStr = "";

        //Parameter
        String Sno = context.Request["Sno"] as String;
        String Name = getRoleName(Sno);

        uploadlog(context, "權限群組管理", "刪除群組(" + Name + ")");
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"
				DELETE FROM Role_Template
				WHERE Sno = @Sno";

            command.CommandText = sqlStr;

            try
            {
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlParameter[] p = {
                    new SqlParameter("@Sno", Sno)
                };

                command.Parameters.Clear();
                command.Parameters.AddRange(p);
                command.ExecuteNonQuery();
                jData = JsonConvert.SerializeObject("OK");
            }
            catch (Exception ex)
            {
                jData = ex.ToString();
            }
            finally
            {
                connection.Close();
            }
        }
        return (jData);
    }
    // End AuthorityManagement

    // Start Audit
    public String GetAuditIndex(HttpContext context) {
        String jData = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('2') > -1)
        {
            String model = GetAuditModel(context);
            String combine = GetAuditCombine(context);
            String countlist = GetCountList(context);
            String olddate = GetAuditOldestDate(context);
            String newdate = GetAuditNewestDate(context);

            var models = JsonConvert.DeserializeObject(model);
            var combines = JsonConvert.DeserializeObject(combine);
            var countlists = JsonConvert.DeserializeObject(countlist);
            var oldates = JsonConvert.DeserializeObject(olddate);
            var newdates = JsonConvert.DeserializeObject(newdate);

            jData = JsonConvert.SerializeObject(new { Models = models, Combines = combines, Countlists = countlists, OldestDate = oldates, NewestDate = newdates });
        }

        return (jData);
    }

    public String GetAuditOldestDate(HttpContext context) {
        String jData = "";
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT DISTINCT Min(Time) 
                       FROM Count_List ";

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

    public String GetAuditNewestDate(HttpContext context) {
        String jData = "";
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT DISTINCT Max(Time) 
                       FROM Count_List ";

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

    public String GetAuditModel(HttpContext context) {
        String jData = "";
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT DISTINCT FunctionName 
                       FROM Count_Combine ";

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

    public String GetAuditCombine(HttpContext context) {
        String jData = "";

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * 
                       FROM Count_Combine ";

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

    public String GetCountList(HttpContext context) {
        String jData = "";

        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * 
                       FROM Count_List ";

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
    // End Audit

    // Start Infomaintain
    public String getBaseData(HttpContext context)
    {
        String jData = "";

       //if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        //{
            DataTable datalog = getDataLogTable(context);
            String year = getShowYear(context);
            String month = getShowMonth(context);
            String day = getShowDay(context);
            MNYear showyears = GetTaiwanYears(context);
            int maxmonth = GetMaxMonth(showyears.maxyear.ToString(), context);

            jData = JsonConvert.SerializeObject(new { table = datalog, year = year, month = month, day = day, showyears = showyears, maxmonth = maxmonth });
        //}

        return (jData);
    }

    public String getShowYear(HttpContext context)
    {
        String type = context.Request["type"] as String;
        string appstring = "";

        if (type == "1")
            appstring = "TaiwanDataYear";
        else if (type == "2")
            appstring = "CityYear";
        else if (type == "4")
            appstring = "SeasonYear";

        string daystring = ConfigurationManager.AppSettings[appstring];
        return daystring;
    }

    public String getShowMonth(HttpContext context)
    {
        String type = context.Request["type"] as String;
        string appstring = "";

        if (type == "1")
            appstring = "TaiwanDataMonth";
        else if (type == "2")
            appstring = "CityMonth";
        else if (type == "4")
            appstring = "SeasonMonth";

        string daystring = ConfigurationManager.AppSettings[appstring];
        return daystring;
    }

    public String getShowDay(HttpContext context)
    {
        String type = context.Request["type"] as String;
        string appstring = "";

        if (type == "1")
            appstring = "TaiwanDataDay";
        else if (type == "2")
            appstring = "CityDataDay";
        else if (type == "3")
            appstring = "Mt30Day";
        else if (type == "4")
            appstring = "SeasonDay";
        else if (type == "5")
            appstring = "YearReport";

        string daystring = ConfigurationManager.AppSettings[appstring];
        return daystring;
    }

    public DataTable getDataLogTable(HttpContext context)
    {
        String type = context.Request["type"] as String;

        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * 
                       FROM Data_Log WHERE Area=@DataType ORDER BY DateTime DESC ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@DataType", type)
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

    public String setShowDay(HttpContext context)
    {
        string jData = "Error";
        String type = context.Request["type"] as String;
        String year = context.Request["year"] as String;
        String month = context.Request["month"] as String;
        String day = context.Request["day"] as String;
        string appstring = "";

        if (type == "1")
            appstring = "TaiwanDataDay";
        else if (type == "2")
            appstring = "CityDataDay";
        else if (type == "3")
            appstring = "Mt30Day";
        else if (type == "4")
            appstring = "SeasonDay";
        else if (type == "5")
            appstring = "YearReport";

        if (type == "1")
        {
            Configuration conf = System.Web.Configuration.WebConfigurationManager.OpenWebConfiguration("~");
            conf.AppSettings.Settings["TaiwanDataYear"].Value = year;
            conf.AppSettings.Settings["TaiwanDataMonth"].Value = month;
            conf.Save();
        }
        else if (type == "2")
        {
            Configuration conf = System.Web.Configuration.WebConfigurationManager.OpenWebConfiguration("~");
            conf.AppSettings.Settings["CityYear"].Value = year;
            conf.AppSettings.Settings["CityMonth"].Value = month;
            conf.Save();
        }
        else if (type == "4")
        {
            Configuration conf = System.Web.Configuration.WebConfigurationManager.OpenWebConfiguration("~");
            conf.AppSettings.Settings["SeasonYear"].Value = year;
            conf.AppSettings.Settings["SeasonMonth"].Value = month;
            conf.Save();
        }
        else
        {
            Configuration conf = System.Web.Configuration.WebConfigurationManager.OpenWebConfiguration("~");
            conf.AppSettings.Settings[appstring].Value = day;
            conf.Save();
        }

        jData = "OK";
        return (jData);
    }
    // End Infomaintain

    // Start Log
    private string uploadlog(HttpContext context, string features, string description)
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

    public String GetLoginLogList(HttpContext context)
    {
        String jData = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('4') > -1)
        {
            DataTable dt = new DataTable();
            String sqlStr = "";
            DataSet ds = new DataSet();

            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                sqlStr = @"SELECT * FROM Login_Record ORDER BY LoginTime DESC ";

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
                    dt = ds.Tables[0];

                    jData = JsonConvert.SerializeObject(dt);
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

        return (jData);
    }


    public String GetEditLogList(HttpContext context)
    {
        String jData = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('4') > -1)
        {
            DataTable dt = new DataTable();
            String sqlStr = "";
            DataSet ds = new DataSet();
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                sqlStr = @"SELECT * FROM Log_Record ORDER BY DateTime DESC ";

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
                    dt = ds.Tables[0];

                    jData = JsonConvert.SerializeObject(dt);
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

        return (jData);
    }
    //End Log

    //Start ExportLog
    public string SetExportLog(HttpContext context)
    {
        string logid = context.Session["logaccount"] as string;
        string a = uploadlog(context, "稽核管理", logid + " 匯出清單.");
        return a;
    }
    //End ExportLog

    //Start BackUp
    public String GetBackDBData(HttpContext context)
    {
        String jData = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('5') > -1)
        {
            DataTable dt = new DataTable();
            String sqlStr = "";
            DataSet ds = new DataSet();
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                sqlStr = @"SELECT * FROM BackDB WHERE id = 1 ";

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
                    dt = ds.Tables[0];

                    jData = JsonConvert.SerializeObject(dt);
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

        return (jData);
    }

    public String UpdateBackDBData(HttpContext context)
    {
        String jData = "";
        String sqlStr = "";
        string dtype = context.Request["dtype"] as string;
        string valdate = context.Request["valdate"] as string;
        string h = context.Request["h"] as string;
        if (h == "24")
            h = "0";

        string keep = context.Request["keep"] as string;
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" UPDATE BackDB 
						SET dtype = @dtype,
							valdate = @valdate,
                            h = @h,
                            keep = @keep
						WHERE id = 1 ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@dtype", dtype),
                    new SqlParameter("@valdate", valdate),
                    new SqlParameter("@h", h),
                    new SqlParameter("@keep", keep)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);
                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                    jData = "OK";

                    if (dtype == "daylily")
                        uploadlog(context, "備份管理", "備份設定管理修改為 (每日進行備份，保留備份數量" + keep + ")");
                    else if (dtype == "week")
                        uploadlog(context, "備份管理", "備份設定管理修改為 (每周 " + cntweek(valdate)  + " " + h + "時 進行備份，保留備份數量" + keep + ")");
                    else if (dtype == "month")
                        uploadlog(context, "備份管理", "備份設定管理修改為 (每月 " + valdate + "號 " + h + "時 進行備份，保留備份數量" + keep + ")");
                }
            }
            catch (Exception ex)
            {
                jData = ex.ToString();
            }
            finally
            {
                connection.Close();
            }
        };
        return (jData);
    }
    //End BackUp

    public string cntweek(string widx)
    {
        string weekstr = "";
        switch (widx)
        {
            case "1":
                weekstr = "星期一";
                break;
            case "2":
                weekstr = "星期二";
                break;
            case "3":
                weekstr = "星期三";
                break;
            case "4":
                weekstr = "星期四";
                break;
            case "5":
                weekstr = "星期五";
                break;
            case "6":
                weekstr = "星期六";
                break;
            case "7":
                weekstr = "星期日";
                break;
        }

        return weekstr;
    }

    //Start Login
    private const string CASHOST = "https://cas.ebas.gov.tw/ebas-cas/";
    public class LogItem
    {
        public bool isLogin { get; set; }
        public string LoginName { get; set; }
        public string LoginAccount { get; set; }
        public string LoginURL { get; set; }
        public string LoginRoles { get; set; }
        public int Status { get; set; }
        public int LoginStatus { get; set; }
    }

    public string LoginCheck(HttpContext context) {
        // This page is the CAS service=, but discard any query string residue
        string service = context.Request.Url.GetLeftPart(UriPartial.Authority);

        LogItem item = new LogItem();
        string op = context.Request["op"] as string;
        /*if (context.Session["logaccount"] == null) {
            string tnetid = "supergeo";

            DataTable dt = GetAccountTable(tnetid);
            context.Session["logaccount"] = tnetid;
            context.Session["logname"] = dt.Rows[0]["Name"].ToString();
            context.Session["logroles"] = dt.Rows[0]["rolrules"].ToString();
            context.Session["logstatus"] = Convert.ToInt32(dt.Rows[0]["Status"].ToString());

            item.isLogin = true;
            item.LoginName = dt.Rows[0]["Name"].ToString();
            item.LoginAccount = tnetid;
            item.LoginRoles = dt.Rows[0]["rolrules"].ToString();
            item.Status = Convert.ToInt32(dt.Rows[0]["Status"].ToString());
        }*/
        if (context.Session["logaccount"] != null) {
            item.isLogin = true;
            item.LoginName = context.Session["logname"] as string;
            item.LoginAccount = context.Session["logaccount"] as string;
            item.LoginRoles = context.Session["logroles"] as string;
            item.Status = Convert.ToInt32(context.Session["logstatus"].ToString());
            item.LoginStatus = Convert.ToInt32(context.Session["loginstat"].ToString());

            if (item.LoginRoles == "" || item.Status == 0)
            {
                item.LoginURL = CASHOST + "logout?" + "url=" + service + "/dgbas_back/";
                context.Session["logaccount"] = null;
            }
            else
                item.LoginURL = "";

            return JsonConvert.SerializeObject(item);
        }

        // Look for the "ticket=" after the "?" in the URL
        string tkt = context.Request["ticket"] as string;
        tkt = "n22";
        // First time through there is no ticket=, so redirect to CAS login
        if (tkt == null || tkt.Length == 0)
        {
            string redir = CASHOST + "login?" + "service=" + service + "/dgbas_back/";
            item.isLogin = false;
            item.LoginURL = redir;
            item.LoginStatus = 2;

            return JsonConvert.SerializeObject(item);
        }

        // Second time (back from CAS) there is a ticket= to validate
        string validateurl = CASHOST + "serviceValidate?" +
          "ticket=" + tkt + "&" +
          "service=" + service + "/dgbas_back/";

        //StreamReader Reader = new StreamReader(new WebClient().OpenRead(validateurl));
        //string resp = Reader.ReadToEnd();
        //I like to have the text in memory for debugging rather than parsing the stream

        // Some boilerplate to set up the parse.
        //NameTable nt = new NameTable();
        //XmlNamespaceManager nsmgr = new XmlNamespaceManager(nt);
        //XmlParserContext context2 = new XmlParserContext(null, nsmgr, null, XmlSpace.None);
        //XmlTextReader reader = new XmlTextReader(resp, XmlNodeType.Element, context2);

        string netid = null;

        // A very dumb use of XML. Just scan for the "user". If it isn't there, its an error.
        //while (reader.Read())
        //{
        //    if (reader.IsStartElement())
        //    {
        //        string tag = reader.LocalName;
        //        if (tag == "user")
        //            netid = reader.ReadString();
        //    }
        //}
        // if you want to parse the proxy chain, just add the logic above
        //reader.Close();
        // If there was a problem, leave the message on the screen. Otherwise, return to original page.

        if (netid == null)
        {
            //item.isLogin = false;
            //item.LoginURL = "";
            //insAccount(netid, item);

            netid = "supergeo";

            DataTable dt = GetAccountTable(netid);
            context.Session["logaccount"] = netid;
            // context.Session["logname"] = StringEncrypt.StringEncrypt.aesDecryptBase64(dt.Rows[0]["Name"].ToString(), key);
            context.Session["logname"] = dt.Rows[0]["Name"].ToString();
            context.Session["logroles"] = dt.Rows[0]["rolrules"].ToString();
            context.Session["logstatus"] = Convert.ToInt32(dt.Rows[0]["Status"].ToString());
            context.Session["loginstat"] = 1;

            item.isLogin = true;
            // item.LoginName = StringEncrypt.StringEncrypt.aesDecryptBase64(dt.Rows[0]["Name"].ToString(), key);
            item.LoginName = dt.Rows[0]["Name"].ToString();
            item.LoginAccount = netid;
            item.LoginRoles = dt.Rows[0]["rolrules"].ToString();
            item.Status = Convert.ToInt32(dt.Rows[0]["Status"].ToString());
            item.LoginStatus = 1;

            if (item.LoginRoles == "" || item.Status == 0)
                item.LoginURL = CASHOST + "logout?" + "url=" + service + "/dgbas_back/";
            else
                item.LoginURL = "";

            login_log(context);

            return JsonConvert.SerializeObject(item);
        }
        else
        {
            int stat = insAccount(netid, item); // -1 錯誤 0 找不到帳號 1有找到帳號

            DataTable dt = GetAccountTable(netid);
            context.Session["logaccount"] = netid;

            // context.Session["logname"] = StringEncrypt.StringEncrypt.aesDecryptBase64(dt.Rows[0]["Name"].ToString(), key);
            context.Session["logname"] = dt.Rows[0]["Name"].ToString();

            context.Session["logroles"] = dt.Rows[0]["rolrules"].ToString();
            context.Session["logstatus"] = Convert.ToInt32(dt.Rows[0]["Status"].ToString());
            context.Session["loginstat"] = stat;

            item.isLogin = true;
            item.LoginName = dt.Rows[0]["Name"].ToString();
            item.LoginAccount = netid;
            item.LoginRoles = dt.Rows[0]["rolrules"].ToString();
            item.Status = Convert.ToInt32(dt.Rows[0]["Status"].ToString());
            item.LoginStatus = stat;

            if (item.LoginRoles == "" || item.Status == 0)
                item.LoginURL = CASHOST + "logout?" + "url=" + service + "/dgbas_back/";
            else
                item.LoginURL = "";

            login_log(context);
            return JsonConvert.SerializeObject(item);
        }
    }

    public int insAccount(string name, LogItem item)
    {
        int stat = -1;
        string sqlstr = "";
        if (name != "")
        {
            string abc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><MEMBER><ACCOUNT><![CDATA[" + name + "]]></ACCOUNT></MEMBER>";
            ebasmbService.EbasMemberServiceClient cc = new ebasmbService.EbasMemberServiceClient();
            string a = cc.getEbasMember(abc);
            XmlDocument xd = new XmlDocument();
            xd.LoadXml(a);
            XmlNodeList nodelist = xd.SelectNodes("//MEMBER");
            string account = nodelist[0]["ACCOUNT"].InnerText;
            string uName = nodelist[0]["NAME"].InnerText;
            string DEPT_NAME = nodelist[0]["DEPT_NAME"].InnerText;
            string DEPT_NAME_PATH = nodelist[0]["DEPT_NAME_PATH"].InnerText;
            string DEPT_NO = nodelist[0]["DEPT_NO"].InnerText;
            string DEPT_NO_PATH = nodelist[0]["DEPT_NO_PATH"].InnerText;
            string EMAIL = nodelist[0]["EMAIL"].InnerText;
            string TITLE_NO = nodelist[0]["TITLE_NO"].InnerText;
            string TITLE_NAME = nodelist[0]["TITLE_NAME"].InnerText;
            string role = "";

            if (DEPT_NAME.IndexOf("資料發展科") > -1)
            {
                role = "1";
            }
            else if (DEPT_NAME.IndexOf("人力調查科") > -1)
            {
                role = "1";
            }
            else
            {
                role = "2";
            }

            uName = StringEncrypt.StringEncrypt.aesEncryptBase64(uName, key);
            DEPT_NAME = StringEncrypt.StringEncrypt.aesEncryptBase64(DEPT_NAME, key);
            DEPT_NAME_PATH = StringEncrypt.StringEncrypt.aesEncryptBase64(DEPT_NAME_PATH, key);
            DEPT_NO = StringEncrypt.StringEncrypt.aesEncryptBase64(DEPT_NO, key);
            DEPT_NO_PATH = StringEncrypt.StringEncrypt.aesEncryptBase64(DEPT_NO_PATH, key);
            EMAIL = StringEncrypt.StringEncrypt.aesEncryptBase64(EMAIL, key);
            TITLE_NO = StringEncrypt.StringEncrypt.aesEncryptBase64(TITLE_NO, key);
            TITLE_NAME = StringEncrypt.StringEncrypt.aesEncryptBase64(TITLE_NAME, key);

            DataTable dt = GetAccountTable(name);
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                if (dt.Rows.Count < 1)
                {
                    stat = 0;
                    return stat;
                }
                else
                {
                    sqlstr = " UPDATE Account_List SET Name = @uName, Deptname = @DEPT_NAME, Titleno = @TITLE_NO, TitleName = @TITLE_NAME, DeptnamePath = @DEPT_NAME_PATH, ";
                    sqlstr += " DeptNo = @DEPT_NO, DeptnoPath = @DEPT_NO_PATH, Email = @EMAIL ";
                    sqlstr += " WHERE Account = @Account ";
                }

                command.CommandText = sqlstr;

                try
                {
                    SqlParameter[] p = {
                        new SqlParameter("@Account", name),
                        new SqlParameter("@uName", uName),
                        new SqlParameter("@DEPT_NAME", DEPT_NAME),
                        new SqlParameter("@DEPT_NAME_PATH", DEPT_NAME_PATH),
                        new SqlParameter("@DEPT_NO", DEPT_NO),
                        new SqlParameter("@DEPT_NO_PATH", DEPT_NO_PATH),
                        new SqlParameter("@EMAIL", EMAIL),
                        new SqlParameter("@TITLE_NO", TITLE_NO),
                        new SqlParameter("@TITLE_NAME", TITLE_NAME),
                        new SqlParameter("@classid", role)
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);

                    if (connection.State == ConnectionState.Closed)
                    {
                        connection.Open();
                        command.ExecuteNonQuery();
                        stat = 1;
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

        return stat;
    }

    private DataTable GetAccountTable(string name)
    {
        string sqlStr = "";
        DataTable dt = new DataTable();
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT a.*, b.RoleSno as rolrules 
                        FROM Account_List as a
                        LEFT JOIN Role_Template as b ON a.Role = b.Sno 
                        WHERE Account = @ACCOUNT 
                      ";

            command.CommandText = sqlStr;

            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@ACCOUNT", name)
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

    public string Logout(HttpContext context)
    {
        logout_log(context);
        context.Session["logaccount"] = null;
        context.Session["logname"] = null;
        string service = context.Request.Url.GetLeftPart(UriPartial.Authority);
        string redir = CASHOST + "logout?" + "url=" + service + "/dgbas_back/";

        return redir;
    }

    public string isLogin(HttpContext context)
    {
        string id = context.Session["logaccount"] as string;
        string roles = context.Session["logroles"] as string;

        if (context.Session["logaccount"] != null)
        {
            return "Login";
        }

        return "NotLogin";
    }

    public string FrontIsLogin(HttpContext context)
    {
        string id = context.Session["logaccount"] as string;
        string roles = context.Session["logroles"] as string;

        if (context.Session["logaccount"] != null && roles.IndexOf('6') != -1)
        {
            return "Login";
        }

        return "Login";
    }

    private void login_log(HttpContext context)
    {
        string sqlStr = "";
        string id = context.Session["logaccount"] as string;
        DateTime ndate = DateTime.Now;
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"INSERT INTO Login_Record (Account, LoginTime) 
                              VALUES (@Account, @LoginTime) ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Account", id),
                    new SqlParameter("@LoginTime", ndate)
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

    private void logout_log(HttpContext context)
    {
        string sqlStr = "";
        string id = context.Session["logaccount"] as string;
        DateTime ndate = DateTime.Now;
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"INSERT INTO Log_Record (Account, DateTime, [Function], Description) 
                              VALUES (@Account, @DateTime, @Function, @Description) ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Account", id),
                    new SqlParameter("@DateTime", ndate),
                    new SqlParameter("@Function", "系統登出"),
                    new SqlParameter("@Description", "(" + id + ") 登出系統")
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

    //End Login

    //Start SettingLayout
    public String getCategoryData(HttpContext context)
    {
        String jData = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        {
            DataTable getcat = getYearCategory(context);
            jData = JsonConvert.SerializeObject(new { yearcategory = getcat });
        }
        return (jData);
    }

    public String getSettingLayoutData(HttpContext context)
    {
        String jData = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        {
            DataTable datalog = getSettingLayoutTable(context);
            DataTable getcat = getYearCategory(context);
            jData = JsonConvert.SerializeObject(new { table = datalog, yearcategory = getcat });
        }

        return (jData);
    }

    public String getLayoutDataMaxYear(HttpContext context)
    {
        String jData = "";

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        {
            String date1 = getTimelineMaxYear(context);
            String date2 = getNoneTimelineMaxYear(context);
            jData = JsonConvert.SerializeObject(new { TimelineMaxYear = date1, NoneTimelineMaxYear = date2 });
        }

        return (jData);
    }
    public String getTimelineMaxYear(HttpContext context)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        String target = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT MAX([欄位1]) as year FROM [Year_Table_Timeline] ";

            command.CommandText = sqlStr;
            try
            {
                command.Parameters.Clear();

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);
                dt = ds.Tables[0];

                if (dt.Rows.Count > 0) target = dt.Rows[0]["year"].ToString();
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

        return target;
    }
    public String getNoneTimelineMaxYear(HttpContext context)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        String target = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT MAX([欄位1]) as year FROM [Year_Table_Nonetimeline] ";

            command.CommandText = sqlStr;
            try
            {
                command.Parameters.Clear();

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);
                dt = ds.Tables[0];

                if (dt.Rows.Count > 0) target = dt.Rows[0]["year"].ToString();
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

        return target;
    }
    //前台使用
    public String getLayoutData(HttpContext context)
    {
        String jData = "";

        DataTable datalog = getDistinctLayoutTable(context);
        DataTable getcat = getYearCategory(context);
        jData = JsonConvert.SerializeObject(new { table = datalog, yearcategory = getcat });

        return (jData);
    }
    //前台使用
    public String getLayoutDataFromID(HttpContext context)
    {
        String jData = "";

        DataTable datalog = getLayoutFromID(context);
        jData = JsonConvert.SerializeObject(new { data = datalog });

        return (jData);
    }

    public void DownLoadLayoutFile(HttpContext context)
    {
        String SNO = context.Request["SNO"] as string;
        String FILENAME = context.Request["FILENAME"] as string;

        if (SNO == null || SNO == "") return;
        if (FILENAME == null || FILENAME == "") return;

        string path = HttpContext.Current.Server.MapPath(".\\layoutupload\\" + SNO + ".xlsx");
        byte[] file = File.ReadAllBytes(path);
        context.Response.Clear();
        context.Response.AddHeader("Content-Disposition", "attachment; filename=" + FILENAME);
        context.Response.ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        context.Response.OutputStream.Write(file, 0, file.Length);
        context.Response.OutputStream.Flush();
        context.Response.OutputStream.Close();
        context.Response.Flush();
        // context.Response.BinaryWrite(file);   //byte array contents of file
        // context.Response.End();
    }

    public String SearchGetHtml(HttpContext context)
    {
        String jData = "ERROR";

        String SNO = HttpUtility.HtmlEncode(context.Request["SNO"] as string);
        String TID = HttpUtility.HtmlEncode(context.Request["TID"] as string);
        String ORDER = HttpUtility.HtmlEncode(context.Request["ORDER"] as string);
        String T_NAME = HttpUtility.HtmlEncode(context.Request["T_NAME"] as string);
        String TIMELINE = HttpUtility.HtmlEncode(context.Request["TIMELINE"] as string);
        String NEXT = HttpUtility.HtmlEncode(context.Request["NEXT"] as string);
        String EDITION = HttpUtility.HtmlEncode(context.Request["EDITION"] as string);

        DataTable tar = getLayoutFromSNO(context);
        StatCondition stat = GetStatCondition(context);
        string filename = SNO + "_1.htm";
        if (stat.StatClass == StatClassItem.Month || stat.StatClass == StatClassItem.YearAverageAndMonth)
        {
            filename = SNO + "_2.htm";
        }

        string strSourceHtm = HttpContext.Current.Server.MapPath(".\\layoutupload\\" + filename);

        if (File.Exists(strSourceHtm))
        {
            Int32 nTable = -1;
            Int32 nV;
            if (Int32.TryParse(TID, out nV))
            {
                nTable = nV;
            }
            List<Int32> lstTables = new List<Int32>();
            // 如果有續表, Table ID 有兩個, 原 ID 尾端分別加 1, 2 
            if (NEXT == "1")
            {
                lstTables.Add(nTable);
                lstTables.Add(nTable);
            }
            else
            {
                lstTables.Add(nTable);
            }

            // 由畫面選項取計算參數
            stat.CssFilename = "table.css";

            List<String> outputHtml = new List<String>();

            for (Int32 i = 0; i < lstTables.Count; i++)
            {
                Int32 idTable = lstTables[i];
                // 依條件從資料庫取得資料.
                DataSet data = GetDataSet(idTable, stat, TIMELINE, EDITION, NEXT, i);

                // 載入樣版 ".htm"
                String strHtm = "";
                if (File.Exists(strSourceHtm))
                {
                    strHtm = File.ReadAllText(strSourceHtm, Encoding.UTF8);
                }
                if (strHtm.Length > 0)
                {
                    // 設定樣版的處理模式及填入的參數...
                    // TODO : 由資料庫取得相對應的文字內容
                    stat.NextPartNode = "<br />"; // 僅套用 "統計項" 的表.
                    stat.TableText = "表" + TID;
                    stat.TitleText = T_NAME;

                    string unitStr = "";
                    if (tar.Rows.Count > 0)
                    {
                        unitStr = tar.Rows[0]["UNIT"].ToString();
                    }
                    String[] unitStrs = unitStr.Split(';');
                    if (i == 0)
                    {
                        stat.NextStatText = "";
                        stat.UnitText = "無單位";
                        if (unitStrs.Length > 0)
                        {
                            if (unitStrs[0] != "") stat.UnitText = unitStrs[0];
                        }
                    }
                    else
                    {
                        stat.NextStatText = "(續)";
                        stat.UnitText = "無單位";
                        if (unitStrs.Length > 1)
                        {
                            if (unitStrs[1] != "") stat.UnitText = unitStrs[1];
                        }
                    }
                    // 由設定參數及實際資料, 套用到樣版 .htm 以形成單一 .html 的內容
                    HtmlHelper export = new HtmlHelper();
                    if (export != null)
                    {
                        // 指定樣版
                        export.SetStatCondition(stat);
                        // 指定資料集 (傳入 DataTable)
                        // 也同時會檢查第一筆資料 欄位6 之後的內容, 若有小數點, Decimal 會自動設成 2)
                        export.SetDataTable(data.Tables.Count > 0 ? data.Tables[0] : null);
                        // 再以資料形成 html
                        String strHtml = export.TemplateApply(strHtm);

                        outputHtml.Add(strHtml);
                    }
                }
            }
            String strOutputHtml = null;
            if (outputHtml.Count > 0)
            {
                if (outputHtml.Count == 1)
                {
                    strOutputHtml = outputHtml[0];
                }
                else
                {
                    // 有續表, 將第二個之後的 html <body></body> 內容接合至第一個 html 中.
                    strOutputHtml = HtmlHelper.JoinBody(outputHtml, "<br />");
                }
                // TODO : 替換 <style></style> 裏面的內容 (可傳入空字串清空)
                strOutputHtml = HtmlHelper.ReplaceStyleWithText(strOutputHtml, "");
                // TODO : 在 <head></head> 加入 css 的 link
                if (stat.CssFilename != null)
                {
                    List<String> cssLinks = new List<String>();
                    cssLinks.Add(String.Format("<link rel='stylesheet' href='./{0}' />\r\n", stat.CssFilename));
                    strOutputHtml = HtmlHelper.AppendNodeToHead(strOutputHtml, cssLinks);
                }
                // Debug : 寫出替換後的結果
                String strOutputFile = Path.ChangeExtension(strSourceHtm, ".html");
                File.WriteAllText(strOutputFile, strOutputHtml);
                jData = strOutputHtml;
            }
        }

        return (jData);
    }

    public void SearchGetExcel(HttpContext context)
    {
        String jData = "ERROR";
        String SNO = context.Request["SNO"] as string;
        String TID = context.Request["TID"] as string;
        String ORDER = context.Request["ORDER"] as string;
        String T_NAME = context.Request["T_NAME"] as string;
        String TIMELINE = context.Request["TIMELINE"] as string;
        String NEXT = context.Request["NEXT"] as string;
        String FILETYPE = context.Request["FILETYPE"] as string;
        String EDITION = context.Request["EDITION"] as string;

        string filename = SNO;
        filename += ".xlsx";
        string strExcel = HttpContext.Current.Server.MapPath(".\\layoutupload\\" + filename);
        DataTable tar = getLayoutFromSNO(context);

        if (File.Exists(strExcel))
        {
            try
            {
                Int32 nTable = -1;
                Int32 nV;
                if (Int32.TryParse(TID, out nV))
                {
                    nTable = nV;
                }
                List<Int32> lstTables = new List<Int32>();
                // 如果有續表, Table ID 有兩個, 原 ID 尾端分別加 1, 2 
                if (NEXT == "1")
                {
                    lstTables.Add(nTable);
                    lstTables.Add(nTable);
                }
                else
                {
                    lstTables.Add(nTable);
                }
                StatCondition stat = GetStatCondition(context);
                stat.TableText = "表" + TID;
                stat.TitleText = T_NAME;

                List<DataSet> datas = new List<DataSet>();
                List<String> unittext = new List<String>();
                for (Int32 i = 0; i < lstTables.Count; i++)
                {
                    Int32 idTable = lstTables[i];
                    // 依條件從資料庫取得資料.
                    string unitStr = "";
                    if (tar.Rows.Count > 0)
                    {
                        unitStr = tar.Rows[0]["UNIT"].ToString();
                    }
                    String[] unitStrs = unitStr.Split(';');
                    if (i == 0)
                    {
                        stat.NextStatText = "";
                        stat.UnitText = "無單位";
                        if (unitStrs.Length > 0)
                        {
                            if (unitStrs[0] != "") unittext.Add(unitStrs[0]);
                        }
                    }
                    else
                    {
                        stat.NextStatText = "(續)";
                        stat.UnitText = "無單位";
                        if (unitStrs.Length > 1)
                        {
                            if (unitStrs[1] != "") unittext.Add(unitStrs[1]);
                        }
                    }

                    DataSet data = GetDataSet(idTable, stat, TIMELINE, EDITION, NEXT, i);
                    datas.Add(data);
                }

                IWorkbook originWorkbook = null;
                NPOI.XSSF.Model.StylesTable originStyle = null;
                String strPath = Path.GetDirectoryName(strExcel);
                String strMainFile = Path.GetFileNameWithoutExtension(strExcel);
                String strExt = Path.GetExtension(strExcel);
                // 載入 Excel 檔.
                using (FileStream fs = new FileStream(strExcel, FileMode.Open, FileAccess.Read))
                {
                    if (String.Compare(".xlsx", strExt, true) == 0)
                    {
                        XSSFWorkbook t = new XSSFWorkbook(fs);
                        originWorkbook = t;
                        originStyle = t.GetStylesSource();
                    }
                    else if (String.Compare(".xls", strExt, true) == 0)
                    {
                        originWorkbook = new HSSFWorkbook(fs);
                    }
                }
                if (originWorkbook != null)
                {
                    string fileName = SetExcelData(originWorkbook, datas, stat, context, unittext, originStyle);

                    String filetar = fileName + ".xlsx";
                    String mimetype = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
                    if (FILETYPE == "ODS")
                    {
                        filetar = fileName + ".ods";
                        mimetype = "application/vnd.oasis.opendocument.spreadsheet";
                    }

                    string path = HttpContext.Current.Server.MapPath(".\\ExportYearReport\\" + filetar);
                    byte[] file = File.ReadAllBytes(path);
                    context.Response.Clear();
                    context.Response.AddHeader("Content-Disposition", "attachment; filename=" + path);
                    context.Response.ContentType = mimetype;
                    context.Response.OutputStream.Write(file, 0, file.Length);
                    context.Response.OutputStream.Flush();
                    context.Response.OutputStream.Close();
                    context.Response.Flush();
                }
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
            }
        }
        // return (jData);
    }

    private string SetExcelData(IWorkbook workbook, List<DataSet> data, StatCondition stat, HttpContext context, List<String> unittext, NPOI.XSSF.Model.StylesTable stylesource)
    {
        XSSFWorkbook Newworkbook = new XSSFWorkbook();
        NPOI.XSSF.Model.StylesTable newstylesource = Newworkbook.GetStylesSource();
        newstylesource.SetTheme(stylesource.GetTheme());

        Int32 i = 0; //target sheet
        if (stat.StatClass == StatClassItem.Month || stat.StatClass == StatClassItem.YearAverageAndMonth)
        {
            i = 1;
        }
        ISheet originSheet = workbook.GetSheetAt(i);

        Dictionary<String, Object> def = null;
        Boolean bGotFieldDef = false;
        Boolean bGotTitleCell = false;
        TemplateItem item = new TemplateItem();
        for (Int32 r = originSheet.FirstRowNum; r <= originSheet.LastRowNum; r++)
        {
            IRow currentRow = originSheet.GetRow(r);
            if (currentRow != null)
            {
                Boolean bGotContent = false;
                for (Int32 c = currentRow.FirstCellNum; c <= currentRow.LastCellNum; c++)
                {
                    if (c >= 0)
                    {
                        ICell currentCell = currentRow.GetCell(c, MissingCellPolicy.RETURN_BLANK_AS_NULL);
                        if (currentCell != null)
                        {
                            String strVal = GetCellValue(currentCell);
                            if (strVal != null)
                            {
                                strVal = strVal.Trim();
                                if (strVal.Length > 0)
                                {
                                    Int32 nRowIndex = currentRow.RowNum - 1;
                                    if (!bGotFieldDef)
                                    {
                                        def = LoadFieldDef(currentRow);
                                        if (def != null)
                                        {
                                            List<Int32> lstIndex = def["FIELDS_INDEX"] as List<Int32>;
                                            if (lstIndex != null && lstIndex.Count > 0)
                                            {
                                                item.ColumnEnd = lstIndex[lstIndex.Count - 1];
                                            }
                                            bGotFieldDef = true;
                                        }
                                    }
                                    else
                                    {
                                        if (String.Compare("$$HEADER$$", strVal, true) == 0)
                                        {
                                            if (nRowIndex < item.HeaderStart) item.HeaderStart = nRowIndex;
                                            if (nRowIndex > item.HeaderEnd) item.HeaderEnd = nRowIndex;
                                        }
                                        else if (String.Compare("$$ROW$$", strVal, true) == 0)
                                        {
                                            // DataRow (Only One Row)
                                            if (item.DataRow < 0)
                                            {
                                                item.DataRow = nRowIndex;
                                            }
                                        }
                                        else if (String.Compare("$$START$$", strVal, true) == 0)
                                        {
                                            // Table Start
                                            if (item.TableStart < 0)
                                            {
                                                item.TableStart = nRowIndex;
                                            }
                                        }
                                        else if (String.Compare("$$END$$", strVal, true) == 0)
                                        {
                                            // Table End
                                            if (item.TableEnd < 0)
                                            {
                                                item.TableEnd = nRowIndex;
                                            }
                                        }
                                        else
                                        {
                                            if (!item.HasHeader &&
                                                !item.HasTable)
                                            {
                                                // Title
                                                if (nRowIndex < item.TitleStart) item.TitleStart = nRowIndex;
                                                if (nRowIndex > item.TitleEnd) item.TitleEnd = nRowIndex;
                                                Int32 nTitle = strVal.IndexOf("$$NEXT");
                                                if (nTitle >= 0 || !bGotTitleCell)
                                                {
                                                    bGotTitleCell = true;
                                                    currentCell.SetCellValue("$$TABLE$$　$$TITLE$$　$$NEXT_STAT$$");
                                                }
                                            }
                                        }
                                    }
                                    if (nRowIndex >= item.RowEnd)
                                    {
                                        item.RowEnd = nRowIndex;
                                    }
                                    bGotContent = true;
                                }
                            }
                        }
                    }
                    if (bGotContent)
                    {
                        break;
                    }
                }
            }
        }
        string fileName = "";
        if (def != null)
        {
            item.SetName(originSheet.SheetName);
            item.SetFields(def);
            fileName = item.SetTemplateWithData(context, originSheet, Newworkbook, data, stat, unittext);
        }
        return fileName;
    }

    private String GetCellValue(ICell iCell)
    {
        String strVal = null;
        if (iCell != null)
        {
            switch (iCell.CellType)
            {
                case CellType.Blank:
                    break;
                case CellType.Boolean:
                    strVal = Convert.ToString(iCell.BooleanCellValue);
                    break;
                case CellType.Error:
                    strVal = Convert.ToString(iCell.ErrorCellValue);
                    break;
                case CellType.Formula:
                    strVal = Convert.ToString(iCell.CellFormula);
                    break;
                case CellType.Numeric:
                    strVal = Convert.ToString(iCell.NumericCellValue);
                    break;
                case CellType.String:
                    strVal = Convert.ToString(iCell.StringCellValue);
                    break;
                default:
                    break;
            }
        }
        return strVal;
    }

    private Dictionary<String, Object> LoadFieldDef(IRow row)
    {
        Dictionary<String, Object> dicDef = new Dictionary<String, Object>();
        List<String> lstFileds = new List<String>();
        List<Int32> lstIndex = new List<Int32>();
        for (Int32 c = row.FirstCellNum; c <= row.LastCellNum; c++)
        {
            ICell currentCell = row.GetCell(c, MissingCellPolicy.RETURN_BLANK_AS_NULL);
            String strVal = GetCellValue(currentCell);
            if (strVal != null && strVal.Trim().Length > 0)
            {
                if (String.Compare("YEAR", strVal, true) == 0 ||
                    String.Compare("MONTH", strVal, true) == 0 ||
                    String.Compare("$$STAT_CLASS$$", strVal, true) == 0 ||
                    String.Compare("CLASS_YEAR", strVal, true) == 0)
                {
                    dicDef.Add(strVal, currentCell.ColumnIndex - 1);
                    if (!strVal.StartsWith("$$"))
                    {
                        lstFileds.Add(strVal);
                        lstIndex.Add(currentCell.ColumnIndex - 1);
                    }
                }
                else
                {
                    lstFileds.Add(strVal);
                    lstIndex.Add(currentCell.ColumnIndex - 1);
                }
            }
        }
        if (dicDef.Count > 0)
        {
            dicDef.Add("FIELDS_NAME", lstFileds);
            dicDef.Add("FIELDS_INDEX", lstIndex);
        }
        else
        {
            dicDef = null;
        }
        return dicDef;
    }

    private StatCondition GetStatCondition(HttpContext context)
    {
        StatCondition stat = new StatCondition();

        String STAT = context.Request["STAT"] as string;
        if (STAT == "1")
        {
            stat.StatClass = StatClassItem.YearAverage;
        }
        else if (STAT == "2")
        {
            stat.StatClass = StatClassItem.Month;
        }
        else if (STAT == "3")
        {
            stat.StatClass = StatClassItem.YearAverageAndMonth;
        }
        else if (STAT == "0")
        {
            stat.StatClass = StatClassItem.Items;
        }

        String S_YEAR = context.Request["S_YEAR"] as string;
        String E_YEAR = context.Request["E_YEAR"] as string;
        Int32 nV;
        if (Int32.TryParse(S_YEAR, out nV))
        {
            stat.StartYear = nV;
        }
        if (Int32.TryParse(E_YEAR, out nV))
        {
            stat.EndYear = nV;
        }

        return stat;
    }

    private DataSet GetDataSet(Int32 table, StatCondition stat, string istime, string edition, string next, int idx)
    {
        DataSet data = null;
        if (table > 0)
        {
            // 連線字串
            String strConnectionString = sqlConnstr;

            // 查詢的年份
            Int32 nStartYear = stat.StartYear;
            Int32 nEndYear = stat.EndYear;

            // 查詢項目
            String strTableID = "";
            String strYearMonth = "";
            if (stat.StatClass == StatClassItem.YearAverage)
            {
                strTableID = String.Format("欄位3 = {0}", table);
                strYearMonth = "AND 欄位2 = 0";
            }
            else if (stat.StatClass == StatClassItem.Month)
            {
                strTableID = String.Format("欄位3 = {0}", table);
                strYearMonth = "AND 欄位2 > 0";
            }
            else if (stat.StatClass == StatClassItem.YearAverageAndMonth)
            {
                strTableID = String.Format("欄位3 = {0}", table);
            }
            else if (stat.StatClass == StatClassItem.Items)
            {
                strTableID = String.Format("欄位3 = {0}", table);
            }

            String strnext = "";
            if (next == "1")
            {
                strnext = String.Format(" AND 欄位4 = {0}", idx + 1);
            }
            else
            {
                strnext = String.Format(" AND 欄位4 = {0}", 0);
            }

            // 查詢的資料表
            String strTable = null;
            if (istime == "1")
                strTable = "Year_Table_Timeline";
            else if (istime == "0")
                strTable = "Year_Table_Nonetimeline";

            String strSqlTemplate1 = @"
                SELECT * FROM {0} 
                WHERE {1} {2} AND [欄位1] >= {3} AND [欄位1] <= {4} AND [欄位5] = {5} {6}
                ORDER BY 欄位1,欄位2,欄位3;
            ";

            edition = edition.Replace(">", "").Replace("<", "").Replace("=", "");

            String strSql = String.Format(strSqlTemplate1,
                strTable, strTableID, strYearMonth, nStartYear + 1911, nEndYear + 1911, edition, strnext);

            if (strSql.Length > 0)
            {
                data = SqlHelper.GetDataSet(strConnectionString, strSql, strTable + "_" + strTableID);
            }
        }

        return data;
    }

    public DataTable getYearCategory(HttpContext context)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @" SELECT * FROM Year_Category ORDER BY [Order] ";

            command.CommandText = sqlStr;
            try
            {
                command.Parameters.Clear();

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

    public DataTable getDistinctLayoutTable(HttpContext context)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr += @"SELECT DISTINCT T_ID, T_NAME, CAT FROM Y_TB_LIST ";

            command.CommandText = sqlStr;
            try
            {
                command.Parameters.Clear();

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

    public DataTable getLayoutFromID(HttpContext context)
    {
        String tid = context.Request["TID"] as string;
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM Y_TB_LIST 
                       WHERE T_ID = @T_ID 
                       ORDER BY Y_TB_LIST.S_YEAR, Y_TB_LIST.E_YEAR ";
            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@T_ID", tid)
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

    public DataTable getLayoutFromSNO(HttpContext context)
    {
        String SNO = context.Request["SNO"] as string;
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM Y_TB_LIST 
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

    public DataTable getSettingLayoutTable(HttpContext context)
    {
        DataTable dt = new DataTable();
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT Y_TB_LIST.T_ID, Y_TB_LIST.[ORDER], Y_TB_LIST.T_NAME, Y_TB_LIST.SUB_NAME, Y_TB_LIST.S_YEAR, 
                              Y_TB_LIST.E_YEAR, Y_TB_LIST.STAT_PERIOD, Y_TB_LIST.UNIT, Y_TB_LIST.COMMENT, Y_TB_LIST.NEXT, 
                              Y_TB_LIST.TIMELINE, Year_Category.Name, Y_TB_LIST.EDITTIME, Y_TB_LIST.SNO, Y_TB_LIST.CAT, Y_TB_LIST.EDITION, Y_TB_LIST.ISUPLOAD, Y_TB_LIST.FORM_NAME 
                        FROM  Y_TB_LIST INNER JOIN 
                              Year_Category ON Y_TB_LIST.CAT = Year_Category.Sno 
                        ORDER BY Y_TB_LIST.T_ID, Y_TB_LIST.S_YEAR, Y_TB_LIST.E_YEAR ";

            command.CommandText = sqlStr;
            try
            {
                command.Parameters.Clear();

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

    public String DeleteLayoutClass(HttpContext context)
    {
        string jData = "ERROR";
        string SNO = context.Request["SNO"] as string;

        String sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            sqlStr = @"
                       DELETE FROM Year_Category 
                       WHERE Sno = @SNO;

                       UPDATE Y_TB_LIST 
                       SET CAT=1
                       WHERE CAT = @SNO;
                       ";

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
                jData = "OK";
            }
            catch (Exception ex)
            {
                ex.StackTrace.ToString();
                jData = "ERROR";
            }
            finally
            {
                connection.Close();
            }
        };

        return (jData);
    }

    public String UpdateLayoutClass(HttpContext context)
    {
        string jData = "ERROR";
        string isEdit = context.Request["isEdit"] as string;

        if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
        {
            if (isEdit == "0") //新增
            {
                InsertDBLayoutClass(context);
                jData = "OK";
            }
            else if (isEdit == "1") //更新
            {
                UpdateDBLayoutClass(context);
                jData = "OK";
            }
        }

        return (jData);
    }

    private void InsertDBLayoutClass(HttpContext context)
    {
        string Name = context.Request["CLASSNAME"] as string;
        String sqlStr = "";

        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            sqlStr = @"INSERT INTO Year_Category ([Order], [Name], [EditTime])
                       VALUES ((SELECT MAX([Order]) FROM Year_Category) + 1, @Name, GETDATE())
                       ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Name", Name)
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

    private void UpdateDBLayoutClass(HttpContext context)
    {
        string SNO = context.Request["SNO"] as string;
        string Name = context.Request["CLASSNAME"] as string;
        string ORDER = context.Request["ORDER"] as string;
        string ISDOWN = context.Request["ISDOWN"] as string;

        String sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            if (ORDER == "" || ORDER == null)
            {
                sqlStr = @"UPDATE Year_Category 
                           SET Name=@Name, EditTime=GETDATE() 
                           WHERE Sno=@Sno
                          ";
            }
            else
            {
                if (ISDOWN == "0")
                {
                    sqlStr = @" UPDATE Year_Category 
                        SET [Order]=@Order1
                        WHERE [Order]=@Order1 - 1; 
                    ";
                }
                else if (ISDOWN == "1")
                {
                    sqlStr = @" UPDATE Year_Category 
                        SET [Order]=@Order1
                        WHERE [Order]=@Order1 + 1; 
                    ";
                }
                sqlStr += @"UPDATE Year_Category 
                    SET [Order]=@Order2,EditTime=GETDATE()
                    WHERE Sno=@Sno;
                    ";
            }

            command.CommandText = sqlStr;
            try
            {
                if (ORDER == "" || ORDER == null)
                {
                    SqlParameter[] p = {
                        new SqlParameter("@Name", Name),
                        new SqlParameter("@Sno", SNO)
                    };
                    command.Parameters.Clear();
                    command.Parameters.AddRange(p);
                }
                else
                {
                    int order = Convert.ToInt16(ORDER);
                    if (ISDOWN == "0")
                        order = order - 1;
                    else if (ISDOWN == "1")
                        order = order + 1;

                    SqlParameter[] p = {
                        new SqlParameter("@Sno", SNO),
                        new SqlParameter("@Order1", ORDER),
                        new SqlParameter("@Order2", order)
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

    public String UpdateLayoutSort(HttpContext context)
    {
        string jData = "ERROR";
        string SNO = context.Request["SNO"] as string;
        string TID = context.Request["TID"] as string;
        string ORDER = context.Request["ORDER"] as string;
        string ISDOWN = context.Request["ISDOWN"] as string;

        String sqlStr = "";
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);

            if (ISDOWN == "0")
            {
                sqlStr = @" UPDATE Y_TB_LIST 
                    SET [ORDER]=@Order1
                    WHERE [ORDER]=(@Order1 - 1) AND [T_ID]=@TID; 
                ";
            }
            else if (ISDOWN == "1")
            {
                sqlStr = @" UPDATE Y_TB_LIST 
                    SET [ORDER]=@Order1
                    WHERE [ORDER]=(@Order1 + 1) AND [T_ID]=@TID; 
                ";
            }
            sqlStr += @"UPDATE Y_TB_LIST 
                SET [ORDER]=@Order2,[EDITTIME]=GETDATE()
                WHERE [SNO]=@Sno;
                ";

            command.CommandText = sqlStr;
            try
            {
                int order = Convert.ToInt16(ORDER);
                if (ISDOWN == "0")
                    order = order - 1;
                else if (ISDOWN == "1")
                    order = order + 1;

                SqlParameter[] p = {
                    new SqlParameter("@Sno", SNO),
                    new SqlParameter("@TID", TID),
                    new SqlParameter("@Order1", ORDER),
                    new SqlParameter("@Order2", order)
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
                jData = "OK";
                connection.Close();
            }
        };


        return (jData);
    }

    //End SettingLayout

    public DataRow CheckAlreadyHasRecord()
    {
        DateTime ndate = DateTime.Now;
        DateTime odate = ndate.Date;

        DataRow row = null;
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM Guest_Count WHERE Time=@Time ";

            command.CommandText = sqlStr;
            try
            {
                SqlParameter[] p = {
                    new SqlParameter("@Time", odate)
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

    public DataRow GetTotalCount()
    {
        DateTime ndate = DateTime.Now;
        DateTime odate = ndate.Date;

        DataRow row = null;
        String sqlStr = "";
        DataSet ds = new DataSet();
        using (SqlConnection connection = new SqlConnection(sqlConnstr))
        {
            SqlCommand command = new SqlCommand("", connection);
            sqlStr = @"SELECT * FROM Guest_TotalCount ";

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

    public void SetViewCount(HttpContext context)
    {
        string hasview = context.Session["views"] as string;

        if (hasview == null)
        {
            DataRow recode = CheckAlreadyHasRecord();
            DataRow tocode = GetTotalCount();
            DateTime ndate = DateTime.Now;
            DateTime odate = ndate.Date;

            String sqlStr = "";
            DataSet ds = new DataSet();
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);

                if (recode != null)
                {
                    sqlStr = @"UPDATE Guest_Count 
                               SET DailyCount=@DailyCount 
                               WHERE Sno=@Sno; ";
                }
                else
                {
                    sqlStr = @"INSERT INTO Guest_Count (DailyCount, Time) 
                               VALUES (1, @Time); ";
                }

                sqlStr += @" UPDATE Guest_TotalCount 
                             SET TotalCount=@TotalCount
                             WHERE 1=1; ";

                command.CommandText = sqlStr;

                try
                {
                    if (recode != null)
                    {
                        SqlParameter[] p = {
                            new SqlParameter("@DailyCount", Convert.ToInt32(recode["DailyCount"].ToString()) + 1),
                            new SqlParameter("@Sno", recode["Sno"].ToString()),
                            new SqlParameter("@TotalCount", Convert.ToInt32(tocode["TotalCount"].ToString()) + 1)
                        };
                        command.Parameters.Clear();
                        command.Parameters.AddRange(p);
                    }
                    else
                    {
                        SqlParameter[] p = {
                            new SqlParameter("@Time", odate),
                            new SqlParameter("@TotalCount", Convert.ToInt32(tocode["TotalCount"].ToString()) + 1)
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
                    context.Session["views"] = "isSet";
                    connection.Close();
                }
            };
        }
    }

    public class viewcount
    {
        public int TotalCount { get; set; }
        public int DayCount { get; set; }
    }

    public string GetViewCount(HttpContext context)
    {
        DataRow recode = CheckAlreadyHasRecord();
        DataRow tocode = GetTotalCount();

        viewcount vc = new viewcount()
        {
            TotalCount = Convert.ToInt32(tocode["TotalCount"].ToString()),
            DayCount = Convert.ToInt32(recode["DailyCount"].ToString())
        };

        return JsonConvert.SerializeObject(vc);
    }

    public string GetAnnouncementList(HttpContext context)
    {
        DataTable dt = new DataTable();
        try
        {
            string sqlStr = string.Empty;
            DataSet ds = new DataSet();
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);
                sqlStr = @"
                    SELECT * FROM [Announcement] 
                ";

                command.CommandText = sqlStr;
                command.Parameters.Clear();

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                }
                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                dt = ds.Tables[0];
            };
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        string jData = JsonConvert.SerializeObject(dt);

        return jData;
    }

    public string AddNewAnnouncement(HttpContext context)
    {
        string state = "ERROR";

        string TYPE = context.Request["Type"] as string;
        string SUB = context.Request["Subject"] as string;
        string DESC = context.Request["Dec"] as string;
        string SDATE = context.Request["sdate"] as string;
        string EDATE = context.Request["edate"] as string;
        string ISFOREVER = context.Request["IsForEver"] as string;

        try
        {
            String sqlStr = "";
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);

                sqlStr = @"
                    INSERT INTO [Announcement] ([Type], [Subject], [Desc], [StartDate], [EndDate], [UpdateTime], [IsForEver])
                    VALUES(@Type, @Subject, @Desc, @StartDate, @EndDate, GETDATE(), @IsForEver)
                ";

                command.CommandText = sqlStr;

                SqlParameter[] p = {
                    new SqlParameter("@Type", TYPE),
                    new SqlParameter("@Subject", SUB),
                    new SqlParameter("@Desc", DESC),
                    new SqlParameter("@StartDate", SDATE),
                    new SqlParameter("@EndDate", EDATE),
                    new SqlParameter("@IsForEver", ISFOREVER)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                connection.Close();

                state = "OK";
            };
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        return state;
    }

    public string EditAnnouncement(HttpContext context)
    {
        string state = "ERROR";

        string SNO = context.Request["Sid"] as string;
        string TYPE = context.Request["Type"] as string;
        string SUB = context.Request["Subject"] as string;
        string DESC = context.Request["Dec"] as string;
        string SDATE = context.Request["sdate"] as string;
        string EDATE = context.Request["edate"] as string;
        string ISFOREVER = context.Request["IsForEver"] as string;

        try
        {
            String sqlStr = "";
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);

                sqlStr = @"
                    UPDATE [Announcement]
                    SET [Type]=@Type, [Subject]=@Subject, [Desc]=@Desc, [StartDate]=@StartDate, [EndDate]=@EndDate, [IsForEver]=@IsForEver, [UpdateTime]=GETDATE()
                    WHERE [SNO]=@SNO;
                ";

                command.CommandText = sqlStr;

                SqlParameter[] p = {
                    new SqlParameter("@SNO", SNO),
                    new SqlParameter("@Type", TYPE),
                    new SqlParameter("@Subject", SUB),
                    new SqlParameter("@Desc", DESC),
                    new SqlParameter("@StartDate", SDATE),
                    new SqlParameter("@EndDate", EDATE),
                    new SqlParameter("@IsForEver", ISFOREVER)
                };
                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                connection.Close();

                state = "OK";
            };
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        return state;
    }

    public string DeleteAnnouncement(HttpContext context)
    {
        string state = "ERROR";

        string SNO = context.Request["Sid"] as string;

        try
        {
            String sqlStr = "";
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);

                sqlStr = @"
                    DELETE FROM [Announcement]
                    WHERE [SNO]=@SNO;
                ";

                command.CommandText = sqlStr;

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

                connection.Close();

                state = "OK";
            };
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        return state;
    }

    public string GetCodeTable(HttpContext context)
    {
        DataTable dt = new DataTable();

        try
        {
            if (context.Session["logroles"] != null && context.Session["logroles"].ToString().IndexOf('3') > -1)
            {
                string CATS = context.Request["cats"] as string;

                String sqlStr = "";
                DataSet ds = new DataSet();
                using (SqlConnection connection = new SqlConnection(sqlConnstr))
                {
                    SqlCommand command = new SqlCommand("", connection);

                    sqlStr = @"
                        SELECT DISTINCT [CAT], [DES_ZH], [DES_EN] 
                        FROM [CODE] 
                    ";
                    if (CATS != "" && CATS != null)
                    {
                        sqlStr += @" WHERE [CAT]=@CAT AND [DES_ZH] <> 'NULL' ";

                        command.CommandText = sqlStr;

                        SqlParameter[] p = {
                            new SqlParameter("@CAT", CATS)
                        };
                        command.Parameters.Clear();
                        command.Parameters.AddRange(p);
                    }
                    else
                    {
                        sqlStr += @" WHERE ([CAT]='最高學歷' OR [CAT]='年齡' OR [CAT]='教育程度' OR [CAT]='非一般教育程度' OR [CAT]='從業身分' OR [CAT]='失業原因' OR [CAT]='非勞動原因' OR [CAT]='行業' OR [CAT]='職業') AND [DES_ZH] <> 'NULL' ";
                        command.CommandText = sqlStr;
                        command.Parameters.Clear();
                    }

                    if (connection.State == ConnectionState.Closed)
                    {
                        connection.Open();
                        command.ExecuteNonQuery();
                    }

                    SqlDataAdapter da = new SqlDataAdapter(command);

                    ds.Clear();
                    da.Fill(ds);

                    dt = ds.Tables[0];

                    connection.Close();
                };
            }
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        string jData = JsonConvert.SerializeObject(dt);

        return jData;
    }

    public string UpdateCode(HttpContext context)
    {
        string state = "ERROR";

        try
        {
            string N_CAT = context.Request["N_CAT"] as string;
            string N_DES_ZH = context.Request["N_DES_ZH"] as string;
            string N_DES_EN = context.Request["N_DES_EN"] as string;
            string O_CAT = context.Request["O_CAT"] as string;
            string O_DES_ZH = context.Request["O_DES_ZH"] as string;
            string O_DES_EN = context.Request["O_DES_EN"] as string;

            String sqlStr = "";

            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                SqlCommand command = new SqlCommand("", connection);

                sqlStr = @"
                    UPDATE [CODE]
                    SET [DES_ZH]=@DES_ZH, [DES_EN]=@DES_EN
                    WHERE [CAT]=@CAT AND [DES_ZH]=@ODES_ZH 
                ";

                command.CommandText = sqlStr;

                SqlParameter[] p = {
                    new SqlParameter("@DES_ZH", N_DES_ZH),
                    new SqlParameter("@DES_EN", N_DES_EN),
                    new SqlParameter("@CAT", O_CAT),
                    new SqlParameter("@ODES_ZH", O_DES_ZH)
                };

                command.Parameters.Clear();
                command.Parameters.AddRange(p);

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                connection.Close();

                state = "OK";

                uploadlog(context, "編碼更新", "更新分類(" + N_CAT + ") 的 中文內容(" + O_DES_ZH + ") 為 (" + N_DES_ZH + ") 英文內容 (" + O_DES_EN + ") 為 (" + N_DES_EN + ")");
            };
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        return state;
    }

    public class StatTableItem
    {
        public String Sno { get; set; }
        public String Name { get; set; }
        public String CreateDate { get; set; }
        public String StartDate { get; set; }
        public String EndDate { get; set; }
        public String State { get; set; }
        public String Order { get; set; }
    }

    public string GetStatTable(HttpContext context)
    {
        List<StatTableItem> data = new List<StatTableItem>();
        try
        {
            DateTime now = DateTime.Now;
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                DataSet ds = new DataSet();
                SqlCommand command = new SqlCommand("", connection);

                String sqlStr = @"
                    SELECT * 
                    FROM [Interactive]
                    ORDER BY [Order]
                ";

                command.CommandText = sqlStr;

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                DataTable dt = new DataTable();
                dt = ds.Tables[0];

                foreach (DataRow r in dt.Rows)
                {
                    StatTableItem tmp = new StatTableItem();

                    tmp.Sno = r["Sno"].ToString();
                    tmp.Name = r["Title"].ToString();
                    tmp.CreateDate = r["CreateDate"].ToString();
                    tmp.StartDate = r["OnlineDate"].ToString();
                    tmp.EndDate = r["OfflineDate"].ToString();
                    tmp.Order = r["Order"].ToString();

                    String state = "";
                    String forever = r["Forever"].ToString();
                    if (forever == "1")
                    {
                        state = "上架中";
                    }
                    else
                    {
                        DateTime stime = Convert.ToDateTime(tmp.StartDate);
                        DateTime etime = Convert.ToDateTime(tmp.EndDate);

                        if (stime > now)
                        {
                            state = "尚未上架";
                        }
                        else if (etime < now)
                        {
                            state = "已下架";
                        }
                        else
                        {
                            state = "上架中";
                        }

                        tmp.StartDate = stime.ToString("yyyy-MM-dd");
                        tmp.EndDate = etime.ToString("yyyy-MM-dd");
                    }
                    tmp.State = state;

                    data.Add(tmp);
                }

                connection.Close();
            };
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        string jData = JsonConvert.SerializeObject(data);

        return jData;
    }

    public class StatItem
    {
        public String Sno { get; set; }
        public String Name { get; set; }
        public String URLLink { get; set; }
        public String IsForEver { get; set; }
        public String StartDate { get; set; }
        public String EndDate { get; set; }
        public String FileName { get; set; }
    }

    public string GetTargetStatItem(HttpContext context)
    {
        StatItem data = new StatItem();

        try
        {
            string SNO = context.Request["SNO"] as string;

            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                DataSet ds = new DataSet();
                SqlCommand command = new SqlCommand("", connection);

                String sqlStr = @"
                    SELECT * 
                    FROM [Interactive]
                    WHERE [Sno]=@Sno;
                ";

                command.CommandText = sqlStr;

                List<SqlParameter> p = new List<SqlParameter>();
                p.Add(new SqlParameter("@Sno", SNO));

                command.Parameters.Clear();
                command.Parameters.AddRange(p.ToArray());

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                DataTable dt = new DataTable();
                dt = ds.Tables[0];

                if (dt.Rows.Count > 0)
                {
                    DataRow r = dt.Rows[0];

                    data.Sno = r["Sno"].ToString();
                    data.Name = r["Title"].ToString();
                    data.URLLink = r["LinkURL"].ToString();
                    data.IsForEver = r["Forever"].ToString();
                    data.FileName = r["FileName_Pic"].ToString();

                    if (data.IsForEver == "2")
                    {
                        DateTime stime = Convert.ToDateTime(r["OnlineDate"].ToString());
                        DateTime etime = Convert.ToDateTime(r["OfflineDate"].ToString());

                        data.StartDate = stime.ToString("yyyy-MM-dd");
                        data.EndDate = etime.ToString("yyyy-MM-dd");
                    }
                    else
                    {
                        data.StartDate = r["OnlineDate"].ToString();
                        data.EndDate = r["OfflineDate"].ToString();
                    }
                }

                connection.Close();
            };
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        string jData = JsonConvert.SerializeObject(data);

        return jData;
    }

    public string SetStatOrder(HttpContext context)
    {
        string state = "ERROR";

        try
        {
            string SNO = context.Request["SNO"] as string;
            string ORDER = context.Request["ORDER"] as string;
            string ISDOWN = context.Request["ISDOWN"] as string;

            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                DataSet ds = new DataSet();
                SqlCommand command = new SqlCommand("", connection);

                String sqlStr = String.Empty;

                if (ISDOWN == "0")
                {
                    sqlStr = @"
                        UPDATE [Interactive] 
                        SET [Order]=@Order1
                        WHERE [Order]=@Order1 - 1; 
                    ";
                }
                else if (ISDOWN == "1")
                {
                    sqlStr = @"
                        UPDATE [Interactive] 
                        SET [Order]=@Order1
                        WHERE [Order]=@Order1 + 1; 
                    ";
                }
                sqlStr += @"
                    UPDATE [Interactive] 
                    SET [Order]=@Order2
                    WHERE Sno=@Sno;
                ";

                command.CommandText = sqlStr;

                int order = Convert.ToInt16(ORDER);
                if (ISDOWN == "0")
                    order = order - 1;
                else if (ISDOWN == "1")
                    order = order + 1;

                List<SqlParameter> p = new List<SqlParameter>();
                p.Add(new SqlParameter("@Sno", SNO));
                p.Add(new SqlParameter("@Order1", ORDER));
                p.Add(new SqlParameter("@Order2", order));

                command.Parameters.Clear();
                command.Parameters.AddRange(p.ToArray());

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                connection.Close();
            };

            state = "OK";
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        string jData = JsonConvert.SerializeObject(state);

        return jData;
    }

    public string DeleteStatItem(HttpContext context)
    {
        string state = "ERROR";

        try
        {
            string SNO = context.Request["SNO"] as string;
            string T_NAME = context.Request["T_NAME"] as string;
            string ORDER = context.Request["ORDER"] as string;

            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                DataSet ds = new DataSet();
                SqlCommand command = new SqlCommand("", connection);

                String sqlStr = String.Empty;

                sqlStr += @"
                    DELETE FROM [Interactive] 
                    WHERE Sno=@Sno;
                    UPDATE [Interactive] 
                    SET [Order]=([Order] - 1)
                    WHERE [Order]>@Order;
                ";

                command.CommandText = sqlStr;

                List<SqlParameter> p = new List<SqlParameter>();
                p.Add(new SqlParameter("@Sno", SNO));
                p.Add(new SqlParameter("@Order", ORDER));

                command.Parameters.Clear();
                command.Parameters.AddRange(p.ToArray());

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                connection.Close();
            };

            uploadlog(context, "統計互動管理", "刪除(" + T_NAME + ")");
            state = "OK";
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        string jData = JsonConvert.SerializeObject(state);

        return jData;
    }

    public class StatFrontItem
    {
        public String Sno { get; set; }
        public String Name { get; set; }
        public String Order { get; set; }
        public String URLLink { get; set; }
        public String FileName { get; set; }
    }

    public string GetStatFront(HttpContext context)
    {
        List<StatFrontItem> data = new List<StatFrontItem>();

        try
        {
            DateTime ntime = DateTime.Now;
            using (SqlConnection connection = new SqlConnection(sqlConnstr))
            {
                DataSet ds = new DataSet();
                SqlCommand command = new SqlCommand("", connection);

                String sqlStr = @"
                    SELECT * 
                    FROM [Interactive]
                    WHERE ([Forever] = '1') OR ([Forever] = '2' AND ([OnlineDate]<@NOWTIME AND [OfflineDate] > @NOWTIME))
                    ORDER BY [Order];
                ";

                command.CommandText = sqlStr;

                List<SqlParameter> p = new List<SqlParameter>();
                p.Add(new SqlParameter("@NOWTIME", ntime));

                command.Parameters.Clear();
                command.Parameters.AddRange(p.ToArray());

                if (connection.State == ConnectionState.Closed)
                {
                    connection.Open();
                    command.ExecuteNonQuery();
                }

                SqlDataAdapter da = new SqlDataAdapter(command);

                ds.Clear();
                da.Fill(ds);

                DataTable dt = new DataTable();
                dt = ds.Tables[0];

                foreach (DataRow r in dt.Rows)
                {
                    StatFrontItem tmp = new StatFrontItem();

                    tmp.Sno = r["Sno"].ToString();
                    tmp.Name = r["Title"].ToString();
                    tmp.Order = r["Order"].ToString();
                    tmp.URLLink = r["LinkURL"].ToString();
                    tmp.FileName = r["Inter_Pic"].ToString();

                    data.Add(tmp);
                }

                connection.Close();
            };
        }
        catch (Exception ex)
        {
            ex.StackTrace.ToString();
        }

        string jData = JsonConvert.SerializeObject(data);

        return jData;
    }

    public bool IsReusable {
        get {
            return false;
        }
    }
}