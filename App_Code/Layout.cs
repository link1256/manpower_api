using System;
using System.Collections.Generic;

namespace Supergeo.StatUtils
{
    public class Layout
    {
        LayoutTypeEnum _LayoutType = LayoutTypeEnum.NotSet;
        List<LayoutItem> _Stats = null;
        LayoutItem _Card = null;
        List<LayoutItem> _Items = null;
        public Layout()
        {
            _Stats = new List<LayoutItem>();
            _Items = new List<LayoutItem>();
        }

        ~Layout()
        {
            Clear();
        }

        private void Clear()
        {
            if (_Stats != null)
            {
                _Stats.Clear();
                _Stats = null;
            }
            if (_Items != null)
            {
                _Items.Clear();
                _Items = null;
            }
        }

        public LayoutTypeEnum LayoutType
        {
            get { return _LayoutType; }
        }

        public List<LayoutItem> GetStats()
        {
            return _Stats;
        }

        public List<LayoutItem> GetItems()
        {
            return _Items;
        }

        public LayoutItem GetCard()
        {
            return _Card;
        }

        private Int32 SetCard(LayoutItemEnum tag, Int32 nIndex, Int32 nStart, Int32 nLength, Int32 nCardNum)
        {
            _Card = new LayoutItem(tag, nIndex, nStart, nLength, nCardNum);
            return _Card.Value;
        }


        private Int32 AddStat(LayoutItemEnum tag, Int32 nIndex, Int32 nStart, Int32 nLength)
        {
            Int32 nRc = -1;
            if (_Stats != null)
            {
                LayoutItem item = new LayoutItem(tag, nIndex, nStart, nLength);
                if (item != null)
                {
                    _Stats.Add(item);
                    nRc = _Stats.Count - 1;
                }
            }
            return nRc;
        }

        private Int32 AddItem(LayoutItemEnum tag, Int32 nIndex, Int32 nStart, Int32 nLength, Int32 nCardNum)
        {
            Int32 nRc = -1;
            if (_Items != null)
            {
                LayoutItem item = new LayoutItem(tag, nIndex, nStart, nLength, nCardNum);
                if (item != null)
                {
                    _Items.Add(item);
                    nRc = _Items.Count - 1;
                }
            }
            return nRc;
        }

        public Boolean Load(String[] saRows, LayoutTypeEnum layoutType)
        {
            Boolean bRc = false;

            if (layoutType == LayoutTypeEnum.Layout)
            {
                String strRow = null;
                Boolean bItemStart = false;
                Int32 nPrevPos = 0;
                for (Int32 i = 0; i < saRows.Length; i++)
                {
                    try
                    {
                        strRow = saRows[i].Trim();
                    }
                    catch (Exception ex)
                    {
                    }
                    if (strRow != null && strRow.Length > 0)
                    {
                        if (!strRow.StartsWith(";"))
                        {
                            String[] header = strRow.Split(new Char[] { ',' });
                            if (header.Length == 2)
                            {
                                String strPos = header[0].Trim();
                                String strCol = header[1].Trim();
                                Boolean bW;
                                Int32 nPos = Utils.ToNumber(strPos, out bW);
                                if (!bItemStart)
                                {
                                    if (Utils.IsNumber(strCol))
                                    {
                                        bItemStart = true;
                                        bRc = true;
                                    }
                                    else
                                    {
                                        if (String.Compare("Year", strCol, true) == 0)
                                        {
                                            AddStat(LayoutItemEnum.Year, -1, nPrevPos, nPos - nPrevPos - 1);
                                            nPrevPos = nPos - 1;
                                        }
                                        else if (String.Compare("Month", strCol, true) == 0)
                                        {
                                            AddStat(LayoutItemEnum.Month, -1, nPrevPos, nPos - nPrevPos - 1);
                                            nPrevPos = nPos - 1;
                                        }
                                        else if (String.Compare("County", strCol, true) == 0)
                                        {
                                            AddStat(LayoutItemEnum.County, -1, nPrevPos, nPos - nPrevPos - 1);
                                            nPrevPos = nPos - 1;
                                        }
                                        else if (String.Compare("CardNum", strCol, true) == 0)
                                        {
                                            Int32 nCard = Utils.ToNumber(strCol, out bW);
                                            SetCard(LayoutItemEnum.CardNum, -1, nPrevPos, nPos - nPrevPos - 1, nCard);
                                            nPrevPos = nPos - 1;
                                        }
                                    }
                                }
                                if (bItemStart)
                                {
                                    Int32 nCol = Utils.ToNumber(strCol, out bW);
                                    AddItem(LayoutItemEnum.Item, -1, nPrevPos, nPos - nPrevPos - 1, nCol);
                                    nPrevPos = nPos - 1;
                                }
                            }
                        }
                    }
                }
            }
            else if (layoutType == LayoutTypeEnum.Header)
            {
                Boolean bItemStart = false;
                for (Int32 i = 0; i < saRows.Length; i++)
                {
                    String strRow = saRows[i].Trim();
                    if (strRow != null && strRow.Length > 0)
                    {
                        String strCol = strRow;
                        Boolean bW;
                        if (!bItemStart)
                        {
                            if (Utils.IsNumber(strCol))
                            {
                                bItemStart = true;
                                bRc = true;
                            }
                            else
                            {
                                if (String.Compare("Year", strCol, true) == 0)
                                {
                                    AddStat(LayoutItemEnum.Year, i, -1, 0);
                                }
                                else if (String.Compare("Month", strCol, true) == 0)
                                {
                                    AddStat(LayoutItemEnum.Month, i, -1, 0);
                                }
                                else if (String.Compare("County", strCol, true) == 0)
                                {
                                    AddStat(LayoutItemEnum.County, i, -1, 0);
                                }
                                else if (String.Compare("CardNum", strCol, true) == 0)
                                {
                                    Int32 nCard = Utils.ToNumber(strCol, out bW);
                                    SetCard(LayoutItemEnum.CardNum, i, -1, 0, nCard);
                                }
                            }
                        }
                        if (bItemStart)
                        {
                            Int32 nCol = Utils.ToNumber(strCol, out bW);
                            AddItem(LayoutItemEnum.Item, i, -1, 0, nCol);
                        }
                    }
                }
            }
            if (bRc)
                _LayoutType = layoutType;
            return bRc;
        }
    }
}
