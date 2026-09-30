using System;

namespace Supergeo.StatUtils
{
    public class LayoutItem
    {
        private LayoutItemEnum _Tag = LayoutItemEnum.NotSet;
        private Int32 _Index = -1;
        private Int32 _Start = -1;
        private Int32 _Length = 0;
        private Int32 _Value = -1;

        public LayoutItem()
        {
        }

        public LayoutItemEnum Tag
        {
            get { return _Tag; }
        }

        public Int32 Index
        {
            get { return _Index; }
        }

        public Int32 Start
        {
            get { return _Start; }
        }

        public Int32 Length
        {
            get { return _Length; }
        }

        public Int32 Value
        {
            get { return _Value; }
        }

        public LayoutItem(LayoutItemEnum tag, Int32 nIndex, Int32 nStart, Int32 nLength)
            :this()
        {
            _Tag = tag;
            _Index = nIndex;
            _Start = nStart;
            _Length = nLength;
            _Value = -1;
        }

        public LayoutItem(LayoutItemEnum tag, Int32 nIndex, Int32 nStart, Int32 nLength, Int32 nValue)
            : this()
        {
            _Tag = tag;
            _Index = nIndex;
            _Start = nStart;
            _Length = nLength;
            _Value = nValue;
        }
    }
}
