using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Timers;

namespace Supergeo.Utilities
{
    public static class Log
    {
        private static Object locker = new Object();
        private static Boolean _WriteDateTime = true;
        private static Boolean _UserInteractive = false;
        private static Dictionary<String, StringBuilder> _LogBuilders = null;
        private static Double _LogCacheSize = 1000;
        private static Double _LogAutoSaveTime = 10;
        private static String _Filter = null;
        private static String _Path = null;

        private static System.Timers.Timer _TimerAutoSave = new System.Timers.Timer();

        static Log()
        {
            AppDomain.CurrentDomain.ProcessExit += Log_Finalize;

            _UserInteractive = Environment.UserInteractive;
            String strExeLocation = System.Reflection.Assembly.GetExecutingAssembly().Location;
            String strExePath = System.IO.Path.GetDirectoryName(strExeLocation);
            _Path = Path.Combine(strExePath, "LOG");
            _LogBuilders = new Dictionary<String, StringBuilder>();
            _Filter = "*.txt";

            try
            {
                _TimerAutoSave.Elapsed += new System.Timers.ElapsedEventHandler(_TimerAutoSave_Elapsed);
                _TimerAutoSave.Interval = _LogAutoSaveTime * 1000;
                _TimerAutoSave.Enabled = false;
            }
            catch (Exception ex)
            {
            }
        }

        static void Log_Finalize(object sender, EventArgs e)
        {
            //Write("Log Class Finalize.");
            // clean it up
            if (_TimerAutoSave != null)
            {
                _TimerAutoSave.Stop();
                _TimerAutoSave.Enabled = false;
            }
            ForceSaveLog();
        }

        private static void _TimerAutoSave_Elapsed(object sender, ElapsedEventArgs e)
        {
            _TimerAutoSave.Stop();

            try
            {
                // TODO :
                // 強制儲存 Log 內容
                //Write("Force Save Log.");
                ForceSaveLog();
            }
            catch (Exception ex)
            {
                Log.Write("_TimerAutoSave_Elapsed (ForceSaveLog) Exception : " + ex.Message);
            }

            Double dInterval = GetOffsetInterval(DateTime.Now);

            _TimerAutoSave.Interval = dInterval;
            _TimerAutoSave.Start();
        }

        private static Double GetOffsetInterval(DateTime dtNow)
        {
            Int32 nOffset = (Int32)(_LogAutoSaveTime - (dtNow.Minute - ((Int32)(dtNow.Minute / _LogAutoSaveTime)) * _LogAutoSaveTime));
            DateTime dtNext = new DateTime(dtNow.Year, dtNow.Month, dtNow.Day, dtNow.Hour, dtNow.Minute, 0).AddMinutes(nOffset + (_LogAutoSaveTime / 2));
            TimeSpan tsNext = dtNext - DateTime.Now;
            Double dInterval = tsNext.TotalMilliseconds;
            return dInterval;
        }

        public static String SetPath(String strPath)
        {
            if (!Directory.Exists(strPath))
            {
                Directory.CreateDirectory(strPath);
            }
            _Path = strPath;
            Write(String.Format("Set Path to {0}", _Path));
            return _Path;
        }

        public static Boolean SetWriteDateTime(Boolean bWriteDateTime)
        {
            _WriteDateTime = bWriteDateTime;
            return _WriteDateTime;
        }

        public static String SetFilter(String strFilter)
        {
            _Filter = strFilter;
            Write(String.Format("Set Filter to {0}", _Filter));
            return _Filter;
        }

        public static Double SetCacheSize(Double dSize)
        {
            if (!Double.IsNaN(dSize))
            {
                if (dSize >= 0)
                {
                    _LogCacheSize = dSize;
                    Write(String.Format("Set Cache Size to {0}", _LogCacheSize.ToString()));
                }
            }
            return _LogCacheSize;
        }

        public static Double SetAutoSaveTime(Double dMinute)
        {
            if (!Double.IsNaN(dMinute))
            {
                if (dMinute >= 0)
                {
                    _LogAutoSaveTime = dMinute;
                    if (_TimerAutoSave != null)
                    {
                        _TimerAutoSave.Interval = _LogAutoSaveTime * 1000;
                        Write(String.Format("Set Auto Save Timer to {0} minites", _LogAutoSaveTime.ToString()));
                    }
                }
            }
            return _LogAutoSaveTime;
        }

        public static void CleanTempLog(Int32 nKeepDay)
        {
            String strLogPath = _Path;
            String strFilter = _Filter;

            if (Directory.Exists(strLogPath))
            {
                Int32 nDeleteFiles = 0;
                if (nKeepDay > 0)
                {
                    // 留 "前" 幾天
                    nKeepDay *= -1;
                }
                DateTime dtCheck = DateTime.Now.AddDays(nKeepDay);

                String[] files = Directory.GetFiles(strLogPath, strFilter, SearchOption.TopDirectoryOnly);
                foreach (String file in files)
                {
                    FileInfo aFile = new FileInfo(file);
                    if (aFile.Exists)
                    {
                        if (aFile.LastWriteTime < dtCheck)
                        {
                            // 刪除檔案
                            try
                            {
                                // TODO : *** 真的要刪除檔案了 ***
                                aFile.Delete();
                                nDeleteFiles++;
                            }
                            catch (Exception ex)
                            {
                            }
                        }
                    }
                    aFile = null;
                }

                Write(String.Format("  ****** CleanTempFiles {0}. ({1}, {2}, {3})", nDeleteFiles, strLogPath, strFilter, nKeepDay));
            }
        }

        public static void ForceSaveLog()
        {
            DateTime dtNow = DateTime.Now;
            String strToday = dtNow.ToString("yyyyMMdd");

            if (_LogBuilders != null)
            {
                List<String> removeKey = new List<String>();

                String strLogPath = _Path;
                if (!Directory.Exists(strLogPath))
                {
                    Directory.CreateDirectory(strLogPath);
                }
                foreach (String strKey in _LogBuilders.Keys)
                {
                    StringBuilder logBuilder = _LogBuilders[strKey];
                    if (logBuilder != null)
                    {
                        String dateTxt = System.IO.Path.Combine(strLogPath, strKey);
                        try
                        {
                            if (!System.IO.File.Exists(dateTxt))
                            {
                                lock (locker)
                                {
                                    System.IO.File.WriteAllText(dateTxt, logBuilder.ToString());
                                    logBuilder.Clear();
                                }
                            }
                            else
                            {
                                lock (locker)
                                {
                                    System.IO.File.AppendAllText(dateTxt, logBuilder.ToString());
                                    logBuilder.Clear();
                                }
                            }
                        }
                        catch (Exception ex)
                        {
#if DEBUG
                            Console.WriteLine("Error Occured : " + ex.Message);
#endif
                        }
                    }
                    if (!strKey.StartsWith(strToday))
                    {
                        // 不是今天的待存 Log, 回存完畢後可直接移除.
                        removeKey.Add(strKey);
                    }
                }

                if (removeKey.Count > 0)
                {
                    lock (locker)
                    {
                        for (Int32 i = 0; i < removeKey.Count; i++)
                        {
                            String strKey = removeKey[i];
                            if (_LogBuilders.ContainsKey(strKey))
                            {
                                _LogBuilders[strKey] = null;
                                _LogBuilders.Remove(strKey);
                            }
                        }
                    }
                }
                removeKey.Clear();
                removeKey = null;
            }
        }

        public static void Write(String strMessage)
        {
            Write(strMessage, null, false);
        }

        public static void Write(String strMessage, String ext)
        {
            Write(strMessage, ext, false);
        }

        public static void Write(String strMessage, String ext, Boolean bForceSave)
        {
            if (_UserInteractive)
            {
                Console.WriteLine(strMessage);
            }

            if (_TimerAutoSave != null)
            {
                if (!_TimerAutoSave.Enabled)
                {
                    _TimerAutoSave.Enabled = true;
                    _TimerAutoSave.Start();
                }
            }

            DateTime dtNow = DateTime.Now;
            String strWriteOutMessage = strMessage;
            if (_WriteDateTime)
            {
                strWriteOutMessage = dtNow.ToString("yyyy/MM/dd HH:mm:ss.fff") + "\t" + strWriteOutMessage;
            }

            StringBuilder logBuilder = null;
            String strKey = dtNow.ToString("yyyyMMdd") + ((ext != null) ? ("_" + ext) : "") + ".txt";
            if (_LogBuilders.ContainsKey(strKey))
            {
                logBuilder = _LogBuilders[strKey];
            }
            else
            {
                logBuilder = new StringBuilder();
                lock (locker)
                {
                    _LogBuilders.Add(strKey, logBuilder);
                }
            }
            lock (locker)
            {
                logBuilder.AppendLine(strWriteOutMessage);
            }

            if ((logBuilder.Length >= _LogCacheSize) || bForceSave)
            {
                String strLogPath = _Path;
                if (!Directory.Exists(strLogPath))
                {
                    Directory.CreateDirectory(strLogPath);
                }
                String dateTxt = System.IO.Path.Combine(strLogPath, strKey);
                try
                {
                    if (!System.IO.File.Exists(dateTxt))
                    {
                        lock (locker)
                        {
                            System.IO.File.WriteAllText(dateTxt, logBuilder.ToString());
                            logBuilder.Clear();
                        }
                    }
                    else
                    {
                        lock (locker)
                        {
                            System.IO.File.AppendAllText(dateTxt, logBuilder.ToString());
                            logBuilder.Clear();
                        }
                    }
                }
                catch (Exception ex)
                {
#if DEBUG
                    Console.WriteLine("Error Occured : " + ex.Message);
#endif
                }
            }
        }
    }
}
