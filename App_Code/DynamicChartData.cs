using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Web;
using System.Web.Caching;
using Newtonsoft.Json;

public static class DynamicChartData
{
    private const string Industry = @"
        SELECT YEAR, NAME, VALUE
        FROM dbo.DYNAMIC_INDTOP10 ORDER BY YEAR, VALUE DESC, SNO";

    private const string Unemployment = @"
        SELECT YEAR, MONTH, NAME, VALUE
        FROM dbo.DYNAMIC_UNEMPLOYED ORDER BY YEAR, MONTH, NAME";

    private const string NotInLabor = @"
        SELECT YEAR, NAME, VALUE
        FROM dbo.DYNAMIC_UNLABORED ORDER BY YEAR, NAME";

    private const string County = @"
        SELECT YEAR, COUNTY_VERSION, COUNTY_CODE, VALUE
        FROM dbo.DYNAMIC_COUNTY ORDER BY YEAR, VALUE DESC, COUNTY_CODE";

    private const string BoundaryQuery = @"
        DECLARE @viewport geometry = geometry::STGeomFromText(
            'POLYGON ((118.9 21.7, 122.2 21.7, 122.2 25.6, 118.9 25.6, 118.9 21.7))', 4326);
        WITH boundary AS (
            SELECT CODE, RTRIM(OLD_NAME) AS NAME, geom FROM dbo.countyold_84 WHERE @version = 1
            UNION ALL
            SELECT CODE, COUNTYNAME, geom FROM dbo.countynew_84 WHERE @version = 2
        )
        SELECT LTRIM(RTRIM(CODE)) AS CODE, NAME,
               geom.STIntersection(@viewport).Reduce(0.001).STAsBinary() AS WKB
        FROM boundary
        WHERE NULLIF(LTRIM(RTRIM(CODE)), '') IS NOT NULL
        ORDER BY CODE";

    public static void WriteResponse(HttpContext context)
    {
        HttpResponse response = context.Response;
        response.ContentType = "application/json";
        response.ContentEncoding = System.Text.Encoding.UTF8;
        response.TrySkipIisCustomErrors = true;

        if (context.Request.HttpMethod != "GET")
        {
            response.AppendHeader("Allow", "GET");
            WriteError(response, 405, "僅支援 GET。");
            return;
        }

        string chart = context.Request.QueryString["chart"];
        try
        {
            if (chart == "boundaries")
            {
                int version;
                if (!int.TryParse(context.Request.QueryString["version"], out version) || (version != 1 && version != 2))
                {
                    WriteError(response, 400, "縣市邊界版次必須為 1 或 2。");
                    return;
                }

                string geoJson = GetBoundaries(version);
                response.Cache.SetCacheability(HttpCacheability.Public);
                response.Cache.SetMaxAge(TimeSpan.FromHours(6));
                response.Write(geoJson);
                return;
            }

            string query;
            switch (chart)
            {
                case "industry": query = Industry; break;
                case "unemployment": query = Unemployment; break;
                case "notinlabor": query = NotInLabor; break;
                case "county": query = County; break;
                default:
                    WriteError(response, 400, "圖表識別碼無效。");
                    return;
            }

            response.Cache.SetNoStore();
            response.Write(JsonConvert.SerializeObject(new { rows = GetRows(chart, query) }));
        }
        catch (Exception error)
        {
            Trace.TraceError("DynamicCharts {0}: {1}", chart, error);
            WriteError(response, 500, "暫時無法取得圖表資料。");
        }
    }

    private static SqlConnection OpenConnection()
    {
        var connection = new SqlConnection(ConfigurationManager.ConnectionStrings["CensusGISADONet"].ConnectionString);
        try
        {
            connection.Open();
            return connection;
        }
        catch
        {
            connection.Dispose();
            throw;
        }
    }

    private static List<object> GetRows(string chart, string query)
    {
        var rows = new List<object>();
        using (SqlConnection connection = OpenConnection())
        using (var command = new SqlCommand(query, connection))
        using (SqlDataReader reader = command.ExecuteReader())
        {
            int lastYear = -1;
            int rank = 0;
            while (reader.Read())
            {
                int year = reader.GetInt32(0);
                switch (chart)
                {
                    case "county":
                        rows.Add(new { year, version = reader.GetInt32(1), code = reader.GetString(2), value = reader.GetDecimal(3) });
                        break;
                    case "unemployment":
                        rows.Add(new { year, month = reader.GetInt32(1), name = reader.GetString(2), value = reader.GetInt32(3) });
                        break;
                    case "industry":
                        if (lastYear != year)
                        {
                            lastYear = year;
                            rank = 0;
                        }
                        rows.Add(new { year, name = reader.GetString(1), value = reader.GetInt32(2), rank = ++rank });
                        break;
                    default:
                        rows.Add(new { year, name = reader.GetString(1), value = reader.GetInt32(2) });
                        break;
                }
            }
        }
        return rows;
    }

    private static string GetBoundaries(int version)
    {
        string cacheKey = "DynamicCharts:Boundaries:" + version;
        string cached = HttpRuntime.Cache[cacheKey] as string;
        if (cached != null)
            return cached;

        var features = new List<object>();
        using (SqlConnection connection = OpenConnection())
        using (var command = new SqlCommand(BoundaryQuery, connection))
        {
            command.Parameters.Add("@version", System.Data.SqlDbType.Int).Value = version;
            using (SqlDataReader reader = command.ExecuteReader())
            {
                while (reader.Read())
                {
                    var polygons = new List<List<List<double[]>>>();
                    using (var bytes = new BinaryReader(new MemoryStream((byte[])reader[2], false)))
                    {
                        ReadGeometry(bytes, polygons);
                    }
                    if (polygons.Count == 0)
                        throw new InvalidDataException("County boundary has no display polygon: " + reader.GetString(0));

                    features.Add(new
                    {
                        type = "Feature",
                        properties = new { code = reader.GetString(0), name = reader.GetString(1) },
                        geometry = new { type = "MultiPolygon", coordinates = polygons }
                    });
                }
            }
        }
        if (features.Count == 0)
            throw new InvalidDataException("No county features for boundary version " + version);

        string json = JsonConvert.SerializeObject(new { type = "FeatureCollection", features });
        HttpRuntime.Cache.Insert(cacheKey, json, null, DateTime.UtcNow.AddHours(6), Cache.NoSlidingExpiration);
        return json;
    }

    // STAsBinary returns little-endian OGC WKB. Simplification can leave line or point
    // members in a collection, which do not contribute to the county's filled geometry.
    private static void ReadGeometry(BinaryReader reader, List<List<List<double[]>>> polygons)
    {
        if (reader.ReadByte() != 1)
            throw new InvalidDataException("Unexpected WKB byte order.");

        switch (reader.ReadUInt32())
        {
            case 1:
                reader.BaseStream.Seek(16, SeekOrigin.Current);
                return;
            case 2:
                reader.BaseStream.Seek(reader.ReadUInt32() * 16L, SeekOrigin.Current);
                return;
            case 3:
                var polygon = new List<List<double[]>>();
                uint ringCount = reader.ReadUInt32();
                for (uint i = 0; i < ringCount; i++)
                {
                    var ring = new List<double[]>();
                    uint pointCount = reader.ReadUInt32();
                    for (uint p = 0; p < pointCount; p++)
                        ring.Add(new[] { reader.ReadDouble(), reader.ReadDouble() });

                    // GeoJSON exterior rings are counterclockwise. Holes go clockwise.
                    double area = 0;
                    for (int p = 1; p < ring.Count; p++)
                        area += ring[p - 1][0] * ring[p][1] - ring[p][0] * ring[p - 1][1];
                    if ((i == 0 && area < 0) || (i > 0 && area > 0))
                        ring.Reverse();

                    polygon.Add(ring);
                }
                polygons.Add(polygon);
                return;
            case 4:
            case 5:
            case 6:
            case 7:
                uint count = reader.ReadUInt32();
                for (uint i = 0; i < count; i++)
                    ReadGeometry(reader, polygons);
                return;
            default:
                throw new InvalidDataException("Unexpected WKB geometry type.");
        }
    }

    private static void WriteError(HttpResponse response, int status, string message)
    {
        response.StatusCode = status;
        response.Cache.SetNoStore();
        response.Write(JsonConvert.SerializeObject(new { error = message }));
    }
}


