using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Supergeo.Utilities
{
    public class StatCondition
    {
        private StatClassItem _StatClass = StatClassItem.Notset;
        private String _CssFilename = null;
        private Int32 _StartYear = -1;
        private Int32 _EndYear = -1;
        private String _TableText = "";
        private String _TitleText = "";
        private String _NextStatText = "";  // 千人("") or 百分比 ("續")
        private String _ItemText = "";
        private String _UnitText = "";
        private Int32 _Decimals = 0;
        private Int32 _GroupRepeat = 0;
        private String _NextPartNode = null;

        public StatCondition()
        {
            Init();
        }

        private void Init()
        {
            _StatClass = StatClassItem.Notset;
            _CssFilename = null;
            _StartYear = -1;
            _EndYear = -1;
            _TableText = "";
            _TitleText = "";
            _NextStatText = "";
            _ItemText = "";
            _UnitText = "";
            _Decimals = 0;
            _GroupRepeat = 0;
            _NextPartNode = null;
        }

        /// <summary>
        /// 統計項計算周期
        /// 會同時設定 GroupRepeat (年平均 10, 月 12, 年平均與月 13)
        /// </summary>
        public StatClassItem StatClass
        {
            get { return _StatClass; }
            set
            {
                _StatClass = value;
                if (_StatClass == StatClassItem.YearAverage)
                {
                    _ItemText = "年平均";
                    _GroupRepeat = 10;
                }
                else if (_StatClass == StatClassItem.Month)
                {
                    _ItemText = "按月";
                    _GroupRepeat = 12;
                }
                else if (_StatClass == StatClassItem.YearAverageAndMonth)
                {
                    _ItemText = "按年平均與月分";
                    _GroupRepeat = 13;
                }
            }
        }

        public String CssFilename
        {
            get { return _CssFilename; }
            set { _CssFilename = value; }
        }


        public Int32 StartYear
        {
            get { return _StartYear; }
            set { _StartYear = value; }
        }

        public Int32 EndYear
        {
            get { return _EndYear; }
            set { _EndYear = value; }
        }

        /// <summary>
        /// $$TABLE$$ 的替換文字
        /// "表n"
        /// </summary>
        public String TableText
        {
            get { return _TableText; }
            set { _TableText = value; }
        }

        /// <summary>
        /// $$TITLE$$ 的替換文字 (表的描述文字)
        /// </summary>
        public String TitleText
        {
            get { return _TitleText; }
            set { _TitleText = value; }
        }
        /// <summary>
        /// $$NEXT_STAT$$ 的替換文字
        /// "" 或是 "續"...
        /// </summary>
        public String NextStatText
        {
            get { return _NextStatText; }
            set { _NextStatText = value; }
        }

        /// <summary>
        /// $$STAT_ITEM$$ 的替換文字
        /// </summary>
        public String ItemText
        {
            get { return _ItemText; }
            set { _ItemText = value; }
        }

        /// <summary>
        /// 單位 $$STAT_UNIT$$ 的替換文字, 
        /// "千人" 或是 "%"...
        /// </summary>
        public String UnitText
        {
            get { return _UnitText; }
            set { _UnitText = value; }
        }

        /// <summary>
        /// 數值顯示的小數點位數
        /// </summary>
        public Int32 Decimals
        {
            get { return _Decimals; }
            set { _Decimals = value; }
        }

        /// <summary>
        /// 顯示多少筆資料之後, 重覆加入標頭區塊
        /// 年平均 10, 月 12, 年平均與月 13
        /// </summary>
        public Int32 GroupRepeat
        {
            get { return _GroupRepeat; }
            set { _GroupRepeat = value; }
        }

        public String NextPartNode
        {
            get { return _NextPartNode; }
            set { _NextPartNode = value; }
        }


    }
}
