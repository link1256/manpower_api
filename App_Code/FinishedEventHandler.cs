using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Supergeo.StatUtils
{
    public class FinishItem
    {
        public FinishItem()
        {
        }

        public FinishItem(String strID, Int32 Break, String strMetaSource, Int32 nLines, Int32 nRecord,
            Int32 nStartYear, Int32 nStartMonth, Int32 nEndYear, Int32 nEndMonth)
        {
            UniqueID = strID;
            UserBreak = Break;
            MetadataSource = strMetaSource;
            Lines = nLines;
            Record = nRecord;
            StartYear = nStartYear;
            StartMonth = nStartMonth;
            EndYear = nEndYear;
            EndMonth = nEndMonth;
        }
        public String UniqueID { get; set; }
        public Int32 UserBreak { get; set; }
        public Int32 Lines { get; set; }
        public Int32 Record { get; set; }
        public String MetadataSource { get; set; }
        public Int32 StartYear { get; set; }
        public Int32 StartMonth { get; set; }
        public Int32 EndYear { get; set; }
        public Int32 EndMonth { get; set; }
    }
}
