using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data;
using System.Data.SqlClient;

namespace Supergeo.Utilities
{
    public class SqlHelper
    {
        private const Int32 _ConnectionTimeout = 300;

        public static DataSet GetDataSet(SqlConnection conn, String sqlString, String tableName)
        {
            DataSet dsResult = null;

            if (conn != null)
            {
                if (conn.State != ConnectionState.Open)
                {
                    conn.Open();
                }

                using (SqlCommand cmd = conn.CreateCommand())
                {
                    cmd.CommandTimeout = _ConnectionTimeout;
                    cmd.CommandType = CommandType.Text;
                    cmd.CommandText = sqlString;

                    try
                    {
                        if (conn.State != ConnectionState.Open)
                        {
                            conn.Open();
                        }
                        using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
                        {
                            dsResult = new DataSet(tableName);
                            if (dsResult != null)
                            {
                                if (adapter.Fill(dsResult) > 0)
                                {
                                }
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                    }
                }
            }
            return dsResult;
        }
        
        public static DataSet GetDataSet(String connectionString, String sqlString, String tableName)
        {
            DataSet dsResult = null;

            using (SqlConnection conn = new SqlConnection(connectionString))
            {
                dsResult = GetDataSet(conn, sqlString, tableName);
                conn.Close();
                conn.Dispose();
            }

            return dsResult;
        }
    }
}