using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;

namespace Supergeo.ComputeMod
{
    public class ComputeMod
    {
        // 平均計算-人
        public decimal ComputeAvgPepole(int month, decimal a, int pepole) // 平均月份/值/要除以的人數
        {
            if (a == 0 || a == -999999 || month == 0) return -999999;
            return Math.Round(Math.Round(a / month, 0, MidpointRounding.AwayFromZero) / pepole, 0, MidpointRounding.AwayFromZero);
        }
        // 平均計算-%/結構比/率
        public decimal ComputeAvgPercent(decimal a, decimal b, int decidx) // 值a/值b
        {
            if (a == 0 || b == 0 || a == -999999 || b == -999999) return -999999;

            if (decidx == -1)
                return (a / b) * 100;
            else
                return Math.Round((a / b) * 100, decidx, MidpointRounding.AwayFromZero);
        }
        public decimal ComputeWeekPercent(decimal a, decimal b, int decidx) // 值a/值b/小數點底下第幾位
        {
            if (a == 0 || b == 0 || a == -999999 || b == -999999) return -999999;

            if (decidx == -1)
                return (a / b);
            else
                return Math.Round((a / b), decidx, MidpointRounding.AwayFromZero);
        }
        // 增減率-%
        public decimal ComputeRate(decimal a, decimal b, int decidx) // 值a/值b/小數點底下第幾位
        {
            if (a == 0 || b == 0 || a == -999999 || b == -999999) return -999999;

            if (decidx == -1)
                return ((a / b) - 1) * 100;
            else
                return Math.Round(((a / b) - 1) * 100, decidx, MidpointRounding.AwayFromZero);
        }
        // 較上期增減值
        public decimal ComputeChangeValue(decimal a, decimal b) // 值a/值b(上期值)
        {
            // if (a == 0 || b == 0) return -999999;
            return a - b;
        }
        // 較上期/較上年 增減百分比-%
        public decimal ComputeChangePercent(decimal a, decimal b, decimal c, decimal d, int decidx)
        {
            if (a == 0 || b == 0 || c == 0 || d == 0) return -999999;
            if (a == -999999 || b == -999999 || c == -999999 || d == -999999) return -999999;

            return ComputeAvgPercent(a, b, decidx) - ComputeAvgPercent(c, d, decidx);
        }
        // 較上期/較上年 月平均-人
        public decimal ComputeChangeAvgPepole(decimal a, decimal b, int months, int pepole)
        {
            if (a == 0 || b == 0 || months == 0) return -999999;
            if (a == -999999 || b == -999999) return -999999;

            return ComputeAvgPepole(months, a, pepole) - ComputeAvgPepole(months, b, pepole);
        }
        // 內網用來算最後的判斷
        public decimal ComputePepole(decimal a, int b, int dec) // 人數 平均 小數點
        {
            if (a == 0 || b == 0) return -999999;
            if (a == -999999 || b == -999999) return -999999;

            if (dec == -1)
                return a / b;
            else
                return Math.Round(a / b, dec, MidpointRounding.AwayFromZero);
        }
    }
}
