using System;

namespace Supergeo.StatUtils
{
    public class ProgressItem
    {
        public ProgressItem()
        {
        }

        public ProgressItem(String strID, Int32 nCurrent, Int32 nLines, Int32 nRecord)
        {
            UniqueID = strID;
            Current = nCurrent;
            Lines = nLines;
            Record = nRecord;
        }
        public String UniqueID { get; set; }
        public Int32 Current { get; set; }
        public Int32 Lines { get; set; }
        public Int32 Record { get; set; }
    }
}
