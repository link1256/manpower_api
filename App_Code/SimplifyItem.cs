using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

public class SimplifyItem
{
	public Int32 d { get; set; } //年月
	public Int32 c { get; set; } //分類
	public Int32 sx { get; set; } //性別
	public Int32 st { get; set; } //統計項
	public Int32 ct { get; set; } //縣市區域
	public decimal v { get; set; } //值
	public string level { get; set; } //階層
	public Int32 d_e { get; set; } //年月-英文
	public Int32 c_e { get; set; } //分類-英文
	public Int32 sx_e { get; set; } //性別-英文
	public Int32 st_e { get; set; } //統計項-英文
	public Int32 ct_e { get; set; } //縣市區域

	public SimplifyItem()
	{
		ct = -1;
		level = "";
		ct_e = -1;
	}

	public static Int32 GetKeyMappingIndex(Dictionary<String, List<String>> dicMapping, String key, Dictionary<String, String> keyMap, String keyOrigin, String text)
	{
		Int32 nRc = -1;
		if (dicMapping != null)
		{
			if (keyMap != null)
			{
				if (!keyMap.ContainsKey(keyOrigin))
				{
					keyMap.Add(keyOrigin, key);
				}
			}
			List<String> data = null;
			if (dicMapping.ContainsKey(key))
			{
				data = dicMapping[key];
			}
			else
			{
				data = new List<String>();
				dicMapping.Add(key, data);
			}
			Int32 nIdx = data.IndexOf(text);
			if (nIdx >= 0)
			{
				nRc = nIdx;
			}
			else
			{
				nRc = data.Count;
				data.Add(text);
			}
		}
		return nRc;
	}

}
