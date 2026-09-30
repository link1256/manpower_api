using System;
using System.Collections.Generic;

namespace Supergeo.StatUtils
{
    public class StatData
    {
        private String _Table = null;
        private String _Year = null;
        private String _Month = null;
        private String _County = null;
        private String _StatID = null;
        public StatData()
        {
        }

        public StatData(String strTable)
            :this()
        {
            _Table = strTable;
        }

        public String Table
        {
            set { _Table = value; }
            get { return _Table; }
        }

        public String Year
        {
            set { _Year = value; }
            get { return _Year; }
        }

        public String Month
        {
            set { _Month = value; }
            get { return _Month; }
        }

        public String County
        {
            set { _County = value; }
            get { return _County; }
        }

        public String StatID
        {
            set { _StatID = value; }
        }

        public Dictionary<String, Object> GetInsertSQL(Int32 nVal)
        {
            Dictionary<String, Object> param = new Dictionary<string, Object>();
            if (_Year != null)
            {
                param.Add("YEAR", _Year);
            }
            if (_Month != null)
            {
                param.Add("MONTH", _Month);
            }
            if (_County != null)
            {
                param.Add("COUNTY", _County);
            }
            if (_StatID != null)
            {
                param.Add("STATID", _StatID);
            }
            param.Add("STAT_VAL", nVal.ToString());
            return param;
        }
    }
}
