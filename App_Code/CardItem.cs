using System;

namespace Supergeo.StatUtils
{
    public class CardItem
    {
        private String _StatID = null;
        private String _SourceTable = null;
        private String _DescriptionFull = null;

        public CardItem()
        {
        }

        public CardItem(String strStatID)
            :this()
        {
            _StatID = strStatID;
        }

        public String StatID
        {
            set { _StatID = value; }
            get { return _StatID; }
        }

        public String SourceTable
        {
            set { _SourceTable = value; }
            get { return _SourceTable; }
        }

        public String DescriptionFull
        {
            set { _DescriptionFull = value; }
            get { return _DescriptionFull; }
        }
    }
}
