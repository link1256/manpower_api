using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Supergeo.StatUtils
{
    public class Metadata
    {
        private Dictionary<String, Dictionary<String, CardItem>> _Metadata = null;

        public Metadata()
        {
        }

        public String GetStatID(String strCard, String strCol)
        {
            String strRc = "";
            if (_Metadata != null && _Metadata.ContainsKey(strCard))
            {
                Dictionary<String, CardItem> card = _Metadata[strCard];
                if (card.ContainsKey(strCol))
                {
                    strRc = card[strCol].StatID;
                }
            }
            return strRc;
        }

        public void Add(Dictionary<String, String> tags)
        {
            if (_Metadata == null)
            {
                _Metadata = new Dictionary<String, Dictionary<String, StatUtils.CardItem>>();
            }
            Dictionary<String, CardItem> cards = null;
            if (_Metadata.ContainsKey(tags["CardNum"]))
            {
                cards = _Metadata[tags["CardNum"]];
            }
            else
            {
                cards = new Dictionary<String, CardItem>();
                _Metadata.Add(tags["CardNum"], cards);
            }

            if (!cards.ContainsKey(tags["ColNum"]))
            {
                CardItem item = new CardItem();
                if (item != null)
                {
                    item.StatID = tags["StatID"];
                    item.SourceTable = tags["SourceTB"];
                    item.DescriptionFull = tags["DescFull"];
                    cards.Add(tags["ColNum"], item);
                }
            }
        }
    }
}
