#ifndef XAUDAILYFLOW_DIAGNOSTICS_MQH
#define XAUDAILYFLOW_DIAGNOSTICS_MQH

class XDFDiagnostics
  {
private:
   bool m_file_enabled;
   int m_handle;
public:
   XDFDiagnostics():m_file_enabled(false),m_handle(INVALID_HANDLE){}

   void Init(bool enable_file)
     {
      m_file_enabled=false;
      if(!enable_file)
         return;
      m_handle=FileOpen("XAUDailyFlowEA.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,';');
      if(m_handle==INVALID_HANDLE)
        {
         Print("XAUDailyFlowEA: file logging disabled (open failed)");
         return;
        }
      m_file_enabled=true;
      FileWrite(m_handle,"time","event","details");
     }

   void Log(const string event,const string details)
     {
      string line=event+" | "+details;
      Print("XAUDailyFlowEA: ",line);
      if(m_file_enabled && m_handle!=INVALID_HANDLE)
         FileWrite(m_handle,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),event,details);
     }

   void Shutdown()
     {
      if(m_handle!=INVALID_HANDLE)
         FileClose(m_handle);
      m_handle=INVALID_HANDLE;
      m_file_enabled=false;
     }
  };

#endif
