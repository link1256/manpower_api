using System;
using System.Runtime.InteropServices;

namespace Supergeo.Tools
{
    public class HiResTimer
    {
        private bool isPerfCounterSupported = false;
        private Int64 frequency = 0;

        [DllImport("kernel32.dll")]
        extern static short QueryPerformanceCounter(ref long count);
        [DllImport("kernel32.dll")]
        extern static short QueryPerformanceFrequency(ref long frequency);

        public HiResTimer()
        {
            // Query the high-resolution timer only if it is supported.
            // A returned frequency of 1000 typically indicates that it is not
            // supported and is emulated by the OS using the same value that is
            // returned by Environment.TickCount.
            // A return value of 0 indicates that the performance counter is
            // not supported.
            int returnVal = QueryPerformanceFrequency(ref frequency);

            if (returnVal != 0 && frequency != 1000)
            {
                // The performance counter is supported.
                isPerfCounterSupported = true;
            }
            else
            {
                // The performance counter is not supported. Use
                // Environment.TickCount instead.
                frequency = 1000;
            }
        }

        public Int64 Frequency
        {
            get
            {
                return frequency;
            }
        }

        public Int64 Value
        {
            get
            {
                Int64 tickCount = 0;

                if (isPerfCounterSupported)
                {
                    // Get the value here if the counter is supported.
                    QueryPerformanceCounter(ref tickCount);
                    return tickCount;
                }
                else
                {
                    // Otherwise, use Environment.TickCount.
                    return (Int64)Environment.TickCount;
                }
            }
        }

        public Double End(Int64 nStart)
        {
            Double dV = Double.NaN;
            if (!Double.IsNaN(nStart))
            {
                Int64 nEnd = this.Value;
                Double timeElapseInTenthsOfMilliseconds = ((Double)(nEnd - nStart)) * 10000 / this.Frequency;
                dV = (timeElapseInTenthsOfMilliseconds / 10000.0);
            }
            return dV;
        }
    }
}
